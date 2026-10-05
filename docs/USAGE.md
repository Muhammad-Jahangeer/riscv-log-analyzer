# RISC-V Log Analyzer Usage Guide

## Overview

RISC-V Log Analyzer is a shell-based tool that analyzes RISC-V simulation logs.

It extracts:

- Total test count
- PASS count
- FAIL count
- SKIP count
- Pass rate
- Failing test names
- Execution time per test
- Minimum execution time
- Maximum execution time
- Average execution time

The analyzer supports text and CSV output formats.

---

## Analyzer Command

Basic syntax:

```bash
./scripts/analyze.sh <log_file> [options]