# Testing Emacs Configuration

This repository includes several tests to ensure the Emacs configuration can start and initialize properly.

## Available Tests

### Quick Structure Test
```bash
# Using just:
just test-structure

# Or directly:
./test-init-structure.sh
```

This test validates:
- All file paths are correctly resolved using relative paths
- The initialization completes and runs the `config/init-complete-hook`
- The configuration can be loaded from any directory (not dependent on `~/dev/dotfiles`)

### Minimal Startup Test
```bash
# Using just:
just test-minimal

# Or directly:
./test-minimal-startup.sh
```

This test attempts to load the full configuration with mocked package functions. It's useful for catching structural issues in the configuration.

### Full Startup Tests
```bash
# Basic startup test
just test-startup
./test-startup.sh basic

# Verbose test with debug output
just test-startup-verbose
./test-startup.sh verbose

# Timing test
just test-startup-time
./test-startup.sh timing

# Run all tests
./test-startup.sh all
```

These tests require a full Emacs environment with packages installed. They will fail in minimal environments (like CI) but are useful for local testing.

### Test Specific Org File
```bash
just test-org-file theme.org
```

This loads a specific org file to test if it can be tangled and loaded correctly.

## Using the Hook

The configuration now includes a `config/init-complete-hook` that runs when initialization is complete. You can use this hook to:

1. Run post-initialization tasks
2. Validate the environment
3. Measure startup time

Example usage:
```elisp
(add-hook 'config/init-complete-hook
          (lambda ()
            (message "Emacs initialized in %.3f seconds"
                     (float-time (time-subtract (current-time) before-init-time)))))
```

## CI Integration

For continuous integration, use the structure test:

```yaml
# Example GitHub Actions
- name: Test Emacs configuration
  run: |
    cd emacs-config
    ./test-init-structure.sh
```

This test is fast, doesn't require packages, and validates the essential structure of your configuration.

## Relative Paths

The configuration has been updated to use relative paths instead of hardcoded paths. This means:
- `init-org-file` now resolves paths relative to the configuration directory
- The configuration can be cloned and used from any location
- Tests can run without modifying system paths