;;; desktop-config.el --- Save the session automatically, restore it on demand  -*- lexical-binding: t; -*-

;;; Commentary:

;; desktop has no setting for saving the session without restoring it at
;; startup, so this file does the bookkeeping `desktop-read' would have done
;; and skips the buffers.  Restoring is still `desktop-read', bound under the
;; window prefix.
;;
;; The coupling is structural rather than a missing option.  The startup
;; restore is an anonymous function on `after-init-hook' gated only on
;; `desktop-save-mode', and the saving side assumes that restore ran.  Emacs
;; 32's development branch is the same on every point.  So `desktop-save-mode'
;; is turned on from `emacs-startup-hook', after the restore has already
;; decided not to run, and `config--desktop-enable-saving' does what the
;; restore would have.

;;; Code:

;; doom-keybinds.el defines the `map!' macro used below.
(eval-when-compile
  (require 'doom-keybinds))

(require 'desktop)

(setq desktop-save t                 ; Save on exit without asking.
      desktop-auto-save-timeout 60   ; nil is off; 60 seconds is arbitrary.
      desktop-restore-eager 0        ; On demand, restore every buffer lazily.
      desktop-save-buffer nil        ; Buffer-local variables are not saved.
      desktop-globals-to-save nil    ; Nor are global ones.
      desktop-restore-frames t)      ; Frame and window layout are.

(defun config--desktop-directory ()
  "Return the directory the session is saved in."
  (file-name-as-directory (expand-file-name (car desktop-path))))

(defun config--desktop-owned-elsewhere-p ()
  "Return non-nil when another running Emacs holds the desktop lock."
  (when-let* ((owner (desktop-owner)))
    (and (not (eq owner (emacs-pid)))
         (desktop--emacs-pid-running-p owner))))

(defun config--desktop-enable-saving ()
  "Turn on `desktop-save-mode' for saving only, leaving the last session alone."
  (setq desktop-dirname (config--desktop-directory))
  ;; `desktop-save' asks before overwriting a file this session did not load,
  ;; which would turn every exit into a prompt.  Recording the file's modtime
  ;; is what marks it as loaded.
  (when (file-exists-p (desktop-full-file-name))
    (desktop--get-file-modtime))
  ;; Two sessions sharing one lock would take turns overwriting one file, so a
  ;; lock held by a running Emacs is left alone.  The periodic save runs only
  ;; for the process holding the lock, and only a load or a save claims it.
  (unless (config--desktop-owned-elsewhere-p)
    (desktop-claim-lock))
  (desktop-save-mode 1))

(add-hook 'emacs-startup-hook #'config--desktop-enable-saving)

(map!
 :leader
 (:prefix ("w" . "window")
  :desc "Desktop restore" "R" #'desktop-read))

(provide 'desktop-config)
;;; desktop-config.el ends here
