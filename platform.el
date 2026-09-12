;;; platform.el --- Capability-based platform integration -*- lexical-binding: t; -*-
(require 'cl-lib)
(require 'subr-x)

(defun my/configure-frame-font (frame)
  "Select the first installed monospace font, including for daemon clients."
  (when (display-graphic-p frame)
    (with-selected-frame frame
      (when-let* ((family (cl-find-if
                          (lambda (name) (find-font (font-spec :family name) frame))
                          '("Cascadia Code" "DejaVu Sans Mono" "Menlo" "Liberation Mono" "Monospace"))))
        (set-face-attribute 'default frame :family family :height 120)))))

;; Keep physical Control shortcuts identical; Option/Alt supplies Meta.
(when (eq system-type 'darwin)
  (setq ns-control-modifier 'control ns-option-modifier 'meta
        ns-command-modifier 'super
        mac-control-modifier 'control mac-option-modifier 'meta
        mac-command-modifier 'super))

(defun my/eglot-ensure-if-installed ()
  "Start the configured language server only when its executable is available."
  (require 'eglot)
  (let* ((modes (cond ((derived-mode-p 'python-mode 'python-ts-mode) '("pylsp" "pyright-langserver"))
                      ((derived-mode-p 'c-mode 'c++-mode 'c-ts-mode 'c++-ts-mode) '("clangd" "ccls"))))
         (server (cl-find-if #'executable-find modes)))
    (when server
      (let ((eglot-server-programs
             (cons (cons major-mode (if (equal server "pyright-langserver")
                                       (list server "--stdio") (list server)))
                   eglot-server-programs)))
        (eglot-ensure)))))
(provide 'platform)
