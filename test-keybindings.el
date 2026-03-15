;;; test-keybindings.el --- Keybinding assertions for the Nix-built Emacs -*- lexical-binding: t; -*-

;; Loaded by test-keybindings.sh AFTER the full init has run.
;; At this point batteries-init has completed, all org files are loaded, and
;; all use-package :init blocks have executed.
;;
;; We check `doom-leader-map' directly — the keymap that `SPC' dispatches to
;; in evil normal mode — to verify that expected leader-key sequences are
;; registered.  `lookup-key' on a sparse keymap returns:
;;
;;   - A command (or keymap) if the key is bound.
;;   - An integer  if the key is a valid prefix but not itself bound
;;     (this can happen with intermediate keymaps; treat as "bound").
;;   - nil          if the key sequence has no binding at all.
;;
;; NOTE: test-keybindings.sh sets `noninteractive' to nil before loading the
;; init.  Without this, the `map!' macro (doom-keybinds.el) is a no-op in
;; batch mode and no leader-key bindings would be registered at all.

(defvar test-kb/failures '())
(defvar test-kb/passes '())

(defun test-kb/check (description condition)
  (if condition
      (push description test-kb/passes)
    (push description test-kb/failures)))

(defun test-kb/lookup (keys)
  "Return the binding for KEY-SEQUENCE in `doom-leader-map', or nil."
  (and (boundp 'doom-leader-map)
       (lookup-key doom-leader-map (kbd keys))))

(defun test-kb/bound-p (keys)
  "Return non-nil when KEYS has any binding in `doom-leader-map'."
  (let ((b (test-kb/lookup keys)))
    ;; lookup-key returns an integer for valid prefixes; treat that as bound.
    (and b (not (eq b nil)))))

;;
;; ── Checks ────────────────────────────────────────────────────────────────────

;; SPC p — project prefix (projectile.org)
(test-kb/check
 "SPC p is a prefix in doom-leader-map (project commands)"
 (keymapp (test-kb/lookup "p")))

;; SPC o m — open mu4e (email.org)
(test-kb/check
 "SPC o m is bound to mu4e in doom-leader-map"
 (eq (test-kb/lookup "o m") #'mu4e))

;;
;; ── Report ────────────────────────────────────────────────────────────────────

(message "")
(message "[KEYBINDING TEST] ================================================")
(dolist (p (reverse test-kb/passes))
  (message "[KEYBINDING TEST] PASS: %s" p))
(dolist (f (reverse test-kb/failures))
  (message "[KEYBINDING TEST] FAIL: %s" f))
(message "[KEYBINDING TEST] ================================================")
(message "[KEYBINDING TEST] %d passed, %d failed"
         (length test-kb/passes) (length test-kb/failures))
(kill-emacs (if test-kb/failures 1 0))

(provide 'test-keybindings)
;;; test-keybindings.el ends here
