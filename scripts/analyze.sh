#!/bin/bash

set -euo pipefail

# Default options
FORMAT="text"
OUTPUT="/dev/stdout"
VERBOSE=false
LOG_FILE=""

# Display help information
show_help() {
    echo "Usage: $0 <log_file> [options]"
    echo
    echo "Options:"
    echo "  --format text|csv   Output format (default: text)"
    echo "  --output <path>     Save output to a file"
    echo "  --verbose           Show extra information"
    echo "  --help              Show this help message"
}

# Check whether the log file exists
check_log_file() {
    if [[ ! -f "$LOG_FILE" ]]; then
        echo "Error: File '$LOG_FILE' not found." >&2
        exit 1
    fi
}

# Collect test counts
collect_counts() {
    TOTAL=$(grep -c "TEST \(PASS\|FAIL\|SKIP\):" "$LOG_FILE" || true)
    PASSED=$(grep -c "TEST PASS:" "$LOG_FILE" || true)
    FAILED=$(grep -c "TEST FAIL:" "$LOG_FILE" || true)
    SKIPPED=$(grep -c "TEST SKIP:" "$LOG_FILE" || true)

    if [[ "$TOTAL" -gt 0 ]]; then
        PASS_RATE=$(awk "BEGIN {printf \"%.1f\", ($PASSED / $TOTAL) * 100}")
    else
        PASS_RATE="0.0"
    fi
}

# Collect timing statistics
collect_timing() {
    TIMES=$(grep "TEST \(PASS\|FAIL\):" "$LOG_FILE" | \
        sed -E 's/.*\(([^)]+)s\).*/\1/' || true)

    if [[ -n "$TIMES" ]]; then
        MIN=$(echo "$TIMES" | sort -n | head -1)
        MAX=$(echo "$TIMES" | sort -n | tail -1)
        AVG=$(echo "$TIMES" | awk '{sum += $1} END {printf "%.2f", sum / NR}')
    else
        MIN="N/A"
        MAX="N/A"
        AVG="N/A"
    fi
}

# Print normal text output
print_text() {
    echo "=== RISC-V Simulation Log Analysis ==="
    echo "Log file: $LOG_FILE"
    echo

    echo "--- Results Summary ---"
    echo "Total tests: $TOTAL"
    echo "Passed: $PASSED"
    echo "Failed: $FAILED"
    echo "Skipped: $SKIPPED"
    echo "Pass rate: ${PASS_RATE}%"

    echo
    echo "--- Failing Tests ---"

    if [[ "$FAILED" -gt 0 ]]; then
        grep "TEST FAIL:" "$LOG_FILE" | \
            sed 's/.*TEST FAIL: \([^ ]*\).*/\1/'
    else
        echo "None"
    fi

    echo
    echo "--- Execution Time Per Test ---"

    grep "TEST \(PASS\|FAIL\):" "$LOG_FILE" | \
        sed -E 's/.*TEST (PASS|FAIL): ([^ ]+) \(([^)]+)\).*/\2: \3/'

    echo
    echo "--- Execution Time Statistics ---"
    echo "Minimum: ${MIN}s"
    echo "Maximum: ${MAX}s"
    echo "Average: ${AVG}s"

    # Show extra information when verbose mode is enabled
    if [[ "$VERBOSE" == true ]]; then
        echo
        echo "--- Verbose Information ---"
        echo "Format: $FORMAT"
        echo "Output: $OUTPUT"
        echo "Analysis completed successfully."
    fi
}

# Print CSV output
print_csv() {
    echo "Type,Test,Status,Time,Value"

    echo "Summary,,Total,,${TOTAL}"
    echo "Summary,,Passed,,${PASSED}"
    echo "Summary,,Failed,,${FAILED}"
    echo "Summary,,Skipped,,${SKIPPED}"
    echo "Summary,,Pass Rate,,${PASS_RATE}%"

    # Add each test and its execution time
    grep "TEST \(PASS\|FAIL\):" "$LOG_FILE" | \
        sed -E 's/.*TEST (PASS|FAIL): ([^ ]+) \(([^)]+)s\).*/Test,\2,\1,\3s,/' 

    # Add skipped tests
    grep "TEST SKIP:" "$LOG_FILE" | \
        sed -E 's/.*TEST SKIP: ([^ ]+) \(([^)]+)\).*/Test,\1,SKIP,,/' || true

    echo "Timing,,Minimum,,${MIN}s"
    echo "Timing,,Maximum,,${MAX}s"
    echo "Timing,,Average,,${AVG}s"
}

# Parse command-line arguments
if [[ "$#" -eq 0 ]]; then
    echo "Error: Log file is required." >&2
    echo "Usage: $0 <log_file> [options]"
    exit 1
fi

if [[ "${1:-}" == "--help" ]]; then
    show_help
    exit 0
fi

LOG_FILE="$1"
shift

while [[ $# -gt 0 ]]; do
    case "$1" in
        --format)
            if [[ $# -lt 2 ]]; then
                echo "Error: --format requires text or csv." >&2
                exit 1
            fi

            FORMAT="$2"

            if [[ "$FORMAT" != "text" && "$FORMAT" != "csv" ]]; then
                echo "Error: Format must be 'text' or 'csv'." >&2
                exit 1
            fi

            shift 2
            ;;

        --output)
            if [[ $# -lt 2 ]]; then
                echo "Error: --output requires a file path." >&2
                exit 1
            fi

            OUTPUT="$2"
            shift 2
            ;;

        --verbose)
            VERBOSE=true
            shift
            ;;

        --help)
            show_help
            exit 0
            ;;

        *)
            echo "Error: Unknown option '$1'." >&2
            echo "Use --help for usage information."
            exit 1
            ;;
    esac
done

# Validate log file
check_log_file

# Collect analysis data
collect_counts
collect_timing

# Generate output
if [[ "$FORMAT" == "text" ]]; then
    print_text > "$OUTPUT"
else
    print_csv > "$OUTPUT"
fi

# Verbose information for terminal
if [[ "$VERBOSE" == true && "$OUTPUT" != "/dev/stdout" ]]; then
    echo "Output written to: $OUTPUT"
fi

# Return failure status when any test fails
if [[ "$FAILED" -gt 0 ]]; then
    exit 1
else
    exit 0
fi