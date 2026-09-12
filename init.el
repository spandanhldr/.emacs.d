;;; init.el --- Personal Emacs configuration -*- lexical-binding: t; -*-

(when (version< emacs-version "29.1")
  (error "This configuration requires Emacs 29.1 or newer"))
(load (expand-file-name "platform.el" user-emacs-directory) nil 'nomessage)

;; BOOTSTRAP: STRAIGHT.EL & USE-PACKAGE
(defvar bootstrap-version)
(let ((bootstrap-file
       (expand-file-name "straight/repos/straight.el/bootstrap.el" user-emacs-directory))
      (bootstrap-version 6))
  (unless (file-exists-p bootstrap-file)
    (with-current-buffer
        (url-retrieve-synchronously
         "https://raw.githubusercontent.com/raxod502/straight.el/develop/install.el"
         'silent 'inhibit-cookies)
      (goto-char (point-max))
      (eval-print-last-sexp)))
  (load bootstrap-file nil 'nomessage))

;; Install use-package and integrate with straight.el
(straight-use-package 'use-package)
(setq straight-use-package-by-default t)


;; UI & BASIC PREFERENCES
(menu-bar-mode -1)
(when (fboundp 'tool-bar-mode) (tool-bar-mode -1))
(setq inhibit-startup-screen t)


;; Line numbers & highlighting
(global-display-line-numbers-mode -1)
(add-hook 'prog-mode-hook #'display-line-numbers-mode)
(add-hook 'text-mode-hook #'display-line-numbers-mode)
(global-hl-line-mode 1)
(column-number-mode t)

;; TAB = 4 spaces 
(setq-default tab-width 4)
(setq-default indent-tabs-mode nil)
(setq tab-always-indent 'complete)

;; Parenthesis matching
(electric-pair-mode t)
(show-paren-mode t)


;; Smooth scrolling
(setq scroll-step 1
      scroll-conservatively 10000)
(when (fboundp 'pixel-scroll-precision-mode) (pixel-scroll-precision-mode 1))


;; File handling behavior
(delete-selection-mode 1)  ; Typing replaces selection
(setq make-backup-files nil) ; Stop creating ~ files
(save-place-mode 1)        ; Save cursor position
(savehist-mode 1)          ; Save command history
(global-auto-revert-mode 1); Auto-refresh buffers if file changes on disk
(setq auto-revert-avoid-polling t
      read-process-output-max (* 1024 1024))
(global-so-long-mode 1)


;; THEME & FONTS
(use-package gruvbox-theme
  :config
  (load-theme 'gruvbox-dark-hard t))

(add-hook 'after-make-frame-functions #'my/configure-frame-font)
(my/configure-frame-font (selected-frame))

;; Finder-launched Emacs needs the login shell's executable search path.
(when (eq system-type 'darwin)
  (use-package exec-path-from-shell
    :config (exec-path-from-shell-initialize)))

;; CUA MODE (Windows/Modern Keybindings)
;; This automatically handles:
;; C-c (Copy), C-v (Paste), C-x (Cut), C-z (Undo)
;; It intelligently keeps C-x as a command prefix when no text is selected.
(cua-mode 1)


;; CUSTOM KEYBINDINGS (VS Code Style overrides)
;; C-s = SAVE
(global-set-key (kbd "C-s") 'save-buffer)
;; C-f = SEARCH (Replacing standard forward-char)
(global-set-key (kbd "C-f") 'isearch-forward)
(define-key isearch-mode-map (kbd "C-f") 'isearch-repeat-forward)
;; C-a = SELECT ALL (Replacing standard move-beginning-of-line)
(global-set-key (kbd "C-a") 'mark-whole-buffer)
;; C-o = OPEN FILE
(global-set-key (kbd "C-o") 'find-file)
;; C-n = SWITCH BUFFER (Replacing standard next-line)
(global-set-key (kbd "C-n") 'switch-to-buffer)
;; C-Shift-P = COMMAND PALETTE (Execute extended command)
(global-set-key (kbd "C-S-p") 'execute-extended-command)
;; C-q = KILL BUFFER
(global-set-key (kbd "C-q") 'kill-current-buffer)
;; M-o = SWITCH WINDOW
(global-set-key (kbd "M-o") 'other-window)
;; Escape = Quit (C-g behavior)
(global-set-key (kbd "<escape>") 'keyboard-escape-quit)


;; Restore open files and show a welcome screen when no editors are open.
(load (expand-file-name "editor-session.el" user-emacs-directory) nil 'nomessage)

;; =====================================================
;; VS Code–like IntelliSense for Emacs 30
;; =====================================================

;; -------------------------
;; Completion UI (CORFU)
;; -------------------------
(straight-use-package 'corfu)
(straight-use-package 'orderless)
(straight-use-package 'cape)

(setq corfu-auto t
      corfu-auto-delay 0.15
      corfu-auto-prefix 2
      corfu-cycle t
      corfu-preselect 'first
      corfu-preview-current nil)

(global-corfu-mode 1)

;; -------------------------
;; Ctrl + Space = IntelliSense
;; -------------------------
(global-set-key (kbd "C-SPC") #'completion-at-point)

;; Prevent mark conflicts
(setq mark-ring-max 32)
(setq global-mark-ring-max 32)

;; -------------------------
;; Completion filtering
;; -------------------------
(setq completion-styles '(orderless basic)
      completion-category-overrides
      '((eglot (styles orderless))))

;; -------------------------
;; Extra completion sources
;; -------------------------
(add-to-list 'completion-at-point-functions #'cape-file)
(add-to-list 'completion-at-point-functions #'cape-dabbrev)
(add-to-list 'completion-at-point-functions #'cape-keyword)
;; Automatic word completion should not scan every open same-mode buffer.
(setq cape-dabbrev-buffer-function #'current-buffer)

;; -------------------------
;; LSP (Eglot – built-in)
;; -------------------------
(add-hook 'python-mode-hook #'my/eglot-ensure-if-installed)
(add-hook 'c-mode-hook #'my/eglot-ensure-if-installed)
(add-hook 'c++-mode-hook #'my/eglot-ensure-if-installed)

(setq eglot-autoshutdown t
      eglot-send-changes-idle-time 0.25)

;; -------------------------
;; Documentation on hover
;; -------------------------
(setq eldoc-echo-area-use-multiline-p t)

;; -------------------------
;; Symbol navigation (VS Code Outline)
;; -------------------------
(straight-use-package 'consult)

(global-set-key (kbd "C-S-o") #'consult-imenu)       ;; current file symbols
(global-set-key (kbd "C-t") #'xref-find-apropos) ;; project symbols

;; -------------------------
;; Go to definition / references
;; -------------------------
(global-set-key (kbd "<f12>") #'xref-find-definitions)
(global-set-key (kbd "<S-f12>") #'xref-find-references)

;; -------------------------
;; Optional: icons in popup (nice)
;; -------------------------
(straight-use-package 'kind-icon)

(setq kind-icon-default-face 'corfu-default)
(when (image-type-available-p 'svg)
  (add-to-list 'corfu-margin-formatters #'kind-icon-margin-formatter))

;; -------------------------
;; Better minibuffer UX
;; -------------------------
(straight-use-package 'vertico)
(vertico-mode 1)

(straight-use-package 'marginalia)
(marginalia-mode 1)



;; =====================================================
;; END
;; =====================================================


(add-hook 'c-mode-hook
          (lambda ()
            (remove-hook 'flymake-diagnostic-functions 'flymake-cc t)))

(add-hook 'c++-mode-hook
          (lambda ()
            (remove-hook 'flymake-diagnostic-functions 'flymake-cc t)))

;; Keep the shared VS Code shortcut layer last so it wins over older bindings.
(load (expand-file-name "vscode-keys.el" user-emacs-directory) nil 'nomessage)
(load (expand-file-name "command-palette.el" user-emacs-directory) nil 'nomessage)


(straight-use-package '(ghostel :type git :host github :repo "dakra/ghostel"
                               :files ("lisp/*.el" "etc")))
(load (expand-file-name "modal-terminal.el" user-emacs-directory) nil 'nomessage)

(load (expand-file-name "search-panel.el" user-emacs-directory) nil 'nomessage)
(load (expand-file-name "notebooks.el" user-emacs-directory) nil 'nomessage)
