#!/bin/bash

set -euo pipefail

# Check that required commands are available
check_command() {
    if command -v "$1" >/dev/null 2>&1; then
        echo "[OK] $1 is installed."
    else
        echo "[ERROR] $1 is not installed."
        return 1
    fi
}

echo "=== RISC-V Log Analyzer Environment Setup ==="
echo

check_command "bash"
check_command "grep"
check_command "sed"
check_command "awk"
check_command "sort"

echo
echo "Environment setup check complete."