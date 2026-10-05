# RISC-V Log Analyzer

A shell-based tool for analyzing RISC-V simulation logs and generating human-readable and CSV reports.

## Description

RISC-V Log Analyzer reads simulation log files and extracts:

- Total number of tests
- PASS, FAIL, and SKIP counts
- Pass rate
- Failing test names
- Execution time for each test
- Minimum, maximum, and average execution time

The analyzer supports text and CSV output, output files, verbose mode, error handling, and exit codes.

## Installation

Make the scripts executable:

    chmod +x scripts/analyze.sh
    chmod +x scripts/setup_env.sh
    chmod +x scripts/generate_report.sh

Check the environment:

    make setup

## Usage

Analyze a log:

    ./scripts/analyze.sh test_data/sample_fail.log

Show help:

    ./scripts/analyze.sh --help

Generate CSV output:

    ./scripts/analyze.sh test_data/sample_fail.log --format csv

Save CSV output:

    ./scripts/analyze.sh test_data/sample_fail.log --format csv --output output/analysis.csv

Enable verbose mode:

    ./scripts/analyze.sh test_data/sample_fail.log --verbose

Generate a report:

    make report

Run the complete workflow:

    make all

## Makefile Commands

- make all - Run analysis and generate reports
- make test - Analyze the sample simulation log
- make report - Generate CSV and text reports
- make clean - Remove generated output files
- make help - Show available commands
- make setup - Check required environment commands

## Sample Output

    === RISC-V Simulation Log Analysis ===
    Log file: test_data/sample_fail.log

    --- Results Summary ---
    Total tests: 7
    Passed: 4
    Failed: 2
    Skipped: 1
    Pass rate: 57.1%

    --- Failing Tests ---
    rv32i-sll
    rv32i-beq

    --- Execution Time Per Test ---
    rv32i-add: 0.42s
    rv32i-sub: 0.65s
    rv32i-sll: 1.02s
    rv32i-beq: 2.31s
    rv32i-mul: 1.15s
    rv32i-nop: 0.42s

    --- Execution Time Statistics ---
    Minimum: 0.42s
    Maximum: 2.31s
    Average: 1.00s

## Exit Codes

- 0 - All tests passed
- 1 - One or more tests failed or an error occurred

## Project Structure

    riscv-log-analyzer/
    ├── README.md
    ├── Makefile
    ├── .gitignore
    ├── scripts/
    │   ├── analyze.sh
    │   ├── setup_env.sh
    │   └── generate_report.sh
    ├── test_data/
    │   ├── sample_sim.log
    │   ├── sample_pass.log
    │   └── sample_fail.log
    ├── output/
    └── docs/
        └── USAGE.md
