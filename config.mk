# Parameter Scalability Benchmark — configuration
# Edit and then run `make` (= `make run`) for an end-to-end rerun.

# =============================================================================
# Compiler paths (on the SLURM compute nodes)
# =============================================================================
SAC2C_NEW_SLURM       := /home/rhensen/sac2c/build_p/sac2c_p
SAC2C_ORIG_SLURM      := /home/rhensen/sacoriginal/sac2c/build_p/sac2c_p
SAC2C_NEW_DIR_SLURM   := /home/rhensen/sac2c/build_p
SAC2C_ORIG_DIR_SLURM  := /home/rhensen/sacoriginal/sac2c/build_p

# Source-tree paths for the compiler repos (for git-commit metadata)
SAC2C_NEW_SRC_SLURM   := /home/rhensen/sac2c
SAC2C_ORIG_SRC_SLURM  := /home/rhensen/sacoriginal/sac2c

# =============================================================================
# Stdlib (must be built once per compiler before running the benchmark)
# =============================================================================
# The Stdlib is the same source clone, but cmake build trees must be separate
# per compiler. `make stdlibs` builds both under $HOME/Stdlib via SLURM.
STDLIB_SRC_SLURM      := /home/rhensen/Stdlib
STDLIB_BUILD_NEW      := $(STDLIB_SRC_SLURM)/build-new
STDLIB_BUILD_ORIG     := $(STDLIB_SRC_SLURM)/build-orig

# =============================================================================
# Benchmark parameters
# =============================================================================
COMPILERS         := new orig
PARAM_MIN         := 0
PARAM_MAX         := 19
RUNS_PER_PARAM    := 10

# Per-individual-compilation timeout (seconds). Anything beyond this is
# recorded as TIMEOUT for that single run.
RUN_TIMEOUT_SEC   := 1800

# Per-individual-compilation virtual-memory cap (KB). Anything exceeding this
# is killed by ulimit -v and recorded as OOM. Matches SLURM_MEM (14 GB).
RUN_VMEM_LIMIT_KB := 14000000

# After this many consecutive TIMEOUT or OOM in one task, the remaining runs
# are recorded as SKIPPED (so e.g. orig at param=19 doesn't waste 5 hours
# of cluster time hitting the same wall ten times).
SHORTCIRCUIT_AFTER := 2

# How many times to resubmit tasks whose JSON record is missing entirely
# (i.e. the task itself failed before recording anything). Per-run failures
# are NOT retried — they are the expected outcome at high param counts.
MAX_RETRIES       := 2

# =============================================================================
# SLURM configuration
# =============================================================================
SLURM_ACCOUNT     := csmpi
SLURM_PARTITION   := cncz
SLURM_CPUS        := 4
SLURM_MEM         := 14G
# Wall clock per task = up to RUNS_PER_PARAM × RUN_TIMEOUT_SEC for hopeless
# tasks (mitigated by SHORTCIRCUIT_AFTER). Default: 6 h.
SLURM_TIMELIMIT   := 06:00:00

# Cap concurrent array tasks per compiler. cncz has 3 nodes; 4 keeps us
# polite. Empty = no cap.
SLURM_ARRAY_CONCURRENCY := 4

# Per-task scratch root for builds + isolated $HOME (avoids ~/.sac2crc race).
TEMP_ROOT_PREFERRED := /scratch
TEMP_ROOT_FALLBACK  := $$HOME

# =============================================================================
# Analysis configuration
# =============================================================================
VENV_DIR := venv
PYTHON   := $(VENV_DIR)/bin/python3
