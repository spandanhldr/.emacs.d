;;; editor-session.el --- Restore editors without empty scratch tabs -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'desktop)
(require 'tab-bar)

(defvar my/scratch-session-file
  (expand-file-name "scratch-session.el" user-emacs-directory))

(load (expand-file-name "pokemon-welcome.el"
                        (file-name-directory (or load-file-name buffer-file-name)))
      nil 'nomessage)

(defun my/nonempty-scratch-p (buffer)
  (with-current-buffer buffer
    (and (not buffer-file-name)
         (string-prefix-p "*scratch" (buffer-name))
         (> (buffer-size) 0)
         (not (equal (buffer-string) initial-scratch-message)))))

(defun my/startup-buffer ()
  "Keep the restored active editor, or choose an open editor or Welcome."
  (let ((current (window-buffer (selected-window))))
    (or (and (buffer-local-value 'buffer-file-name current) current)
        (cl-find-if (lambda (buffer) (buffer-local-value 'buffer-file-name buffer))
                    (buffer-list))
        (cl-find-if #'my/nonempty-scratch-p (buffer-list))
        (my/welcome-buffer))))

(defun my/save-scratch-session ()
  "Persist only untitled buffers that actually contain text."
  (let ((buffers (cl-remove-if-not #'my/nonempty-scratch-p (buffer-list))))
    (with-temp-file my/scratch-session-file
      (dolist (buffer buffers)
        (prin1 (cons (buffer-name buffer)
                     (with-current-buffer buffer (buffer-substring-no-properties
                                                  (point-min) (point-max))))
               (current-buffer))
        (insert "\n")))))

(defun my/restore-scratch-session ()
  "Restore nonempty untitled buffers without creating extra tabs."
  (when (file-exists-p my/scratch-session-file)
    (with-temp-buffer
      (insert-file-contents my/scratch-session-file)
      (goto-char (point-min))
      (while (progn (skip-chars-forward " \t\r\n") (not (eobp)))
        (let ((pair (read (current-buffer))))
          (when (and (consp pair) (stringp (car pair)) (stringp (cdr pair))
                     (string-prefix-p "*scratch" (car pair))
                     (> (length (cdr pair)) 0)
                     (not (equal (cdr pair) initial-scratch-message)))
            (with-current-buffer (get-buffer-create (car pair))
              ;; Re-evaluating the config must not overwrite current edits.
              (when (= (buffer-size) 0)
                (text-mode)
                (insert (cdr pair))
                (goto-char (point-min))))))))))

;; Use one stable directory regardless of the directory Emacs was launched in.
;; Set these before enabling the mode: the default asks before the first save.
(setq desktop-dirname user-emacs-directory
      desktop-path (list user-emacs-directory)
      desktop-save t
      desktop-load-locked-desktop 'check-pid
      desktop-restore-frames t
      desktop-restore-eager 5
      desktop-lazy-idle-delay 1
      initial-scratch-message nil
      initial-buffer-choice #'my/startup-buffer
      inhibit-startup-screen t
      tab-bar-new-tab-choice #'my/welcome-buffer
      tab-bar-tab-name-function #'tab-bar-tab-name-current)
(desktop-save-mode 1)
(tab-bar-mode 1)
(recentf-mode 1)
(add-hook 'after-init-hook #'my/restore-scratch-session t)
(add-hook 'kill-emacs-hook #'my/save-scratch-session)

;; Remove the old hooks when this configuration is reloaded in a live session.
(dolist (entry '((tab-bar-new-tab :before my/prompt-save-scratch-buffer)
                 (tab-bar-new-tab :after my/tab-bar-new-tab-scratch)
                 (tab-bar-close-tab :before my/tab-bar-close-tab-smart)
                 (find-file :around my/find-file-prompt-save-scratch)
                 (find-file :around my/find-file-dnd-smart)
                 (kill-buffer :around my/kill-buffer-advice)))
  (advice-remove (car entry) (nth 2 entry)))

(provide 'editor-session)
;;; editor-session.el ends here
