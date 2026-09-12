;;; pokemon-welcome.el --- A small animated Pokemon dashboard -*- lexical-binding: t; -*-

(require 'svg)
(require 'button)
(require 'cl-lib)
(load (expand-file-name "welcome-themes.el"
                        (file-name-directory (or load-file-name buffer-file-name)))
      nil 'nomessage)

(defvar my/welcome-session-index nil)
(defvar my/welcome-heading nil)

(defun my/welcome-choose-message ()
  "Choose a new greeting once per Emacs session, preserving the rotation."
  (unless my/welcome-heading
    (let* ((file (expand-file-name "welcome-message-state" user-emacs-directory))
           (previous (condition-case nil
                         (with-temp-buffer
                           (insert-file-contents file)
                           (read (current-buffer)))
                       (error -1))))
      (setq my/welcome-session-index
            (mod (1+ (if (integerp previous) previous -1))
                 9)
            my/welcome-theme (car (nth (% my/welcome-session-index 3) my/welcome-themes))
            my/welcome-heading (aref (my/welcome-theme-value :greetings)
                                    (/ my/welcome-session-index 3)))
      (with-temp-file file (prin1 my/welcome-session-index (current-buffer)))))
  my/welcome-heading)

(defun my/welcome-say-goodbye ()
  "Show this session's farewell during normal shutdown without delaying exit."
  (when my/welcome-session-index
    (setq my/welcome-heading (aref (my/welcome-theme-value :farewells)
                                  (/ my/welcome-session-index 3)))
    (when-let* ((window (get-buffer-window "*Welcome*" t)))
      (with-current-buffer (window-buffer window)
        (my/welcome-render window)
        (my/welcome-tick)))
    (message "%s" my/welcome-heading)
    (redisplay)))

(unless noninteractive (my/welcome-choose-message))
(add-hook 'kill-emacs-hook #'my/welcome-say-goodbye t)

(defvar my/welcome-timer nil)
(defvar-local my/welcome-art nil)
(defvar-local my/welcome-clock nil)
(defvar-local my/welcome-date nil)
(defvar-local my/welcome-width nil)
(defvar-local my/welcome-height nil)
(defvar-local my/welcome-images nil)
(defvar-local my/welcome-image-width nil)
(defvar-local my/welcome-image-theme nil)
(defvar-local my/welcome-step 0)

(defun my/welcome-line (text &optional face)
  (insert (make-string (max 0 (/ (- my/welcome-width (string-width text)) 2)) ?\s))
  (insert (if face (propertize text 'face face) text) "\n"))

(defun my/welcome-action (label command)
  (insert (make-string (max 0 (/ (- my/welcome-width (string-width label)) 2)) ?\s))
  (insert-text-button label 'follow-link t
                      'face `(:foreground ,(my/welcome-theme-value :accent)
                              :box (:line-width 1 :color "#34465f"))
                      'help-echo "Click or press Enter"
                      'action (lambda (_)
                                ;; Multiform selects the popup by `this-command'.
                                (let ((this-command command)
                                      (real-this-command command))
                                  (call-interactively command))))
  (insert "\n\n"))

(defun my/welcome-render (window)
  "Lay out the dashboard for WINDOW."
  (let ((inhibit-read-only t))
    (remove-overlays)
    (erase-buffer)
    (setq my/welcome-width (max 20 (window-body-width window))
          my/welcome-height (window-body-height window))
    (insert "\n")
    (my/welcome-choose-message)
    (setq-local face-remapping-alist
                `((default (:background ,(my/welcome-theme-value :background)
                            :foreground "#c8d6e8"))))
    (my/welcome-line my/welcome-heading
                     `(:foreground ,(my/welcome-theme-value :accent) :weight bold))
    (insert "\n")
    (if (and (display-graphic-p) (image-type-available-p 'svg))
        (let ((start (point)))
          (insert " \n")
          (setq my/welcome-art (make-overlay start (1+ start)))
          (let ((width (min 900 (max 100 (- (window-body-width window t) 48))
                            (max 210 (round (/ (- (window-body-height window t)
                                                 (* 18 (frame-char-height (window-frame window))))
                                              0.43))))))
            ;; Quantize resize steps and keep one bounded cache per welcome buffer.
            (setq width (* 16 (max 1 (/ width 16))))
            (unless (and my/welcome-images (equal width my/welcome-image-width)
                         (eq my/welcome-image-theme my/welcome-theme))
              (setq my/welcome-images
                    (vconcat (cl-loop for step below my/welcome-frame-count
                                      collect (funcall (my/welcome-theme-value :art) step width)))
                    my/welcome-image-width width
                    my/welcome-image-theme my/welcome-theme))
            (overlay-put my/welcome-art 'before-string
                         (propertize " " 'display `(space :align-to (- center (,(/ width 2))))))
            (overlay-put my/welcome-art 'display (aref my/welcome-images 0))
))
      (my/welcome-line (my/welcome-theme-value :name)
                       `(:foreground ,(my/welcome-theme-value :accent))))
    (insert "\n")
    (my/welcome-line (my/welcome-theme-value :subtitle) '(:foreground "#edf3ff" :weight bold))
    (insert "\n")
    (dolist (entry '((my/welcome-clock . "%I:%M:%S %p") (my/welcome-date . "%A, %d %B %Y")))
      (let ((start (point)))
        (insert "\n")
        (set (car entry) (make-overlay start start))))
    (insert "\n\n")
    (my/welcome-action "  OPEN FILE       Ctrl+O  " 'my/vscode-open-file)
    (my/welcome-action "  NEW ADVENTURE   Ctrl+N  " 'my/vscode-new-file)
    (my/welcome-action "  COMMANDS   Ctrl+Shift+P  " 'execute-extended-command)
    (my/welcome-line (my/welcome-theme-value :footer) '(:foreground "#8799b3"))
    (setq my/welcome-step 0)
    (my/welcome-update-clock)
    (set-buffer-modified-p nil)
    (goto-char (point-min))))

(defun my/welcome-update-clock ()
  "Change clock overlays only when their displayed values change."
  (let ((now (current-time)))
    (dolist (entry `((,my/welcome-clock "%I:%M:%S %p" ,(my/welcome-theme-value :accent) bold)
                     (,my/welcome-date "%A, %d %B %Y" "#9db2d0" normal)))
      (let ((text (format-time-string (nth 1 entry) now)))
        (unless (equal text (overlay-get (car entry) 'my/last-value))
          (overlay-put (car entry) 'my/last-value text)
          (overlay-put (car entry) 'before-string
                       (concat (make-string (max 0 (/ (- my/welcome-width (length text)) 2)) ?\s)
                               (propertize text 'face `(:foreground ,(nth 2 entry)
                                                       :weight ,(nth 3 entry))))))))))

(defun my/welcome-update-animation (&rest _)
  "Run the animation timer only while Welcome is visible."
  (if (get-buffer-window "*Welcome*" t)
      (unless (timerp my/welcome-timer)
        (setq my/welcome-timer (run-at-time 0 0.1 #'my/welcome-tick)))
    (when (timerp my/welcome-timer)
      (cancel-timer my/welcome-timer)
      (setq my/welcome-timer nil))))

(add-hook 'window-buffer-change-functions #'my/welcome-update-animation)

(defun my/welcome-tick ()
  "Animate only while the welcome screen is visible; show local system time."
  (my/welcome-update-animation)
  (when-let* ((_ (not (or (active-minibuffer-window) (input-pending-p))))
              (buffer (get-buffer "*Welcome*"))
              (window (get-buffer-window buffer t)))
    (with-current-buffer buffer
      (when (or (not (equal my/welcome-width (max 20 (window-body-width window))))
                (not (equal my/welcome-height (window-body-height window))))
        (my/welcome-render window))
      (when (and my/welcome-images (overlayp my/welcome-art))
        (overlay-put my/welcome-art 'display
                     (aref my/welcome-images (% (cl-incf my/welcome-step) my/welcome-frame-count))))
      (my/welcome-update-clock))))

(define-derived-mode my/pokemon-welcome-mode special-mode "Trainer HQ"
  "A read-only Pokemon home screen."
  (setq-local display-line-numbers nil
              cursor-type nil
              truncate-lines t
              mode-line-format nil
              face-remapping-alist '((default (:background "#111b30" :foreground "#c8d6e8"))))
  (local-set-key (kbd "C-n") #'my/vscode-new-file)
  (local-set-key (kbd "C-o") #'my/vscode-open-file)
  (local-set-key (kbd "C-S-p") #'execute-extended-command)
  (local-set-key (kbd "TAB") #'forward-button)
  (local-set-key (kbd "<backtab>") #'backward-button))

(defun my/welcome-buffer ()
  "Return the animated welcome dashboard without creating an untitled file."
  (let ((buffer (get-buffer-create "*Welcome*")))
    (with-current-buffer buffer
      (unless (derived-mode-p 'my/pokemon-welcome-mode)
        (my/pokemon-welcome-mode)
        (my/welcome-render (selected-window))))
    (my/welcome-update-animation)
    buffer))

(provide 'pokemon-welcome)
