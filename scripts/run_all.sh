#!/bin/bash
# End-to-end orchestrator: jobs -> submit -> wait -> retry -> collect -> report.
set -eu
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
cd "${PROJECT_DIR}"

echo "============================================================"
echo "Parameter Scalability Benchmark — one-shot run"
echo "============================================================"
echo "Compilers          : ${COMPILERS}"
echo "Param range        : ${PARAM_MIN}..${PARAM_MAX}"
echo "Runs per param     : ${RUNS_PER_PARAM}"
echo "Per-run timeout    : ${RUN_TIMEOUT_SEC} s"
echo "Per-run vmem cap   : ${RUN_VMEM_LIMIT_KB} KB"
echo "Short-circuit at   : ${SHORTCIRCUIT_AFTER} consecutive failures"
echo "SLURM partition    : ${SLURM_PARTITION}"
echo "Max retry rounds   : ${MAX_RETRIES}"
echo "============================================================"
echo

# Verify pre-built Stdlibs are in place before we burn cluster time
missing=0
for c in ${COMPILERS}; do
  case "$c" in
    new)  build="${STDLIB_BUILD_NEW}";;
    orig) build="${STDLIB_BUILD_ORIG}";;
    *)    build="";;
  esac
  if [[ -n "${build}" && ! -d "${build}" ]]; then
    echo "ERROR: ${c} compiler's Stdlib build is missing: ${build}"
    missing=1
  fi
done
if (( missing )); then
  echo
  echo "Run 'make stdlibs' once to build both Stdlibs, then re-run 'make'."
  exit 1
fi

make --no-print-directory jobs
make --no-print-directory submit
make --no-print-directory wait

attempt=0
while (( attempt < MAX_RETRIES )); do
  attempt=$(( attempt + 1 ))
  echo
  echo "------------------------------------------------------------"
  echo "Retry round ${attempt}/${MAX_RETRIES}"
  echo "------------------------------------------------------------"
  if make --no-print-directory retry; then
    echo "Nothing to retry — every task produced a record."
    break
  fi
  make --no-print-directory wait
done

echo
make --no-print-directory collect
echo
make --no-print-directory report

echo
echo "============================================================"
echo "Done. Open:"
echo "  summary/report.md           (human report)"
echo "  summary/thesis_snippet.typ  (paste into the thesis appendix)"
echo "  summary/analysis.json       (machine-readable per-cell stats)"
echo "  summary/metadata.json       (reproducibility footer)"
echo "============================================================"
