#!/usr/bin/env bash
# Test that the Nix-built Emacs can start with our configuration without
# runtime errors.  Must be run after `nix build .#default` (i.e. `just build`).
#
# In batch mode, any unhandled Lisp error causes Emacs to exit non-zero,
# making this an effective smoke test for runtime init failures.
#
# NOTE: --batch sets debug-on-error=t, which means errors caught by
# condition-case in use-package :init blocks are still fatal here (those same
# errors would be warnings/continuable in interactive mode).  This is
# intentional: we want a clean init with no errors at all.
#
# We use -q (not -Q) in step 2 so that site-start.el runs and package autoloads
# are available.  -Q would also skip site-start.el, causing spurious
# void-function errors for third-party modes that rely on autoloads.

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

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Step 1: Locate the installed init file.
# emacsWithPackagesFromUsePackage with defaultInitFile=true installs our
# init.el as default.el in the emacs-packages-deps site-lisp directory.
# We find it via locate-library, writing to a file to avoid IFS=: quoting
# issues with the Nix emacs shell wrapper.
DEFAULTEL_PATH="$TMPDIR/defaultel-path.txt"
HOME="$TMPDIR" "$EMACS" --batch -Q \
  --eval "(with-temp-file \"$DEFAULTEL_PATH\" (insert (or (locate-library \"default\") \"\")))" \
  --eval '(kill-emacs 0)' 2>/dev/null || true
DEFAULT_EL=$(cat "$DEFAULTEL_PATH" 2>/dev/null || echo "")

if [ -z "$DEFAULT_EL" ]; then
  echo "Error: Could not locate default.el (our init.el) in the Nix-built Emacs load path."
  echo "Check that 'nix build .#default' completed successfully."
  exit 1
fi
echo "Found init (default.el): $DEFAULT_EL"
echo ""

# Step 2: Load the init file in batch mode.
# -q (--no-init-file) skips the user's init file but keeps site-start.el,
# which loads package autoloads.  We need autoloads so that third-party mode
# functions (e.g. vertico-mode called in :init blocks) are resolvable.
# -Q would also skip site-start.el, making autoloads unavailable, which
# causes spurious void-function errors that don't occur in interactive mode.
# --load explicitly loads our Nix-installed init (default.el / init.el).
# Batch mode sets debug-on-error=t, so any unhandled Lisp error exits 255.
HOME="$TMPDIR" timeout 120 "$EMACS" --batch -q --load "$DEFAULT_EL" 2>&1 | tee "$LOG"
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
  exit 1
fi
