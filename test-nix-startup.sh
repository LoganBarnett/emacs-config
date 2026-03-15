#!/usr/bin/env bash
# Test that the Nix-built Emacs can start with our configuration without
# runtime errors.  Must be run after `nix build .#default` (i.e. `just build`).
#
# This test catches errors that the structure test cannot, because it runs the
# actual compiled and installed packages rather than mocking them.  In batch
# mode, any unhandled Lisp error causes Emacs to print the backtrace and exit
# with code 255, making this an effective smoke test for runtime init failures.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
EMACS="${SCRIPT_DIR}/result/bin/emacs"
LOG="${SCRIPT_DIR}/test-nix-startup.log"

if [ ! -x "$EMACS" ]; then
  echo "Error: ./result/bin/emacs not found."
  echo "Run 'just build' first, then run this test."
  exit 1
fi

echo "Testing Nix-built Emacs startup..."
echo "Emacs: $EMACS"
echo ""

# Use a temporary HOME directory so Emacs does not find any local user init
# files.  Without a user init file, Emacs falls back to default.el, which is
# where emacsWithPackagesFromUsePackage (defaultInitFile = true) installs our
# init.el.
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Run the built Emacs in batch mode with a 120-second timeout.
# - No -q/-Q so site-start.el and default.el (our init.el) are loaded.
# - Batch mode + unhandled Lisp error = exit 255 → test fails.
# - Batch mode + clean completion = exit 0 → test passes.
HOME="$TMPDIR" timeout 120 "$EMACS" --batch 2>&1 | tee "$LOG"
EXIT_CODE=${PIPESTATUS[0]}

echo ""
if [ "$EXIT_CODE" -eq 0 ]; then
  echo "✓ Nix startup test passed!"
  exit 0
elif [ "$EXIT_CODE" -eq 124 ]; then
  echo "✗ Nix startup test TIMED OUT after 120 seconds"
  echo "  This may indicate a hang during initialization."
  echo "  Check: $LOG"
  exit 1
else
  echo "✗ Nix startup test FAILED (exit code: $EXIT_CODE)"
  echo "  Check: $LOG"
  echo ""
  echo "Last 30 lines of output:"
  tail -30 "$LOG"
  exit 1
fi
