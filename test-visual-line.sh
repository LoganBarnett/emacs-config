#!/usr/bin/env bash
# Test that no wrap prefix is computed in buffers that do not wrap, and that
# the wrap-prefix companion of visual-line-mode follows that mode when it is
# toggled.  The checks live in test-visual-line.el.
#
# This test requires `just build` (./result/bin/emacs) to exist first: it
# needs the real package set and the byte-compiled config files.

set -o errexit -o nounset -o pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
EMACS="${EMACS:-${SCRIPT_DIR}/result/bin/emacs}"
LOG="${SCRIPT_DIR}/test-visual-line.log"

if [ ! -x "$EMACS" ]; then
  echo "Error: Emacs not found at: $EMACS"
  echo "Run 'just build' first, or set EMACS=/path/to/emacs."
  exit 1
fi

echo "Testing that wrap prefixes are only computed under visual-line-mode..."
echo "Emacs: $EMACS"
echo ""

TMPDIR=$(mktemp --directory)
trap 'rm --recursive --force "$TMPDIR"' EXIT

# Locate the installed default.el (our init.el installed by the Nix build).
# EMACSLOADPATH="" ensures the Nix wrapper builds the load path entirely from
# the Nix store, with no directories inherited from the calling environment.
DEFAULTEL_PATH="$TMPDIR/defaultel-path.txt"
LOCATE_FORM="(with-temp-file \"$DEFAULTEL_PATH\"
  (insert (or (locate-library \"default\") \"\")))"
EMACSLOADPATH="" HOME="$TMPDIR" "$EMACS" --batch --quick \
  --eval "$LOCATE_FORM" \
  --eval '(kill-emacs 0)' 2>/dev/null || true
DEFAULT_EL=$(cat "$DEFAULTEL_PATH" 2>/dev/null || echo "")

if [ -z "$DEFAULT_EL" ]; then
  echo "Error: Could not locate default.el in the Nix-built Emacs load path."
  echo "Check that 'nix build .#default' completed successfully."
  exit 1
fi
echo "Found init (default.el): $DEFAULT_EL"
echo ""

# Batch mode makes the init skip hooks a real session runs, so `noninteractive'
# is cleared before the init loads.  --no-init-file keeps site-start.el
# (package autoloads); --quick would skip it.
EMACSLOADPATH="" HOME="$TMPDIR" timeout 120 "$EMACS" --batch --no-init-file \
  --eval "(setq noninteractive nil)" \
  --load "$DEFAULT_EL" \
  --load "${SCRIPT_DIR}/test-visual-line.el" \
  2>&1 | tee "$LOG"
EXIT_CODE=${PIPESTATUS[0]}

echo ""
if [ "$EXIT_CODE" -eq 0 ]; then
  echo "✓ Visual-line test passed!"
  exit 0
elif [ "$EXIT_CODE" -eq 124 ]; then
  echo "✗ Visual-line test TIMED OUT after 120 seconds"
  echo "  Check: $LOG"
  exit 1
else
  echo "✗ Visual-line test FAILED (exit code: $EXIT_CODE)"
  echo "  Check: $LOG"
  exit 1
fi
