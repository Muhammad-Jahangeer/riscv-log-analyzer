# RISC-V Log Analyzer Makefile

SHELL := /bin/bash

ANALYZER := ./scripts/analyze.sh
SETUP := ./scripts/setup_env.sh
REPORT_GENERATOR := ./scripts/generate_report.sh

TEST_LOGS := test_data/sample_sim.log test_data/sample_pass.log test_data/sample_fail.log
REPORT_LOG := test_data/sample_sim.log

OUTPUT_DIR := output
CSV_REPORT := $(OUTPUT_DIR)/analysis.csv
TEXT_REPORT := $(OUTPUT_DIR)/final_report.txt
HTML_REPORT := $(OUTPUT_DIR)/final_report.html

.PHONY: all test report clean help setup

# Run all tests and then generate the reports
all: test report

# Run the analyzer on every sample log and verify expected results
test:
	@failed=0; \
	for log in $(TEST_LOGS); do \
		echo; \
		echo "=== Testing $$log ==="; \
		rc=0; \
		$(ANALYZER) "$$log" > /tmp/riscv_analyzer_test.out 2>&1 || rc=$$?; \
		cat /tmp/riscv_analyzer_test.out; \
		case "$$log" in \
			test_data/sample_sim.log) \
				expected_total=5; expected_passed=3; expected_failed=1; expected_skipped=1; expected_rc=1 ;; \
			test_data/sample_pass.log) \
				expected_total=4; expected_passed=4; expected_failed=0; expected_skipped=0; expected_rc=0 ;; \
			test_data/sample_fail.log) \
				expected_total=7; expected_passed=4; expected_failed=2; expected_skipped=1; expected_rc=1 ;; \
		esac; \
		if grep -q "Total tests: $$expected_total" /tmp/riscv_analyzer_test.out && \
		   grep -q "Passed: $$expected_passed" /tmp/riscv_analyzer_test.out && \
		   grep -q "Failed: $$expected_failed" /tmp/riscv_analyzer_test.out && \
		   grep -q "Skipped: $$expected_skipped" /tmp/riscv_analyzer_test.out && \
		   [ "$$rc" -eq "$$expected_rc" ]; then \
			echo "Verification: PASS"; \
		else \
			echo "Verification: FAIL"; \
			failed=1; \
		fi; \
	done; \
	rm -f /tmp/riscv_analyzer_test.out; \
	exit $$failed

# Generate CSV, text, and HTML reports
report:
	mkdir -p $(OUTPUT_DIR)
	$(ANALYZER) $(REPORT_LOG) --format csv --output $(CSV_REPORT) || true
	$(ANALYZER) $(REPORT_LOG) --format text --output $(TEXT_REPORT) || true
	$(REPORT_GENERATOR) $(CSV_REPORT) $(HTML_REPORT)

# Remove generated report files but keep .gitkeep
clean:
	rm -f $(OUTPUT_DIR)/*.csv $(OUTPUT_DIR)/*.txt $(OUTPUT_DIR)/*.html

# Show available targets
help:
	@echo "RISC-V Log Analyzer"
	@echo
	@echo "Available targets:"
	@echo "  make all     Run all tests and generate reports"
	@echo "  make test    Analyze all test logs and verify expected results"
	@echo "  make report  Generate CSV, text, and HTML reports"
	@echo "  make clean   Remove generated report files"
	@echo "  make help    Show available Makefile targets"
	@echo "  make setup   Check required environment commands"

# Check required tools
setup:
	$(SETUP)