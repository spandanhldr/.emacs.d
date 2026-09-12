;;; vscode-keys.el --- Windows VS Code editing shortcuts -*- lexical-binding: t; -*-

;; Reference: https://code.visualstudio.com/shortcuts/keyboard-shortcuts-windows.pdf
;; Emacs equivalents: quick open uses project files, Explorer uses Dired,
;; the terminal uses Eshell, and settings opens init.el. Debugger/extension
;; UI commands require separate integrations and are intentionally not mapped.

(require 'cl-lib)
(require 'subr-x)
(require 'newcomment)
(require 'xref)
(require 'hideshow)

(use-package multiple-cursors)
(use-package expand-region)

;; Keep CUA selection behavior; handle copy/cut ourselves, including whole lines.
(setq cua-enable-cua-keys nil)
(cua-mode -1)
(cua-mode 1)
(setq shift-select-mode t)

(defconst my/vscode-dialog-script
  (expand-file-name "save-file-dialog.ps1"
                    (file-name-directory (or load-file-name buffer-file-name)))
  "Path to the shared modern Windows Open and Save As dialog helper.")

(defun my/vscode-save-default-name ()
  "Return the current filename, or a Windows-safe untitled buffer name."
  (if buffer-file-name
      (file-name-nondirectory buffer-file-name)
    (let ((name (replace-regexp-in-string "[<>:\"/\\\\|?*]" "" (buffer-name))))
      (setq name (replace-regexp-in-string "[ .]+\\'" "" name))
      (if (string-empty-p name) "Untitled" name))))

(defun my/vscode-windows-file-dialog (directory filename mode)
  "Show a modern Windows file dialog in MODE (Open or Save)."
  (let ((owner (format "%s" (or (frame-parameter nil 'window-id) 0)))
        (coding-system-for-read 'utf-8)
        (coding-system-for-write 'utf-8))
    (with-temp-buffer
      ;; Pass arguments directly, without interpolating filenames into shell code.
      (let ((status (apply #'call-process "powershell.exe" nil t nil
                                  "-NoProfile" "-STA" "-WindowStyle" "Hidden"
                                  ;; Permit this local helper for this process only.
                                  "-ExecutionPolicy" "Bypass"
                                  "-File" my/vscode-dialog-script
                                  "-InitialDirectory" (expand-file-name directory)
                                  "-Mode" mode
                                  "-OwnerHandle" owner
                                  ;; Omit an empty argument: Windows PowerShell's
                                  ;; command-line parser otherwise consumes the next flag.
                                  (when (and filename (not (string-empty-p filename)))
                                    (list "-FileName" filename)))))
        (cond ((equal status 2) (signal 'quit nil))
              ((and (equal status 0) (> (buffer-size) 0)) (buffer-string))
              (t (error "%s dialog failed: %s" mode (buffer-string))))))))

(defun my/vscode-windows-save-dialog (directory filename)
  (my/vscode-windows-file-dialog directory filename "Save"))

(defun my/vscode-modern-file-dialog (original prompt directory
                                           &optional filename mustmatch only-directory)
  "Use the shared modern picker for other graphical file-dialog requests."
  (if (and (eq system-type 'windows-nt) (display-graphic-p)
           (not only-directory) (not (file-remote-p directory)))
      (my/vscode-windows-file-dialog
       directory (and filename (file-name-nondirectory filename))
       (if mustmatch "Open" "Save"))
    (funcall original prompt directory filename mustmatch only-directory)))

(when (fboundp 'x-file-dialog)
  (advice-add 'x-file-dialog :around #'my/vscode-modern-file-dialog))

(defun my/vscode-read-file-dialog (prompt &optional mustmatch)
  "Read a file using the native dialog when the display supports it."
  (let* ((filename (and (not mustmatch) (my/vscode-save-default-name)))
         (directory (if (and filename buffer-file-name)
                        (file-name-directory buffer-file-name)
                      default-directory))
         (use-dialog-box t)
        (use-file-dialog t)
        ;; Keyboard commands normally bypass the native file dialog.
        (last-nonmenu-event nil)
        (read-file-name-function #'read-file-name-default))
    (if (and (eq system-type 'windows-nt) (display-graphic-p)
             (not (file-remote-p directory)))
        (if mustmatch
            (my/vscode-windows-file-dialog directory nil "Open")
          (my/vscode-windows-save-dialog directory filename))
      (read-file-name prompt directory
                      (and filename (expand-file-name filename directory))
                      mustmatch filename))))

(defun my/vscode-open-file ()
  "Choose an existing file in a separate native Open dialog."
  (interactive)
  (let ((file (my/vscode-read-file-dialog "Open file: " t)))
    (find-file-existing file)))

(defun my/vscode-save-as ()
  "Choose a destination in a separate native Save As dialog."
  (interactive)
  (let ((file (my/vscode-read-file-dialog "Save file as: ")))
    (write-file file t)))

(defun my/vscode-save ()
  "Save the current file, asking for a destination for an untitled buffer."
  (interactive)
  (if buffer-file-name (save-buffer) (my/vscode-save-as)))

(defun my/vscode-line-bounds ()
  "Return whole-line bounds for the selection or current line."
  (let ((beg (if (use-region-p) (region-beginning) (point)))
        (end (if (use-region-p) (region-end) (point))))
    (cons (save-excursion (goto-char beg) (line-beginning-position))
          (save-excursion
            (goto-char end)
            (if (and (> end beg) (bolp)) (point)
              (min (point-max) (1+ (line-end-position))))))))

(defun my/vscode-copy ()
  "Copy selection, or the current line when there is no selection."
  (interactive)
  (if (use-region-p)
      (kill-ring-save (region-beginning) (region-end))
    (let ((bounds (my/vscode-line-bounds)))
      (kill-new (concat (buffer-substring-no-properties (car bounds) (cdr bounds))
                        (if (eq (char-before (cdr bounds)) ?\n) "" "\n"))))))

(defun my/vscode-cut ()
  "Cut selection, or the current line when there is no selection."
  (interactive)
  (if (use-region-p)
      (kill-region (region-beginning) (region-end))
    (let ((bounds (my/vscode-line-bounds)))
      (my/vscode-copy)
      (delete-region (car bounds) (cdr bounds)))))

(defun my/vscode-delete-line ()
  (interactive)
  (let ((bounds (my/vscode-line-bounds)))
    (delete-region (car bounds) (cdr bounds))))

(defun my/vscode-move-lines (direction)
  "Move selected lines by DIRECTION, preserving the selection."
  (let* ((bounds (my/vscode-line-bounds))
         (beg (car bounds)) (end (cdr bounds))
         (selected (use-region-p)) (offset (- (point) beg)))
    (unless (or (and (< direction 0) (= beg (point-min)))
                (and (> direction 0) (= end (point-max))))
      (atomic-change-group
        (let ((text (delete-and-extract-region beg end)))
          (goto-char beg)
          (forward-line direction)
          (unless (bolp) (insert "\n"))
          (let ((start (point)))
            (insert text)
            (unless (or (bolp) (eobp)) (insert "\n"))
            (if selected
                (progn (set-mark start) (activate-mark))
              (goto-char (+ start offset)))))))))

(defun my/vscode-move-up () (interactive) (my/vscode-move-lines -1))
(defun my/vscode-move-down () (interactive) (my/vscode-move-lines 1))

(defun my/vscode-copy-lines (above)
  (let* ((bounds (my/vscode-line-bounds))
         (text (buffer-substring (car bounds) (cdr bounds)))
         (offset (- (point) (car bounds))))
    (goto-char (if above (car bounds) (cdr bounds)))
    (unless (bolp) (insert "\n"))
    (let ((start (point)))
      (insert text)
      (unless (string-suffix-p "\n" text) (insert "\n"))
      (goto-char (+ start offset)))))
(defun my/vscode-copy-up () (interactive) (my/vscode-copy-lines t))
(defun my/vscode-copy-down () (interactive) (my/vscode-copy-lines nil))

(defun my/vscode-line-below () (interactive) (end-of-line) (newline-and-indent))
(defun my/vscode-line-above ()
  (interactive) (beginning-of-line) (open-line 1) (indent-according-to-mode))
(defun my/vscode-select-line ()
  (interactive)
  (unless (use-region-p) (beginning-of-line) (set-mark (point)))
  (forward-line 1)
  (activate-mark))
(defun my/vscode-indent (outdent)
  (let ((bounds (my/vscode-line-bounds)))
    (indent-rigidly (car bounds) (cdr bounds) (* (if outdent -1 1) tab-width))))
(defun my/vscode-indent-lines () (interactive) (my/vscode-indent nil))
(defun my/vscode-outdent-lines () (interactive) (my/vscode-indent t))
(defun my/vscode-comment ()
  (interactive)
  (let ((bounds (my/vscode-line-bounds)))
    (comment-or-uncomment-region (car bounds) (cdr bounds))))
(defun my/vscode-add-comment ()
  (interactive)
  (let ((bounds (my/vscode-line-bounds))) (comment-region (car bounds) (cdr bounds))))
(defun my/vscode-uncomment ()
  (interactive)
  (let ((bounds (my/vscode-line-bounds))) (uncomment-region (car bounds) (cdr bounds))))
(defun my/vscode-match-bracket ()
  (interactive)
  (cond ((eq (char-syntax (or (char-after) 32)) ?\() (forward-sexp))
        ((eq (char-syntax (or (char-before) 32)) ?\)) (backward-sexp))
        (t (backward-up-list))))

(defun my/vscode-new-file ()
  "Create an untitled editor only on an explicit New File command."
  (interactive)
  (unless (eq (current-buffer) (get-buffer "*Welcome*"))
    (tab-bar-new-tab))
  (switch-to-buffer (generate-new-buffer "*scratch-new*"))
  (text-mode))
(defun my/vscode-close-editor ()
  "Close current buffer with normal save prompts, then its tab if possible."
  (interactive)
  (when (kill-buffer (current-buffer))
    (if (> (length (tab-bar-tabs)) 1)
        (tab-bar-close-tab)
      (switch-to-buffer (my/startup-buffer)))))
(defun my/vscode-quick-open ()
  (interactive)
  (require 'project)
  (call-interactively (if (project-current) #'project-find-file #'find-file)))
(defun my/vscode-settings ()
  (interactive) (find-file (expand-file-name "init.el" user-emacs-directory)))
(defun my/vscode-keybindings ()
  (interactive) (find-file (expand-file-name "vscode-keys.el" user-emacs-directory)))
(defun my/vscode-save-all () (interactive) (save-some-buffers t))
(defun my/vscode-format ()
  (interactive)
  (if (bound-and-true-p eglot--managed-mode)
      (eglot-format-buffer)
    (indent-region (point-min) (point-max))))
(defun my/vscode-format-selection ()
  (interactive)
  (unless (use-region-p) (user-error "Select text to format"))
  (if (bound-and-true-p eglot--managed-mode)
      (eglot-format (region-beginning) (region-end))
    (indent-region (region-beginning) (region-end))))
(defun my/vscode-fold () (interactive) (hs-minor-mode 1) (hs-hide-block))
(defun my/vscode-unfold () (interactive) (hs-minor-mode 1) (hs-show-block))
(defun my/vscode-fold-all () (interactive) (hs-minor-mode 1) (hs-hide-all))
(defun my/vscode-unfold-all () (interactive) (hs-minor-mode 1) (hs-show-all))
(defun my/vscode-terminal () (interactive) (eshell))
(defun my/vscode-new-terminal () (interactive) (eshell t))
(defun my/vscode-select-next ()
  "Select the word at point first, then add its next occurrence."
  (interactive)
  (if (use-region-p)
      (mc/mark-next-like-this 1)
    (let ((bounds (bounds-of-thing-at-point 'word)))
      (unless bounds (user-error "No word at point"))
      (goto-char (car bounds)) (push-mark (cdr bounds) t t))))
(defun my/vscode-language ()
  (interactive)
  (call-interactively
   (intern (completing-read "Major mode: " obarray
                            (lambda (symbol)
                              (and (commandp symbol)
                                   (string-suffix-p "-mode" (symbol-name symbol)))) t))))

(defvar my/vscode-keys-mode-map
  (let ((map (make-sparse-keymap)))
    (dolist (binding
             '(("C-s" . my/vscode-save) ("C-S-s" . my/vscode-save-as)
               ("C-n" . my/vscode-new-file) ("C-o" . my/vscode-open-file)
               ("C-p" . my/vscode-quick-open)
               ("C-S-p" . execute-extended-command) ("<f1>" . execute-extended-command)
               ("C-S-n" . make-frame-command) ("C-S-w" . delete-frame)
               ("C-," . my/vscode-settings)
               ("C-a" . mark-whole-buffer) ("C-c" . my/vscode-copy)
               ("C-x" . my/vscode-cut) ("C-v" . yank)
               ("C-z" . undo-only) ("C-y" . undo-redo) ("C-S-z" . undo-redo)
               ("C-w" . my/vscode-close-editor) ("C-<f4>" . my/vscode-close-editor)
               ("C-f" . isearch-forward) ("C-h" . query-replace)
               ("<f3>" . isearch-repeat-forward) ("S-<f3>" . isearch-repeat-backward)
               ("C-S-f" . project-find-regexp) ("C-S-h" . project-query-replace-regexp)
               ("C-g" . goto-line) ("C-t" . xref-find-apropos)
               ("C-S-o" . consult-imenu) ("M-<left>" . xref-go-back)
               ("M-<right>" . xref-go-forward)
               ("C-<tab>" . tab-bar-switch-to-next-tab)
               ("C-S-<tab>" . tab-bar-switch-to-prev-tab)
               ("C-<prior>" . tab-bar-switch-to-prev-tab)
               ("C-<next>" . tab-bar-switch-to-next-tab)
               ("C-S-t" . tab-bar-undo-close-tab)
               ("C-\\" . split-window-right)
               ("M-<up>" . my/vscode-move-up) ("M-<down>" . my/vscode-move-down)
               ("M-S-<up>" . my/vscode-copy-up) ("M-S-<down>" . my/vscode-copy-down)
               ("C-S-k" . my/vscode-delete-line) ("C-l" . my/vscode-select-line)
               ("C-<return>" . my/vscode-line-below)
               ("C-S-<return>" . my/vscode-line-above)
               ("C-]" . my/vscode-indent-lines) ("<backtab>" . my/vscode-outdent-lines)
               ("C-/" . my/vscode-comment) ("M-S-a" . my/vscode-comment)
               ("C-S-\\" . my/vscode-match-bracket)
               ("M-z" . toggle-truncate-lines)
               ("C-<home>" . beginning-of-buffer) ("C-<end>" . end-of-buffer)
               ("C-<up>" . scroll-down-line) ("C-<down>" . scroll-up-line)
               ("C-d" . my/vscode-select-next) ("C-S-l" . mc/mark-all-like-this)
               ("C-<f2>" . mc/mark-all-symbols-like-this)
               ("C-M-<up>" . mc/mark-previous-lines) ("C-M-<down>" . mc/mark-next-lines)
               ("M-S-i" . mc/edit-ends-of-lines)
               ("M-S-<right>" . er/expand-region) ("M-S-<left>" . er/contract-region)
               ("C-SPC" . completion-at-point) ("C-S-SPC" . eldoc)
               ("M-S-f" . my/vscode-format) ("C-." . eglot-code-actions)
               ("<f2>" . eglot-rename) ("<f12>" . xref-find-definitions)
               ("S-<f12>" . xref-find-references)
               ("C-S-m" . flymake-show-buffer-diagnostics)
               ("<f8>" . flymake-goto-next-error) ("S-<f8>" . flymake-goto-prev-error)
               ("C-S-[" . my/vscode-fold) ("C-S-]" . my/vscode-unfold)
               ("C-S-e" . dired-jump) ("C-S-g" . vc-dir)
               ("C-`" . my/vscode-terminal) ("C-~" . my/vscode-new-terminal)
               ("<f11>" . toggle-frame-fullscreen)
               ("C-=" . text-scale-increase) ("C--" . text-scale-decrease)
               ("<escape>" . keyboard-quit)))
      (define-key map (kbd (car binding)) (cdr binding)))
    ;; C-[ normally aliases ESC in Emacs; preserve Meta key sequences.
    ;; Handle the distinct GUI event where available, with Shift+Tab fallback.
    (define-key map (vector (logior (ash 1 26) ?\[)) #'my/vscode-outdent-lines)
    (define-key map (kbd "C-k") (make-sparse-keymap))
    (dolist (binding '(("C-s" . my/vscode-keybindings) ("s" . my/vscode-save-all)
                       ("C-c" . my/vscode-add-comment) ("C-u" . my/vscode-uncomment)
                       ("C-f" . my/vscode-format-selection) ("C-x" . delete-trailing-whitespace)
                       ("C-0" . my/vscode-fold-all) ("C-j" . my/vscode-unfold-all)
                       ("C-i" . eldoc-doc-buffer) ("m" . my/vscode-language)))
      (define-key map (kbd (concat "C-k " (car binding))) (cdr binding)))
    map))

(define-minor-mode my/vscode-keys-mode
  "Use Windows VS Code shortcuts in editing buffers."
  :lighter " VSKeys" :keymap my/vscode-keys-mode-map)
(defun my/vscode-enable-in-editor ()
  ;; Preserve minibuffer, Dired, help and shell-specific interaction.
  (unless (or (minibufferp) (derived-mode-p 'special-mode 'comint-mode 'eshell-mode))
    (my/vscode-keys-mode 1)))
(define-globalized-minor-mode my/global-vscode-keys-mode
  my/vscode-keys-mode my/vscode-enable-in-editor)
(my/global-vscode-keys-mode 1)

;; Also make file dialogs available from help and other non-editing buffers.
(global-set-key (kbd "C-o") #'my/vscode-open-file)
(global-set-key (kbd "C-s") #'my/vscode-save)
(global-set-key (kbd "C-S-s") #'my/vscode-save-as)

;; Search and completion transient maps take precedence over the editing layer.
(define-key isearch-mode-map (kbd "<escape>") #'isearch-exit)
(define-key isearch-mode-map (kbd "<f3>") #'isearch-repeat-forward)
(define-key isearch-mode-map (kbd "S-<f3>") #'isearch-repeat-backward)
(define-key isearch-mode-map (kbd "C-v") #'isearch-yank-kill)
(with-eval-after-load 'corfu
  (define-key corfu-map (kbd "<escape>") #'corfu-quit)
  (define-key corfu-map (kbd "TAB") #'corfu-insert)
  (define-key corfu-map (kbd "<tab>") #'corfu-insert))

;; Remove the old advice as well when re-evaluating an already running config.
(advice-remove 'kill-buffer #'my/kill-buffer-advice)

(provide 'vscode-keys)
;;; vscode-keys.el ends here
