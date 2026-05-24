#!/bin/bash
# Find array tasks whose JSON record is missing or whose task_status is
# ERROR (NOT PARTIAL — per-compilation failures at high param counts are
# the expected outcome). Resubmit only those task IDs.
#
# Exit code:
#   0 = nothing to retry
#   1 = at least one retry resubmitted

set -eu
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
cd "${PROJECT_DIR}"

PY="${PYTHON:-python3}"
ANY_RESUBMITTED=0

for compiler in ${COMPILERS}; do
  failures=()
  for p in $(seq "${PARAM_MIN}" "${PARAM_MAX}"); do
    file="results/param-${compiler}-${p}.json"
    if [[ ! -f "${file}" ]]; then
      failures+=("${p}")
      continue
    fi
    task_status="$("${PY}" -c "import json,sys; print(json.load(open(sys.argv[1])).get('task_status',''))" "${file}" 2>/dev/null || echo "")"
    # Only retry hard failures (sac2c missing, source missing, slurm killed task).
    # PARTIAL is expected at high param counts and not retried.
    if [[ "${task_status}" == "ERROR" || -z "${task_status}" ]]; then
      failures+=("${p}")
    fi
  done

  if [[ ${#failures[@]} -eq 0 ]]; then
    echo "[retry] compiler '${compiler}': all tasks have a valid record"
    continue
  fi

  for p in "${failures[@]}"; do
    rm -f "results/param-${compiler}-${p}.json"
  done

  array_spec="$(IFS=,; echo "${failures[*]}")"
  if [[ -n "${SLURM_ARRAY_CONCURRENCY:-}" ]]; then
    array_spec="${array_spec}%${SLURM_ARRAY_CONCURRENCY}"
  fi

  script="jobs/param-${compiler}.array.sh"
  echo "[retry] compiler '${compiler}': resubmitting ${#failures[@]} task(s) -> --array=${array_spec}"
  jid="$(sbatch --parsable --array="${array_spec}" "${script}")"
  echo "${jid}  ${compiler}  ${array_spec}  $(date -Iseconds)  RETRY" >> job_ids.txt
  ANY_RESUBMITTED=1
done

exit ${ANY_RESUBMITTED}
