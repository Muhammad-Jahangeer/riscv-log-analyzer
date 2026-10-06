#!/bin/bash

set -euo pipefail

FORMAT="text"
OUTPUT="/dev/stdout"
VERBOSE=false
LOG_FILE=""
COMPARE_MODE=false
COMPARE_LOG=""

show_help() {
    echo "Usage: $0 <log_file> [options]"
    echo "       $0 --compare <old_log> <new_log> [options]"
    echo
    echo "Options:"
    echo "  --format text|csv       Output format (default: text)"
    echo "  --output <path>         Save output to a file"
    echo "  --verbose               Show extra information"
    echo "  --compare <new_log>     Compare current log with a newer log"
    echo "  --help                  Show this help message"
}

check_log_file() {
    if [[ ! -f "$1" ]]; then
        echo "Error: File '$1' not found." >&2
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
        echo -e "${RED}--- Verdict: FAIL ---${NC}"
    else
        echo -e "${GREEN}--- Verdict: PASS ---${NC}"
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

compare_logs() {
    local old_log="$1"
    local new_log="$2"

    local regression_count=0
    local improvement_count=0
    local new_test_count=0
    local removed_test_count=0

    declare -A OLD_STATUS=()
    declare -A NEW_STATUS=()

    while read -r status test_name; do
        [[ -n "$test_name" ]] && OLD_STATUS["$test_name"]="$status"
    done < <(
        grep "TEST \(PASS\|FAIL\|SKIP\):" "$old_log" | \
            sed -E 's/.*TEST (PASS|FAIL|SKIP): ([^ ]+).*/\1 \2/' || true
    )

    while read -r status test_name; do
        [[ -n "$test_name" ]] && NEW_STATUS["$test_name"]="$status"
    done < <(
        grep "TEST \(PASS\|FAIL\|SKIP\):" "$new_log" | \
            sed -E 's/.*TEST (PASS|FAIL|SKIP): ([^ ]+).*/\1 \2/' || true
    )

    {
        echo "=== RISC-V Simulation Log Comparison ==="
        echo "Before: $old_log"
        echo "After:  $new_log"
        echo

        echo "--- Regressions (PASS -> FAIL) ---"

        for test_name in "${!OLD_STATUS[@]}"; do
            old_status="${OLD_STATUS[$test_name]}"
            new_status="${NEW_STATUS[$test_name]:-MISSING}"

            if [[ "$old_status" == "PASS" && "$new_status" == "FAIL" ]]; then
                echo -e "${RED}REGRESSION: $test_name (PASS -> FAIL)${NC}"
                regression_count=$((regression_count + 1))
            fi
        done

        if [[ "$regression_count" -eq 0 ]]; then
            echo "None"
        fi

        echo
        echo "--- Improvements (FAIL -> PASS) ---"

        for test_name in "${!OLD_STATUS[@]}"; do
            old_status="${OLD_STATUS[$test_name]}"
            new_status="${NEW_STATUS[$test_name]:-MISSING}"

            if [[ "$old_status" == "FAIL" && "$new_status" == "PASS" ]]; then
                echo -e "${GREEN}IMPROVEMENT: $test_name (FAIL -> PASS)${NC}"
                improvement_count=$((improvement_count + 1))
            fi
        done

        if [[ "$improvement_count" -eq 0 ]]; then
            echo "None"
        fi

        echo
        echo "--- New Tests ---"

        for test_name in "${!NEW_STATUS[@]}"; do
            if [[ -z "${OLD_STATUS[$test_name]+exists}" ]]; then
                echo "NEW: $test_name (${NEW_STATUS[$test_name]})"
                new_test_count=$((new_test_count + 1))
            fi
        done

        if [[ "$new_test_count" -eq 0 ]]; then
            echo "None"
        fi

        echo
        echo "--- Removed Tests ---"

        for test_name in "${!OLD_STATUS[@]}"; do
            if [[ -z "${NEW_STATUS[$test_name]+exists}" ]]; then
                echo "REMOVED: $test_name (${OLD_STATUS[$test_name]})"
                removed_test_count=$((removed_test_count + 1))
            fi
        done

        if [[ "$removed_test_count" -eq 0 ]]; then
            echo "None"
        fi

        echo
        echo "--- Comparison Summary ---"
        echo "Regressions: $regression_count"
        echo "Improvements: $improvement_count"
        echo "New tests: $new_test_count"
        echo "Removed tests: $removed_test_count"

        echo

        if [[ "$regression_count" -gt 0 ]]; then
            echo -e "${RED}Comparison Result: REGRESSION DETECTED${NC}"
        else
            echo -e "${GREEN}Comparison Result: NO REGRESSIONS${NC}"
        fi
    } > "$OUTPUT"

    if [[ "$VERBOSE" == true && "$OUTPUT" != "/dev/stdout" ]]; then
        echo "Output written to: $OUTPUT"
    fi

    if [[ "$regression_count" -gt 0 ]]; then
        return 1
    fi

    return 0
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

# Support: ./analyze.sh --compare old.log new.log
if [[ "${1:-}" == "--compare" ]]; then
    if [[ "$#" -lt 3 ]]; then
        echo "Error: --compare requires two log files." >&2
        echo "Usage: $0 --compare <old_log> <new_log> [options]"
        exit 1
    fi

    COMPARE_MODE=true
    LOG_FILE="$2"
    COMPARE_LOG="$3"
    shift 3
else
    LOG_FILE="$1"
    shift
fi

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

        --compare)
            if [[ $# -lt 2 ]]; then
                echo "Error: --compare requires a new log file." >&2
                exit 1
            fi

            COMPARE_MODE=true
            COMPARE_LOG="$2"
            shift 2
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

if [[ "$COMPARE_MODE" == true ]]; then
    check_log_file "$LOG_FILE"
    check_log_file "$COMPARE_LOG"

    if [[ "$FORMAT" != "text" ]]; then
        echo "Error: --compare currently supports text output only." >&2
        exit 1
    fi

    compare_logs "$LOG_FILE" "$COMPARE_LOG"
    exit $?
fi

check_log_file "$LOG_FILE"
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