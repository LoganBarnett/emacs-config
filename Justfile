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

# Quick test to verify Emacs can start (recommended for CI)
test: test-structure
  @echo "Basic initialization test passed!"
