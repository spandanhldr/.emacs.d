;;; early-init.el --- Bounded startup and background work -*- lexical-binding: t; -*-

;; Straight manages packages; skip the second package manager's startup scan.
(setq package-enable-at-startup nil
      frame-inhibit-implied-resize t
      gc-cons-threshold (* 128 1024 1024)
      gc-cons-percentage 0.2)

(defun my/finish-startup-performance ()
  "Restore bounded garbage collection after the startup allocation burst."
  (setq gc-cons-threshold (* 32 1024 1024)
        gc-cons-percentage 0.1))
(add-hook 'emacs-startup-hook #'my/finish-startup-performance)

;; Native compilation uses separate processes on every supported platform.
(setq native-comp-async-jobs-number
      (min 4 (max 1 (/ (if (fboundp 'num-processors) (num-processors) 2) 2))))
