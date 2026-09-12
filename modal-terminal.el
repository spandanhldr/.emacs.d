;;; modal-terminal.el --- Insert gate and animated top console -*- lexical-binding: t; -*-
(require 'cl-lib)
(load (expand-file-name "native-terminal.el"
                        (file-name-directory (or load-file-name buffer-file-name))) nil 'nomessage)

(defvar-local my/modal-normal nil)
(defvar-local my/modal-insert nil)
(defvar-local my/modal-original-read-only nil)
(defvar-local my/modal-original-cursor nil)

(defun my/modal-enter-insert ()
  "Allow editing until Escape, respecting an originally read-only buffer."
  (interactive)
  (when my/modal-original-read-only (user-error "This buffer is read-only"))
  (setq buffer-read-only nil my/modal-normal nil my/modal-insert t cursor-type 'bar)
  (force-mode-line-update))

(defun my/modal-leave-insert ()
  "Dismiss completion and return to the locked editor state."
  (interactive)
  (when (and (bound-and-true-p corfu-mode) (bound-and-true-p completion-in-region-mode))
    (corfu-quit))
  (when my/modal-edit-mode
    (setq buffer-read-only t my/modal-normal t my/modal-insert nil cursor-type 'box)
    (deactivate-mark)
    (force-mode-line-update)))

(defvar my/modal-normal-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "i") #'my/modal-enter-insert)
    (define-key map (kbd "`") #'my/quake-open)
    (define-key map (kbd "<escape>") #'my/modal-leave-insert)
    map))
(defvar my/modal-insert-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "<escape>") #'my/modal-leave-insert)
    map))
(defvar my/modal-emulation-maps
  `((my/modal-normal . ,my/modal-normal-map) (my/modal-insert . ,my/modal-insert-map)))
(add-to-list 'emulation-mode-map-alists 'my/modal-emulation-maps)

(define-minor-mode my/modal-edit-mode
  "Start editors locked; i enters Insert and Escape leaves it."
  :lighter (:eval (if my/modal-insert " INSERT" " NORMAL"))
  (if my/modal-edit-mode
      (progn
        (unless (or my/modal-normal my/modal-insert)
          (setq my/modal-original-read-only buffer-read-only
                my/modal-original-cursor cursor-type))
        (my/modal-leave-insert))
    (setq buffer-read-only my/modal-original-read-only
          cursor-type my/modal-original-cursor
          my/modal-normal nil my/modal-insert nil)))

(defun my/modal-release-before-major-mode-change ()
  "Remove our temporary lock before a major mode resets its local state.
Otherwise the next mode mistakes our lock for an originally read-only file."
  (when my/modal-edit-mode
    (setq buffer-read-only my/modal-original-read-only
          cursor-type my/modal-original-cursor)))
(add-hook 'change-major-mode-hook #'my/modal-release-before-major-mode-change)

(defun my/modal-enable-editor ()
  (when (and (not (minibufferp))
             (not (derived-mode-p 'special-mode 'comint-mode 'eshell-mode 'ghostel-mode))
             (or buffer-file-name (derived-mode-p 'prog-mode 'text-mode 'fundamental-mode)))
    (unless my/modal-edit-mode (my/modal-edit-mode 1))))
(define-globalized-minor-mode my/global-modal-edit-mode my/modal-edit-mode my/modal-enable-editor)
(unless noninteractive (my/global-modal-edit-mode 1))

(defun my/modal-desktop-buffer-info (original buffer)
  "Persist the actual read-only flag, rather than the temporary editing lock."
  (with-current-buffer buffer
    (let ((buffer-read-only (if my/modal-edit-mode my/modal-original-read-only buffer-read-only)))
      (funcall original buffer))))
(with-eval-after-load 'desktop
  (add-to-list 'desktop-minor-mode-table '(my/modal-edit-mode nil))
  (advice-add 'desktop-buffer-info :around #'my/modal-desktop-buffer-info))

;; Corfu's transient map outranks editor maps. Escape must still lock editing.
(with-eval-after-load 'corfu
  (define-key corfu-map (kbd "<escape>")
              (lambda () (interactive)
                (if (bound-and-true-p my/modal-edit-mode)
                    (my/modal-leave-insert)
                  (corfu-quit)))))

(defvar-local my/quake-terminal-buffer nil)
(defvar-local my/quake-owner nil)
(defconst my/quake-duration 0.20)

(defun my/quake-directory (source)
  "Return SOURCE's current file directory, or its buffer directory."
  (with-current-buffer source
    (file-name-as-directory
     (expand-file-name (if buffer-file-name (file-name-directory buffer-file-name)
                         default-directory)))))

(defun my/quake-terminal (source)
  "Return the native shell for SOURCE's current file directory."
  (let ((buffer (my/quake-native-terminal source (my/quake-directory source))))
    (with-current-buffer source (setq my/quake-terminal-buffer buffer))
    buffer))

(defun my/quake-cancel-timer (frame)
  (when-let* ((timer (frame-parameter frame 'my/quake-timer)))
    (cancel-timer timer)
    (set-frame-parameter frame 'my/quake-timer nil)))

(defun my/quake-target-height (frame)
  (max 3 (min (max 3 (- (frame-height frame) 5))
              (round (* (frame-height frame) 0.35)))))

(defun my/quake-animate (frame window opening)
  "Animate WINDOW with eased, nonblocking resize steps."
  (my/quake-cancel-timer frame)
  (let* ((started (float-time))
         (pixelwise (display-graphic-p frame))
         (unit (if pixelwise (frame-char-height frame) 1))
         (initial (if pixelwise (window-pixel-height window) (window-total-height window))))
    (set-frame-parameter frame 'my/quake-opening opening)
    (set-frame-parameter
     frame 'my/quake-timer
     (run-at-time
      0 0.016
      (lambda ()
        (if (not (and (frame-live-p frame) (window-live-p window)))
            (my/quake-cancel-timer frame)
          (let* ((progress (min 1.0 (/ (- (float-time) started) my/quake-duration)))
                 (ease (- 1 (expt (- 1 progress) 3)))
                 (target (* unit (if opening (my/quake-target-height frame) 1)))
                 (height (max unit (round (+ initial (* ease (- target initial)))))))
            (condition-case nil
                (window-resize window (- height (if pixelwise (window-pixel-height window)
                                                  (window-total-height window))) nil 'safe pixelwise)
              (error nil))
            (when (>= progress 1)
              (my/quake-cancel-timer frame)
              (when (and opening (fboundp 'ghostel--adjust-size)
                         (buffer-local-value 'my/quake-native-active (window-buffer window)))
                (ghostel--adjust-size window t))
              (unless opening
                (when (window-live-p window) (delete-window window))
                (set-frame-parameter frame 'my/quake-window nil))))))))))

(defun my/quake-toggle ()
  "Toggle a top console for the active editor, restoring focus when hidden."
  (interactive)
  (let* ((frame (selected-frame))
         (window (frame-parameter frame 'my/quake-window))
         (source-window (if (eq (selected-window) window)
                            (frame-parameter frame 'my/quake-source-window)
                          (selected-window)))
         (source (and (window-live-p source-window) (window-buffer source-window))))
    (if (and (window-live-p window)
             (frame-parameter frame 'my/quake-opening)
             (or (eq window (selected-window))
                 (eq source (buffer-local-value 'my/quake-owner (window-buffer window)))))
        (progn
          (when (window-live-p source-window) (select-window source-window))
          (my/quake-animate frame window nil))
      (unless source (user-error "No editor window available"))
      (let* ((buffer (my/quake-terminal source))
             (window-min-height 1)
             (console (display-buffer-in-side-window
                       buffer '((side . top) (slot . 0) (window-height . 1)
                                (window-parameters . ((no-delete-other-windows . t)))))))
        (set-frame-parameter frame 'my/quake-source-window source-window)
        (set-frame-parameter frame 'my/quake-window console)
        (select-window console)
        (goto-char (point-max))
        (my/quake-animate frame console t)))))

(defun my/quake-open ()
  "Open or focus the console without toggling a visible one closed."
  (interactive)
  (let* ((frame (selected-frame))
         (window (frame-parameter frame 'my/quake-window)))
    (if (and (window-live-p window) (frame-parameter frame 'my/quake-opening))
        (progn (my/quake-follow-editor frame) (select-window window))
      (my/quake-toggle))))

(defun my/quake-hide ()
  "Hide the visible console and return to its source editor."
  (interactive)
  (let* ((frame (selected-frame))
         (window (frame-parameter frame 'my/quake-window))
         (editor (frame-parameter frame 'my/quake-source-window)))
    (when (window-live-p window)
      (when (window-live-p editor) (select-window editor))
      (my/quake-animate frame window nil))))

(defun my/quake-new-terminal ()
  "Start a fresh native shell for the active editor, preserving older shells."
  (interactive)
  (let* ((frame (selected-frame))
         (console (frame-parameter frame 'my/quake-window))
         (editor (if (eq console (selected-window))
                     (frame-parameter frame 'my/quake-source-window)
                   (selected-window))))
    (unless (window-live-p editor) (user-error "No editor window available"))
    (with-current-buffer (window-buffer editor)
      (setf (alist-get (my/quake-directory (current-buffer)) my/quake-terminal-sessions nil nil #'equal) nil))
    (select-window editor)
    (if (window-live-p console)
        (let ((buffer (my/quake-terminal (window-buffer editor))))
          (set-window-dedicated-p console nil)
          (set-window-buffer console buffer)
          (set-window-dedicated-p console 'side)
          (select-window console)
          (my/quake-animate frame console t))
      (my/quake-toggle))))

(defun my/quake-resize (frame)
  "Follow parent frame size changes when no animation is running."
  (when-let* ((_ (not (frame-parameter frame 'my/quake-timer)))
              (_ (frame-parameter frame 'my/quake-opening))
              (window (frame-parameter frame 'my/quake-window))
              (_ (window-live-p window)))
    (let ((delta (- (my/quake-target-height frame) (window-total-height window))))
      (unless (zerop delta)
        (condition-case nil (window-resize window delta nil 'safe) (error nil))))))
(defun my/quake-follow-editor (frame)
  "Switch the visible console context when another editor gains focus."
  (when-let* ((console (frame-parameter frame 'my/quake-window))
              (_ (window-live-p console))
              (_ (frame-parameter frame 'my/quake-opening))
              (editor (frame-selected-window frame))
              (_ (not (eq editor console)))
              (_ (not (window-minibuffer-p editor))))
    (let ((source (window-buffer editor)))
      (when (with-current-buffer source
              (or buffer-file-name (derived-mode-p 'text-mode 'prog-mode 'my/pokemon-welcome-mode)))
        (unless (and (eq source (buffer-local-value 'my/quake-owner (window-buffer console)))
                     (equal (my/quake-directory source)
                            (buffer-local-value 'my/quake-source-directory (window-buffer console))))
          (let ((buffer (my/quake-terminal source)))
            (set-window-dedicated-p console nil)
            (set-window-buffer console buffer)
            (set-window-dedicated-p console 'side)
            (set-frame-parameter frame 'my/quake-source-window editor)))))))
(add-hook 'window-selection-change-functions #'my/quake-follow-editor)
(add-hook 'window-buffer-change-functions #'my/quake-follow-editor)

(add-hook 'window-size-change-functions #'my/quake-resize)
(add-hook 'delete-frame-functions #'my/quake-cancel-timer)
;; Clear the previous toggle binding when reloading an existing session.
(define-key my/modal-normal-map (kbd "~") nil)
(define-key my/modal-normal-map (kbd "`") #'my/quake-open)
(with-eval-after-load 'pokemon-welcome
  (define-key my/pokemon-welcome-mode-map (kbd "~") nil)
  (define-key my/pokemon-welcome-mode-map (kbd "`") #'my/quake-open))

(provide 'modal-terminal)
