# SAC Parameter Count Compilation Benchmark
# Measures compilation time and memory usage vs parameter count (0-19 parameters)
# Compares two SAC compiler versions: new and orig

# Configuration
COMPILERS := new orig
SAC2C_new := /home/rhensen/sac2c/build_p/sac2c_p
SAC2C_orig := /home/rhensen/orig/sac2c/build_p/sac2c_p
PARAM_COUNTS := $(shell seq 0 19)
RUNS := 10
SOURCE_FILES := $(foreach i,$(PARAM_COUNTS),$(i)-param.sac)

# SLURM Configuration
SLURM_CPUS ?= 1
SLURM_MEM ?= 4G
SLURM_ACCOUNT ?= csmpi
SLURM_PARTITION ?= csmpi_fpga_long
SLURM_GPU ?= 0
SLURM_TIMELIMIT ?= 02:00:00
SLURM_LOGS := slurm_logs

# Python for statistical analysis
PYTHON := python3

.PHONY: all clean slurm-submit slurm-status slurm-collect slurm-clean help benchmark venv
.PHONY: benchmark-new benchmark-orig comparison slurm-sync analyze-slurm-new analyze-slurm-orig

# Default target
all: help

# Setup Python virtual environment for statistical analysis
venv: venv/bin/activate

venv/bin/activate:
	python3 -m venv venv
	venv/bin/pip install scipy numpy
	@echo "Virtual environment created."

# Local benchmark (sequential) - both compilers
benchmark: benchmark-new benchmark-orig comparison

# Local benchmark - new compiler
benchmark-new:
	@echo "Starting SAC compilation benchmark for NEW compiler (local)..."
	@echo "filename,param_count,run,compilation_time,max_memory_kb" > results-new.csv
	@for i in $(PARAM_COUNTS); do \
		filename="$$i-param.sac"; \
		echo "Benchmarking $$filename with NEW compiler..."; \
		for run in $$(seq 1 $(RUNS)); do \
			echo "  Run $$run/$(RUNS)..."; \
			rm -f "$$i-param"; \
			start=$$(date +%s.%N); \
			/usr/bin/time -f "%M" $(SAC2C_new) "$$filename" >/dev/null 2>/tmp/mem_$$$$; \
			end=$$(date +%s.%N); \
			time=$$(echo "$$end - $$start" | bc); \
			mem=$$(cat /tmp/mem_$$$$ 2>/dev/null || echo "0"); \
			echo "$$filename,$$i,$$run,$$time,$$mem" >> results-new.csv; \
			rm -f "$$i-param" /tmp/mem_$$$$; \
		done; \
	done
	@echo "NEW compiler benchmark complete! Results in results-new.csv"

# Local benchmark - orig compiler
benchmark-orig:
	@echo "Starting SAC compilation benchmark for ORIG compiler (local)..."
	@echo "filename,param_count,run,compilation_time,max_memory_kb" > results-orig.csv
	@for i in $(PARAM_COUNTS); do \
		filename="$$i-param.sac"; \
		echo "Benchmarking $$filename with ORIG compiler..."; \
		for run in $$(seq 1 $(RUNS)); do \
			echo "  Run $$run/$(RUNS)..."; \
			rm -f "$$i-param"; \
			start=$$(date +%s.%N); \
			/usr/bin/time -f "%M" $(SAC2C_orig) "$$filename" >/dev/null 2>/tmp/mem_$$$$; \
			end=$$(date +%s.%N); \
			time=$$(echo "$$end - $$start" | bc); \
			mem=$$(cat /tmp/mem_$$$$ 2>/dev/null || echo "0"); \
			echo "$$filename,$$i,$$run,$$time,$$mem" >> results-orig.csv; \
			rm -f "$$i-param" /tmp/mem_$$$$; \
		done; \
	done
	@echo "ORIG compiler benchmark complete! Results in results-orig.csv"

# Analyze local results and compare compilers
comparison: results-new.csv results-orig.csv
	@echo "Analyzing and comparing compilers..."
	@$(MAKE) analyze-new
	@$(MAKE) analyze-orig
	@$(MAKE) compare-compilers

# Analyze new compiler results
analyze-new: results-new.csv
	@echo "Analyzing NEW compiler results..."
	@echo "# SAC Compilation Analysis - NEW Compiler" > summary-new.md
	@echo "" >> summary-new.md
	@echo "## Summary Statistics" >> summary-new.md
	@echo "" >> summary-new.md
	@echo "| Params | Avg Time (s) | Min Time (s) | Max Time (s) | StdDev Time | Avg Mem (MB) | Max Mem (MB) | StdDev Mem |" >> summary-new.md
	@echo "|--------|--------------|--------------|--------------|-------------|--------------|--------------|------------|" >> summary-new.md
	@for i in $(PARAM_COUNTS); do \
		grep "^$$i-param.sac," results-new.csv | awk -F',' -v params=$$i '{ \
			time_sum += $$4; times[NR] = $$4; \
			mem_sum += $$5; mems[NR] = $$5; \
			if (NR == 1 || $$4 < min_time) min_time = $$4; \
			if (NR == 1 || $$4 > max_time) max_time = $$4; \
			if (NR == 1 || $$5 < min_mem) min_mem = $$5; \
			if (NR == 1 || $$5 > max_mem) max_mem = $$5; \
		} END { \
			avg_time = time_sum / NR; avg_mem = mem_sum / NR; \
			for (i = 1; i <= NR; i++) { \
				time_sq += (times[i] - avg_time)^2; \
				mem_sq += (mems[i] - avg_mem)^2; \
			} \
			stddev_time = sqrt(time_sq / NR); stddev_mem = sqrt(mem_sq / NR); \
			printf "| %d | %.3f | %.3f | %.3f | %.3f | %.2f | %.2f | %.2f |\n", \
				params, avg_time, min_time, max_time, stddev_time, \
				avg_mem/1024, max_mem/1024, stddev_mem/1024; \
		}' >> summary-new.md; \
	done
	@echo "" >> summary-new.md
	@echo "Generated: $$(date)" >> summary-new.md
	@cat summary-new.md

# Analyze orig compiler results
analyze-orig: results-orig.csv
	@echo "Analyzing ORIG compiler results..."
	@echo "# SAC Compilation Analysis - ORIG Compiler" > summary-orig.md
	@echo "" >> summary-orig.md
	@echo "## Summary Statistics" >> summary-orig.md
	@echo "" >> summary-orig.md
	@echo "| Params | Avg Time (s) | Min Time (s) | Max Time (s) | StdDev Time | Avg Mem (MB) | Max Mem (MB) | StdDev Mem |" >> summary-orig.md
	@echo "|--------|--------------|--------------|--------------|-------------|--------------|--------------|------------|" >> summary-orig.md
	@for i in $(PARAM_COUNTS); do \
		grep "^$$i-param.sac," results-orig.csv | awk -F',' -v params=$$i '{ \
			time_sum += $$4; times[NR] = $$4; \
			mem_sum += $$5; mems[NR] = $$5; \
			if (NR == 1 || $$4 < min_time) min_time = $$4; \
			if (NR == 1 || $$4 > max_time) max_time = $$4; \
			if (NR == 1 || $$5 < min_mem) min_mem = $$5; \
			if (NR == 1 || $$5 > max_mem) max_mem = $$5; \
		} END { \
			avg_time = time_sum / NR; avg_mem = mem_sum / NR; \
			for (i = 1; i <= NR; i++) { \
				time_sq += (times[i] - avg_time)^2; \
				mem_sq += (mems[i] - avg_mem)^2; \
			} \
			stddev_time = sqrt(time_sq / NR); stddev_mem = sqrt(mem_sq / NR); \
			printf "| %d | %.3f | %.3f | %.3f | %.3f | %.2f | %.2f | %.2f |\n", \
				params, avg_time, min_time, max_time, stddev_time, \
				avg_mem/1024, max_mem/1024, stddev_mem/1024; \
		}' >> summary-orig.md; \
	done
	@echo "" >> summary-orig.md
	@echo "Generated: $$(date)" >> summary-orig.md
	@cat summary-orig.md

# Compare compilers with statistical analysis
compare-compilers: results-new.csv results-orig.csv
	@echo "Comparing NEW vs ORIG compilers..."
	@echo "# Compiler Comparison: NEW vs ORIG" > summary-comparison.md
	@echo "" >> summary-comparison.md
	@echo "## Compilation Time Comparison" >> summary-comparison.md
	@echo "" >> summary-comparison.md
	@echo "| Params | NEW Avg (s) | ORIG Avg (s) | Speedup | Time Diff (s) | Winner |" >> summary-comparison.md
	@echo "|--------|-------------|--------------|---------|---------------|--------|" >> summary-comparison.md
	@for i in $(PARAM_COUNTS); do \
		new_avg=$$(grep "^$$i-param.sac," results-new.csv | awk -F',' '{sum+=$$4} END {printf "%.3f", sum/NR}'); \
		orig_avg=$$(grep "^$$i-param.sac," results-orig.csv | awk -F',' '{sum+=$$4} END {printf "%.3f", sum/NR}'); \
		echo "$$new_avg $$orig_avg" | awk -v params=$$i '{ \
			speedup = $$2 / $$1; \
			diff = $$1 - $$2; \
			winner = ($$1 < $$2) ? "NEW" : "ORIG"; \
			if ($$1 == $$2) winner = "TIE"; \
			printf "| %d | %.3f | %.3f | %.2fx | %+.3f | %s |\n", \
				params, $$1, $$2, speedup, diff, winner; \
		}' >> summary-comparison.md; \
	done
	@echo "" >> summary-comparison.md
	@echo "## Memory Usage Comparison" >> summary-comparison.md
	@echo "" >> summary-comparison.md
	@echo "| Params | NEW Avg (MB) | ORIG Avg (MB) | Mem Ratio | Mem Diff (MB) | Winner |" >> summary-comparison.md
	@echo "|--------|--------------|---------------|-----------|---------------|--------|" >> summary-comparison.md
	@for i in $(PARAM_COUNTS); do \
		new_mem=$$(grep "^$$i-param.sac," results-new.csv | awk -F',' '{sum+=$$5} END {printf "%.2f", sum/NR/1024}'); \
		orig_mem=$$(grep "^$$i-param.sac," results-orig.csv | awk -F',' '{sum+=$$5} END {printf "%.2f", sum/NR/1024}'); \
		echo "$$new_mem $$orig_mem" | awk -v params=$$i '{ \
			ratio = $$1 / $$2; \
			diff = $$1 - $$2; \
			winner = ($$1 < $$2) ? "NEW" : "ORIG"; \
			if ($$1 == $$2) winner = "TIE"; \
			printf "| %d | %.2f | %.2f | %.2fx | %+.2f | %s |\n", \
				params, $$1, $$2, ratio, diff, winner; \
		}' >> summary-comparison.md; \
	done
	@echo "" >> summary-comparison.md
	@echo "## Overall Summary" >> summary-comparison.md
	@echo "" >> summary-comparison.md
	@new_wins=$$(grep "| [0-9]" summary-comparison.md | grep "NEW |" | wc -l); \
	orig_wins=$$(grep "| [0-9]" summary-comparison.md | grep "ORIG |" | wc -l); \
	echo "- Time performance: NEW wins $$new_wins times, ORIG wins $$orig_wins times" >> summary-comparison.md
	@echo "" >> summary-comparison.md
	@echo "Generated: $$(date)" >> summary-comparison.md
	@cat summary-comparison.md

# SLURM: Submit all jobs (both compilers, all parameter counts)
slurm-submit: $(SOURCE_FILES)
	@echo "Generating and submitting SLURM jobs for both compilers..."
	@mkdir -p $(SLURM_LOGS)
	@rm -f job_ids.txt
	@for compiler in $(COMPILERS); do \
		for i in $(PARAM_COUNTS); do \
			echo "Submitting $$i-param job for $$compiler compiler..."; \
			if [ "$$compiler" = "new" ]; then \
				sac2c_path="$(SAC2C_new)"; \
			else \
				sac2c_path="$(SAC2C_orig)"; \
			fi; \
			job_id=$$(sbatch --parsable \
				--job-name=sac-$$compiler-$$i \
				--output=$(SLURM_LOGS)/$$compiler-$$i-param-%j.out \
				--error=$(SLURM_LOGS)/$$compiler-$$i-param-%j.err \
				--time=$(SLURM_TIMELIMIT) \
				--ntasks=1 \
				--cpus-per-task=$(SLURM_CPUS) \
				--mem=$(SLURM_MEM) \
				--account=$(SLURM_ACCOUNT) \
				--partition=$(SLURM_PARTITION) \
				--gres=gpu:$(SLURM_GPU) \
				--wrap="cd $(PWD) && \
					echo 'filename,param_count,run,compilation_time,max_memory_kb,job_id,node' > results-$$compiler-$$i-param.csv && \
					echo 'Starting benchmark for $$i-param.sac with $$compiler compiler on node \$$(hostname)' && \
					echo 'Job ID: \$$SLURM_JOB_ID' && \
					for run in \$$(seq 1 $(RUNS)); do \
						echo 'Run \$$run/$(RUNS) for $$i-param.sac...'; \
						rm -f $$i-param; \
						start=\$$(date +%s.%N); \
						/usr/bin/time -f '%M' $$sac2c_path $$i-param.sac >/dev/null 2>/tmp/mem_\$$\$$; \
						end=\$$(date +%s.%N); \
						time=\$$(echo \"\$$end - \$$start\" | bc); \
						mem=\$$(cat /tmp/mem_\$$\$$ 2>/dev/null || echo '0'); \
						echo \"$$i-param.sac,$$i,\$$run,\$$time,\$$mem,\$$SLURM_JOB_ID,\$$(hostname)\" >> results-$$compiler-$$i-param.csv; \
						rm -f $$i-param /tmp/mem_\$$\$$; \
					done && \
					echo 'Benchmark complete for $$i-param.sac with $$compiler compiler' && \
					echo 'Results saved to results-$$compiler-$$i-param.csv'"); \
			echo "$$job_id $$compiler $$i" >> job_ids.txt; \
			echo "  Job ID: $$job_id"; \
		done; \
	done
	@echo ""
	@echo "All jobs submitted! (40 jobs: 2 compilers × 20 parameter counts)"
	@echo "Monitor with: make slurm-status"

# SLURM: Check job status
slurm-status:
	@if [ ! -f job_ids.txt ]; then \
		echo "No job_ids.txt found. Run 'make slurm-submit' first."; \
		exit 1; \
	fi
	@echo "SAC Benchmark Job Status"
	@echo "========================"
	@echo ""
	@echo "NEW compiler jobs:"
	@while read job_id compiler param; do \
		if [ "$$compiler" = "new" ]; then \
			status=$$(squeue -h -j $$job_id -o "%T" 2>/dev/null || echo "COMPLETED"); \
			echo "  $$param-param ($$job_id): $$status"; \
		fi; \
	done < job_ids.txt
	@echo ""
	@echo "ORIG compiler jobs:"
	@while read job_id compiler param; do \
		if [ "$$compiler" = "orig" ]; then \
			status=$$(squeue -h -j $$job_id -o "%T" 2>/dev/null || echo "COMPLETED"); \
			echo "  $$param-param ($$job_id): $$status"; \
		fi; \
	done < job_ids.txt
	@echo ""
	@echo "Overall queue status:"
	@squeue -u $$USER --format="%.8i %.16j %.8T %.10M %.9l %.6D %R" | grep sac- || echo "No SAC jobs in queue"

# SLURM: Wait for all jobs to complete
slurm-sync:
	@echo "Waiting for SLURM jobs to complete..."
	@if [ -f job_ids.txt ]; then \
		while read job_id compiler param; do \
			while squeue -h -j $$job_id 2>/dev/null | grep -q .; do \
				sleep 2; \
			done; \
		done < job_ids.txt; \
	fi
	@echo "All jobs completed!"

# SLURM: Collect and analyze results
slurm-collect:
	@echo "Collecting SLURM job results..."
	@echo "==============================="
	@echo ""
	@$(MAKE) slurm-collect-new
	@$(MAKE) slurm-collect-orig
	@$(MAKE) slurm-comparison

# Collect results for new compiler
slurm-collect-new:
	@echo "Collecting NEW compiler results..."
	@echo "filename,param_count,run,compilation_time,max_memory_kb,job_id,node" > results-slurm-new.csv
	@results_found=0; missing=""; \
	for i in $(PARAM_COUNTS); do \
		if [ -f "results-new-$$i-param.csv" ]; then \
			echo "  Found results for $$i-param (new)"; \
			tail -n +2 "results-new-$$i-param.csv" >> results-slurm-new.csv; \
			results_found=$$((results_found + 1)); \
		else \
			missing="$$missing $$i"; \
		fi; \
	done; \
	echo "NEW compiler: $$results_found/20 files found"; \
	if [ -n "$$missing" ]; then \
		echo "Missing:$$missing"; \
	fi

# Collect results for orig compiler
slurm-collect-orig:
	@echo "Collecting ORIG compiler results..."
	@echo "filename,param_count,run,compilation_time,max_memory_kb,job_id,node" > results-slurm-orig.csv
	@results_found=0; missing=""; \
	for i in $(PARAM_COUNTS); do \
		if [ -f "results-orig-$$i-param.csv" ]; then \
			echo "  Found results for $$i-param (orig)"; \
			tail -n +2 "results-orig-$$i-param.csv" >> results-slurm-orig.csv; \
			results_found=$$((results_found + 1)); \
		else \
			missing="$$missing $$i"; \
		fi; \
	done; \
	echo "ORIG compiler: $$results_found/20 files found"; \
	if [ -n "$$missing" ]; then \
		echo "Missing:$$missing"; \
	fi

# Analyze and compare SLURM results
slurm-comparison: results-slurm-new.csv results-slurm-orig.csv
	@echo ""
	@echo "Analyzing SLURM results..."
	@$(MAKE) analyze-slurm-new
	@$(MAKE) analyze-slurm-orig
	@$(MAKE) compare-slurm-compilers

# Analyze SLURM results - new compiler
analyze-slurm-new: results-slurm-new.csv
	@echo "# SAC Compilation Analysis - NEW Compiler (SLURM)" > summary-slurm-new.md
	@echo "" >> summary-slurm-new.md
	@echo "## Summary Statistics" >> summary-slurm-new.md
	@echo "" >> summary-slurm-new.md
	@echo "| Params | Avg Time (s) | Min Time | Max Time | StdDev Time | Avg Mem (MB) | Max Mem (MB) | Node(s) |" >> summary-slurm-new.md
	@echo "|--------|--------------|----------|----------|-------------|--------------|--------------|---------|" >> summary-slurm-new.md
	@for i in $(PARAM_COUNTS); do \
		data=$$(grep "^$$i-param.sac," results-slurm-new.csv); \
		if [ -n "$$data" ]; then \
			nodes=$$(echo "$$data" | cut -d',' -f7 | sort -u | tr '\n' ',' | sed 's/,$$//'); \
			echo "$$data" | awk -F',' -v params=$$i -v nodes="$$nodes" '{ \
				time_sum += $$4; times[NR] = $$4; \
				mem_sum += $$5; mems[NR] = $$5; \
				if (NR == 1 || $$4 < min_time) min_time = $$4; \
				if (NR == 1 || $$4 > max_time) max_time = $$4; \
				if (NR == 1 || $$5 > max_mem) max_mem = $$5; \
			} END { \
				avg_time = time_sum / NR; avg_mem = mem_sum / NR; \
				for (i = 1; i <= NR; i++) time_sq += (times[i] - avg_time)^2; \
				stddev_time = sqrt(time_sq / NR); \
				printf "| %d | %.3f | %.3f | %.3f | %.3f | %.2f | %.2f | %s |\n", \
					params, avg_time, min_time, max_time, stddev_time, \
					avg_mem/1024, max_mem/1024, nodes; \
			}' >> summary-slurm-new.md; \
		fi; \
	done
	@echo "" >> summary-slurm-new.md
	@echo "Generated: $$(date)" >> summary-slurm-new.md
	@cat summary-slurm-new.md

# Analyze SLURM results - orig compiler
analyze-slurm-orig: results-slurm-orig.csv
	@echo "# SAC Compilation Analysis - ORIG Compiler (SLURM)" > summary-slurm-orig.md
	@echo "" >> summary-slurm-orig.md
	@echo "## Summary Statistics" >> summary-slurm-orig.md
	@echo "" >> summary-slurm-orig.md
	@echo "| Params | Avg Time (s) | Min Time | Max Time | StdDev Time | Avg Mem (MB) | Max Mem (MB) | Node(s) |" >> summary-slurm-orig.md
	@echo "|--------|--------------|----------|----------|-------------|--------------|--------------|---------|" >> summary-slurm-orig.md
	@for i in $(PARAM_COUNTS); do \
		data=$$(grep "^$$i-param.sac," results-slurm-orig.csv); \
		if [ -n "$$data" ]; then \
			nodes=$$(echo "$$data" | cut -d',' -f7 | sort -u | tr '\n' ',' | sed 's/,$$//'); \
			echo "$$data" | awk -F',' -v params=$$i -v nodes="$$nodes" '{ \
				time_sum += $$4; times[NR] = $$4; \
				mem_sum += $$5; mems[NR] = $$5; \
				if (NR == 1 || $$4 < min_time) min_time = $$4; \
				if (NR == 1 || $$4 > max_time) max_time = $$4; \
				if (NR == 1 || $$5 > max_mem) max_mem = $$5; \
			} END { \
				avg_time = time_sum / NR; avg_mem = mem_sum / NR; \
				for (i = 1; i <= NR; i++) time_sq += (times[i] - avg_time)^2; \
				stddev_time = sqrt(time_sq / NR); \
				printf "| %d | %.3f | %.3f | %.3f | %.3f | %.2f | %.2f | %s |\n", \
					params, avg_time, min_time, max_time, stddev_time, \
					avg_mem/1024, max_mem/1024, nodes; \
			}' >> summary-slurm-orig.md; \
		fi; \
	done
	@echo "" >> summary-slurm-orig.md
	@echo "Generated: $$(date)" >> summary-slurm-orig.md
	@cat summary-slurm-orig.md

# Compare SLURM compilers
compare-slurm-compilers: results-slurm-new.csv results-slurm-orig.csv
	@echo "# SLURM Compiler Comparison: NEW vs ORIG" > summary-slurm-comparison.md
	@echo "" >> summary-slurm-comparison.md
	@echo "## Compilation Time Comparison" >> summary-slurm-comparison.md
	@echo "" >> summary-slurm-comparison.md
	@echo "| Params | NEW Avg (s) | ORIG Avg (s) | Speedup | Time Diff (s) | Winner |" >> summary-slurm-comparison.md
	@echo "|--------|-------------|--------------|---------|---------------|--------|" >> summary-slurm-comparison.md
	@for i in $(PARAM_COUNTS); do \
		new_avg=$$(grep "^$$i-param.sac," results-slurm-new.csv | awk -F',' '{sum+=$$4} END {printf "%.3f", sum/NR}'); \
		orig_avg=$$(grep "^$$i-param.sac," results-slurm-orig.csv | awk -F',' '{sum+=$$4} END {printf "%.3f", sum/NR}'); \
		echo "$$new_avg $$orig_avg" | awk -v params=$$i '{ \
			speedup = $$2 / $$1; \
			diff = $$1 - $$2; \
			winner = ($$1 < $$2) ? "NEW" : "ORIG"; \
			if ($$1 == $$2) winner = "TIE"; \
			printf "| %d | %.3f | %.3f | %.2fx | %+.3f | %s |\n", \
				params, $$1, $$2, speedup, diff, winner; \
		}' >> summary-slurm-comparison.md; \
	done
	@echo "" >> summary-slurm-comparison.md
	@echo "## Memory Usage Comparison" >> summary-slurm-comparison.md
	@echo "" >> summary-slurm-comparison.md
	@echo "| Params | NEW Avg (MB) | ORIG Avg (MB) | Mem Ratio | Mem Diff (MB) | Winner |" >> summary-slurm-comparison.md
	@echo "|--------|--------------|---------------|-----------|---------------|--------|" >> summary-slurm-comparison.md
	@for i in $(PARAM_COUNTS); do \
		new_mem=$$(grep "^$$i-param.sac," results-slurm-new.csv | awk -F',' '{sum+=$$5} END {printf "%.2f", sum/NR/1024}'); \
		orig_mem=$$(grep "^$$i-param.sac," results-slurm-orig.csv | awk -F',' '{sum+=$$5} END {printf "%.2f", sum/NR/1024}'); \
		echo "$$new_mem $$orig_mem" | awk -v params=$$i '{ \
			ratio = $$1 / $$2; \
			diff = $$1 - $$2; \
			winner = ($$1 < $$2) ? "NEW" : "ORIG"; \
			if ($$1 == $$2) winner = "TIE"; \
			printf "| %d | %.2f | %.2f | %.2fx | %+.2f | %s |\n", \
				params, $$1, $$2, ratio, diff, winner; \
		}' >> summary-slurm-comparison.md; \
	done
	@echo "" >> summary-slurm-comparison.md
	@echo "Generated: $$(date)" >> summary-slurm-comparison.md
	@cat summary-slurm-comparison.md

# SLURM: Clean up all SLURM-related files
slurm-clean:
	@echo "Cleaning up SLURM files..."
	@rm -f results-new-*-param.csv results-orig-*-param.csv
	@rm -f results-slurm-new.csv results-slurm-orig.csv
	@rm -f job_ids.txt
	@rm -f summary-slurm-*.md
	@rm -rf $(SLURM_LOGS)
	@echo "SLURM cleanup complete."

# Clean local files
clean:
	@echo "Cleaning up local files..."
	@rm -f *.mod *.c *.o *.h
	@rm -f results-new.csv results-orig.csv
	@rm -f summary-new.md summary-orig.md summary-comparison.md
	@for i in $(PARAM_COUNTS); do rm -f $$i-param; done
	@echo "Cleanup complete."

# Full clean (local + SLURM)
distclean: clean slurm-clean
	@rm -rf venv

# Help
help:
	@echo "SAC Compilation Benchmark Suite"
	@echo "================================"
	@echo "Compares two SAC compilers (NEW vs ORIG) on compilation time and memory usage"
	@echo ""
	@echo "Local execution:"
	@echo "  make benchmark        - Run benchmark for both compilers locally"
	@echo "  make benchmark-new    - Run benchmark for NEW compiler only"
	@echo "  make benchmark-orig   - Run benchmark for ORIG compiler only"
	@echo "  make comparison       - Analyze and compare both compilers"
	@echo "  make clean            - Clean local files"
	@echo ""
	@echo "SLURM cluster execution:"
	@echo "  make slurm-submit     - Submit all jobs (40 jobs: 2×20)"
	@echo "  make slurm-status     - Check status of submitted jobs"
	@echo "  make slurm-sync       - Wait for all jobs to complete"
	@echo "  make slurm-collect    - Collect and analyze SLURM results"
	@echo "  make slurm-clean      - Clean SLURM files"
	@echo ""
	@echo "Configuration:"
	@echo "  SAC2C_new=$(SAC2C_new)"
	@echo "  SAC2C_orig=$(SAC2C_orig)"
	@echo "  RUNS=$(RUNS)"
	@echo "  SLURM_PARTITION=$(SLURM_PARTITION)"
	@echo ""
	@echo "Typical SLURM workflow:"
	@echo "  1. make slurm-submit   (submits 40 jobs)"
	@echo "  2. make slurm-status   (monitor progress)"
	@echo "  3. make slurm-collect  (analyze results)"
	@echo ""
	@echo "Output files:"
	@echo "  summary-new.md / summary-slurm-new.md        - NEW compiler stats"
	@echo "  summary-orig.md / summary-slurm-orig.md      - ORIG compiler stats"
	@echo "  summary-comparison.md / summary-slurm-comparison.md - Comparison"
