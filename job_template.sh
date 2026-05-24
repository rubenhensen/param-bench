#!/bin/bash
#SBATCH --job-name=__JOB_NAME__
#SBATCH --output=slurm-__COMPILER__-%a-%A.out
#SBATCH --error=slurm-__COMPILER__-%a-%A.err
#SBATCH --time=__TIMELIMIT__
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=__CPUS__
#SBATCH --mem=__MEM__
#SBATCH --account=__ACCOUNT__
#SBATCH --partition=__PARTITION__
#SBATCH --array=__ARRAY_SPEC__

# =============================================================================
# Parameter Scalability Benchmark — SLURM array task
# =============================================================================
# Each array task = one (compiler, param_count) pair. Inside the task we run
# RUNS_PER_PARAM independent compilations of <param_count>-param.sac, time
# each one separately, classify each run as SUCCESS / TIMEOUT / OOM / ERROR,
# and record the lot as a single JSON file:
#
#     results/param-<compiler>-<param_count>.json
#
# We also short-circuit: after SHORTCIRCUIT_AFTER consecutive TIMEOUT/OOM,
# the remaining runs are recorded as SKIPPED rather than wasting wall time
# hitting the same wall over and over.
#
# Captures the same reproducibility metadata as stdlib-bench-sac.
# =============================================================================

set -u

# -------- placeholders filled by generate_jobs.sh -------------------------
COMPILER="__COMPILER__"
SAC2C_PATH="__SAC2C_PATH__"
SAC2C_DIR="__SAC2C_DIR__"
SAC2C_SRC="__SAC2C_SRC__"
STDLIB_SRC="__STDLIB_SRC__"
STDLIB_BUILD="__STDLIB_BUILD__"
RUNS_PER_PARAM="__RUNS_PER_PARAM__"
RUN_TIMEOUT_SEC="__RUN_TIMEOUT_SEC__"
RUN_VMEM_LIMIT_KB="__RUN_VMEM_LIMIT_KB__"
SHORTCIRCUIT_AFTER="__SHORTCIRCUIT_AFTER__"
TEMP_ROOT_PREFERRED="__TEMP_ROOT_PREFERRED__"
TEMP_ROOT_FALLBACK="__TEMP_ROOT_FALLBACK__"
SLURM_MEM_REQUESTED="__MEM__"
SLURM_TIMELIMIT_REQUESTED="__TIMELIMIT__"

# -------- per-task identifiers --------------------------------------------
PARAM_COUNT="${SLURM_ARRAY_TASK_ID}"
JOB_ID="${SLURM_ARRAY_JOB_ID:-${SLURM_JOB_ID}}"
TASK_ID="${SLURM_ARRAY_TASK_ID}"
NODE_NAME="$(hostname -s)"
SUBMIT_DIR="${SLURM_SUBMIT_DIR:-$(pwd)}"
RESULT_JSON="${SUBMIT_DIR}/results/param-${COMPILER}-${PARAM_COUNT}.json"
SOURCE_FILE="${SUBMIT_DIR}/${PARAM_COUNT}-param.sac"
mkdir -p "${SUBMIT_DIR}/results"

# Runs are accumulated as one-line JSON objects in this temp file. The final
# JSON record wraps them as the "runs" array.
RUNS_TMP="$(mktemp)"
trap 'rm -f "${RUNS_TMP}"' EXIT

# -------- helper: append one run record to RUNS_TMP -----------------------
append_run () {
  python3 - "$@" >> "${RUNS_TMP}" <<'PY'
import json, sys
keys = ["run","status","exit_code","compilation_time_seconds",
        "peak_rss_kb","user_cpu_s","sys_cpu_s","error_message"]
def parse(v):
    if v in ("", "null", "None"): return None
    try: return int(v)
    except ValueError: pass
    try: return float(v)
    except ValueError: pass
    return v
vals = sys.argv[1:]
rec  = dict(zip(keys, [parse(v) for v in vals]))
sys.stdout.write(json.dumps(rec) + "\n")
PY
}

# -------- helper: emit the final per-task JSON ----------------------------
emit_json () {
  local task_status="$1"
  local task_exit="$2"
  local task_err="$3"

  python3 - >> "${RESULT_JSON}.new" <<PY
import json, os, sys

runs = []
with open("${RUNS_TMP}") as f:
    for line in f:
        line = line.strip()
        if line:
            runs.append(json.loads(line))

record = {
  "compiler": "${COMPILER}",
  "param_count": ${PARAM_COUNT},
  "runs_per_param_requested": ${RUNS_PER_PARAM},
  "task_status": "${task_status}",
  "task_exit_code": ${task_exit},
  "task_error_message": """${task_err}""",
  "runs": runs,
  "started_at": os.environ.get("TASK_STARTED_AT", ""),
  "finished_at": os.environ.get("TASK_FINISHED_AT", ""),
  "job_id": "${JOB_ID}",
  "array_task_id": ${TASK_ID},
  "node": "${NODE_NAME}",
  "slurm_partition": os.environ.get("SLURM_JOB_PARTITION", ""),
  "slurm_cpus_per_task": int(os.environ.get("SLURM_CPUS_PER_TASK", "0") or 0),
  "slurm_mem_requested": "${SLURM_MEM_REQUESTED}",
  "slurm_timelimit_requested": "${SLURM_TIMELIMIT_REQUESTED}",
  "run_timeout_seconds": ${RUN_TIMEOUT_SEC},
  "run_vmem_limit_kb": ${RUN_VMEM_LIMIT_KB},
  "shortcircuit_after": ${SHORTCIRCUIT_AFTER},
  "temp_build_root": os.environ.get("TEMP_BUILD_ROOT", ""),
  "source_file": "${SOURCE_FILE}",
  "sac2c_path": "${SAC2C_PATH}",
  "sac2c_version_raw": os.environ.get("SAC2C_VERSION_RAW", ""),
  "sac2c_commit": os.environ.get("SAC2C_COMMIT", ""),
  "sac2c_branch": os.environ.get("SAC2C_BRANCH", ""),
  "sac2c_describe": os.environ.get("SAC2C_DESCRIBE", ""),
  "stdlib_src": "${STDLIB_SRC}",
  "stdlib_build": "${STDLIB_BUILD}",
  "stdlib_commit": os.environ.get("STDLIB_COMMIT", ""),
  "stdlib_branch": os.environ.get("STDLIB_BRANCH", ""),
  "gcc_version": os.environ.get("GCC_VERSION", ""),
  "kernel": os.environ.get("KERNEL", ""),
  "os_release": os.environ.get("OS_RELEASE", ""),
  "cpu_model": os.environ.get("CPU_MODEL", ""),
  "total_memory_kb": int(os.environ.get("TOTAL_MEMORY_KB", "0") or 0),
}
json.dump(record, sys.stdout, indent=2, sort_keys=True)
sys.stdout.write("\n")
PY
  mv "${RESULT_JSON}.new" "${RESULT_JSON}"
}

# Always emit a JSON on exit (even on early crash).
on_exit () {
  local code=$?
  if [[ ! -f "${RESULT_JSON}" ]]; then
    emit_json "ERROR" "${code}" "exited before result was recorded"
  fi
  rm -f "${RUNS_TMP}"
}
trap on_exit EXIT

echo "========================================================================"
echo "Parameter benchmark — task ${COMPILER}/param=${PARAM_COUNT}"
echo "========================================================================"
echo "Compiler   : ${COMPILER}  (${SAC2C_PATH})"
echo "Source     : ${SOURCE_FILE}"
echo "Stdlib     : ${STDLIB_BUILD}"
echo "Runs       : ${RUNS_PER_PARAM} (timeout ${RUN_TIMEOUT_SEC}s, vmem cap ${RUN_VMEM_LIMIT_KB}KB)"
echo "Job ID     : ${JOB_ID} (task ${TASK_ID})"
echo "Node       : ${NODE_NAME}"
echo "========================================================================"

# -------- 1. Sanity checks -------------------------------------------------
if [[ ! -x "${SAC2C_PATH}" ]]; then
  emit_json "ERROR" 2 "sac2c binary not found or not executable: ${SAC2C_PATH}"
  exit 2
fi
if [[ ! -f "${SOURCE_FILE}" ]]; then
  emit_json "ERROR" 3 "source file not found: ${SOURCE_FILE}"
  exit 3
fi
if [[ ! -d "${STDLIB_BUILD}" ]]; then
  emit_json "ERROR" 4 "stdlib build dir missing: ${STDLIB_BUILD} — run 'make stdlibs' first"
  exit 4
fi

# -------- 2. Environment metadata -----------------------------------------
export SAC2C_VERSION_RAW="$("${SAC2C_PATH}" -V 2>&1 | head -5 | tr '\n' '|' || true)"
if [[ -n "${SAC2C_SRC}" && -d "${SAC2C_SRC}/.git" ]]; then
  export SAC2C_COMMIT="$(git -C "${SAC2C_SRC}" rev-parse HEAD 2>/dev/null || echo "")"
  export SAC2C_BRANCH="$(git -C "${SAC2C_SRC}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
  export SAC2C_DESCRIBE="$(git -C "${SAC2C_SRC}" describe --always --dirty --tags 2>/dev/null || echo "")"
fi
if [[ -d "${STDLIB_SRC}/.git" ]]; then
  export STDLIB_COMMIT="$(git -C "${STDLIB_SRC}" rev-parse HEAD 2>/dev/null || echo "")"
  export STDLIB_BRANCH="$(git -C "${STDLIB_SRC}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
fi
export GCC_VERSION="$(gcc --version 2>/dev/null | head -1 || echo "")"
export KERNEL="$(uname -r 2>/dev/null || echo "")"
export OS_RELEASE="$( ( . /etc/os-release 2>/dev/null && echo "${PRETTY_NAME}" ) || echo "")"
export CPU_MODEL="$(lscpu 2>/dev/null | awk -F: '/^Model name/ {gsub(/^ +/,"",$2); print $2; exit}')"
export TOTAL_MEMORY_KB="$(awk '/^MemTotal:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)"

# -------- 3. Per-task scratch root with isolated $HOME --------------------
choose_temp_root () {
  local pref="${TEMP_ROOT_PREFERRED:-/scratch}/${USER:-$LOGNAME}"
  if mkdir -p "${pref}" 2>/dev/null && [[ -w "${pref}" ]]; then
    echo "${pref}"; return
  fi
  echo "${TEMP_ROOT_FALLBACK:-$HOME}"
}
TEMP_ROOT="$(choose_temp_root)"
TASK_ROOT="${TEMP_ROOT}/param_bench_${COMPILER}_${PARAM_COUNT}_${JOB_ID}_${TASK_ID}"
export HOME="${TASK_ROOT}/home"          # per-task $HOME, removes ~/.sac2crc race
export TMPDIR="${TASK_ROOT}/tmp"
export TEMP_BUILD_ROOT="${TEMP_ROOT}"
mkdir -p "${HOME}" "${TMPDIR}"

# -------- 4. sac2c environment in the isolated $HOME ----------------------
unset SAC2CRC SAC2C_STANDARD_PACKAGES SAC2C_INCLUDE_PATH SAC2C_LIBRARY_PATH
export SAC2CBASE="${SAC2C_DIR}"
PRELUDE_PATH="${SAC2C_DIR}/runtime_build/src/runtime_libraries-build/lib/prelude"
export LD_LIBRARY_PATH="${SAC2C_DIR}/runtime_build/src/runtime_libraries-build/lib:${PRELUDE_PATH}:${LD_LIBRARY_PATH:-}"

mkdir -p "${HOME}/.sac2crc"
cat > "${HOME}/.sac2crc/sac2crc.release.prelude" <<EOF
/* Auto-generated for ${COMPILER} compiler, task ${TASK_ID} of job ${JOB_ID} */
target add_local:
TREEPATH       += "${PRELUDE_PATH}:"
LIBPATH        += "${PRELUDE_PATH}:"

target default_sbi :: add_local:
EOF
cp "${HOME}/.sac2crc/sac2crc.release.prelude" "${HOME}/.sac2crc/sac2crc.debug.prelude"

# Compiler invocation flags: prelude (sac2c's own) + Stdlib (pre-built).
LIBFLAGS=( -L "${PRELUDE_PATH}" -T "${PRELUDE_PATH}"
           -L "${STDLIB_BUILD}/lib" -T "${STDLIB_BUILD}/lib" )

# -------- 5. Run RUNS_PER_PARAM compilations -------------------------------
export TASK_STARTED_AT="$(date -Iseconds)"
consecutive_fail=0
overall_status="SUCCESS"

mkdir -p "${TASK_ROOT}/build"
cd "${TASK_ROOT}/build" || { emit_json "ERROR" 5 "cannot cd to build dir"; exit 5; }

for run in $(seq 1 "${RUNS_PER_PARAM}"); do
  echo
  echo "--- run ${run}/${RUNS_PER_PARAM} ---"

  # Short-circuit: too many consecutive hopeless failures
  if (( consecutive_fail >= SHORTCIRCUIT_AFTER )); then
    echo "Short-circuit (${consecutive_fail} consecutive failures); skipping remaining runs."
    append_run "${run}" "SKIPPED" "" "" "" "" "" "short-circuit after ${consecutive_fail} consecutive failures"
    overall_status="PARTIAL"
    continue
  fi

  TIME_LOG="${TASK_ROOT}/time-${run}.log"
  RUN_LOG="${TASK_ROOT}/run-${run}.log"
  # Clean any compiler artefacts from previous runs
  rm -f "${PARAM_COUNT}-param" *.o *.c *.i

  start="$(date +%s.%N)"
  /usr/bin/time -v -o "${TIME_LOG}" \
    timeout --kill-after=30 "${RUN_TIMEOUT_SEC}" \
    bash -c "ulimit -v ${RUN_VMEM_LIMIT_KB}; '${SAC2C_PATH}' ${LIBFLAGS[*]@Q} '${SOURCE_FILE}'" \
    > "${RUN_LOG}" 2>&1
  exit_code=$?
  end="$(date +%s.%N)"
  wall="$(awk "BEGIN{printf \"%.6f\", ${end} - ${start}}")"

  # Parse /usr/bin/time -v output (may be partial on OOM)
  peak_rss_kb=""
  user_cpu_s=""
  sys_cpu_s=""
  if [[ -f "${TIME_LOG}" ]]; then
    peak_rss_kb="$(awk -F: '/Maximum resident set size/ {gsub(/^ +/, "", $2); print $2; exit}' "${TIME_LOG}")"
    user_cpu_s="$(awk -F: '/User time \(seconds\)/ {gsub(/^ +/, "", $2); print $2; exit}' "${TIME_LOG}")"
    sys_cpu_s="$(awk -F: '/System time \(seconds\)/ {gsub(/^ +/, "", $2); print $2; exit}' "${TIME_LOG}")"
  fi

  # Classify outcome
  status="SUCCESS"
  err_msg=""
  if [[ ${exit_code} -eq 0 ]]; then
    consecutive_fail=0
  elif [[ ${exit_code} -eq 124 || ${exit_code} -eq 137 ]] && \
       (( $(awk "BEGIN{print (${wall} >= ${RUN_TIMEOUT_SEC} - 5) ? 1 : 0}") )); then
    # Wall time at or near the cap → timeout
    status="TIMEOUT"
    err_msg="killed by timeout at ${wall}s (cap ${RUN_TIMEOUT_SEC}s); exit ${exit_code}"
    consecutive_fail=$((consecutive_fail + 1))
    overall_status="PARTIAL"
  elif [[ ${exit_code} -eq 137 ]] || grep -qiE "out of memory|cannot allocate|memory exhausted" "${RUN_LOG}"; then
    status="OOM"
    err_msg="killed (exit ${exit_code}); likely ulimit -v ${RUN_VMEM_LIMIT_KB}KB hit"
    consecutive_fail=$((consecutive_fail + 1))
    overall_status="PARTIAL"
  else
    status="ERROR"
    err_msg="sac2c exited with ${exit_code}"
    consecutive_fail=$((consecutive_fail + 1))
    overall_status="PARTIAL"
  fi

  # On non-SUCCESS, blank the compilation_time and peak_rss
  if [[ "${status}" != "SUCCESS" ]]; then
    record_time=""
    record_rss=""
  else
    record_time="${wall}"
    record_rss="${peak_rss_kb}"
  fi

  printf "  status=%s  wall=%ss  rss=%sKB  exit=%d\n" "${status}" "${wall}" "${peak_rss_kb:-?}" "${exit_code}"
  append_run "${run}" "${status}" "${exit_code}" "${record_time}" "${record_rss}" "${user_cpu_s}" "${sys_cpu_s}" "${err_msg}"

  # On non-success, dump a snippet of the run log so SLURM stdout has context
  if [[ "${status}" != "SUCCESS" ]]; then
    echo "  --- last 20 lines of ${RUN_LOG} ---"
    tail -n 20 "${RUN_LOG}" 2>/dev/null || true
    echo "  ------------------------------------"
  fi
done

export TASK_FINISHED_AT="$(date -Iseconds)"

# -------- 6. Emit final record --------------------------------------------
emit_json "${overall_status}" 0 ""

echo
echo "========================================================================"
echo "Task complete: ${overall_status}"
echo "Record: ${RESULT_JSON}"
echo "========================================================================"

cd /
rm -rf "${TASK_ROOT}"
exit 0
