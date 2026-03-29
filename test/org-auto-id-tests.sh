#!/usr/bin/env bash
# ERT test suite for org-auto-id.el
#
# Standalone — no Nix build required, just Emacs with org-mode.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"
EMACS="${EMACS:-emacs}"

echo "Running org-auto-id ERT tests..."
echo "Emacs: $EMACS"
echo ""

"$EMACS" --batch \
  -L "$PROJECT_DIR/lisp" \
  -l ert \
  -l "$SCRIPT_DIR/org-auto-id-tests.el" \
  -f ert-run-tests-batch-and-exit
