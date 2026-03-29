;;; org-auto-id-tests.el --- ERT tests for org-auto-id -*- lexical-binding: t; -*-

;;; Commentary:
;; Test suite for org-auto-id.el.
;; Run with: emacs --batch -L lisp -l ert -l test/org-auto-id-tests -f ert-run-tests-batch-and-exit

;;; Code:

(require 'ert)
(require 'org-auto-id)

;;; Test helpers

(defmacro org-auto-id-test/with-org-buffer (text &rest body)
  "Insert TEXT into a temp `org-mode' buffer, go to point-min, run BODY."
  (declare (indent 1))
  `(with-temp-buffer
     (org-mode)
     (insert ,text)
     (goto-char (point-min))
     ,@body))

(defun org-auto-id-test/populate ()
  "Run `org-auto-id/buffer-custom-id-populate' and reset the element cache.
The cache becomes stale after populate inserts property drawers, which
causes `org-entry-get' to return nil at headline positions."
  (org-auto-id/buffer-custom-id-populate)
  (when (fboundp 'org-element-cache-reset)
    (org-element-cache-reset)))

;;; 1. Pure functions — anchorize-headline-title

(ert-deftest org-auto-id-test/anchorize-simple ()
  "Simple title becomes kebab-case."
  (should (equal "hello-world"
                 (org-auto-id/anchorize-headline-title "Hello World"))))

(ert-deftest org-auto-id-test/anchorize-punctuation ()
  "Parens, commas, quotes, and question marks are removed."
  (should (equal "what-is-this"
                 (org-auto-id/anchorize-headline-title "What is this?")))
  (should (equal "foo-bar"
                 (org-auto-id/anchorize-headline-title "foo (bar)")))
  (should (equal "ab"
                 (org-auto-id/anchorize-headline-title "a,b")))
  (should (equal "hello"
                 (org-auto-id/anchorize-headline-title "\"hello\""))))

(ert-deftest org-auto-id-test/anchorize-idempotent ()
  "Already-kebab input is unchanged."
  (should (equal "already-kebab"
                 (org-auto-id/anchorize-headline-title "already-kebab"))))

;;; 1. Pure functions — id-as-extra-kebab

(ert-deftest org-auto-id-test/extra-kebab-hierarchy ()
  "Hierarchy list produces double-dash-separated kebab IDs."
  (should (equal "foo--bar--baz-qux"
                 (org-auto-id/id-as-extra-kebab '("foo" "bar" "baz qux")))))

(ert-deftest org-auto-id-test/extra-kebab-single ()
  "Single element list produces plain kebab."
  (should (equal "foo"
                 (org-auto-id/id-as-extra-kebab '("foo")))))

(ert-deftest org-auto-id-test/extra-kebab-empty ()
  "Empty list produces empty string."
  (should (equal ""
                 (org-auto-id/id-as-extra-kebab '()))))

;;; 2. Keyword reading

(ert-deftest org-auto-id-test/get-keyword-present ()
  "Returns value when keyword is present."
  (org-auto-id-test/with-org-buffer "#+AUTO_ID: t\n* Heading\n"
    (should (equal "t" (org-auto-id/get-org-keyword "AUTO_ID")))))

(ert-deftest org-auto-id-test/get-keyword-absent ()
  "Returns nil when keyword is absent."
  (org-auto-id-test/with-org-buffer "* Heading\n"
    (should (null (org-auto-id/get-org-keyword "AUTO_ID")))))

(ert-deftest org-auto-id-test/get-keyword-case ()
  "Keyword lookup is case-insensitive for org keywords."
  (org-auto-id-test/with-org-buffer "#+auto_id: t\n* Heading\n"
    (should (equal "t" (org-auto-id/get-org-keyword "AUTO_ID")))))

;;; 3. Buffer population

(ert-deftest org-auto-id-test/populate-flat-headings ()
  "Single-level headings get correct CUSTOM_IDs."
  (org-auto-id-test/with-org-buffer "#+AUTO_ID: t\n* Hello World\n* Another Heading\n"
    (org-auto-id-test/populate)
    (goto-char (point-min))
    (org-next-visible-heading 1)
    (should (equal "hello-world" (org-entry-get (point) "CUSTOM_ID")))
    (org-next-visible-heading 1)
    (should (equal "another-heading" (org-entry-get (point) "CUSTOM_ID")))))

(ert-deftest org-auto-id-test/populate-nested-headings ()
  "Child heading gets parent-prefixed ID."
  (org-auto-id-test/with-org-buffer "#+AUTO_ID: t\n* Parent\n** Child\n"
    (org-auto-id-test/populate)
    (goto-char (point-min))
    (org-next-visible-heading 1)
    (should (equal "parent" (org-entry-get (point) "CUSTOM_ID")))
    (org-next-visible-heading 1)
    (should (equal "parent--child" (org-entry-get (point) "CUSTOM_ID")))))

(ert-deftest org-auto-id-test/populate-deeply-nested ()
  "Three levels produce correct hierarchy."
  (org-auto-id-test/with-org-buffer "#+AUTO_ID: t\n* A\n** B\n*** C\n"
    (org-auto-id-test/populate)
    (goto-char (point-min))
    (org-next-visible-heading 1)
    (should (equal "a" (org-entry-get (point) "CUSTOM_ID")))
    (org-next-visible-heading 1)
    (should (equal "a--b" (org-entry-get (point) "CUSTOM_ID")))
    (org-next-visible-heading 1)
    (should (equal "a--b--c" (org-entry-get (point) "CUSTOM_ID")))))

(ert-deftest org-auto-id-test/populate-idempotent ()
  "Running populate twice produces identical buffer content."
  (org-auto-id-test/with-org-buffer "#+AUTO_ID: t\n* Heading One\n** Sub Heading\n"
    (org-auto-id-test/populate)
    (let ((first-pass (buffer-string)))
      (org-auto-id-test/populate)
      (should (equal first-pass (buffer-string))))))

(ert-deftest org-auto-id-test/populate-skip-unchanged ()
  "Pre-set correct CUSTOM_IDs leave the buffer unmodified."
  (let ((text "#+AUTO_ID: t\n* Hello\n:PROPERTIES:\n:CUSTOM_ID: hello\n:END:\n"))
    (org-auto-id-test/with-org-buffer text
      (org-auto-id-test/populate)
      (should (equal text (buffer-string))))))

(ert-deftest org-auto-id-test/populate-overwrite-wrong-id ()
  "Incorrect existing CUSTOM_ID gets replaced."
  (org-auto-id-test/with-org-buffer
      "#+AUTO_ID: t\n* Hello\n:PROPERTIES:\n:CUSTOM_ID: wrong-id\n:END:\n"
    (org-auto-id-test/populate)
    (goto-char (point-min))
    (org-next-visible-heading 1)
    (should (equal "hello" (org-entry-get (point) "CUSTOM_ID")))))

(ert-deftest org-auto-id-test/populate-special-chars ()
  "Headings with parens, commas, quotes, question marks get clean IDs."
  (org-auto-id-test/with-org-buffer
      "#+AUTO_ID: t\n* What (is) \"this\", really?\n"
    (org-auto-id-test/populate)
    (goto-char (point-min))
    (org-next-visible-heading 1)
    (should (equal "what-is-this-really"
                   (org-entry-get (point) "CUSTOM_ID")))))

;;; 4. Undo preservation

(ert-deftest org-auto-id-test/undo-preserved ()
  "Undo list is preserved after populate — populate changes are not in undo."
  (org-auto-id-test/with-org-buffer "#+AUTO_ID: t\n* Heading\n"
    ;; Make a user edit so the undo list is non-nil.
    (goto-char (point-max))
    (insert "user text")
    (let ((undo-before buffer-undo-list))
      (org-auto-id/buffer-custom-id-populate)
      (should (equal undo-before buffer-undo-list)))))

;;; 5. Save hook gating

(ert-deftest org-auto-id-test/save-hook-runs-with-keyword ()
  "save-auto-id populates IDs when AUTO_ID keyword is present."
  (org-auto-id-test/with-org-buffer "#+AUTO_ID: t\n* Test\n"
    (org-auto-id/save-auto-id)
    (when (fboundp 'org-element-cache-reset) (org-element-cache-reset))
    (goto-char (point-min))
    (org-next-visible-heading 1)
    (should (equal "test" (org-entry-get (point) "CUSTOM_ID")))))

(ert-deftest org-auto-id-test/save-hook-skips-without-keyword ()
  "save-auto-id does nothing when AUTO_ID keyword is absent."
  (org-auto-id-test/with-org-buffer "* Test\n"
    (let ((before (buffer-string)))
      (org-auto-id/save-auto-id)
      (should (equal before (buffer-string))))))

(ert-deftest org-auto-id-test/save-hook-skips-non-org ()
  "save-auto-id does nothing in non-org buffers."
  (with-temp-buffer
    (insert "#+AUTO_ID: t\n* Test\n")
    (let ((before (buffer-string)))
      (org-auto-id/save-auto-id)
      (should (equal before (buffer-string))))))

(ert-deftest org-auto-id-test/save-hook-skips-read-only ()
  "save-auto-id does nothing in read-only buffers."
  (org-auto-id-test/with-org-buffer "#+AUTO_ID: t\n* Test\n"
    (setq buffer-read-only t)
    (let ((before (buffer-string)))
      (org-auto-id/save-auto-id)
      (should (equal before (buffer-string))))))

;;; 6. Custom ID function

(ert-deftest org-auto-id-test/custom-id-fn ()
  "AUTO_ID_FN keyword selects a custom ID generation function."
  (defun org-auto-id-test/upcase-id (hierarchy)
    "Test ID function that upcases and joins with /"
    (upcase (string-join hierarchy "/")))
  (org-auto-id-test/with-org-buffer
      "#+AUTO_ID: t\n#+AUTO_ID_FN: org-auto-id-test/upcase-id\n* Hello World\n"
    (org-auto-id-test/populate)
    (goto-char (point-min))
    (org-next-visible-heading 1)
    (should (equal "HELLO WORLD" (org-entry-get (point) "CUSTOM_ID")))))

(provide 'org-auto-id-tests)

;;; org-auto-id-tests.el ends here
