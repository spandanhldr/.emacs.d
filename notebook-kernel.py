"""Local Jupyter kernel bridge: JSON lines over stdio, no HTTP server/browser."""
import argparse
import json
import os
import queue
import sys
import threading


def main():
    sys.stdin.reconfigure(encoding="utf-8")
    sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser()
    parser.add_argument("--kernel", default="python3")
    parser.add_argument("--list", action="store_true")
    args = parser.parse_args()
    from jupyter_client import KernelManager
    from jupyter_client.kernelspec import KernelSpecManager

    class EnvironmentKernels(KernelSpecManager):
        def get_kernel_spec(self, name):
            spec = super().get_kernel_spec(name)
            if name == "python3":
                spec.argv = [sys.executable, "-m", "ipykernel_launcher", "-f", "{connection_file}"]
            return spec

    specs = EnvironmentKernels()
    if args.list:
        print(json.dumps({k: v["spec"]["display_name"] for k, v in specs.get_all_specs().items()}))
        return
    lock = threading.Lock()

    def emit(kind, **values):
        with lock:
            print(json.dumps(dict(event=kind, **values)), flush=True)

    manager = KernelManager(kernel_name=args.kernel, kernel_spec_manager=specs)
    work = queue.Queue()
    stopping = threading.Event()
    client = None

    def execute_loop():
        nonlocal client
        try:
            manager.start_kernel(cwd=os.getcwd(), stdout=sys.stderr, stderr=sys.stderr)
            client = manager.client()
            client.start_channels()
            client.wait_for_ready(timeout=30)
            emit("ready")
            while not stopping.is_set():
                command = work.get()
                if command is None:
                    break
                request_id = command["id"]
                if command.get("op") == "complete":
                    msg_id = client.complete(command["code"], command["cursor"])
                    while True:
                        reply = client.get_shell_msg(timeout=10)
                        if reply.get("parent_header", {}).get("msg_id") == msg_id:
                            break
                    emit("complete", id=request_id, content=reply["content"])
                    continue
                msg_id = client.execute(command["code"], allow_stdin=True, stop_on_error=False)
                emit("busy", id=request_id)
                while not stopping.is_set():
                    try:
                        prompt = client.get_stdin_msg(timeout=0)
                        if prompt.get("parent_header", {}).get("msg_id") == msg_id:
                            emit("input", id=request_id, **prompt["content"])
                    except queue.Empty:
                        pass
                    try:
                        msg = client.get_iopub_msg(timeout=0.1)
                    except queue.Empty:
                        if not manager.is_alive():
                            raise RuntimeError("Kernel exited unexpectedly")
                        continue
                    if msg.get("parent_header", {}).get("msg_id") != msg_id:
                        continue
                    kind, content = msg["header"]["msg_type"], msg["content"]
                    if kind == "status" and content["execution_state"] == "idle":
                        while True:
                            reply = client.get_shell_msg(timeout=10)
                            if reply.get("parent_header", {}).get("msg_id") == msg_id:
                                break
                        emit("done", id=request_id, status=reply["content"].get("status"))
                        break
                    if kind in ("stream", "display_data", "execute_result", "error",
                                "clear_output", "update_display_data", "execute_input"):
                        emit(kind, id=request_id, content=content)
        except Exception as exc:
            emit("fatal", message=str(exc))
        finally:
            if client:
                client.stop_channels()
            if manager.has_kernel:
                manager.shutdown_kernel(now=True)
            emit("stopped")

    worker = threading.Thread(target=execute_loop, daemon=True)
    worker.start()
    try:
        for line in sys.stdin:
            command = json.loads(line)
            op = command.get("op")
            if op in ("execute", "complete"):
                work.put(command)
            elif op == "interrupt" and manager.has_kernel:
                manager.interrupt_kernel()
            elif op == "input" and client:
                client.input(command.get("value", ""))
            elif op == "shutdown":
                break
    finally:
        stopping.set()
        work.put(None)
        worker.join(timeout=40)


if __name__ == "__main__":
    main()
