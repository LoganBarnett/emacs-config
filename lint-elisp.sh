#!/usr/bin/env bash
# Byte-compile and checkdoc Emacs Lisp files, printing every compiler warning
# and every checkdoc docstring/comment issue.  Exits 1 if there were any.
#
#   ./lint-elisp.sh FILE...
#
# Uses the Nix-built Emacs so that `eval-when-compile' requires of packages
# resolve and the warnings match what the build prints.  Requires `just
# build` (./result/bin/emacs), or set EMACS=/path/to/emacs.  The checks
# themselves live in lint-elisp.el.

set -o errexit -o nounset -o pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
EMACS="${EMACS:-${SCRIPT_DIR}/result/bin/emacs}"

if [ "$#" -eq 0 ]; then
  echo "Usage: $0 FILE..."
  echo "Example: $0 lisp/lsp.el test-lsp.el"
  exit 2
fi

if [ ! -x "$EMACS" ]; then
  echo "Error: Emacs not found at: $EMACS"
  echo "Run 'just build' first, or set EMACS=/path/to/emacs."
  exit 1
fi

# mktemp: -d creates a directory.  BSD mktemp (macOS) has no --directory.
TMPDIR=$(mktemp -d)
# rm: -r is recursive, -f is force.  BSD rm (macOS) has no long spellings.
trap 'rm -rf "$TMPDIR"' EXIT

# HOME in a scratch directory keeps the run from touching the real one.
# EMACSLOADPATH="" makes the Nix wrapper build the load path from the store
# alone.  --no-init-file skips the user's init but keeps site-start.el,
# which activates the packages the config files require at compile time.
EMACSLOADPATH="" HOME="$TMPDIR" "$EMACS" --batch --no-init-file \
  --load "${SCRIPT_DIR}/lint-elisp.el" "$@"
