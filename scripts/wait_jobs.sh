#!/bin/bash
# Poll squeue until every submitted array task is in a terminal state.
set -eu
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
cd "${PROJECT_DIR}"

if [[ ! -f job_ids.txt ]]; then
  echo "ERROR: job_ids.txt not found; submit first with 'make submit'." >&2
  exit 1
fi

mapfile -t ARRAY_JOB_IDS < <(awk 'NF && $1 !~ /^#/ {print $1}' job_ids.txt)
POLL_INTERVAL="${POLL_INTERVAL:-30}"

echo "Waiting for ${#ARRAY_JOB_IDS[@]} array job(s): ${ARRAY_JOB_IDS[*]}"
echo "(polling every ${POLL_INTERVAL}s; ctrl-c to stop polling, jobs keep running)"

while :; do
  active=0
  for jid in "${ARRAY_JOB_IDS[@]}"; do
    n="$(squeue -h -j "${jid}" 2>/dev/null | wc -l | tr -d ' ')"
    active=$(( active + n ))
  done
  if [[ ${active} -eq 0 ]]; then
    echo "[$(date -Iseconds)] all array tasks finished"
    break
  fi
  printf '[%s] still active: %d task(s)\n' "$(date -Iseconds)" "${active}"
  sleep "${POLL_INTERVAL}"
done
