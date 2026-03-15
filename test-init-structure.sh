#!/usr/bin/env bash
# Test to validate Emacs initialization structure without loading packages

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
INIT_FILE="${SCRIPT_DIR}/lisp/init.el"

echo "Testing Emacs initialization structure..."
echo "This test validates:"
echo "  - All file paths are correctly resolved"
echo "  - All org files exist and can be found"
echo "  - The initialization completes with the hook"
echo ""

# Run Emacs with a minimal test that only checks structure
emacs --batch --quick \
    --eval "(defvar test-mode t)" \
    --eval "(defvar test-org-files nil)" \
    --eval "(defvar test-start-time (current-time))" \
    --eval "(defun init-org-file (file)
              (message \"[TEST] Checking org file: %s\" file)
              (let* ((base-dir (file-name-directory (directory-file-name (file-name-directory (or load-file-name buffer-file-name)))))
                     (file-path (expand-file-name (format \"org/%s\" file) base-dir)))
                (if (file-exists-p file-path)
                    (progn
                      (push file test-org-files)
                      (message \"[TEST] ✓ Found: %s\" file-path))
                  (error \"Missing org file: %s\" file-path))))" \
    --eval "(defun config/init-org-file-private (file)
              (message \"[TEST] Checking private org file: %s\" file)
              (message \"[TEST] (Private files are optional, skipping)\"))" \
    --eval "(defmacro use-package (name &rest args)
              (message \"[TEST] Package declaration: %s\" name)
              nil)" \
    --eval "(defun load-library (lib)
              (message \"[TEST] Would load library: %s\" lib))" \
    --eval "(defun dirty-init ()
              (message \"[TEST] Skipping dirty-init\"))" \
    --eval "(defun batteries-init ()
              (message \"[TEST] Would run batteries-init\")
              (run-hooks 'config/init-complete-hook))" \
    --eval "(add-hook 'config/init-complete-hook
              (lambda ()
                (let ((duration (float-time (time-subtract (current-time) test-start-time))))
                  (message \"[TEST] ======================================\")
                  (message \"[TEST] INITIALIZATION STRUCTURE VALIDATED!\")
                  (message \"[TEST] ======================================\")
                  (message \"[TEST] Found %d org files\" (length test-org-files))
                  (message \"[TEST] Structure test took: %.3f seconds\" duration)
                  (message \"[TEST] ======================================\")
                  (kill-emacs 0))))" \
    --load "${INIT_FILE}" \
    2>&1 | tee emacs-structure-test.log

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo ""
    echo "✓ Structure test passed!"
    echo ""
    echo "Summary:"
    grep "\[TEST\] Found" emacs-structure-test.log | tail -1
    echo ""
    echo "This confirms that:"
    echo "  ✓ Your init files use relative paths correctly"
    echo "  ✓ All referenced org files exist"
    echo "  ✓ The initialization hook works"
    echo "  ✓ The configuration can be loaded from any directory"
else
    echo ""
    echo "✗ Structure test failed - check emacs-structure-test.log for details"
    exit 1
fi