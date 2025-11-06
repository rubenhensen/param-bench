# SAC Parameter Count Compilation Benchmark

Measures and compares SAC compilation time and memory usage as a function of parameter count (0-19 parameters) between two compiler versions.

## Quick Start

### Local Execution
```bash
make benchmark     # Run benchmark for both compilers locally
make comparison    # Analyze and compare results
```

### SLURM Cluster Execution
```bash
make slurm-submit  # Submit 40 jobs (2 compilers × 20 parameter counts)
make slurm-status  # Monitor job status
make slurm-collect # Collect and analyze results when complete
```

## Features

- **Dual compiler comparison** - Tests both NEW and ORIG compilers independently
- **Memory tracking** - Measures peak memory usage during compilation using `/usr/bin/time`
- **Parallel SLURM execution** - 40 jobs run in parallel (2 compilers × 20 parameter counts)
- **Statistical analysis** - Mean, min, max, and standard deviation for both time and memory
- **Comprehensive comparison** - Head-to-head analysis with speedup ratios and winners
- **Simple Makefile workflow** - Everything in one place, no scattered shell scripts

## Configuration

Edit the Makefile to customize:

```makefile
SAC2C_new := /home/rhensen/sac2c/build_p/sac2c_p          # NEW compiler
SAC2C_orig := /home/rhensen/orig/sac2c/build_p/sac2c_p    # ORIG compiler

# Library and tree paths for prelude and stdlib
LIBFLAGS_new := -L ... -T ...   # NEW compiler library paths
LIBFLAGS_orig := -L ... -T ...  # ORIG compiler library paths

RUNS := 10                      # Compilation runs per test
SLURM_* := ...                  # SLURM settings
```

## Available Commands

### Local Execution
- `make benchmark` - Run full benchmark for both compilers
- `make benchmark-new` - Run benchmark for NEW compiler only
- `make benchmark-orig` - Run benchmark for ORIG compiler only
- `make comparison` - Analyze and compare both compilers
- `make clean` - Clean local build artifacts and results

### SLURM Execution
- `make slurm-submit` - Submit all 40 jobs to cluster
- `make slurm-status` - Check job status (shows both compilers separately)
- `make slurm-sync` - Wait for all jobs to complete
- `make slurm-collect` - Collect and analyze all results
- `make slurm-clean` - Clean SLURM files and logs

### Other
- `make help` - Show help message
- `make distclean` - Full cleanup (local + SLURM + venv)
- `make venv` - Setup Python virtual environment for advanced statistics

## Output Files

### Local execution:
- `results-new.csv` - NEW compiler raw data
- `results-orig.csv` - ORIG compiler raw data
- `summary-new.md` - NEW compiler statistics (time + memory)
- `summary-orig.md` - ORIG compiler statistics (time + memory)
- `summary-comparison.md` - Head-to-head comparison with winners

### SLURM execution:
- `results-new-{0..19}-param.csv` - Individual NEW compiler job results
- `results-orig-{0..19}-param.csv` - Individual ORIG compiler job results
- `results-slurm-new.csv` - Combined NEW compiler results
- `results-slurm-orig.csv` - Combined ORIG compiler results
- `summary-slurm-new.md` - NEW compiler stats with node info
- `summary-slurm-orig.md` - ORIG compiler stats with node info
- `summary-slurm-comparison.md` - Comparison with speedups and winners
- `job_ids.txt` - SLURM job IDs for monitoring
- `slurm_logs/` - SLURM output logs

## Example Workflow

```bash
# Submit jobs to cluster (40 jobs total)
make slurm-submit

# Monitor progress (repeat as needed)
make slurm-status

# Once all jobs complete, collect and analyze
make slurm-collect

# View results
cat summary-slurm-new.md           # NEW compiler stats
cat summary-slurm-orig.md          # ORIG compiler stats
cat summary-slurm-comparison.md    # Head-to-head comparison

# Clean up when done
make slurm-clean
```

## Analysis Output

Each summary file includes:

### Individual Compiler Analysis
- **Time Statistics**: Average, min, max, standard deviation
- **Memory Statistics**: Average peak memory, max peak memory, standard deviation
- **Per-parameter breakdown**: 0-19 parameters analyzed

### Comparison Analysis
- **Compilation Time Comparison**:
  - Speedup ratios (NEW vs ORIG)
  - Time differences in seconds
  - Winner declaration for each parameter count

- **Memory Usage Comparison**:
  - Memory ratios (NEW vs ORIG)
  - Memory differences in MB
  - Winner declaration for memory efficiency

- **Overall Summary**:
  - Win counts for each compiler
  - Performance trends across parameter counts

## Example Output

```markdown
## Compilation Time Comparison

| Params | NEW Avg (s) | ORIG Avg (s) | Speedup | Time Diff (s) | Winner |
|--------|-------------|--------------|---------|---------------|--------|
| 0      | 0.234       | 0.245        | 1.05x   | -0.011        | NEW    |
| 1      | 0.312       | 0.298        | 0.96x   | +0.014        | ORIG   |
...

## Memory Usage Comparison

| Params | NEW Avg (MB) | ORIG Avg (MB) | Mem Ratio | Mem Diff (MB) | Winner |
|--------|--------------|---------------|-----------|---------------|--------|
| 0      | 45.23        | 48.12         | 0.94x     | -2.89         | NEW    |
| 1      | 52.34        | 51.98         | 1.01x     | +0.36         | ORIG   |
...
```

## Comparison to CFAL-bench

This repository follows the simplified structure of CFAL-bench:
- Single Makefile handles all operations
- Multiple compilers tested independently
- SLURM jobs generated on-the-fly (no pre-generated scripts)
- Built-in statistical comparison
- Memory tracking alongside timing
- Clear separation of local vs cluster workflows
- Minimal file clutter

## Technical Details

### Compiler Invocation
Each compiler is invoked with library flags (`LIBFLAGS`) that specify paths to:
- Prelude library (`-L` and `-T` flags for library and tree paths)
- Stdlib library (`-L` and `-T` flags for library and tree paths)

This ensures the compiler can find all necessary runtime libraries during compilation.

### Memory Measurement
Memory is tracked using `/usr/bin/time -f "%M"` which reports maximum resident set size in KB. This is converted to MB in the analysis.

### SLURM Job Distribution
- Each compiler/parameter combination runs as a separate job
- 40 total jobs: 2 compilers × 20 parameter counts
- Jobs are independent and can run in parallel
- Results are collected after all jobs complete

### Statistical Analysis
- Each configuration is run 10 times (configurable via `RUNS`)
- Statistics computed: mean, min, max, standard deviation
- Comparisons include speedup ratios and absolute differences
- Winner determined by lower time/memory (not considering statistical significance)
