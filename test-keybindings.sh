#!/usr/bin/env bash
# Test that leader-key bindings survive a full Emacs startup.
#
# Specifically checks:
#   SPC p   — project prefix (projectile.org / map! :after projectile)
#   SPC o m — open mu4e     (email.org / on-doom map!)
#
# This test requires `just build` (./result/bin/emacs) to exist first because:
#   - It needs the full package set (evil, general, projectile, mu4e, …)
#   - It needs byte-compiled .el files so the `map!' macro has already been
#     expanded (map! is a no-op in batch mode when loading uncompiled sources)
#
# Known failures with the current code — this test is intentionally red until
# the underlying issues are fixed:
#
#   SPC p   — binding lives inside (with-eval-after-load 'projectile ...) but
#             projectile is never explicitly required during startup.
#   SPC o m — binding is wrapped in (on-doom ...) which always expands to nil
#             in this standalone config because doom-version is not defined.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
EMACS="${EMACS:-${SCRIPT_DIR}/result/bin/emacs}"
LOG="${SCRIPT_DIR}/test-keybindings.log"

if [ ! -x "$EMACS" ]; then
  echo "Error: Emacs not found at: $EMACS"
  echo "Run 'just build' first, or set EMACS=/path/to/emacs."
  exit 1
fi

echo "Testing that leader-key bindings survive a full startup..."
echo "Emacs: $EMACS"
echo ""

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Locate the installed default.el (our init.el installed by the Nix build).
# EMACSLOADPATH="" ensures the Nix wrapper builds the load path entirely from
# the Nix store, with no directories inherited from the calling environment.
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

# Load the full init, then run the keybinding assertions.
# -q keeps site-start.el (package autoloads); -Q would skip it.
# --load runs our test-keybindings.el which calls kill-emacs when done.
#
# `noninteractive' is set to nil before loading the init so that the `map!'
# macro (doom-keybinds.el) actually registers bindings.  In batch mode `map!'
# is a no-op (its guard is `(when (or byte-compile-current-file
# (not noninteractive)) ...)'). The org-tangled .el files are loaded as source
# (not byte-compiled), so without this the test would never see any `map!'
# bindings regardless of whether the underlying config is correct.
EMACSLOADPATH="" HOME="$TMPDIR" timeout 120 "$EMACS" --batch -q \
  --eval "(setq noninteractive nil)" \
  --load "$DEFAULT_EL" \
  --load "${SCRIPT_DIR}/test-keybindings.el" \
  2>&1 | tee "$LOG"
EXIT_CODE=${PIPESTATUS[0]}

echo ""
if [ "$EXIT_CODE" -eq 0 ]; then
  echo "✓ Keybinding test passed!"
  exit 0
elif [ "$EXIT_CODE" -eq 124 ]; then
  echo "✗ Keybinding test TIMED OUT after 120 seconds"
  echo "  Check: $LOG"
  exit 1
else
  echo "✗ Keybinding test FAILED (exit code: $EXIT_CODE)"
  echo "  Check: $LOG"
  exit 1
fi
