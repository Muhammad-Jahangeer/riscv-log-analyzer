#!/bin/bash

set -euo pipefail

# Check that the analysis CSV report exists
check_report() {
    if [[ ! -f "$1" ]]; then
        echo "Error: Report file '$1' not found."
        exit 1
    fi
}

# Escape special characters for safe HTML output
html_escape() {
    printf '%s' "$1" | sed \
        -e 's/&/\&amp;/g' \
        -e 's/</\&lt;/g' \
        -e 's/>/\&gt;/g' \
        -e 's/"/\&quot;/g'
}

# Generate an HTML report with a table
generate_report() {
    local report_file="$1"
    local output_file="$2"

    mkdir -p "$(dirname "$output_file")"

    {
        echo "<!DOCTYPE html>"
        echo "<html lang=\"en\">"
        echo "<head>"
        echo "    <meta charset=\"UTF-8\">"
        echo "    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">"
        echo "    <title>RISC-V Simulation Report</title>"
        echo "    <style>"
        echo "        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }"
        echo "        h1 { text-align: center; }"
        echo "        p { text-align: center; }"
        echo "        table { width: 100%; border-collapse: collapse; background: white; }"
        echo "        th, td { border: 1px solid #ccc; padding: 10px; text-align: left; }"
        echo "        th { background: #333; color: white; }"
        echo "        tr:nth-child(even) { background: #f2f2f2; }"
        echo "    </style>"
        echo "</head>"
        echo "<body>"

        echo "    <h1>RISC-V Simulation Report</h1>"
        echo "    <p>Generated from: $(html_escape "$report_file")</p>"

        echo "    <table>"
        echo "        <thead>"
        echo "            <tr>"
        echo "                <th>Type</th>"
        echo "                <th>Test</th>"
        echo "                <th>Status</th>"
        echo "                <th>Time</th>"
        echo "                <th>Value</th>"
        echo "            </tr>"
        echo "        </thead>"
        echo "        <tbody>"

        tail -n +2 "$report_file" | while IFS=',' read -r type test status time value
        do
            echo "            <tr>"
            echo "                <td>$(html_escape "$type")</td>"
            echo "                <td>$(html_escape "$test")</td>"
            echo "                <td>$(html_escape "$status")</td>"
            echo "                <td>$(html_escape "$time")</td>"
            echo "                <td>$(html_escape "$value")</td>"
            echo "            </tr>"
        done

        echo "        </tbody>"
        echo "    </table>"

        echo "</body>"
        echo "</html>"
    } > "$output_file"

    echo "HTML report generated: $output_file"
}

# Check command-line arguments
if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <analysis_csv> <output_html>"
    exit 1
fi

REPORT_FILE="$1"
OUTPUT_FILE="$2"

check_report "$REPORT_FILE"
generate_report "$REPORT_FILE" "$OUTPUT_FILE"