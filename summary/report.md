# Parameter Scalability Benchmark — Report

_Generated: 2026-05-25T18:39:01_

## Compilation time (seconds)

| Params | new mean | orig mean | new std | orig std |
|---|---|---|---|---|
| 0 | 0.565 | 0.578 | 0.012 | 0.011 |
| 1 | 0.633 | 0.672 | 0.012 | 0.011 |
| 2 | 0.587 | 0.634 | 0.011 | 0.035 |
| 3 | 0.636 | 0.704 | 0.009 | 0.050 |
| 4 | 0.644 | 0.738 | 0.010 | 0.013 |
| 5 | 0.659 | 1.057 | 0.011 | 0.012 |
| 6 | 0.687 | 2.903 | 0.011 | 0.013 |
| 7 | 0.729 | 16.092 | 0.039 | 0.199 |
| 8 | 0.724 | 147.202 | 0.038 | 11.505 |
| 9 | 0.717 | 1753.026 | 0.015 | 11.880 |
| 10 | 0.708 | OUT OF MEM. | 0.011 | — |
| 11 | 0.750 | OUT OF MEM. | 0.042 | — |
| 12 | 0.790 | OUT OF MEM. | 0.042 | — |
| 13 | 0.790 | OUT OF MEM. | 0.052 | — |
| 14 | 0.747 | OUT OF MEM. | 0.013 | — |
| 15 | 0.757 | OUT OF MEM. | 0.010 | — |
| 16 | 0.773 | OUT OF MEM. | 0.014 | — |
| 17 | 0.790 | OUT OF MEM. | 0.011 | — |
| 18 | 0.794 | OUT OF MEM. | 0.012 | — |
| 19 | 0.811 | OUT OF MEM. | 0.012 | — |

## Peak resident-set memory (MB; via /usr/bin/time -v)

| Params | new mean (MB) | orig mean (MB) | new max (MB) | orig max (MB) |
|---|---|---|---|---|
| 0 | 36.13 | 39.18 | 36.23 | 39.26 |
| 1 | 42.88 | 49.71 | 43.15 | 49.83 |
| 2 | 41.86 | 46.68 | 42.05 | 46.96 |
| 3 | 42.90 | 49.61 | 42.98 | 49.76 |
| 4 | 43.56 | 56.98 | 43.82 | 57.18 |
| 5 | 44.27 | 80.85 | 44.48 | 81.04 |
| 6 | 45.05 | 163.49 | 45.20 | 163.64 |
| 7 | 45.75 | 503.16 | 45.92 | 503.37 |
| 8 | 46.43 | 1659.35 | 46.57 | 1659.53 |
| 9 | 47.21 | 5653.93 | 47.32 | 5654.10 |
| 10 | 47.96 | OUT OF MEM. | 48.17 | — |
| 11 | 48.80 | OUT OF MEM. | 48.91 | — |
| 12 | 49.54 | OUT OF MEM. | 49.80 | — |
| 13 | 50.35 | OUT OF MEM. | 50.48 | — |
| 14 | 51.18 | OUT OF MEM. | 51.42 | — |
| 15 | 51.99 | OUT OF MEM. | 52.12 | — |
| 16 | 52.80 | OUT OF MEM. | 52.91 | — |
| 17 | 53.62 | OUT OF MEM. | 53.75 | — |
| 18 | 54.54 | OUT OF MEM. | 54.67 | — |
| 19 | 55.39 | OUT OF MEM. | 55.50 | — |

## Failure thresholds

- `orig` first hit a non-SUCCESS state at **param = 10** (`OUT OF MEM.`).

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

_Started: 2026-05-25T12:25:44+00:00 — Finished: 2026-05-25T17:35:15+00:00_

Source data: `summary/combined_results.csv` (one row per individual compilation), `summary/all_runs.json` (full per-task records), `summary/metadata.json` (this footer).