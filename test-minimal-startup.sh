#!/usr/bin/env bash
# Minimal test to verify Emacs initialization structure is valid

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
INIT_FILE="${SCRIPT_DIR}/lisp/init.el"

echo "Testing minimal Emacs startup (structure validation)..."
echo "Using init file: ${INIT_FILE}"

# Create a minimal test that just validates the structure
emacs --batch --quick \
    --load "${SCRIPT_DIR}/test-structure.el" \
    2>&1 | tee emacs-minimal-startup.log

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo "✓ Minimal startup test passed - initialization structure is valid"
    echo "  This test only validates that:"
    echo "  - All org files can be found and tangled"
    echo "  - The initialization hook runs successfully"
    echo "  - No fatal errors occur during initialization"
    echo ""
    echo "For full functionality testing, run Emacs with your complete package environment."
else
    echo "✗ Minimal startup test failed - check emacs-minimal-startup.log"
    exit 1
fi