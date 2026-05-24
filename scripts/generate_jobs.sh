#!/bin/bash
# Generate one SLURM array script per compiler.
#
# Inputs (env vars set by the Makefile):
#   COMPILERS, PARAM_MIN, PARAM_MAX, RUNS_PER_PARAM,
#   RUN_TIMEOUT_SEC, RUN_VMEM_LIMIT_KB, SHORTCIRCUIT_AFTER,
#   SLURM_TIMELIMIT, SLURM_CPUS, SLURM_MEM, SLURM_ACCOUNT, SLURM_PARTITION,
#   SLURM_ARRAY_CONCURRENCY, SLURM_NODELIST, SLURM_EXCLUDE,
#   SAC2C_NEW_SLURM, SAC2C_ORIG_SLURM, SAC2C_NEW_DIR_SLURM, SAC2C_ORIG_DIR_SLURM,
#   SAC2C_NEW_SRC_SLURM, SAC2C_ORIG_SRC_SLURM,
#   STDLIB_SRC_SLURM, STDLIB_BUILD_NEW, STDLIB_BUILD_ORIG,
#   TEMP_ROOT_PREFERRED, TEMP_ROOT_FALLBACK
#
# Output: jobs/param-<compiler>.array.sh

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
cd "${PROJECT_DIR}"

mkdir -p jobs

ARRAY_SPEC="${PARAM_MIN}-${PARAM_MAX}"
if [[ -n "${SLURM_ARRAY_CONCURRENCY:-}" ]]; then
  ARRAY_SPEC="${ARRAY_SPEC}%${SLURM_ARRAY_CONCURRENCY}"
fi

# Node constraint: SLURM_NODELIST wins (pin to specific nodes), else
# SLURM_EXCLUDE (exclude specific nodes), else nothing.
if [[ -n "${SLURM_NODELIST:-}" ]]; then
  NODE_DIRECTIVE="#SBATCH --nodelist=${SLURM_NODELIST}"
  echo "constraining tasks to node(s): ${SLURM_NODELIST}"
elif [[ -n "${SLURM_EXCLUDE:-}" ]]; then
  NODE_DIRECTIVE="#SBATCH --exclude=${SLURM_EXCLUDE}"
  echo "excluding node(s): ${SLURM_EXCLUDE}"
else
  NODE_DIRECTIVE="# (no node constraint — SLURM may pick any node in the partition)"
  echo "WARNING: no node constraint set; mixed CPU generations will add noise"
fi

for compiler in ${COMPILERS}; do
  case "${compiler}" in
    new)
      SAC2C_PATH="${SAC2C_NEW_SLURM}"
      SAC2C_DIR="${SAC2C_NEW_DIR_SLURM}"
      SAC2C_SRC="${SAC2C_NEW_SRC_SLURM:-}"
      STDLIB_BUILD="${STDLIB_BUILD_NEW}"
      ;;
    orig)
      SAC2C_PATH="${SAC2C_ORIG_SLURM}"
      SAC2C_DIR="${SAC2C_ORIG_DIR_SLURM}"
      SAC2C_SRC="${SAC2C_ORIG_SRC_SLURM:-}"
      STDLIB_BUILD="${STDLIB_BUILD_ORIG}"
      ;;
    *)
      echo "ERROR: unknown compiler '${compiler}' (extend generate_jobs.sh)" >&2
      exit 1
      ;;
  esac

  JOB_NAME="param-${compiler}"
  OUT="jobs/${JOB_NAME}.array.sh"

  sed -e "s|__COMPILER__|${compiler}|g" \
      -e "s|__JOB_NAME__|${JOB_NAME}|g" \
      -e "s|__ARRAY_SPEC__|${ARRAY_SPEC}|g" \
      -e "s|__SAC2C_PATH__|${SAC2C_PATH}|g" \
      -e "s|__SAC2C_DIR__|${SAC2C_DIR}|g" \
      -e "s|__SAC2C_SRC__|${SAC2C_SRC}|g" \
      -e "s|__STDLIB_SRC__|${STDLIB_SRC_SLURM}|g" \
      -e "s|__STDLIB_BUILD__|${STDLIB_BUILD}|g" \
      -e "s|__RUNS_PER_PARAM__|${RUNS_PER_PARAM}|g" \
      -e "s|__RUN_TIMEOUT_SEC__|${RUN_TIMEOUT_SEC}|g" \
      -e "s|__RUN_VMEM_LIMIT_KB__|${RUN_VMEM_LIMIT_KB}|g" \
      -e "s|__SHORTCIRCUIT_AFTER__|${SHORTCIRCUIT_AFTER}|g" \
      -e "s|__TIMELIMIT__|${SLURM_TIMELIMIT}|g" \
      -e "s|__CPUS__|${SLURM_CPUS}|g" \
      -e "s|__MEM__|${SLURM_MEM}|g" \
      -e "s|__ACCOUNT__|${SLURM_ACCOUNT}|g" \
      -e "s|__PARTITION__|${SLURM_PARTITION}|g" \
      -e "s|__SLURM_NODE_DIRECTIVE__|${NODE_DIRECTIVE}|g" \
      -e "s|__TEMP_ROOT_PREFERRED__|${TEMP_ROOT_PREFERRED:-/scratch}|g" \
      -e "s|__TEMP_ROOT_FALLBACK__|${TEMP_ROOT_FALLBACK:-\$HOME}|g" \
      job_template.sh > "${OUT}"
  chmod +x "${OUT}"
  echo "wrote ${OUT}  (array ${ARRAY_SPEC})"
done

echo
echo "Done. Submit with: make submit  (or 'make run' for one-command end-to-end)"
