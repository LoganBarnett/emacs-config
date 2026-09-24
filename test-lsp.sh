#!/usr/bin/env bash
# Test that the LSP performance setup actually takes effect after a full
# Emacs startup.  The assertions live in test-lsp.el; in short they check
# that lsp-protocol saw LSP_USE_PLISTS when it loaded, that the Nix build and
# the runtime agree on the plist representation, that emacs-lsp-booster wraps
# the resolved server command, that the subprocess/GC tuning from init.el is
# set, and that lsp.el loads byte-compiled rather than as source.  Finally it
# starts a real stdio server (test-lsp-server.sh) through lsp-mode and waits
# for the workspace to reach `initialized' -- the end-to-end symptom.
#
# This test requires `just build` (./result/bin/emacs) to exist first: it
# needs the real lsp-mode compiled by the Nix build, the injected booster
# path, and the byte-compiled config files.

set -o errexit -o nounset -o pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
EMACS="${EMACS:-${SCRIPT_DIR}/result/bin/emacs}"
LOG="${SCRIPT_DIR}/test-lsp.log"

if [ ! -x "$EMACS" ]; then
  echo "Error: Emacs not found at: $EMACS"
  echo "Run 'just build' first, or set EMACS=/path/to/emacs."
  exit 1
fi

echo "Testing that the LSP performance setup survives a full startup..."
echo "Emacs: $EMACS"
echo ""

# mktemp: -d creates a directory.  BSD mktemp (macOS) has no --directory.
TMPDIR=$(mktemp -d)
# rm: -r is recursive, -f is force.  BSD rm (macOS) has no long spellings.
trap 'rm -rf "$TMPDIR"' EXIT

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

# test-lsp.el loads the init itself (it must hook `after-load-functions'
# before lsp-protocol can load), so hand it the path rather than --load-ing
# the init here.  --no-init-file keeps site-start.el (package autoloads);
# --quick would skip it.  The env var is deliberately NOT set in this shell:
# the config must set it on its own, before anything loads lsp bits.
unset LSP_USE_PLISTS
EMACSLOADPATH="" HOME="$TMPDIR" timeout 180 "$EMACS" --batch --no-init-file \
  --eval "(setq test-lsp--init-file \"$DEFAULT_EL\")" \
  --eval "(setq test-lsp--fake-server \"${SCRIPT_DIR}/test-lsp-server.sh\")" \
  --load "${SCRIPT_DIR}/test-lsp.el" \
  2>&1 | tee "$LOG"
EXIT_CODE=${PIPESTATUS[0]}

echo ""
if [ "$EXIT_CODE" -eq 0 ]; then
  echo "✓ LSP test passed!"
  exit 0
elif [ "$EXIT_CODE" -eq 124 ]; then
  echo "✗ LSP test TIMED OUT after 180 seconds"
  echo "  Check: $LOG"
  exit 1
else
  echo "✗ LSP test FAILED (exit code: $EXIT_CODE)"
  echo "  Check: $LOG"
  exit 1
fi
