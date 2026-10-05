# RISC-V Log Analyzer Makefile

SHELL := /bin/bash

ANALYZER := ./scripts/analyze.sh
SETUP := ./scripts/setup_env.sh
REPORT_GENERATOR := ./scripts/generate_report.sh

LOG_FILE := test_data/sample_sim.log
PASS_LOG := test_data/sample_pass.log
FAIL_LOG := test_data/sample_fail.log

OUTPUT_DIR := output
CSV_REPORT := $(OUTPUT_DIR)/analysis.csv
FINAL_REPORT := $(OUTPUT_DIR)/final_report.txt

.PHONY: all test report clean help setup

all: test report

# Run the analyzer on the sample simulation log
test:
	$(ANALYZER) $(LOG_FILE)

# Generate CSV and final report
report:
	mkdir -p $(OUTPUT_DIR)
	$(ANALYZER) $(LOG_FILE) --format csv --output $(CSV_REPORT) || true
	$(REPORT_GENERATOR) $(CSV_REPORT) $(FINAL_REPORT)

# Remove generated output files
clean:
	rm -f $(OUTPUT_DIR)/*

# Show available Makefile targets
help:
	@echo "RISC-V Log Analyzer"
	@echo
	@echo "Available targets:"
	@echo "  make all     Run tests and generate report"
	@echo "  make test    Analyze the sample simulation log"
	@echo "  make report  Generate CSV and text reports"
	@echo "  make clean   Remove generated output files"
	@echo "  make help    Show this help message"
	@echo "  make setup   Check required environment commands"

# Check the environment
setup:
	$(SETUP)