;;; test-nix-org-agenda.el --- Assert the Nix agenda declaration took effect -*- lexical-binding: t; -*-

;;; Commentary:

;; Loaded by test-nix-org-agenda.sh AFTER the full init has run against a
;; HOME holding the fixture declaration and note files.  The expected set is
;; the walk of the declared directories minus the exclusions, plus the one
;; declared file that exists.

;;; Code:

(require 'org)

(defvar test-noa--expected
  (mapcar #'expand-file-name
          '("~/declared/notes/a.org"
            "~/declared/notes/sub/b.org"
            "~/declared/work/w.org"
            "~/generated/cal.org"))
  "The agenda files the fixture declaration should yield.")

(let ((actual (sort (copy-sequence org-agenda-files) #'string<))
      (expected (sort (copy-sequence test-noa--expected) #'string<)))
  (message "[NIX ORG AGENDA TEST] expected: %S" expected)
  (message "[NIX ORG AGENDA TEST] actual:   %S" actual)
  (if (equal actual expected)
      (progn
        (message "[NIX ORG AGENDA TEST] PASS: org-agenda-files matches")
        (kill-emacs 0))
    (message "[NIX ORG AGENDA TEST] FAIL: org-agenda-files differs")
    (kill-emacs 1)))

(provide 'test-nix-org-agenda)
;;; test-nix-org-agenda.el ends here
