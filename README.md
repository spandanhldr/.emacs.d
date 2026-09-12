# Portable Emacs configuration

Use Emacs 29.1 or newer and Git. Put this repository in your Emacs user directory
(`~/.emacs.d` on Unix; `~/.config/emacs` also works when selected by Emacs).
On Windows, use the directory reported by `user-emacs-directory`.
The first startup needs network access to install packages through Straight.
Do not copy Straight build artifacts or session files between operating systems.

The shared Ctrl shortcuts, editing commands, session restoration, 12-hour clock,
and rotating Pokemon, Beyblade and Bakugan welcome scenes use the same Lisp on
Windows, macOS, Linux and BSD. On macOS Control stays Control and Option is Meta.
Font selection uses the first installed family: Cascadia Code, DejaVu Sans Mono,
Menlo, Liberation Mono, then Monospace. Install the same font on each machine for
closer visual consistency. macOS imports the login-shell executable search path.

## Display requirements and limits

For the full interface use a graphical Emacs build with SVG support and child
frames. Native Windows dialogs use the included PowerShell helper; macOS and
Unix use Emacs' native file chooser. Linux/BSD should use a GTK build for modern
file dialogs. Dialog styling belongs to the OS/toolkit and cannot be identical
across operating systems. See the [Emacs manual](https://www.gnu.org/software/emacs/manual/html_node/emacs/Visiting.html).

Terminal or non-SVG builds retain a text welcome screen, clock and actions.
The command palette falls back to Vertico in the minibuffer where child frames
are unavailable. Terminals and desktop window managers may intercept shortcuts
or merge Ctrl+Shift keys; F1 also opens the palette. SVG animation uses native
Emacs SVG support, not GPU rendering or raster artwork.

Install `pylsp` or `pyright-langserver` for Python and `clangd` or `ccls` for C/C++
on PATH to enable automatic language-server features. Editing works without them.
Native compilation uses up to four background processes based on available CPUs.

## Validation

Run from this directory:

```sh
emacs --batch -Q -l vscode-keys-tests.el
emacs --batch -Q -l editor-session-tests.el
emacs --batch -Q -l welcome-tests.el
emacs --batch -Q -l portability-tests.el
emacs --batch -Q -l editor-behavior-tests.el
emacs --batch -Q -l command-palette-tests.el
```

The palette tests require packages installed by the first startup. SVG rendering
tests require an SVG-capable build. Platform-routing tests simulate OS selection;
they do not certify native GUI behavior on a different operating system.
Validation for this revision was performed on Windows with Emacs 31.1;
macOS, Linux and BSD native GUI testing remains outstanding.

Session contents, history, generated caches and installed packages are ignored
by Git; only configuration, its dialog helper, documentation and tests are shared.

Session restore follows the editors in open tabs across frames. Closing a tab
excludes its hidden buffer from the next session, and an active Welcome screen
stays active on restart, including when other file tabs remain open.

Discarding a file buffer removes its auto-save recovery copy. Confirmed normal
exit also removes file recovery copies and prevents shutdown from recreating
them. Canceling close/exit retains recovery; crash recovery remains enabled.
Tab accepts the selected completion (or the first suggestion) in one press.

## Insert gate and top console

Editors start in NORMAL (locked) mode. Press `i` to enter INSERT and `Esc` to
lock editing again. This is an insert gate, not the full Vim command system.
Existing Ctrl shortcuts remain available; commands that change text need INSERT.
Read-only files remain protected. Help, Dired, minibuffers and shells keep their
normal interaction.

In NORMAL, the backtick key (&#96;) opens the animated top console.
Esc hides it; backtick is ordinary shell input. `C-q` followed by a key sends that key literally to the shell.
Tilde is ordinary shell input. Ctrl+backtick opens the same console from INSERT;
Ctrl+Shift+backtick starts a fresh shell.

The console uses [Ghostel](https://dakra.github.io/ghostel/) with real native PTYs:
PowerShell (preferring working PowerShell 7) on Windows, and `$SHELL` on Unix,
including Bash/Zsh and the user's shell profiles. Set `my/quake-shell` to an
executable or a list of executable and arguments to override the selection.
Tab, Ctrl+L and other shell editing keys go to the shell. Emacs/Corfu suggestions
are disabled here; shell completion and any predictions come from PSReadLine
or the configured Unix shell. The backend requires an Emacs build with dynamic
modules and a matching Ghostel module. Official release binaries download on
first use into the ignored, architecture-specific `ghostel-modules/` directory.
Platforms without a prebuilt module need Ghostel's supported source build.

Each editor/location retains a separate console. Switching editors updates the
visible console without stealing focus. New consoles start in the current file's
directory, or `default-directory` for untitled buffers. Save As to another folder
selects a console in that folder, preserving the old shell and any running job.
Manual directory changes within a shell remain under the user's control.
The panel uses eased pixel resizing in graphical Emacs and line resizing in a
terminal. The PTY resizes after the slide finishes, avoiding repeated prompt
reflow during the animation. Frame resizing remains supported.

Run `emacs --batch -Q -l modal-terminal-tests.el` and
`emacs --batch -Q -l native-terminal-tests.el` for modal/console checks after
installing the packages and native module. The native tests execute real shells;
PowerShell clear/completion tests run only on Windows. Shell-selection checks
for Unix are simulated, not a claim of native testing on those operating systems.

## Jupyter notebooks

`.ipynb` files open directly as editable cells in Emacs. Code has Python syntax
highlighting/indentation and kernel completion; results, errors and PNG plots
appear below the cells. Markdown supports a basic native preview of headings,
bold and inline code. Notebook metadata and rich output data survive saving.
Use `my/notebook-new` in the command palette to create a notebook.

| Shortcut | Action |
| --- | --- |
| Enter or i / Esc | Edit cell / command mode |
| Shift+Enter | Run and select next cell (create one at the end) |
| Ctrl+Enter or F5 | Run current cell |
| Alt+Enter | Run and insert a cell below |
| Ctrl+Shift+Enter | Run all cells |
| A / B in command mode | Insert above / below |
| D, D / Z in command mode | Delete cell / undo cell deletion |
| M / Y in command mode | Markdown / code cell |
| Up, Down or K, J in command mode | Previous / next cell |
| Tab in edit mode | Kernel completion when idle, otherwise indentation |
| Ctrl+S | Save valid notebook JSON, including outputs |

The header has Run, Run All, Interrupt, Restart, Kernel and Python controls.
Cells share a persistent local kernel, started on first execution in the
notebook's directory. Closing the buffer or Emacs shuts down its kernel.

No browser, JupyterLab server or Anaconda is required. Use any standard Python
or virtual environment with `python -m pip install jupyter_client ipykernel`.
Interpreter selection checks `my/notebook-python`, an activated `VIRTUAL_ENV`,
a project `.venv`, then PATH. The Python header control (or
`my/notebook-select-python`) overrides it for the current notebook. The selected
interpreter runs Python cells even if a user-wide kernel spec points elsewhere.
Other installed Jupyter kernels are available through the Kernel control.

The current machine's PATH happens to select Anaconda's Python; choosing another
interpreter removes that usage. Anaconda paths are not embedded in the config.
JavaScript widgets, browser HTML rendering, remote servers and notebook debugging
are not implemented. Markdown preview is intentionally a basic renderer.
Save explicitly with Ctrl+S: ordinary Emacs auto-save is disabled for the rendered
notebook buffer to prevent writing presentation text as `.ipynb` JSON. Text undo
is available within cells; structural edits reset text undo, with Z restoring
deleted cells. Interrupting blocking native calls can depend on the kernel/OS.

Run `emacs --batch -Q -l notebooks-tests.el` for editor checks and
`emacs --batch -Q -l notebook-kernel-tests.el` for real execution, completion,
interruption and saved-format validation (the latter also needs `nbformat`).

## Floating find and replace


Ctrl+F opens a dark floating Find panel; Ctrl+R (or Ctrl+H) opens Find and
Replace. Selected text seeds the query. Matches highlight live in the current
file, with a match counter, Enter/Shift+Enter navigation, case/whole-word/regexp
toggles and Replace/Replace All buttons. Esc closes the panel and returns to the
file. The panel repositions when its parent frame resizes; terminal Emacs uses
a top pane. Regular expressions use Emacs syntax. Highlighting is capped at
2,000 matches for responsiveness; Replace All still covers the whole buffer.
Explicit replacement works from NORMAL mode, while genuinely read-only files
remain protected. Run `emacs --batch -Q -l search-panel-tests.el` for checks.
