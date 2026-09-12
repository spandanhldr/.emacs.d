;;; command-palette.el --- VS Code style command popup -*- lexical-binding: t; -*-

(use-package vertico-posframe
  :demand t
  :config
  (require 'vertico-multiform)
  ;; These faces belong to the popup, so the editor keeps its Gruvbox theme.
  (set-face-attribute 'vertico-posframe nil
                      :background "#252526" :foreground "#cccccc")
  (set-face-attribute 'vertico-posframe-border nil :background "#454545")

  (defun my/palette-position (info)
    "Center the palette horizontally, a little below the frame's top edge."
    (cons (max 0 (/ (- (plist-get info :parent-frame-width)
                       (plist-get info :posframe-width)) 2))
          (min 55 (max 0 (- (plist-get info :parent-frame-height)
                            (plist-get info :posframe-height))))))

  (defun my/palette-parent-frame ()
    "Return the editor frame, even when the popup itself has focus."
    (let ((window (minibuffer-selected-window)))
      (if (window-live-p window) (window-frame window)
        (or (frame-parent) (selected-frame)))))

  (defun my/palette-size (_buffer)
    "Keep the popup comfortably sized, including in smaller Emacs windows."
    (let* ((frame (my/palette-parent-frame))
           ;; Reserve room for fringes, borders and the top offset.
           (columns (max 1 (- (frame-width frame) 8)))
           (width (min columns 100 (max 40 (round (* columns 0.75)))))
           (height (min 14 (max 2 (- (frame-height frame) 8)))))
      (list :width width :min-width width
            :height height :min-height height)))

  (defvar my/palette-resize-timer nil)
  (defvar my/palette-resizing nil)
  (defvar-local my/palette-last-geometry nil)

  (defun my/palette-active-p (frame)
    "Return the active palette window if it belongs to FRAME."
    (let ((window (active-minibuffer-window)))
      (when (and (frame-live-p frame) (window-live-p window)
                 (eq frame (my/palette-parent-frame))
                 (eq (buffer-local-value 'vertico-posframe-poshandler
                                         (window-buffer window))
                     #'my/palette-position))
        window)))

  (defun my/palette-refresh (frame)
    "Redraw an open palette using the current parent frame dimensions."
    (setq my/palette-resize-timer nil)
    (when-let* ((window (my/palette-active-p frame)))
      (let ((my/palette-resizing t))
        (with-current-buffer (window-buffer window)
          (setq-local vertico-count
                      (max 1 (min 11 (1- (plist-get (my/palette-size (current-buffer))
                                                    :height)))))
          (vertico--exhibit)))))

  (defun my/palette-window-resized (frame)
    "Refresh after parent-frame resizes, ignoring popup resize events."
    (when-let* ((_ (not my/palette-resizing))
                (window (my/palette-active-p frame)))
      (with-current-buffer (window-buffer window)
        (let ((geometry (list (frame-pixel-width frame) (frame-pixel-height frame))))
          ;; Changes to the minibuffer layout are not parent-frame resizes.
          (unless (equal geometry my/palette-last-geometry)
            (setq my/palette-last-geometry geometry)
            (when (timerp my/palette-resize-timer)
              (cancel-timer my/palette-resize-timer))
            ;; Coalesce mouse-drag events outside redisplay.
            (setq my/palette-resize-timer
                  (run-at-time 0.04 nil #'my/palette-refresh frame)))))))

  (add-hook 'window-size-change-functions #'my/palette-window-resized)

  (setf (alist-get 'execute-extended-command vertico-multiform-commands)
        '(posframe
          (vertico-count . 11)
          (vertico-cycle . t)
          (vertico-resize . nil)
          (vertico-posframe-poshandler . my/palette-position)
          (vertico-posframe-size-function . my/palette-size)
          (vertico-posframe-border-width . 1)
          (vertico-posframe-parameters . ((left-fringe . 14)
                                         (right-fringe . 14)
                                         (internal-border-width . 10)))
          (face-remapping-alist
           . ((default (:background "#252526" :foreground "#cccccc"))
              (minibuffer-prompt (:foreground "#75beff" :weight bold))
              (vertico-current (:background "#094771" :foreground "#ffffff"))
              (completions-common-part (:foreground "#75beff" :weight bold))
              (marginalia-documentation (:foreground "#999999"))
              (marginalia-key (:foreground "#d7ba7d"))))))
  (vertico-multiform-mode 1)
  ;; Escape dismisses the palette; arrows select and Enter runs a command.
  (define-key vertico-map (kbd "<escape>") #'abort-recursive-edit))

(provide 'command-palette)
;;; command-palette.el ends here
