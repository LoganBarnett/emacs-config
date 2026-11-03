#!/usr/bin/env bash
# Test that the Nix agenda declaration drives org-agenda-files.
#
# A scratch HOME gets a nix-org-agenda.json plus note files that exercise
# every rule.  The full init runs against that HOME and
# test-nix-org-agenda.el compares the result.
#
# Requires `just build` (./result/bin/emacs), or set EMACS=/path/to/emacs.

set -o errexit -o nounset -o pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
EMACS="${EMACS:-${SCRIPT_DIR}/result/bin/emacs}"
LOG="${SCRIPT_DIR}/test-nix-org-agenda.log"

if [ ! -x "$EMACS" ]; then
  echo "Error: Emacs not found at: $EMACS"
  echo "Run 'just build' first, or set EMACS=/path/to/emacs."
  exit 1
fi

TMPDIR=$(mktemp --directory)
trap 'rm --recursive --force "$TMPDIR"' EXIT

# The fixture mirrors what nix/home-modules/org-agenda.nix emits.
mkdir --parents "$TMPDIR/.config/emacs" \
  "$TMPDIR/declared/notes/sub" "$TMPDIR/declared/notes/journal" \
  "$TMPDIR/declared/notes/old-notes" "$TMPDIR/declared/work" \
  "$TMPDIR/generated"
touch "$TMPDIR/declared/notes/a.org" "$TMPDIR/declared/notes/sub/b.org" \
  "$TMPDIR/declared/notes/sub/c_archive.org" \
  "$TMPDIR/declared/notes/journal/d.org" \
  "$TMPDIR/declared/notes/old-notes/e.org" "$TMPDIR/declared/notes/SE.org" \
  "$TMPDIR/declared/work/w.org" "$TMPDIR/generated/cal.org"
# The two regexps hold backslashes and a quote, so they travel as jq
# arguments rather than inside the program text.
jq --null-input \
  --arg home "$TMPDIR" \
  --arg archive "_archive\\.org\\'" \
  --arg se "/SE\\.org\\'" \
  '{
    "org-agenda-directories": [
      ($home + "/declared/notes"), ($home + "/declared/work"),
      ($home + "/declared/absent")
    ],
    "org-agenda-excludes": [$archive, "old-notes", "journal/", $se],
    "org-agenda-files": [
      ($home + "/generated/cal.org"), ($home + "/generated/missing.org")
    ]
  }' > "$TMPDIR/.config/emacs/nix-org-agenda.json"

DEFAULTEL_PATH="$TMPDIR/defaultel-path.txt"
# EMACSLOADPATH="" makes the Nix wrapper build the load path from the store
# alone.
LOCATE_FORM="(with-temp-file \"$DEFAULTEL_PATH\"
  (insert (or (locate-library \"default\") \"\")))"
EMACSLOADPATH="" HOME="$TMPDIR" "$EMACS" --batch --quick \
  --eval "$LOCATE_FORM" \
  --eval '(kill-emacs 0)' 2>/dev/null || true
DEFAULT_EL=$(cat "$DEFAULTEL_PATH" 2>/dev/null || echo "")

if [ -z "$DEFAULT_EL" ]; then
  echo "Error: Could not locate default.el in the Nix-built Emacs load path."
  exit 1
fi

echo "Testing that the Nix agenda declaration drives org-agenda-files..."
echo "Emacs: $EMACS"
echo ""

# --no-init-file keeps site-start.el and its package autoloads, which
# --quick would skip.
EMACSLOADPATH="" HOME="$TMPDIR" timeout 120 "$EMACS" --batch --no-init-file \
  --load "$DEFAULT_EL" \
  --load "${SCRIPT_DIR}/test-nix-org-agenda.el" \
  2>&1 | tee "$LOG"
EXIT_CODE=${PIPESTATUS[0]}

# The absent directory and the missing file each earn exactly one warning.
WARNINGS=$(grep --text --count \
  'Warning (nix-org-agenda): .* does not exist' "$LOG" || true)
if [ "$WARNINGS" -ne 2 ]; then
  echo ""
  echo "FAIL: Expected 2 missing-path warnings, saw $WARNINGS"
  echo "  Check: $LOG"
  exit 1
fi

echo ""
if [ "$EXIT_CODE" -eq 0 ]; then
  echo "PASS: Nix org-agenda test passed!"
  exit 0
elif [ "$EXIT_CODE" -eq 124 ]; then
  echo "FAIL: Nix org-agenda test TIMED OUT after 120 seconds"
  echo "  Check: $LOG"
  exit 1
else
  echo "FAIL: Nix org-agenda test FAILED (exit code: $EXIT_CODE)"
  echo "  Check: $LOG"
  exit 1
fi
