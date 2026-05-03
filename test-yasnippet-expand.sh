#!/usr/bin/env bash
# Test that yasnippet TAB expansion works end-to-end.
#
# This is independent of which in-buffer completion popup is configured
# (company, corfu, none).  It exercises the snippet expansion machinery
# itself: yas-minor-mode-map's TAB binding must resolve through
# yas-maybe-expand's :filter to yas-expand at a real snippet trigger,
# and that expansion must replace the trigger with the snippet body.
#
# We use the sh-mode "dir" snippet because it is pure text (no embedded
# elisp evaluation) and contains a distinctive marker ("readlink -f")
# that cannot be confused with the trigger or with default sh-mode text.
#
# Requires `just build` (./result/bin/emacs must exist).

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
EMACS="${SCRIPT_DIR}/result/bin/emacs"
LOG="${SCRIPT_DIR}/test-yasnippet-expand.log"

if [ ! -x "$EMACS" ]; then
  echo "Error: ./result/bin/emacs not found."
  echo "Run 'just build' first, then run this test."
  exit 1
fi

echo "Testing yasnippet TAB expansion..."
echo "Emacs: $EMACS"
echo ""

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Locate the installed default.el (same approach as test-yasnippet.sh).
DEFAULTEL_PATH="$TMPDIR/defaultel-path.txt"
EMACSLOADPATH="" HOME="$TMPDIR" "$EMACS" --batch -Q \
  --eval "(with-temp-file \"$DEFAULTEL_PATH\" (insert (or (locate-library \"default\") \"\")))" \
  --eval '(kill-emacs 0)' 2>/dev/null || true
DEFAULT_EL=$(cat "$DEFAULTEL_PATH" 2>/dev/null || echo "")

if [ -z "$DEFAULT_EL" ]; then
  echo "Error: Could not locate default.el in the Nix-built Emacs load path."
  exit 1
fi
echo "Found init (default.el): $DEFAULT_EL"
echo ""

# The test:
#   1. Load full init (yas-global-mode is enabled, snippet tables loaded).
#   2. Enter sh-mode in a temp buffer (yas-global-mode auto-enables
#      yas-minor-mode in non-excluded modes).
#   3. Insert the trigger "dir" at point.
#   4. Resolve the TAB binding via key-binding -- this exercises the
#      yas-maybe-expand :filter, which only returns yas-expand when a
#      snippet match is present at point.  If the binding does not
#      resolve to yas-expand, that itself is a failure (proves yas
#      either is not active or has no matching snippet).
#   5. Invoke the resolved binding via call-interactively (TAB-equivalent).
#   6. Assert the buffer contains the expanded snippet body marker.
EMACSLOADPATH="" HOME="$TMPDIR" timeout 120 "$EMACS" --batch -q \
  --load "$DEFAULT_EL" \
  --eval '(with-temp-buffer
            (sh-mode)
            (yas-minor-mode 1)
            (insert "dir")
            (let ((tab-cmd (key-binding (kbd "TAB"))))
              (message "[YAS-EXPAND-TEST] TAB resolves to: %s" tab-cmd)
              (unless (eq tab-cmd (quote yas-expand))
                (message "[YAS-EXPAND-TEST] FAIL: TAB at \"dir\" did not resolve to yas-expand.")
                (message "[YAS-EXPAND-TEST] Got %s -- yas-minor-mode-map binding chain is broken or no snippet match." tab-cmd)
                (kill-emacs 1))
              (call-interactively tab-cmd))
            (let ((result (buffer-substring-no-properties (point-min) (point-max))))
              (message "[YAS-EXPAND-TEST] Buffer after TAB: %S" result)
              (if (string-match-p "readlink -f" result)
                  (progn
                    (message "[YAS-EXPAND-TEST] PASS: \"dir\" expanded to its sh-mode snippet body.")
                    (kill-emacs 0))
                (progn
                  (message "[YAS-EXPAND-TEST] FAIL: expansion did not produce expected body.")
                  (message "[YAS-EXPAND-TEST] Expected to find \"readlink -f\" in expansion.")
                  (kill-emacs 1)))))' \
  2>&1 | tee "$LOG"
EXIT_CODE=${PIPESTATUS[0]}

echo ""
if [ "$EXIT_CODE" -eq 0 ]; then
  echo "✓ Yasnippet expansion test passed!"
  exit 0
elif [ "$EXIT_CODE" -eq 124 ]; then
  echo "✗ Yasnippet expansion test TIMED OUT after 120 seconds"
  echo "  Check: $LOG"
  exit 1
else
  echo "✗ Yasnippet expansion test FAILED (exit code: $EXIT_CODE)"
  echo "  Check: $LOG"
  exit 1
fi
