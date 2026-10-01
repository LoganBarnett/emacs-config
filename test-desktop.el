;;; test-desktop.el --- Desktop save-only assertions for the Nix-built Emacs -*- lexical-binding: t; -*-

;;; Commentary:

;; Loaded by test-desktop.sh after the full init has run.
;;
;; The session must be saved on exit and periodically without the previous
;; one being restored at startup.  The commentary of lisp/desktop-config.el
;; explains why desktop does not offer that split on its own.
;;
;; The startup function is called by hand here: `emacs-startup-hook' runs
;; only once the command line is fully processed, which is after this file
;; has already ended the session.

;;; Code:

(require 'cl-lib)

;; These arrive with the init this file is loaded after, so they are not
;; present at byte-compile time.
(declare-function config--desktop-directory "desktop-config" ())
(declare-function config--desktop-enable-saving "desktop-config" ())

(defvar test-desktop--failures '()
  "Descriptions of checks that failed, most recent first.")
(defvar test-desktop--passes '()
  "Descriptions of checks that passed, most recent first.")

(defun test-desktop--check (description condition)
  "Record DESCRIPTION as passed when CONDITION is non-nil, else as failed."
  (if condition
      (push description test-desktop--passes)
    (push description test-desktop--failures)))

(defun test-desktop--file-mentions-p (name)
  "Return non-nil when the saved desktop file mentions NAME."
  (with-temp-buffer
    (insert-file-contents (desktop-full-file-name))
    (goto-char (point-min))
    (search-forward name nil t)))

(defun test-desktop--seed-previous-session (dir)
  "Write a desktop file and a stale lock into DIR as an earlier session would."
  (make-directory dir t)
  (with-temp-file (desktop-full-file-name dir)
    (insert desktop-header "(setq desktop-saved-frameset nil)\n"))
  ;; A lock naming a live process that is not an Emacs is what a crashed
  ;; session leaves behind once its pid is reused; the parent shell serves.
  (with-temp-file (desktop-full-lock-name dir)
    (insert (number-to-string
             (alist-get 'ppid (process-attributes (emacs-pid)))))))

;;
;; ── Checks ───────────────────────────────────────────────────────────────────

(test-desktop--check
 "desktop-save-mode is off when the startup restore makes its decision"
 (not desktop-save-mode))

(test-desktop--check
 "the save-only startup function is on emacs-startup-hook"
 (memq #'config--desktop-enable-saving emacs-startup-hook))

(let ((marker (make-temp-file "test-desktop-marker-" nil ".txt"))
      (prompts '()))
  (test-desktop--seed-previous-session (config--desktop-directory))
  (find-file-noselect marker)
  (config--desktop-enable-saving)
  (test-desktop--check
   "the startup function turns desktop-save-mode on"
   desktop-save-mode)
  (test-desktop--check
   "the startup function takes the stale lock for this Emacs"
   (eq (desktop-owner) (emacs-pid)))
  (test-desktop--check
   "the startup function records the previous file's modtime"
   (time-equal-p desktop-file-modtime
                 (file-attribute-modification-time
                  (file-attributes (desktop-full-file-name)))))
  ;; Frames are not under test, and the batch session's terminal frame is
  ;; not something frameset can serialize.
  (let ((desktop-restore-frames nil))
    (cl-letf (((symbol-function 'yes-or-no-p)
               (lambda (prompt) (push prompt prompts) nil))
              ((symbol-function 'y-or-n-p)
               (lambda (prompt) (push prompt prompts) nil)))
      (desktop-kill)))
  (test-desktop--check
   "the exit save asks nothing about the previous session's file"
   (null prompts))
  (test-desktop--check
   "the exit save writes this session's buffers"
   (test-desktop--file-mentions-p (file-name-nondirectory marker)))
  (test-desktop--check
   "the exit save releases the lock"
   (null (desktop-owner)))
  (dolist (prompt prompts)
    (message "[DESKTOP TEST] prompt seen: %s" prompt))
  (delete-file marker))

;;
;; ── Report ───────────────────────────────────────────────────────────────────

(message "")
(message "[DESKTOP TEST] ===================================================")
(dolist (p (reverse test-desktop--passes))
  (message "[DESKTOP TEST] PASS: %s" p))
(dolist (f (reverse test-desktop--failures))
  (message "[DESKTOP TEST] FAIL: %s" f))
(message "[DESKTOP TEST] ===================================================")
(message "[DESKTOP TEST] %d passed, %d failed"
         (length test-desktop--passes) (length test-desktop--failures))
(kill-emacs (if test-desktop--failures 1 0))

(provide 'test-desktop)
;;; test-desktop.el ends here
