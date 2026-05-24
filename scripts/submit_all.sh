#!/bin/bash
# Submit one SLURM array job per compiler.
set -eu
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
cd "${PROJECT_DIR}"

mkdir -p results

: > job_ids.txt
echo "# job_id  compiler  array_spec  submitted_at  note" >> job_ids.txt

for compiler in ${COMPILERS}; do
  script="jobs/param-${compiler}.array.sh"
  if [[ ! -f "${script}" ]]; then
    echo "ERROR: ${script} not found; run 'make jobs' first." >&2
    exit 1
  fi
  echo "Submitting ${script}..."
  jid="$(sbatch --parsable "${script}")"
  echo "  -> array job ${jid} for compiler '${compiler}'"
  echo "${jid}  ${compiler}  ${PARAM_MIN}-${PARAM_MAX}  $(date -Iseconds)  INITIAL" >> job_ids.txt
done

echo
echo "All array jobs submitted. Monitor: make status  |  wait: make wait"
