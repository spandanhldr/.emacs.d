;;; search-panel-tests.el --- Search regression tests -*- lexical-binding: t; -*-
(require 'ert)
(load-file (expand-file-name "search-panel.el" (file-name-directory load-file-name)))
(defmacro my/test-search (&rest body)
  `(save-window-excursion
     (let ((source (generate-new-buffer "search-test"))
           (my/search-last-query "cat") (my/search-last-replacement "dog"))
       (unwind-protect
           (progn (switch-to-buffer source) (insert "cat Cat scatter cat")
                  (goto-char (point-min)) (my/search-open t) ,@body)
         (my/search-close) (kill-buffer source)))))
(ert-deftest search-live-navigation-and-options ()
  (my/test-search
   (should (= 4 (length (my/search-state-matches my/search-session))))
   (my/search-next) (should (= 1 (my/search-state-index my/search-session)))
   (my/search-previous) (should (= 0 (my/search-state-index my/search-session)))
   (setf (my/search-state-whole-word my/search-session) t)
   (my/search-refresh) (should (= 3 (length (my/search-state-matches my/search-session))))
   (setf (my/search-state-case-sensitive my/search-session) t)
   (my/search-refresh) (should (= 2 (length (my/search-state-matches my/search-session))))))
(ert-deftest search-replace-and-readonly ()
  (my/test-search
   (my/search-replace)
   (should (equal (with-current-buffer source (buffer-string)) "dog Cat scatter cat"))
   (my/search-replace-all)
   (should (equal (with-current-buffer source (buffer-string)) "dog dog sdogter dog"))
   (with-current-buffer source (setq buffer-read-only t))
   (should-error (my/search-replace-all) :type 'buffer-read-only)))
(ert-deftest search-field-keyboard-and-close ()
  (my/test-search
   (should (eq (key-binding (kbd "RET")) #'my/search-next))
   (my/search-select-field) (delete-region (region-beginning) (region-end))
   (execute-kbd-macro "Cat")
   (should (equal (widget-value (my/search-state-find my/search-session)) "Cat"))
   (execute-kbd-macro (kbd "<escape>"))
   (should-not my/search-session)
   (should (eq (current-buffer) source))
   (should-not (overlays-in (point-min) (point-max)))))
(ert-deftest search-regexp-and-empty-match ()
  (my/test-search
   (setf (my/search-state-regexp my/search-session) t
         (my/search-state-query my/search-session) "[")
   (my/search-refresh) (should-not (my/search-state-matches my/search-session))
   (setf (my/search-state-query my/search-session) "^"
         (my/search-state-replacement my/search-session) ">")
   (my/search-replace-all)
   (should (equal (with-current-buffer source (buffer-string)) ">cat Cat scatter cat"))))
(ert-deftest search-panel-reopens-and-switches-to-replace ()
  (my/test-search
   (my/search-close)
   (my/search-open)
   (should-not (my/search-state-replacing my/search-session))
   (my/search-open-replace)
   (should (my/search-state-replacing my/search-session))
   (should (eq (widget-field-at (point)) (my/search-state-replace my/search-session)))))
(ert-deftest search-position-tracks-parent-and-clamps ()
  (should (equal (my/search-position '(:parent-frame-width 1000 :parent-frame-height 700
                                     :posframe-width 500 :posframe-height 200)) '(480 . 50)))
  (should (equal (my/search-position '(:parent-frame-width 400 :parent-frame-height 100
                                     :posframe-width 500 :posframe-height 200)) '(0 . 0)))
  (my/test-search
   (let ((calls 0))
     (cl-letf (((symbol-function 'my/search-show) (lambda (&rest _) (cl-incf calls))))
       (my/search-parent-resized (selected-frame))
       (should (= calls 0))
       (setf (my/search-state-geometry my/search-session) nil)
       (my/search-parent-resized (selected-frame))
       (should (= calls 1))))))
(ert-run-tests-batch-and-exit)
