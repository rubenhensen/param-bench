#!/bin/bash
# Show the per-task status of every submitted array job.
set -eu
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
cd "${PROJECT_DIR}"

if [[ ! -f job_ids.txt ]]; then
  echo "ERROR: job_ids.txt not found; submit first with 'make submit'." >&2
  exit 1
fi

mapfile -t LINES < <(awk 'NF && $1 !~ /^#/' job_ids.txt)

declare -A counts
for s in PENDING RUNNING COMPLETED FAILED TIMEOUT CANCELLED OUT_OF_MEMORY NODE_FAIL OTHER; do
  counts[$s]=0
done

echo "Per-task status (sacct):"
echo "========================"
for line in "${LINES[@]}"; do
  jid="$(echo "${line}" | awk '{print $1}')"
  compiler="$(echo "${line}" | awk '{print $2}')"
  while IFS='|' read -r task_id state exit_code elapsed; do
    [[ -z "${task_id}" ]] && continue
    [[ "${task_id}" == *.batch || "${task_id}" == *.extern ]] && continue
    state_trim="$(echo "${state}" | awk '{print $1}')"
    key="${state_trim%+}"
    case "${key}" in
      PENDING|RUNNING|COMPLETED|FAILED|TIMEOUT|CANCELLED|OUT_OF_MEMORY|NODE_FAIL) ;;
      *) key="OTHER" ;;
    esac
    counts[$key]=$(( counts[$key] + 1 ))
    printf "  %-14s  %-22s  exit=%-5s  elapsed=%s\n" "${state_trim}" "${task_id} (${compiler})" "${exit_code}" "${elapsed}"
  done < <(sacct -j "${jid}" -P -n -o JobIDRaw,State,ExitCode,Elapsed 2>/dev/null)
done

echo
echo "Summary:"
for s in PENDING RUNNING COMPLETED FAILED TIMEOUT CANCELLED OUT_OF_MEMORY NODE_FAIL OTHER; do
  printf "  %-15s %d\n" "${s}:" "${counts[$s]}"
done

got="$(find results -maxdepth 1 -name 'param-*-*.json' 2>/dev/null | wc -l | tr -d ' ')"
expected="$(( $(echo "${COMPILERS:-new orig}" | wc -w) * ( ${PARAM_MAX:-19} - ${PARAM_MIN:-0} + 1 ) ))"
echo
echo "Result files on disk: ${got} / ${expected}"
