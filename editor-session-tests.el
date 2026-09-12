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
          (setq buffer (get-file-buffer file))
          (should (buffer-live-p buffer))
          (should (= (with-current-buffer buffer (point)) 15))
          (should (eq (my/startup-buffer) buffer)))
      (when (buffer-live-p buffer) (kill-buffer buffer)))))

(ert-run-tests-batch-and-exit)
