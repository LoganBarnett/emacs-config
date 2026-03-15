;;; test-mu4e.el --- Tests for mu4e configuration -*- lexical-binding: t; -*-

;; Loaded by test-mu4e.sh AFTER the full init has run.
;;
;; Reproduces the error observed when opening mu4e via `SPC o m':
;;
;;   QuitError during redisplay: (eval (mu4e--modeline-string) t)
;;   signaled (void-variable maildir-account-inbox-subdir)
;;
;; The bookmark query lambdas in email.org reference maildir-account-*
;; variables that are only set (not declared) by mu4e context :vars.
;; Without a prior defcustom/defvar the variables are void when the
;; modeline evaluates those lambdas during redisplay.

(defvar test-mu4e/failures '())
(defvar test-mu4e/passes '())

(defun test-mu4e/check (description condition)
  (if condition
      (push description test-mu4e/passes)
    (push description test-mu4e/failures)))

;;
;; ── Checks ────────────────────────────────────────────────────────────────────

;; These three variables are referenced in the bookmark :query lambdas in
;; email.org (config/mu4e-add-bookmarks, config/mu4e-gmail-messages-delete,
;; config/mu4e-mark-for-spam).  mu4e--modeline-string evaluates those lambdas
;; during redisplay, so all three must be declared before mu4e starts.

(test-mu4e/check
 "maildir-account-inbox-subdir is declared (not void-variable)"
 (boundp 'maildir-account-inbox-subdir))

(test-mu4e/check
 "maildir-account-trash-subdir is declared (not void-variable)"
 (boundp 'maildir-account-trash-subdir))

(test-mu4e/check
 "maildir-account-spam-subdir is declared (not void-variable)"
 (boundp 'maildir-account-spam-subdir))

;; Exercise the bookmark query lambdas the way mu4e--modeline-string does.
;; Only runs when mu4e and its bookmarks are available in the current session.
(when (and (featurep 'mu4e) (boundp 'mu4e-bookmarks))
  (test-mu4e/check
   "mu4e bookmark query lambdas evaluate without void-variable error"
   (condition-case err
       (progn
         (dolist (bm mu4e-bookmarks)
           (let ((query (plist-get bm :query)))
             (when (functionp query)
               (funcall query))))
         t)
     (void-variable
      (message "[MU4E TEST] void-variable caught: %s" (cadr err))
      nil)
     (error
      (message "[MU4E TEST] unexpected error: %s" err)
      nil))))

;;
;; ── Report ────────────────────────────────────────────────────────────────────

(message "")
(message "[MU4E TEST] ================================================")
(dolist (p (reverse test-mu4e/passes))
  (message "[MU4E TEST] PASS: %s" p))
(dolist (f (reverse test-mu4e/failures))
  (message "[MU4E TEST] FAIL: %s" f))
(message "[MU4E TEST] ================================================")
(message "[MU4E TEST] %d passed, %d failed"
         (length test-mu4e/passes) (length test-mu4e/failures))
(kill-emacs (if test-mu4e/failures 1 0))

(provide 'test-mu4e)
;;; test-mu4e.el ends here
