#!/usr/bin/env bash
# Test script to verify Emacs can start with our configuration

set -euo pipefail

# Get the absolute path of the script's directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
INIT_FILE="${SCRIPT_DIR}/lisp/init.el"

echo "Testing Emacs startup..."
echo "Using init file: ${INIT_FILE}"

# Test basic startup
test_basic() {
    echo "Running basic startup test..."
    emacs --batch \
        --eval "(setq package-enable-at-startup nil)" \
        --eval "(add-hook 'config/init-complete-hook (lambda () (message \"[TEST] Initialization complete!\") (kill-emacs 0)))" \
        --eval "(condition-case err (load \"${INIT_FILE}\") (error (message \"[TEST] ERROR: %s\" err) (kill-emacs 1)))" \
        2>&1 | tee emacs-startup.log

    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        echo "✓ Basic startup test passed"
        return 0
    else
        echo "✗ Basic startup test failed"
        return 1
    fi
}

# Test startup with timing
test_timing() {
    echo "Running startup timing test..."
    start_time=$(date +%s.%N)

    emacs --batch \
        --eval "(defvar config/startup-time (current-time))" \
        --eval "(add-hook 'config/init-complete-hook (lambda () (message \"[TEST] Initialization took: %.3f seconds\" (float-time (time-subtract (current-time) config/startup-time))) (kill-emacs 0)))" \
        --eval "(load \"${INIT_FILE}\")" \
        2>&1 | tee emacs-startup-time.log

    end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc)

    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        echo "✓ Timing test passed (took ${duration} seconds)"
        return 0
    else
        echo "✗ Timing test failed"
        return 1
    fi
}

# Test verbose/debug mode
test_verbose() {
    echo "Running verbose startup test..."
    emacs --batch --debug-init \
        --eval "(setq debug-on-error t)" \
        --eval "(add-hook 'config/init-complete-hook (lambda () (message \"[TEST] Initialization complete!\") (kill-emacs 0)))" \
        --eval "(condition-case err (load \"${INIT_FILE}\") (error (message \"[TEST] ERROR: %s\" err) (backtrace) (kill-emacs 1)))" \
        2>&1 | tee emacs-startup-verbose.log

    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        echo "✓ Verbose test passed"
        return 0
    else
        echo "✗ Verbose test failed"
        return 1
    fi
}

# Main test runner
main() {
    local failed=0

    # Run tests based on arguments
    if [ $# -eq 0 ]; then
        # Run basic test by default
        test_basic || failed=$((failed + 1))
    else
        for test in "$@"; do
            case $test in
                basic)
                    test_basic || failed=$((failed + 1))
                    ;;
                timing)
                    test_timing || failed=$((failed + 1))
                    ;;
                verbose)
                    test_verbose || failed=$((failed + 1))
                    ;;
                all)
                    test_basic || failed=$((failed + 1))
                    echo ""
                    test_timing || failed=$((failed + 1))
                    ;;
                *)
                    echo "Unknown test: $test"
                    echo "Available tests: basic, timing, verbose, all"
                    exit 1
                    ;;
            esac
            echo ""
        done
    fi

    # Summary
    echo "========================="
    if [ $failed -eq 0 ]; then
        echo "All tests passed! ✓"
        echo "Emacs startup is working correctly."
    else
        echo "$failed test(s) failed ✗"
        echo "Check the log files for details."
        exit 1
    fi
}

main "$@"