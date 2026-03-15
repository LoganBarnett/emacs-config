;;; test-flyspell.el --- Test C-; flyspell-correct keybinding -*- lexical-binding: t; -*-
;;
;; Loaded by test-flyspell.sh AFTER the full init has run.
;;
;; Verifies that C-; on a misspelled word invokes the flyspell-correct
;; interface with a non-empty list of spelling suggestions.
;;
;; The completion UI is mocked (via flyspell-correct-interface) so the test
;; works in batch mode without any display.
;;
;; Note: flyspell-correct-at-point calls ispell directly via ispell-send-string
;; rather than relying on flyspell overlays, so the dictionary check and e2e
;; test both use the same ispell subprocess API.

(defvar test-flyspell/failures '())
(defvar test-flyspell/passes '())

(defun test-flyspell/check (description condition)
  (if condition
      (push description test-flyspell/passes)
    (push description test-flyspell/failures)))

;;; ── Constants ────────────────────────────────────────────────────────────────

;; A realistic misspelling that ispell/aspell will have suggestions for.
;; "zxqfjk" has no close words so ispell returns zero suggestions;
;; "recieve" is a very common misspelling of "receive" with known corrections.
(defconst test-flyspell/misspelled-word "recieve")

;;; ── Mock ─────────────────────────────────────────────────────────────────────

(defvar test-flyspell/interface-args nil
  "Captured (CANDIDATES WORD) when the mock interface is called.")

(defun test-flyspell/mock-interface (candidates word)
  "Record the call and return the first suggestion, to simulate a selection."
  (setq test-flyspell/interface-args (list candidates word))
  (car candidates))

;;; ── Check 1: word is recognized as misspelled by ispell ─────────────────────
;;
;; Use ispell's -l flag (POSIX, supported by both ispell and aspell): reads
;; words from stdin and writes misspelled ones to stdout.  If the word
;; appears in the output it is not in the dictionary.

(let ((is-misspelled
       (condition-case err
           (with-temp-buffer
             (insert test-flyspell/misspelled-word "\n")
             (let ((out (generate-new-buffer " *test-flyspell-ispell-out*")))
               (call-process-region (point-min) (point-max)
                                    ispell-program-name
                                    nil out nil
                                    "-l")
               (prog1 (with-current-buffer out (< 0 (buffer-size)))
                 (kill-buffer out))))
         (error nil))))
  (test-flyspell/check
   (format "'%s' is not in the dictionary (ispell -l)" test-flyspell/misspelled-word)
   is-misspelled))

;;; ── Checks 2 & 3: C-; is bound in evil state maps ───────────────────────────

(test-flyspell/check
 "C-; is bound in evil-normal-state-map"
 (and (boundp 'evil-normal-state-map)
      (lookup-key evil-normal-state-map (kbd "C-;"))))

(test-flyspell/check
 "C-; is bound in evil-insert-state-map"
 (and (boundp 'evil-insert-state-map)
      (lookup-key evil-insert-state-map (kbd "C-;"))))

;;; ── Check 4: binding points to the right command ────────────────────────────

(test-flyspell/check
 "C-; in evil-normal-state-map is bound to flyspell-correct-at-point"
 (eq (and (boundp 'evil-normal-state-map)
          (lookup-key evil-normal-state-map (kbd "C-;")))
     'flyspell-correct-at-point))

;;; ── Checks 5 & 6: end-to-end ─────────────────────────────────────────────────
;;
;; flyspell-correct-at-point calls ispell-send-string directly (no overlay
;; needed) so we just need flyspell-mode active and the word at point.

(setq test-flyspell/interface-args nil)

(defvar test-flyspell/e2e-result
  (condition-case err
      (with-current-buffer (get-buffer-create "*test-flyspell-e2e*")
        (erase-buffer)
        (flyspell-mode 1)
        (insert test-flyspell/misspelled-word)
        (goto-char (point-min))
        ;; Install the mock before triggering the command.
        (setq flyspell-correct-interface #'test-flyspell/mock-interface)
        ;; Simulate C-; via the bound command.
        (call-interactively
         (lookup-key evil-normal-state-map (kbd "C-;")))
        (kill-buffer)
        test-flyspell/interface-args)
    (error (format "error: %s" err))))

(test-flyspell/check
 "C-; on a misspelled word invokes the flyspell-correct interface"
 (and (listp test-flyspell/e2e-result)
      (= 2 (length test-flyspell/e2e-result))))

(test-flyspell/check
 "flyspell-correct interface receives a non-empty suggestions list"
 (and (listp test-flyspell/e2e-result)
      (listp (car test-flyspell/e2e-result))
      (> (length (car test-flyspell/e2e-result)) 0)))

;;; ── Report ───────────────────────────────────────────────────────────────────

(message "")
(message "[FLYSPELL TEST] ================================================")
(dolist (p (reverse test-flyspell/passes))
  (message "[FLYSPELL TEST] PASS: %s" p))
(dolist (f (reverse test-flyspell/failures))
  (message "[FLYSPELL TEST] FAIL: %s" f))
(message "[FLYSPELL TEST] ================================================")
(message "[FLYSPELL TEST] %d passed, %d failed"
         (length test-flyspell/passes) (length test-flyspell/failures))
(kill-emacs (if test-flyspell/failures 1 0))

(provide 'test-flyspell)
;;; test-flyspell.el ends here
