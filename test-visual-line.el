;;; test-visual-line.el --- Wrap-prefix assertions for the Nix-built Emacs -*- lexical-binding: t; -*-

;;; Commentary:

;; Loaded by test-visual-line.sh after the full init has run.
;;
;; The wrap-prefix companion of `visual-line-mode' must follow that mode's
;; state, not its hook.  The comment above `config--visual-line-companion' in
;; lisp/visual-line-config.el explains what goes wrong otherwise.

;;; Code:

(defvar test-vl--failures '()
  "Descriptions of checks that failed, most recent first.")
(defvar test-vl--passes '()
  "Descriptions of checks that passed, most recent first.")

(defun test-vl--check (description condition)
  "Record DESCRIPTION as passed when CONDITION is non-nil, else as failed."
  (if condition
      (push description test-vl--passes)
    (push description test-vl--failures)))

(defun test-vl--wrap-prefix-active-p ()
  "Return non-nil when a wrap-prefix companion is computing in this buffer."
  (or (bound-and-true-p visual-wrap-prefix-mode)
      (bound-and-true-p adaptive-wrap-prefix-mode)
      (seq-some (lambda (fn)
                  (memq fn '(visual-wrap-prefix-function
                             adaptive-wrap-prefix-function)))
                jit-lock-functions)))

;;
;; ── Checks ───────────────────────────────────────────────────────────────────

(dolist (mode '(emacs-lisp-mode yaml-mode))
  (with-temp-buffer
    (insert "x\n")
    (funcall mode)
    (test-vl--check
     (format "%s: visual-line-mode is off" mode)
     (not visual-line-mode))
    (test-vl--check
     (format "%s: no wrap prefix is computed while visual-line-mode is off"
             mode)
     (not (test-vl--wrap-prefix-active-p)))))

(with-temp-buffer
  (insert "x\n")
  (text-mode)
  (visual-line-mode 1)
  (test-vl--check
   "text-mode: the wrap-prefix companion follows visual-line-mode on"
   (test-vl--wrap-prefix-active-p))
  (visual-line-mode -1)
  (test-vl--check
   "text-mode: the wrap-prefix companion follows visual-line-mode off"
   (not (test-vl--wrap-prefix-active-p))))

;;
;; ── Report ───────────────────────────────────────────────────────────────────

(message "")
(message "[VISUAL-LINE TEST] ===============================================")
(dolist (p (reverse test-vl--passes))
  (message "[VISUAL-LINE TEST] PASS: %s" p))
(dolist (f (reverse test-vl--failures))
  (message "[VISUAL-LINE TEST] FAIL: %s" f))
(message "[VISUAL-LINE TEST] ===============================================")
(message "[VISUAL-LINE TEST] %d passed, %d failed"
         (length test-vl--passes) (length test-vl--failures))
(kill-emacs (if test-vl--failures 1 0))

(provide 'test-visual-line)
;;; test-visual-line.el ends here
