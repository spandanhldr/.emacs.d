;;; native-terminal.el --- Native shells for the Quake panel -*- lexical-binding: t; -*-
(require 'cl-lib)
(require 'subr-x)

(setq ghostel-module-directory
      (expand-file-name (concat "ghostel-modules/" system-configuration "/") user-emacs-directory)
      ghostel-module-auto-install 'download)

(defvar my/quake-shell nil
  "Optional shell executable or list of executable and arguments.
Nil selects working PowerShell on Windows and the login shell on Unix.")
(defvar my/quake-windows-shell-cache nil)
(defvar-local my/quake-native-active nil)
(defvar-local my/quake-source-directory nil)
(defvar-local my/quake-terminal-sessions nil)

(defun my/quake-shell-command ()
  "Resolve a native shell without assuming a WindowsApps alias works."
  (or my/quake-shell
      (if (eq system-type 'windows-nt)
          (or my/quake-windows-shell-cache
              (setq my/quake-windows-shell-cache
                    (let ((program
                           (cl-find-if
                            (lambda (exe)
                              (and exe
                                   (condition-case nil
                                       (eq 0 (call-process exe nil nil nil "-NoLogo" "-NoProfile"
                                                           "-NonInteractive" "-Command" "exit 0"))
                                     (error nil))))
                            (list (executable-find "pwsh.exe")
                                  (executable-find "powershell.exe")))))
                      (unless program (user-error "No working PowerShell executable found"))
                      (list program "-NoLogo"))))
        (or (let ((shell (getenv "SHELL")))
              (and shell (not (string-empty-p shell)) shell))
            shell-file-name "/bin/sh"))))

(defun my/quake-no-editor-completion ()
  "Return nil in a terminal to keep automatic Corfu activation out."
  (not (derived-mode-p 'ghostel-mode)))
(with-eval-after-load 'corfu
  (advice-add 'corfu--on :before-while #'my/quake-no-editor-completion))

(defvar my/quake-native-keymap
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "<escape>") #'my/quake-hide)
    (define-key map (kbd "C-q") #'ghostel-send-next-key)
    (define-key map (kbd "C-v") #'ghostel-yank)
    map))
(define-key my/quake-native-keymap (kbd "`") nil)
(define-key my/quake-native-keymap (kbd "<escape>") #'my/quake-hide)

(defvar my/quake-native-emulation-maps
  `((my/quake-native-active . ,my/quake-native-keymap)))

(defun my/quake-finish-native-close ()
  "Let Windows release a closing ConPTY event channel before reusing file handles.
Ghostel's own kill hook runs first and requests native process termination."
  (when (and (eq system-type 'windows-nt) my/quake-native-active
             (boundp 'ghostel--process) (processp ghostel--process))
    (let ((deadline (+ (float-time) 0.5)))
      (while (and (process-live-p ghostel--process) (< (float-time) deadline))
        (accept-process-output nil 0.01)))
    (accept-process-output nil 0.02)))

(defun my/quake-configure-native-terminal ()
  "Keep editor bindings, completion and the insert gate out of native shells."
  (when (bound-and-true-p my/modal-edit-mode) (my/modal-edit-mode -1))
  (when (bound-and-true-p my/vscode-keys-mode) (my/vscode-keys-mode -1))
  (when (bound-and-true-p corfu-mode) (corfu-mode -1))
  (setq-local cua-mode nil
              corfu-auto nil
              completion-at-point-functions nil
              display-line-numbers nil
              global-hl-line-mode nil
              desktop-save-buffer nil)
  (setq-local my/quake-native-active t)
  (add-hook 'kill-buffer-hook #'my/quake-finish-native-close 90 t)
  ;; This map must precede Ghostel's character-mode map for the two panel keys.
  (setq emulation-mode-map-alists
        (cons 'my/quake-native-emulation-maps
              (delq 'my/quake-native-emulation-maps emulation-mode-map-alists)))
  (setq-local header-line-format
              "  NATIVE CONSOLE    Esc: hide    Backtick: shell input    C-q: literal key")
  (setq-local face-remapping-alist
              '((default (:background "#10151f" :foreground "#d1e7db")))))

(defun my/quake-native-session-live-p (buffer)
  (and (buffer-live-p buffer)
       (with-current-buffer buffer
         (and (derived-mode-p 'ghostel-mode)
              (boundp 'ghostel--process) (process-live-p ghostel--process)))))

(defun my/quake-native-terminal (source directory)
  "Use a native shell in DIRECTORY, with separate sessions per editor/location.
Never inject a cd command into a running job or partially typed shell input."
  (require 'ghostel)
  (with-current-buffer source
    (let* ((entry (assoc directory my/quake-terminal-sessions))
           (buffer (cdr entry)))
      (unless (my/quake-native-session-live-p buffer)
        (let ((default-directory directory)
              (ghostel-shell (my/quake-shell-command))
              (ghostel-initial-input-mode 'char))
          (setq buffer (ghostel-create (format "*Console: %s*" (buffer-name)))))
        (setf (alist-get directory my/quake-terminal-sessions nil nil #'equal) buffer)
        (with-current-buffer buffer
          (my/quake-configure-native-terminal)
          (setq-local my/quake-owner source my/quake-source-directory directory)))
      buffer)))

;; A terminal resize after every animation pixel causes shell prompt reflow.
;; Resize the PTY once the panel settles, while the Emacs window slides smoothly.
(defun my/quake-defer-pty-resize (window &rest _)
  (not (and (window-live-p window)
            (buffer-local-value 'my/quake-native-active (window-buffer window))
            (frame-parameter (window-frame window) 'my/quake-timer))))
(with-eval-after-load 'ghostel
  (advice-add 'ghostel--adjust-size :before-while #'my/quake-defer-pty-resize))

(provide 'native-terminal)
