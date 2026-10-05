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

Clone the repository:

```bash
git clone <repository-url>
cd riscv-log-analyzer