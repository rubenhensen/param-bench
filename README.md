# Parameter Scalability Benchmark

Measures `sac2c` compilation time and peak memory as a function of the
number of function parameters (default 0–19) for two compiler versions,
captures the reproducibility metadata the thesis appendix needs, and
emits paste-ready Typst tables.

This is the benchmark that validates the *"exponential to linear"* memory
claim in §47 of the thesis and feeds the appendix tables at §70 and §71.

## One-command run

```bash
make stdlibs            # ONCE per cluster account: build Stdlib with each compiler
make                    # = make run; jobs → submit → wait → retry → collect → report
```

`make stdlibs` submits a single SLURM job that builds the SaC Standard
Library twice (once per compiler) into `$HOME/Stdlib/build-new` and
`$HOME/Stdlib/build-orig`. Subsequent runs of `make` reuse those builds.

`make` itself runs the whole pipeline:

1. **`make jobs`** generates one SLURM array script per compiler (`array=PARAM_MIN..PARAM_MAX`).
2. **`make submit`** submits both array jobs; IDs land in `job_ids.txt`.
3. **`make wait`** polls `squeue` every 30 s until every task finishes.
4. **`make retry`** (looped up to `MAX_RETRIES` times) resubmits *only* tasks
   whose JSON record is missing or whose `task_status` is `ERROR` —
   per-compilation `TIMEOUT`/`OOM` at high param counts are the *expected*
   outcome and are not retried.
5. **`make collect`** aggregates per-task JSONs into
   `summary/combined_results.csv`, `summary/all_runs.json`, and the
   reproducibility footer `summary/metadata.json`.
6. **`make report`** writes `summary/report.md` (human report),
   `summary/analysis.json` (per-(compiler, param) stats), and
   `summary/thesis_snippet.typ` (two paste-ready Typst `#figure` tables:
   compilation time and memory).

Run inside `tmux` so the orchestrator survives login-shell time caps:

```bash
tmux new -s param-bench
make
# Ctrl-b d to detach; tmux attach -t param-bench to peek
```

## Configure

Edit `config.mk`:

```makefile
COMPILERS         := new orig
PARAM_MIN         := 0
PARAM_MAX         := 19
RUNS_PER_PARAM    := 10
RUN_TIMEOUT_SEC   := 1800              # 30 min cap per individual compilation
RUN_VMEM_LIMIT_KB := 14000000          # 14 GB ulimit -v per compilation
SHORTCIRCUIT_AFTER := 2                # skip remaining runs after N consecutive failures
MAX_RETRIES       := 2

SLURM_PARTITION   := cncz
SLURM_ACCOUNT     := csmpi
SLURM_CPUS        := 4
SLURM_MEM         := 14G
SLURM_TIMELIMIT   := 06:00:00          # worst-case per task with short-circuit
SLURM_ARRAY_CONCURRENCY := 4
```

`make print-config` echoes the resolved settings.

## What every per-task JSON records

`results/param-<compiler>-<param_count>.json`:

```jsonc
{
  "compiler": "new",
  "param_count": 9,
  "task_status": "SUCCESS",              // or PARTIAL | ERROR
  "task_exit_code": 0,
  "runs": [
    {
      "run": 1,
      "status": "SUCCESS",               // or TIMEOUT | OOM | ERROR | SKIPPED
      "exit_code": 0,
      "compilation_time_seconds": 0.382, // wall-clock (date +%s.%N)
      "peak_rss_kb": 25600,              // GNU /usr/bin/time -v
      "user_cpu_s": 0.30,
      "sys_cpu_s": 0.07,
      "error_message": ""
    }, ...
  ],
  "runs_per_param_requested": 10,
  "run_timeout_seconds": 1800,
  "run_vmem_limit_kb": 14000000,
  "shortcircuit_after": 2,
  "job_id": "7984982",
  "array_task_id": 9,
  "node": "cn58",
  "slurm_partition": "cncz",
  "slurm_cpus_per_task": 4,
  "slurm_mem_requested": "14G",
  "slurm_timelimit_requested": "06:00:00",
  "temp_build_root": "/scratch/rhensen",
  "source_file": ".../9-param.sac",
  "sac2c_path": "/home/rhensen/sac2c/build_p/sac2c_p",
  "sac2c_commit": "...",
  "sac2c_branch": "progressive-dispatch-clean",
  "sac2c_describe": "v1.3.3-...",
  "stdlib_src": "/home/rhensen/Stdlib",
  "stdlib_build": "/home/rhensen/Stdlib/build-new",
  "stdlib_commit": "...",
  "stdlib_branch": "main",
  "gcc_version": "gcc (Ubuntu 11.4.0-...)",
  "kernel": "5.15...",
  "os_release": "Ubuntu 22.04...",
  "cpu_model": "Intel(R) Xeon(R) ...",
  "total_memory_kb": 131072000,
  "started_at": "...",
  "finished_at": "..."
}
```

`summary/metadata.json` deduplicates the constants across all tasks and
warns if anything varied across runs (different nodes, GCC versions, ...).

## How a single compilation is measured

```
/usr/bin/time -v -o time.log \
  timeout --kill-after=30 ${RUN_TIMEOUT_SEC} \
  bash -c "ulimit -v ${RUN_VMEM_LIMIT_KB}; sac2c_p -L… -T… N-param.sac"
```

Exit-code → status classification:

| Exit | Status      | Meaning                                                       |
|-----:|-------------|---------------------------------------------------------------|
|  0   | `SUCCESS`   | compilation succeeded; `compilation_time_seconds` + `peak_rss_kb` recorded |
| 124  | `TIMEOUT`   | `timeout` killed the compilation at the wall-clock cap        |
| 137  | `OOM`       | `ulimit -v` killed the compilation (or external SIGKILL)      |
| other| `ERROR`     | sac2c exited non-zero for some other reason                   |
|  —   | `SKIPPED`   | short-circuit: too many consecutive failures, this run skipped |

The per-task SLURM `--mem` is set to match the per-compilation `ulimit -v`
so that hitting the cap surfaces as an OOM at the compilation level, not
at the task level.

## Outputs

```
summary/
├── combined_results.csv   # one row per individual compilation (~400 rows)
├── all_runs.json          # full per-task records
├── metadata.json          # batch-level reproducibility footer
├── analysis.json          # per-(compiler, param) stats
├── report.md              # human-readable summary
└── thesis_snippet.typ     # two Typst figures: compile time + memory
```

## Troubleshooting

- **`make stdlibs` failed.** Look at `build-stdlibs-<jobid>.{out,err}`. Most
  common cause: the corresponding `sac2c_p` binary doesn't exist — check
  the paths in `config.mk` and build the compilers via stdlib-bench-sac's
  `build_sac2c.sh` (or any equivalent).
- **A task fails (`task_status = ERROR`).** The per-task JSON has the
  reason in `task_error_message`. `make retry` will resubmit it.
  Per-compilation failures (`PARTIAL`) are *expected* at high param counts
  for the baseline compiler and are **not** retried.
- **Inspect a specific run.** SLURM logs are
  `slurm-<compiler>-<param_count>-<job_id>.{out,err}`.
- **Keep the previous run's data.** `make clean` does **not** delete: it
  moves the current `jobs/`, `results/`, `summary/`, SLURM logs and
  `job_ids.txt` into `archive/<YYYYMMDDTHHMMSS>/`.

## Layout

```
.
├── Makefile                  # workflow orchestration
├── config.mk                 # editable configuration
├── job_template.sh           # SLURM array task body (filled by generate_jobs.sh)
├── [0..19]-param.sac         # benchmark inputs (one source file per param count)
├── scripts/
│   ├── generate_jobs.sh      # emit jobs/param-<compiler>.array.sh
│   ├── submit_all.sh         # sbatch each array job; write job_ids.txt
│   ├── wait_jobs.sh          # poll squeue until terminal
│   ├── check_jobs.sh         # human-readable per-task status
│   ├── retry_failed.sh       # resubmit only the ERROR task IDs
│   ├── collect_results.sh    # aggregate JSON -> CSV + metadata
│   ├── generate_report.sh    # report.md + analysis.json + thesis snippet
│   ├── build_stdlibs.sh      # one-time `make stdlibs` driver
│   └── run_all.sh            # umbrella invoked by `make run`
├── jobs/                     # generated; one array script per compiler
├── results/                  # generated; one JSON per task
├── summary/                  # generated; final aggregates
└── archive/                  # produced by `make clean`
```
