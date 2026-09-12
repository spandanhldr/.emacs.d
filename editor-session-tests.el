;;; editor-session-tests.el --- Isolated session regression tests -*- lexical-binding: t; -*-
(require 'ert)
(defmacro use-package (&rest _args) nil)
(defvar my/test-session-directory (make-temp-file "emacs-session-test-" t))
(setq user-emacs-directory (file-name-as-directory my/test-session-directory))
(dolist (file '("init.el" "editor-session.el" "vscode-keys.el"))
  (with-temp-buffer (insert-file-contents file) (emacs-lisp-mode) (check-parens)))
(load-file "editor-session.el")
(load-file "vscode-keys.el")
(setq kill-emacs-hook nil)

(ert-deftest session-empty-start-shows-welcome ()
  (save-window-excursion
    (switch-to-buffer (get-buffer-create "*scratch*"))
    (let ((buffer (my/startup-buffer)))
      (should (equal (buffer-name buffer) "*Welcome*"))
      (should (buffer-local-value 'buffer-read-only buffer)))))

(ert-deftest session-ignores-empty-legacy-scratch ()
  (with-temp-file my/scratch-session-file
    (insert "(\"*scratch-empty-test*\" . \"\")\n\n"))
  (let ((tabs (length (tab-bar-tabs))))
    (my/restore-scratch-session)
    (should-not (get-buffer "*scratch-empty-test*"))
    (should (= tabs (length (tab-bar-tabs))))))

(ert-deftest session-untitled-text-survives ()
  (let ((buffer (get-buffer-create "*scratch-content-test*")))
    (unwind-protect
        (progn
          (with-current-buffer buffer (insert "unsaved notes"))
          (my/save-scratch-session)
          (kill-buffer buffer)
          (my/restore-scratch-session)
          (setq buffer (get-buffer "*scratch-content-test*"))
          (should (equal (with-current-buffer buffer (buffer-string)) "unsaved notes")))
      (when (buffer-live-p buffer) (kill-buffer buffer)))))

(ert-deftest session-new-file-is-explicit ()
  (save-window-excursion
    (switch-to-buffer (my/welcome-buffer))
    (my/vscode-new-file)
    (let ((buffer (current-buffer)))
      (unwind-protect
          (progn (should (string-prefix-p "*scratch-new*" (buffer-name)))
                 (should-not buffer-read-only)
                 (should (= (buffer-size) 0)))
        (kill-buffer buffer)))))

(ert-deftest session-close-last-editor-shows-welcome ()
  (save-window-excursion
    (tab-bar-close-other-tabs)
    (switch-to-buffer (generate-new-buffer "*scratch-close-test*"))
    (my/vscode-close-editor)
    (should (equal (buffer-name) "*Welcome*"))))

(ert-deftest session-desktop-roundtrip-restores-file-and-point ()
  (let* ((file (expand-file-name "remember.txt" user-emacs-directory))
         (desktop-restore-frames nil)
         (desktop-auto-save-timeout nil)
         buffer)
    (unwind-protect
        (save-window-excursion
          (with-temp-file file (insert "first line\nsecond line\n"))
          (setq buffer (find-file-noselect file))
          (switch-to-buffer buffer)
          (goto-char 15)
          (desktop-save user-emacs-directory t)
          (kill-buffer buffer)
          ;; Desktop intentionally skips reads in batch mode.
          (let ((noninteractive nil)) (desktop-read user-emacs-directory))
          (setq buffer (find-buffer-visiting file))
          (should (buffer-live-p buffer))
          (should (= (with-current-buffer buffer (point)) 15))
          (should (eq (my/startup-buffer) buffer)))
      (when (buffer-live-p buffer) (kill-buffer buffer)))))

(ert-deftest session-closed-tab-is-not-restored-with-welcome ()
  (let* ((file (expand-file-name "closed-tab.txt" user-emacs-directory))
         (desktop-restore-frames nil) buffer)
    (unwind-protect
        (save-window-excursion
          (tab-bar-close-other-tabs)
          (with-temp-file file (insert "closed editor"))
          (setq buffer (find-file-noselect file))
          (switch-to-buffer buffer)
          (desktop-save user-emacs-directory t)
          (tab-bar-new-tab)
          (tab-bar-close-tab 1)
          (should (eq (current-buffer) (my/welcome-buffer)))
          ;; Clicking a tab's X leaves its buffer alive internally.
          (should (buffer-live-p buffer))
          (desktop-save user-emacs-directory t)
          (kill-buffer buffer)
          (kill-buffer "*Welcome*")
          (let ((noninteractive nil)) (desktop-read user-emacs-directory))
          (should-not (find-buffer-visiting file))
          (should (get-buffer "*Welcome*"))
          (switch-to-buffer "*Welcome*")
          (should (eq (my/startup-buffer) (current-buffer))))
      (when (buffer-live-p buffer) (kill-buffer buffer)))))

(ert-deftest session-welcome-remains-active-with-other-open-tab ()
  (save-window-excursion
    (let ((buffer (generate-new-buffer "open-editor")))
      (unwind-protect
          (progn
            (tab-bar-close-other-tabs)
            (switch-to-buffer buffer)
            (setq-local buffer-file-name (expand-file-name "other.txt" user-emacs-directory))
            (tab-bar-new-tab)
            (should (tab-bar-get-buffer-tab buffer t))
            (should (desktop-save-buffer-p (buffer-local-value 'buffer-file-name buffer)
                                           (buffer-name buffer) 'text-mode))
            (should (eq (my/startup-buffer) (my/welcome-buffer))))
        (tab-bar-close-other-tabs)
        (kill-buffer buffer)))))

(ert-run-tests-batch-and-exit)
