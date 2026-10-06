#!/bin/bash

set -euo pipefail

FORMAT="text"
OUTPUT="/dev/stdout"
VERBOSE=false
LOG_FILE=""

show_help() {
    echo "Usage: $0 <log_file> [options]"
    echo
    echo "Options:"
    echo "  --format text|csv   Output format (default: text)"
    echo "  --output <path>     Save output to a file"
    echo "  --verbose           Show extra information"
    echo "  --help              Show this help message"
}

check_log_file() {
    if [[ ! -f "$LOG_FILE" ]]; then
        echo "Error: File '$LOG_FILE' not found." >&2
        exit 1
    fi
}

collect_counts() {
    TOTAL=$(grep -c "TEST \(PASS\|FAIL\|SKIP\):" "$LOG_FILE" || true)
    PASSED=$(grep -c "TEST PASS:" "$LOG_FILE" || true)
    FAILED=$(grep -c "TEST FAIL:" "$LOG_FILE" || true)
    SKIPPED=$(grep -c "TEST SKIP:" "$LOG_FILE" || true)

    if [[ "$TOTAL" -gt 0 ]]; then
        PASS_RATE=$(awk "BEGIN {printf \"%.1f\", ($PASSED / $TOTAL) * 100}")
        FAIL_RATE=$(awk "BEGIN {printf \"%.1f\", ($FAILED / $TOTAL) * 100}")
        SKIP_RATE=$(awk "BEGIN {printf \"%.1f\", ($SKIPPED / $TOTAL) * 100}")
    else
        PASS_RATE="0.0"
        FAIL_RATE="0.0"
        SKIP_RATE="0.0"
    fi
}

collect_timing() {
    TIMING_DATA=$(grep "TEST \(PASS\|FAIL\):" "$LOG_FILE" || true)

    if [[ -n "$TIMING_DATA" ]]; then
        MIN_TIME=$(echo "$TIMING_DATA" | \
            sed -E 's/.*\(([^)]+)s\).*/\1/' | sort -n | head -1)

        MAX_TIME=$(echo "$TIMING_DATA" | \
            sed -E 's/.*\(([^)]+)s\).*/\1/' | sort -n | tail -1)

        AVG_TIME=$(echo "$TIMING_DATA" | \
            sed -E 's/.*\(([^)]+)s\).*/\1/' | \
            awk '{sum += $1} END {printf "%.2f", sum / NR}')

        MIN_TEST=$(echo "$TIMING_DATA" | \
            sed -E 's/.*TEST (PASS|FAIL): ([^ ]+) \(([^)]+)s\).*/\2 \3/' | \
            sort -k2,2n | head -1 | sed -E 's/ ([0-9.]+)$//')

        MAX_TEST=$(echo "$TIMING_DATA" | \
            sed -E 's/.*TEST (PASS|FAIL): ([^ ]+) \(([^)]+)s\).*/\2 \3/' | \
            sort -k2,2nr | head -1 | sed -E 's/ ([0-9.]+)$//')
    else
        MIN_TIME="N/A"
        MAX_TIME="N/A"
        AVG_TIME="N/A"
        MIN_TEST="N/A"
        MAX_TEST="N/A"
    fi
}

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_text() {
    ANALYSIS_DATE=$(date '+%Y-%m-%d %H:%M:%S')

    echo "=== RISC-V Simulation Log Analysis ==="
    echo "Log file: $LOG_FILE"
    echo "Analysis date: $ANALYSIS_DATE"
    echo

    echo "--- Results Summary ---"
    echo "Total tests: $TOTAL"
    echo -e "${GREEN}Passed: $PASSED (${PASS_RATE}%)${NC}"
    echo -e "${RED}Failed: $FAILED (${FAIL_RATE}%)${NC}"
    echo -e "${YELLOW}Skipped: $SKIPPED (${SKIP_RATE}%)${NC}"

    echo
    echo "--- Failed Tests ---"

    if [[ "$FAILED" -gt 0 ]]; then
        grep "TEST FAIL:" "$LOG_FILE" | \
            sed 's/.*TEST FAIL: \([^ ]*\).*/\1/' | \
            awk '{printf "%d. %s\n", NR, $0}'
    else
        echo "None"
    fi

    echo
    echo "--- Timing Statistics ---"

    if [[ "$MIN_TIME" != "N/A" ]]; then
        echo "Min time: ${MIN_TIME}s (${MIN_TEST})"
        echo "Max time: ${MAX_TIME}s (${MAX_TEST})"
        echo "Avg time: ${AVG_TIME}s"
    else
        echo "Min time: N/A"
        echo "Max time: N/A"
        echo "Avg time: N/A"
    fi

    echo

    if [[ "$FAILED" -gt 0 ]]; then
        echo "--- Verdict: FAIL ---"
    else
        echo "--- Verdict: PASS ---"
    fi

    if [[ "$VERBOSE" == true ]]; then
        echo
        echo "--- Verbose Information ---"
        echo "Format: $FORMAT"
        echo "Output: $OUTPUT"
        echo "Analysis completed successfully."
    fi
}

print_csv() {
    echo "Type,Test,Status,Time,Value"

    echo "Summary,,Total,,${TOTAL}"
    echo "Summary,,Passed,,${PASSED}"
    echo "Summary,,Failed,,${FAILED}"
    echo "Summary,,Skipped,,${SKIPPED}"
    echo "Summary,,Pass Rate,,${PASS_RATE}%"
    echo "Summary,,Fail Rate,,${FAIL_RATE}%"
    echo "Summary,,Skip Rate,,${SKIP_RATE}%"

    grep "TEST \(PASS\|FAIL\):" "$LOG_FILE" | \
        sed -E 's/.*TEST (PASS|FAIL): ([^ ]+) \(([^)]+)s\).*/Test,\2,\1,\3s,/' || true

    grep "TEST SKIP:" "$LOG_FILE" | \
        sed -E 's/.*TEST SKIP: ([^ ]+) \(([^)]+)\).*/Test,\1,SKIP,,/' || true

    echo "Timing,,Minimum,,${MIN_TIME}s"
    echo "Timing,,Maximum,,${MAX_TIME}s"
    echo "Timing,,Average,,${AVG_TIME}s"

    if [[ "$FAILED" -gt 0 ]]; then
        echo "Verdict,,FAIL,,"
    else
        echo "Verdict,,PASS,,"
    fi
}

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

check_log_file
collect_counts
collect_timing

if [[ "$FORMAT" == "text" ]]; then
    print_text > "$OUTPUT"
else
    print_csv > "$OUTPUT"
fi

if [[ "$VERBOSE" == true && "$OUTPUT" != "/dev/stdout" ]]; then
    echo "Output written to: $OUTPUT"
fi

if [[ "$FAILED" -gt 0 ]]; then
    exit 1
else
    exit 0
fi