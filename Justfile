# Justfile for emacs-config

# Default recipe - show available commands
default:
  @just --list

# Test that Emacs can start successfully with our configuration
test-startup:
  @echo "Testing Emacs startup..."
  ./test-startup.sh basic

# Test startup with verbose output
test-startup-verbose:
  @echo "Testing Emacs startup with verbose output..."
  ./test-startup.sh verbose

# Test startup and measure time
test-startup-time:
  @echo "Testing Emacs startup time..."
  ./test-startup.sh timing

# Run all startup tests
test-all: test-startup test-startup-time

# Clean up test logs
clean:
  rm -f emacs-startup*.log

# Test a specific org file initialization
test-org-file file:
  @echo "Testing initialization of {{ file }}..."
  emacs --batch \
  --eval "(load \"./lisp/init.el\")" \
  --eval "(condition-case err (init-org-file \"{{ file }}\") (error (message \"[TEST] ERROR loading {{ file }}: %s\" err) (kill-emacs 1)))" \
  --eval "(message \"[TEST] Successfully loaded {{ file }}\")" \
  --eval "(kill-emacs 0)"

# Test minimal startup (structure validation only)
test-minimal:
  ./test-minimal-startup.sh

# Test initialization structure (validates file paths and hook)
test-structure:
  ./test-init-structure.sh

# Build the full Nix Emacs package (runs byte-compilation, org tangling, etc.)
# This is the most comprehensive test of the configuration.
build:
  nix build .#default

# Test that the Nix-built Emacs can actually start without runtime errors.
# Requires `just build` to have run first (./result must exist).
# Catches errors that the structure test cannot: real package loading, macro
# expansion at load time, evil-define-operator forms, etc.
test-nix-startup:
  ./test-nix-startup.sh

# Test that yasnippet has at least one snippet table loaded after startup.
# Requires `just build` (./result must exist).
# Fails if yas-snippet-dirs points to a non-existent location (e.g. a
# dotfiles-relative path not present in the Nix build or test $HOME).
test-yasnippet:
  ./test-yasnippet.sh

# Test that leader-key bindings (SPC p, SPC o m, …) are registered after a
# full startup.  Requires `just build` (./result must exist).
test-keybindings:
  ./test-keybindings.sh

# Test that C-; on a misspelled word invokes flyspell-correct with suggestions.
# Requires `just build` (./result must exist).
test-flyspell:
  ./test-flyspell.sh

# ERT test suite for org-auto-id.el (standalone, no Nix build needed)
test-org-auto-id:
  ./test/org-auto-id-tests.sh

# Quick test to verify Emacs can start (recommended for CI)
test: test-structure build test-nix-startup test-yasnippet test-keybindings test-flyspell test-org-auto-id
  nix flake check
  @echo "All tests passed!"
