#!/bin/bash

set -euo pipefail

# Check that the analysis report exists
check_report() {
    if [[ ! -f "$1" ]]; then
        echo "Error: Report file '$1' not found."
        exit 1
    fi
}

# Generate a simple human-readable report
generate_report() {
    local report_file="$1"
    local output_file="$2"

    {
        echo "========================================"
        echo "       RISC-V Simulation Report"
        echo "========================================"
        echo
        echo "Generated from: $report_file"
        echo
        cat "$report_file"
        echo
        echo "========================================"
        echo "             End of Report"
        echo "========================================"
    } > "$output_file"

    echo "Report generated: $output_file"
}

# Check command-line arguments
if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <analysis_report> <output_file>"
    exit 1
fi

REPORT_FILE="$1"
OUTPUT_FILE="$2"

check_report "$REPORT_FILE"
generate_report "$REPORT_FILE" "$OUTPUT_FILE"