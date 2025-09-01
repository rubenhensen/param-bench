.PHONY: all clean slurm slurm-submit slurm-status slurm-collect slurm-clean jobs

# Local benchmark (original)
all:
	@echo "Starting SAC compilation benchmark (local)..."
	@./benchmark.sh

# SLURM cluster workflow
slurm: slurm-submit

jobs:
	@echo "Generating SLURM job scripts..."
	@./generate_jobs.sh

slurm-submit: jobs
	@echo "Submitting jobs to SLURM cluster..."
	@./submit_all.sh

slurm-status:
	@echo "Checking SLURM job status..."
	@./check_jobs.sh

slurm-collect:
	@echo "Collecting SLURM results..."
	@./collect_results.sh
	@if [ -f results-slurm.csv ]; then \
		echo "Generating SLURM analysis..."; \
		./analyze-slurm.sh; \
	fi

slurm-clean:
	@echo "Cleaning up SLURM files..."
	@rm -f results-*-param.csv results-slurm.csv
	@rm -f slurm-*.out slurm-*.err
	@rm -f job_ids.txt
	@rm -f summary-slurm.md
	@rm -rf jobs/
	@echo "SLURM cleanup complete."

clean:
	@echo "Cleaning up generated files..."
	@rm -f *.mod *.c *.o *.h
	@rm -f results.csv summary.md
	@rm -f 0-param 1-param 2-param 3-param 4-param 5-param 6-param 7-param 8-param 9-param
	@rm -f 10-param 11-param 12-param 13-param 14-param 15-param 16-param 17-param 18-param 19-param
	@echo "Cleanup complete."

help:
	@echo "SAC Compilation Benchmark Suite"
	@echo "================================"
	@echo ""
	@echo "Local execution:"
	@echo "  make all       - Run benchmark locally"
	@echo "  make clean     - Clean local files"
	@echo ""
	@echo "SLURM cluster execution:"
	@echo "  make slurm          - Submit all jobs to SLURM (alias for slurm-submit)"
	@echo "  make jobs           - Generate SLURM job scripts"
	@echo "  make slurm-submit   - Submit jobs to cluster"
	@echo "  make slurm-status   - Check job status"
	@echo "  make slurm-collect  - Collect and analyze results"
	@echo "  make slurm-clean    - Clean SLURM files"
	@echo ""
	@echo "Manual SLURM workflow:"
	@echo "  ./submit_all.sh     - Submit jobs"
	@echo "  ./check_jobs.sh     - Monitor jobs" 
	@echo "  ./collect_results.sh - Collect results"
	@echo "  ./analyze-slurm.sh  - Generate analysis"