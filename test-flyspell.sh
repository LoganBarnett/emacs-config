#!/usr/bin/env bash
# Test that C-; on a misspelled word invokes the flyspell-correct interface
# with spelling suggestions.
#
# Requires `just build` (./result/bin/emacs) to exist first.
# The flyspell-correct UI is mocked so no display is needed in batch mode.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
EMACS="${EMACS:-${SCRIPT_DIR}/result/bin/emacs}"
LOG="${SCRIPT_DIR}/test-flyspell.log"

if [ ! -x "$EMACS" ]; then
  echo "Error: Emacs not found at: $EMACS"
  echo "Run 'just build' first, or set EMACS=/path/to/emacs."
  exit 1
fi

echo "Testing C-; flyspell-correct keybinding..."
echo "Emacs: $EMACS"
echo ""

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

DEFAULTEL_PATH="$TMPDIR/defaultel-path.txt"
EMACSLOADPATH="" HOME="$TMPDIR" "$EMACS" --batch -Q \
  --eval "(with-temp-file \"$DEFAULTEL_PATH\" (insert (or (locate-library \"default\") \"\")))" \
  --eval '(kill-emacs 0)' 2>/dev/null || true
DEFAULT_EL=$(cat "$DEFAULTEL_PATH" 2>/dev/null || echo "")

if [ -z "$DEFAULT_EL" ]; then
  echo "Error: Could not locate default.el in the Nix-built Emacs load path."
  echo "Run 'just build' first."
  exit 1
fi
echo "Found init (default.el): $DEFAULT_EL"
echo ""

# noninteractive nil is required so that map! actually registers keybindings
# (doom-keybinds.el skips binding registration in noninteractive mode).
EMACSLOADPATH="" HOME="$TMPDIR" timeout 120 "$EMACS" --batch -q \
  --eval "(setq noninteractive nil)" \
  --load "$DEFAULT_EL" \
  --load "${SCRIPT_DIR}/test-flyspell.el" \
  2>&1 | tee "$LOG"
EXIT_CODE=${PIPESTATUS[0]}

echo ""
if [ "$EXIT_CODE" -eq 0 ]; then
  echo "✓ Flyspell test passed!"
  exit 0
elif [ "$EXIT_CODE" -eq 124 ]; then
  echo "✗ Flyspell test TIMED OUT after 120 seconds"
  echo "  Check: $LOG"
  exit 1
else
  echo "✗ Flyspell test FAILED (exit code: $EXIT_CODE)"
  echo "  Check: $LOG"
  exit 1
fi
