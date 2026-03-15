#!/usr/bin/env bash
# Test that mu4e can be opened without void-variable errors.
#
# Specifically reproduces:
#   QuitError during redisplay: (eval (mu4e--modeline-string) t)
#   signaled (void-variable maildir-account-inbox-subdir)
#
# The fix is declaring maildir-account-inbox-subdir (and related subdir
# variables) via defcustom in email.org so they are not void when mu4e
# bookmark query lambdas are evaluated during modeline rendering.
#
# This test requires `just build` (./result/bin/emacs) to exist first.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
EMACS="${EMACS:-${SCRIPT_DIR}/result/bin/emacs}"
LOG="${SCRIPT_DIR}/test-mu4e.log"

if [ ! -x "$EMACS" ]; then
  echo "Error: Emacs not found at: $EMACS"
  echo "Run 'just build' first, or set EMACS=/path/to/emacs."
  exit 1
fi

echo "Testing that mu4e opens without void-variable errors (SPC o m)..."
echo "Emacs: $EMACS"
echo ""

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Locate the installed default.el (our init.el installed by the Nix build).
DEFAULTEL_PATH="$TMPDIR/defaultel-path.txt"
EMACSLOADPATH="" HOME="$TMPDIR" "$EMACS" --batch -Q \
  --eval "(with-temp-file \"$DEFAULTEL_PATH\" (insert (or (locate-library \"default\") \"\")))" \
  --eval '(kill-emacs 0)' 2>/dev/null || true
DEFAULT_EL=$(cat "$DEFAULTEL_PATH" 2>/dev/null || echo "")

if [ -z "$DEFAULT_EL" ]; then
  echo "Error: Could not locate default.el in the Nix-built Emacs load path."
  echo "Check that 'nix build .#default' completed successfully."
  exit 1
fi
echo "Found init (default.el): $DEFAULT_EL"
echo ""

# Load the full init, then run the mu4e assertions.
EMACSLOADPATH="" HOME="$TMPDIR" timeout 120 "$EMACS" --batch -q \
  --eval "(setq noninteractive nil)" \
  --load "$DEFAULT_EL" \
  --load "${SCRIPT_DIR}/test-mu4e.el" \
  2>&1 | tee "$LOG"
EXIT_CODE=${PIPESTATUS[0]}

echo ""
if [ "$EXIT_CODE" -eq 0 ]; then
  echo "✓ mu4e test passed!"
  exit 0
elif [ "$EXIT_CODE" -eq 124 ]; then
  echo "✗ mu4e test TIMED OUT after 120 seconds"
  echo "  Check: $LOG"
  exit 1
else
  echo "✗ mu4e test FAILED (exit code: $EXIT_CODE)"
  echo "  Check: $LOG"
  exit 1
fi
