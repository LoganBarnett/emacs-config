#!/usr/bin/env bash
# Test that at least one yasnippet snippet table is loaded after startup.
# This exercises the snippet migration: snippets must live inside the repo
# (not a dotfiles-relative path) so they are present in the Nix build and in
# any $HOME-isolated test environment.
#
# The test FAILS if no snippet tables are loaded (yas--tables is empty).
# Requires `just build` (./result) to exist first.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
EMACS="${SCRIPT_DIR}/result/bin/emacs"
LOG="${SCRIPT_DIR}/test-yasnippet.log"

if [ ! -x "$EMACS" ]; then
  echo "Error: ./result/bin/emacs not found."
  echo "Run 'just build' first, then run this test."
  exit 1
fi

echo "Testing yasnippet snippet loading..."
echo "Emacs: $EMACS"
echo ""

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Locate the installed default.el (same approach as test-nix-startup.sh).
DEFAULTEL_PATH="$TMPDIR/defaultel-path.txt"
HOME="$TMPDIR" "$EMACS" --batch -Q \
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

# Load the full init, then assert that at least one snippet table exists.
# yas--tables is a hash table keyed by major-mode symbol; a non-empty hash
# table means at least one snippet directory was found and loaded.
HOME="$TMPDIR" timeout 120 "$EMACS" --batch -q \
  --load "$DEFAULT_EL" \
  --eval '(let ((count (hash-table-count yas--tables)))
            (message "[YAS-TEST] yas-snippet-dirs: %s" yas-snippet-dirs)
            (message "[YAS-TEST] yas--tables count: %d" count)
            (if (> count 0)
                (progn
                  (message "[YAS-TEST] PASS: %d snippet table(s) loaded." count)
                  (kill-emacs 0))
              (progn
                (message "[YAS-TEST] FAIL: no snippet tables loaded.")
                (message "[YAS-TEST] yas-snippet-dirs must point to a directory")
                (message "[YAS-TEST] that exists inside the repo / Nix store.")
                (kill-emacs 1))))' \
  2>&1 | tee "$LOG"
EXIT_CODE=${PIPESTATUS[0]}

echo ""
if [ "$EXIT_CODE" -eq 0 ]; then
  echo "✓ Yasnippet test passed!"
  exit 0
elif [ "$EXIT_CODE" -eq 124 ]; then
  echo "✗ Yasnippet test TIMED OUT after 120 seconds"
  echo "  Check: $LOG"
  exit 1
else
  echo "✗ Yasnippet test FAILED (exit code: $EXIT_CODE)"
  echo "  Snippets were not loaded. The snippet directory is likely missing"
  echo "  or not included in the Nix build."
  echo "  Check: $LOG"
  exit 1
fi
