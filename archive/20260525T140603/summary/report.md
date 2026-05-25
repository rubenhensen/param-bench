# Parameter Scalability Benchmark — Report

_Generated: 2026-05-25T09:52:33_

## Compilation time (seconds)

| Params | new mean | orig mean | new std | orig std |
|---|---|---|---|---|
| 0 | ERROR | 0.581 | — | 0.012 |
| 1 | ERROR | 0.688 | — | 0.013 |
| 2 | ERROR | 0.627 | — | 0.013 |
| 3 | ERROR | 0.688 | — | 0.008 |
| 4 | ERROR | 0.796 | — | 0.018 |
| 5 | ERROR | 1.219 | — | 0.032 |
| 6 | ERROR | 3.321 | — | 0.028 |
| 7 | ERROR | 17.364 | — | 0.423 |
| 8 | ERROR | 173.600 | — | 17.537 |
| 9 | ERROR | TIME OUT | — | — |
| 10 | ERROR | ERROR | — | — |
| 11 | ERROR | ERROR | — | — |
| 12 | ERROR | ERROR | — | — |
| 13 | ERROR | ERROR | — | — |
| 14 | ERROR | ERROR | — | — |
| 15 | ERROR | ERROR | — | — |
| 16 | ERROR | ERROR | — | — |
| 17 | ERROR | ERROR | — | — |
| 18 | ERROR | ERROR | — | — |
| 19 | ERROR | ERROR | — | — |

## Peak resident-set memory (MB; via /usr/bin/time -v)

| Params | new mean (MB) | orig mean (MB) | new max (MB) | orig max (MB) |
|---|---|---|---|---|
| 0 | ERROR | 39.20 | — | 39.26 |
| 1 | ERROR | 49.70 | — | 49.75 |
| 2 | ERROR | 46.79 | — | 46.92 |
| 3 | ERROR | 49.71 | — | 49.80 |
| 4 | ERROR | 56.99 | — | 57.18 |
| 5 | ERROR | 80.80 | — | 81.02 |
| 6 | ERROR | 163.47 | — | 163.62 |
| 7 | ERROR | 503.09 | — | 503.36 |
| 8 | ERROR | 1659.42 | — | 1659.60 |
| 9 | ERROR | TIME OUT | — | — |
| 10 | ERROR | ERROR | — | — |
| 11 | ERROR | ERROR | — | — |
| 12 | ERROR | ERROR | — | — |
| 13 | ERROR | ERROR | — | — |
| 14 | ERROR | ERROR | — | — |
| 15 | ERROR | ERROR | — | — |
| 16 | ERROR | ERROR | — | — |
| 17 | ERROR | ERROR | — | — |
| 18 | ERROR | ERROR | — | — |
| 19 | ERROR | ERROR | — | — |

## Failure thresholds

- `new` first hit a non-SUCCESS state at **param = 0** (`ERROR`).
- `orig` first hit a non-SUCCESS state at **param = 9** (`TIME OUT`).

## Reproducibility metadata

### SLURM

- Partition: `cncz`
- Account: `csmpi`
- CPUs per task: `4`
- Memory requested: `14G`
- Wall-clock cap: `06:00:00`
- Node(s) used: `cn99`
- Per-compilation wall-clock cap: `1800 s`
- Per-compilation virtual-memory cap: `14000000 KB` (ulimit -v)
- Short-circuit threshold: `2` consecutive failures

### Host environment

- CPU: `Intel(R) Xeon(R) CPU E5-2630 v3 @ 2.40GHz`
- Total memory (kB): `264023620`
- Kernel: `6.17.0-14-generic`
- OS: `Ubuntu 24.04.4 LTS`
- GCC: `gcc (Ubuntu 13.3.0-6ubuntu2~24.04.1) 13.3.0`

### Compilers

#### `new`

- Path: `/home/rhensen/sac2c/build_p/sac2c_p`
- Commit: `f2870cfeac931033f66bf11ab827beee08030327`
- Branch: `progressive-dispatch-clean`
- `git describe`: `v2.1.0-PuurGeluk-327-gf2870cfea`
- Pre-built Stdlib: `/home/rhensen/Stdlib/build-new`
- `sac2c -V`: sac2c 2.1.0-PuurGeluk-327-gf2870 / build-type: RELEASE / built-by: "rhensen" at 2026-05-24T17:49:38 / 

#### `orig`

- Path: `/home/rhensen/sacoriginal/sac2c/build_p/sac2c_p`
- Commit: `ab3bbecacf1a978daf64b88cabc4b9df53d4b2e8`
- Branch: `develop`
- `git describe`: `v2.1.0-PuurGeluk-269-gab3bbecac`
- Pre-built Stdlib: `/home/rhensen/Stdlib/build-orig`
- `sac2c -V`: sac2c 2.1.0-PuurGeluk-269-gab3bb / build-type: RELEASE / built-by: "rhensen" at 2026-05-24T17:37:57 / 

### Stdlib

- Path: `/home/rhensen/Stdlib`
- Commit: `9afffd46db51fd6877048f34fbd6c5a5de5eede5`
- Branch: `master`

### Benchmark configuration

- Compilers: `new orig`
- Param range: `0` to `19` inclusive
- Runs per (compiler, param): `10`
- Measurement: wall-clock via `date +%s.%N` around `timeout … ulimit -v … sac2c …`; peak RSS via GNU `/usr/bin/time -v`.

_Started: 2026-05-25T04:35:27+00:00 — Finished: 2026-05-25T05:42:38+00:00_

Source data: `summary/combined_results.csv` (one row per individual compilation), `summary/all_runs.json` (full per-task records), `summary/metadata.json` (this footer).