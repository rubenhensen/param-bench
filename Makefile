.PHONY: all run stdlibs jobs submit wait status collect retry report venv clean distclean print-config help

include config.mk

# Default target: one-shot end-to-end run.
all: run

# ---------------------------------------------------------------------------
# One-command end-to-end run (this is the only command you normally need).
# ---------------------------------------------------------------------------
run: venv
	@COMPILERS="$(COMPILERS)" \
	 PARAM_MIN=$(PARAM_MIN) PARAM_MAX=$(PARAM_MAX) \
	 RUNS_PER_PARAM=$(RUNS_PER_PARAM) \
	 RUN_TIMEOUT_SEC=$(RUN_TIMEOUT_SEC) \
	 RUN_VMEM_LIMIT_KB=$(RUN_VMEM_LIMIT_KB) \
	 SHORTCIRCUIT_AFTER=$(SHORTCIRCUIT_AFTER) \
	 MAX_RETRIES=$(MAX_RETRIES) \
	 SLURM_PARTITION="$(SLURM_PARTITION)" \
	 SLURM_ACCOUNT="$(SLURM_ACCOUNT)" \
	 SLURM_CPUS=$(SLURM_CPUS) \
	 SLURM_MEM="$(SLURM_MEM)" \
	 SLURM_TIMELIMIT="$(SLURM_TIMELIMIT)" \
	 SLURM_ARRAY_CONCURRENCY="$(SLURM_ARRAY_CONCURRENCY)" \
	 SLURM_NODELIST="$(SLURM_NODELIST)" \
	 SLURM_EXCLUDE="$(SLURM_EXCLUDE)" \
	 SAC2C_NEW_SLURM="$(SAC2C_NEW_SLURM)" \
	 SAC2C_ORIG_SLURM="$(SAC2C_ORIG_SLURM)" \
	 SAC2C_NEW_DIR_SLURM="$(SAC2C_NEW_DIR_SLURM)" \
	 SAC2C_ORIG_DIR_SLURM="$(SAC2C_ORIG_DIR_SLURM)" \
	 SAC2C_NEW_SRC_SLURM="$(SAC2C_NEW_SRC_SLURM)" \
	 SAC2C_ORIG_SRC_SLURM="$(SAC2C_ORIG_SRC_SLURM)" \
	 STDLIB_SRC_SLURM="$(STDLIB_SRC_SLURM)" \
	 STDLIB_BUILD_NEW="$(STDLIB_BUILD_NEW)" \
	 STDLIB_BUILD_ORIG="$(STDLIB_BUILD_ORIG)" \
	 TEMP_ROOT_PREFERRED="$(TEMP_ROOT_PREFERRED)" \
	 TEMP_ROOT_FALLBACK="$(TEMP_ROOT_FALLBACK)" \
	 PYTHON="$(PYTHON)" \
	 ./scripts/run_all.sh

# ---------------------------------------------------------------------------
# One-time prerequisite: build the Stdlib once with each compiler.
# ---------------------------------------------------------------------------
stdlibs:
	@SLURM_PARTITION="$(SLURM_PARTITION)" SLURM_ACCOUNT="$(SLURM_ACCOUNT)" \
	 SLURM_CPUS=$(SLURM_CPUS) SLURM_MEM="$(SLURM_MEM)" \
	 SAC2C_NEW_SLURM="$(SAC2C_NEW_SLURM)" SAC2C_ORIG_SLURM="$(SAC2C_ORIG_SLURM)" \
	 STDLIB_SRC_SLURM="$(STDLIB_SRC_SLURM)" \
	 STDLIB_BUILD_NEW="$(STDLIB_BUILD_NEW)" STDLIB_BUILD_ORIG="$(STDLIB_BUILD_ORIG)" \
	 ./scripts/build_stdlibs.sh

# ---------------------------------------------------------------------------
# Granular targets (for debugging / partial reruns).
# ---------------------------------------------------------------------------
jobs:
	@COMPILERS="$(COMPILERS)" \
	 PARAM_MIN=$(PARAM_MIN) PARAM_MAX=$(PARAM_MAX) \
	 RUNS_PER_PARAM=$(RUNS_PER_PARAM) \
	 RUN_TIMEOUT_SEC=$(RUN_TIMEOUT_SEC) \
	 RUN_VMEM_LIMIT_KB=$(RUN_VMEM_LIMIT_KB) \
	 SHORTCIRCUIT_AFTER=$(SHORTCIRCUIT_AFTER) \
	 SLURM_TIMELIMIT="$(SLURM_TIMELIMIT)" \
	 SLURM_CPUS=$(SLURM_CPUS) SLURM_MEM="$(SLURM_MEM)" \
	 SLURM_ACCOUNT="$(SLURM_ACCOUNT)" SLURM_PARTITION="$(SLURM_PARTITION)" \
	 SLURM_ARRAY_CONCURRENCY="$(SLURM_ARRAY_CONCURRENCY)" \
	 SAC2C_NEW_SLURM="$(SAC2C_NEW_SLURM)" SAC2C_ORIG_SLURM="$(SAC2C_ORIG_SLURM)" \
	 SAC2C_NEW_DIR_SLURM="$(SAC2C_NEW_DIR_SLURM)" SAC2C_ORIG_DIR_SLURM="$(SAC2C_ORIG_DIR_SLURM)" \
	 SAC2C_NEW_SRC_SLURM="$(SAC2C_NEW_SRC_SLURM)" SAC2C_ORIG_SRC_SLURM="$(SAC2C_ORIG_SRC_SLURM)" \
	 STDLIB_SRC_SLURM="$(STDLIB_SRC_SLURM)" \
	 STDLIB_BUILD_NEW="$(STDLIB_BUILD_NEW)" STDLIB_BUILD_ORIG="$(STDLIB_BUILD_ORIG)" \
	 TEMP_ROOT_PREFERRED="$(TEMP_ROOT_PREFERRED)" TEMP_ROOT_FALLBACK="$(TEMP_ROOT_FALLBACK)" \
	 ./scripts/generate_jobs.sh

submit:
	@COMPILERS="$(COMPILERS)" \
	 PARAM_MIN=$(PARAM_MIN) PARAM_MAX=$(PARAM_MAX) \
	 ./scripts/submit_all.sh

wait:
	@./scripts/wait_jobs.sh

status:
	@COMPILERS="$(COMPILERS)" \
	 PARAM_MIN=$(PARAM_MIN) PARAM_MAX=$(PARAM_MAX) \
	 ./scripts/check_jobs.sh

retry:
	@COMPILERS="$(COMPILERS)" \
	 PARAM_MIN=$(PARAM_MIN) PARAM_MAX=$(PARAM_MAX) \
	 PYTHON="$(PYTHON)" \
	 SLURM_ARRAY_CONCURRENCY="$(SLURM_ARRAY_CONCURRENCY)" \
	 ./scripts/retry_failed.sh

collect:
	@COMPILERS="$(COMPILERS)" \
	 PARAM_MIN=$(PARAM_MIN) PARAM_MAX=$(PARAM_MAX) \
	 RUNS_PER_PARAM=$(RUNS_PER_PARAM) \
	 RUN_TIMEOUT_SEC=$(RUN_TIMEOUT_SEC) RUN_VMEM_LIMIT_KB=$(RUN_VMEM_LIMIT_KB) \
	 SHORTCIRCUIT_AFTER=$(SHORTCIRCUIT_AFTER) \
	 SLURM_PARTITION="$(SLURM_PARTITION)" SLURM_ACCOUNT="$(SLURM_ACCOUNT)" \
	 SLURM_CPUS=$(SLURM_CPUS) SLURM_MEM="$(SLURM_MEM)" \
	 SLURM_TIMELIMIT="$(SLURM_TIMELIMIT)" \
	 PYTHON="$(PYTHON)" \
	 ./scripts/collect_results.sh

report: venv
	@if [ ! -f summary/combined_results.csv ]; then \
		echo "ERROR: summary/combined_results.csv missing — run 'make collect' first."; \
		exit 1; \
	fi
	@PYTHON="$(PYTHON)" ./scripts/generate_report.sh

# ---------------------------------------------------------------------------
# Helpers.
# ---------------------------------------------------------------------------
venv:
	@if [ ! -f $(VENV_DIR)/bin/activate ]; then \
		echo "Creating Python virtual environment..."; \
		python3 -m venv $(VENV_DIR); \
		$(VENV_DIR)/bin/pip install --upgrade pip >/dev/null; \
		$(VENV_DIR)/bin/pip install numpy >/dev/null; \
	fi

print-config:
	@echo "Compilers              : $(COMPILERS)"
	@echo "Param range            : $(PARAM_MIN)..$(PARAM_MAX)"
	@echo "Runs per param         : $(RUNS_PER_PARAM)"
	@echo "Per-run timeout        : $(RUN_TIMEOUT_SEC) s"
	@echo "Per-run vmem cap       : $(RUN_VMEM_LIMIT_KB) KB"
	@echo "Short-circuit after    : $(SHORTCIRCUIT_AFTER) failures"
	@echo "Max retries            : $(MAX_RETRIES)"
	@echo "SAC2C new              : $(SAC2C_NEW_SLURM) (src: $(SAC2C_NEW_SRC_SLURM))"
	@echo "SAC2C orig             : $(SAC2C_ORIG_SLURM) (src: $(SAC2C_ORIG_SRC_SLURM))"
	@echo "Stdlib src             : $(STDLIB_SRC_SLURM)"
	@echo "Stdlib build (new)     : $(STDLIB_BUILD_NEW)"
	@echo "Stdlib build (orig)    : $(STDLIB_BUILD_ORIG)"
	@echo "SLURM partition        : $(SLURM_PARTITION)"
	@echo "SLURM cpus/mem/time    : $(SLURM_CPUS) / $(SLURM_MEM) / $(SLURM_TIMELIMIT)"
	@echo "Array concurrency      : $(SLURM_ARRAY_CONCURRENCY)"
	@echo "Node pin               : $(SLURM_NODELIST)"
	@echo "Node exclude           : $(SLURM_EXCLUDE)"
	@echo "Temp root              : $(TEMP_ROOT_PREFERRED) (fallback: $(TEMP_ROOT_FALLBACK))"

# Archive previous-run artefacts (jobs/, results/, summary/, slurm logs,
# old per-(compiler,param) CSVs from the previous architecture).
clean:
	@stamp=$$(date +%Y%m%dT%H%M%S); \
	 archived=0; \
	 if [ -d results ] || [ -d summary ] || [ -d jobs ] || [ -d slurm_logs ] || \
	    ls slurm-*.out >/dev/null 2>&1 || ls build-stdlibs-*.out >/dev/null 2>&1 || \
	    ls results-*-*-param.csv >/dev/null 2>&1 || ls results-slurm-*.csv >/dev/null 2>&1 || \
	    ls summary-*.md >/dev/null 2>&1 || [ -f job_ids.txt ]; then \
		mkdir -p archive/$$stamp; archived=1; \
		[ -d jobs ]       && mv jobs       archive/$$stamp/ 2>/dev/null || true; \
		[ -d results ]    && mv results    archive/$$stamp/ 2>/dev/null || true; \
		[ -d summary ]    && mv summary    archive/$$stamp/ 2>/dev/null || true; \
		[ -d slurm_logs ] && mv slurm_logs archive/$$stamp/ 2>/dev/null || true; \
		mv slurm-*.out slurm-*.err archive/$$stamp/ 2>/dev/null || true; \
		mv build-stdlibs-*.out build-stdlibs-*.err archive/$$stamp/ 2>/dev/null || true; \
		mv results-*-*-param.csv archive/$$stamp/ 2>/dev/null || true; \
		mv results-slurm-*.csv   archive/$$stamp/ 2>/dev/null || true; \
		mv summary-*.md          archive/$$stamp/ 2>/dev/null || true; \
		mv job_ids.txt           archive/$$stamp/ 2>/dev/null || true; \
		echo "Previous artefacts archived to archive/$$stamp/"; \
	 fi; \
	 [ $$archived -eq 0 ] && echo "Nothing to clean." || true

distclean: clean
	@rm -rf $(VENV_DIR)
	@echo "Removed venv."

help:
	@echo "Usage:"
	@echo "  make stdlibs    one-time prerequisite: build Stdlib with each compiler (sbatch)"
	@echo "  make run        end-to-end: jobs -> submit -> wait -> retry -> collect -> report"
	@echo "  make status     per-task status of the current submission"
	@echo "  make report     regenerate summary/report.md from existing results/"
	@echo "  make clean      archive jobs/results/summary into archive/<timestamp>/"
	@echo
	@echo "  Granular debugging targets: jobs, submit, wait, retry, collect, print-config"
	@echo
	@echo "Edit config.mk to change compilers, run count, SLURM caps, etc."
