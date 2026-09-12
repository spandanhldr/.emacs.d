;;; editor-behavior-tests.el --- Discard and completion regressions -*- lexical-binding: t; -*-
(require 'ert)
(require 'cl-lib)
(defmacro use-package (&rest _) nil)
(add-to-list 'load-path (expand-file-name "straight/repos/corfu"))
(require 'corfu)
(defvar my/test-root (make-temp-file "editor-behavior-" t))
(setq user-emacs-directory (file-name-as-directory my/test-root))
(load-file "editor-session.el")
(load-file "vscode-keys.el")
(setq kill-emacs-hook nil python-indent-guess-indent-offset nil)

(defmacro my/with-recovery-file (&rest body)
  `(let* ((file (make-temp-file (expand-file-name "source-" my/test-root) nil ".py" "saved"))
          (buffer (find-file-noselect file)) recovery)
     (unwind-protect
         (with-current-buffer buffer
           (auto-save-mode 1)
           (goto-char (point-max)) (insert " changed")
           (do-auto-save t t)
           (setq recovery buffer-auto-save-file-name)
           (should (file-exists-p recovery))
           ,@body)
       (when (buffer-live-p buffer)
         (with-current-buffer buffer (set-buffer-modified-p nil))
         (kill-buffer buffer))
       (when (and recovery (file-exists-p recovery)) (delete-file recovery))
       (delete-file file))))

(ert-deftest discard-close-removes-copy-but-keeps-original ()
  (my/with-recovery-file
   (cl-letf (((symbol-function 'yes-or-no-p) (lambda (&rest _) t)))
     (should (kill-buffer buffer)))
   (should-not (file-exists-p recovery))
   (should (equal (with-temp-buffer (insert-file-contents file) (buffer-string)) "saved"))))

(ert-deftest discard-cancel-close-keeps-copy-and-edits ()
  (my/with-recovery-file
   (let ((kill-buffer-query-functions (list (lambda () nil))))
     (should-not (kill-buffer buffer)))
   (should (buffer-live-p buffer))
   (should (file-exists-p recovery))
   (should (equal (buffer-string) "saved changed"))))

(ert-deftest discard-confirmed-exit-cleans-and-prevents-recreation ()
  (my/with-recovery-file
   (let ((my/interactive-exit-in-progress t))
     (my/remove-auto-saves-before-confirmed-exit))
   (do-auto-save t t)
   (should-not buffer-auto-save-file-name)
   (should-not (file-exists-p recovery))
   (should (equal (with-temp-buffer (insert-file-contents file) (buffer-string)) "saved"))))

(ert-deftest discard-unconfirmed-exit-keeps-recovery ()
  (my/with-recovery-file
   (let ((my/interactive-exit-in-progress nil))
     (my/remove-auto-saves-before-confirmed-exit))
   (should (file-exists-p recovery))
   (should buffer-auto-save-file-name)))

(ert-deftest discard-cancel-exit-does-not-run-cleanup ()
  (my/with-recovery-file
   (let ((kill-emacs-query-functions (list (lambda () nil))))
     (cl-letf (((symbol-function 'save-some-buffers) #'ignore)
               ((symbol-function 'use-dialog-box-p) (lambda (&rest _) nil))
               ((symbol-function 'yes-or-no-p) (lambda (&rest _) t))
               ((symbol-function 'kill-emacs) (lambda (&rest _) (ert-fail "Canceled exit continued"))))
       (save-buffers-kill-emacs)))
   (should (file-exists-p recovery))
   (should buffer-auto-save-file-name)))

(ert-deftest completion-tab-accepts-import-once ()
  (dolist (key '("TAB" "<tab>"))
    (dolist (index '(-1 0 1))
      (with-temp-buffer
        (python-mode)
        (buffer-enable-undo)
        (insert "imp")
        (let ((completion-in-region-mode-predicate #'always)
              (completion-extra-properties nil)
              (corfu--candidates '("import" "important"))
              (corfu--total 2) (corfu--index index) (corfu--preselect -1)
              (corfu--base ""))
          (unwind-protect
              (progn
                (corfu--setup 1 (point) '("import" "important") nil)
                (call-interactively (lookup-key corfu-map (kbd key)))
                (should (equal (buffer-string) (if (= index 1) "important" "import")))
                (should-not completion-in-region-mode))
            (when completion-in-region-mode (corfu-quit))))))))

(ert-deftest discard-real-process-exit-leaves-no-recovery-copy ()
  (let* ((file (make-temp-file (expand-file-name "exit-source-" my/test-root) nil ".txt" "saved"))
         (script (make-temp-file (expand-file-name "exit-check-" my/test-root) nil ".el"))
         (recovery (expand-file-name (concat "#" (file-name-nondirectory file) "#") my/test-root))
         (session-source (expand-file-name "editor-session.el" default-directory)))
    (unwind-protect
        (progn
          (with-temp-file script
            (insert ";;; -*- lexical-binding: t; -*-\n")
            (prin1
             `(progn
                (require 'cl-lib)
                (setq user-emacs-directory ,user-emacs-directory)
                (load ,session-source nil t)
                (setq kill-emacs-hook nil)
                (find-file ,file)
                (auto-save-mode 1)
                (goto-char (point-max)) (insert " discarded")
                (do-auto-save t t)
                (unless (file-exists-p ,recovery) (error "Recovery copy not created"))
                (cl-letf (((symbol-function 'save-some-buffers) #'ignore)
                          ((symbol-function 'use-dialog-box-p) (lambda (&rest _) nil))
                          ((symbol-function 'yes-or-no-p) (lambda (&rest _) t)))
                  (save-buffers-kill-emacs)))
             (current-buffer)))
          (with-temp-buffer
            (should (= 0 (call-process (expand-file-name invocation-name invocation-directory)
                                        nil t nil "--batch" "-Q" "-l" script))))
          (should-not (file-exists-p recovery))
          (should (equal (with-temp-buffer (insert-file-contents file) (buffer-string)) "saved")))
      (delete-file script)
      (delete-file file)
      (when (file-exists-p recovery) (delete-file recovery)))))

(ert-run-tests-batch-and-exit)
