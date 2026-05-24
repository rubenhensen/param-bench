#!/bin/bash
# One-shot SLURM job that builds the Stdlib once with each compiler.
#
# Reads the same config.mk paths as the benchmark, so the produced
# build trees are exactly where the benchmark expects them.
#
# Run once before the first `make run` (or whenever you re-clone Stdlib
# or rebuild a compiler). Subsequent reruns of the benchmark do not need
# to rebuild Stdlib unless you've changed either compiler.

set -eu
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
cd "${PROJECT_DIR}"

SBATCH_SCRIPT="${PROJECT_DIR}/jobs/build_stdlibs.sh"
mkdir -p "${PROJECT_DIR}/jobs"

cat > "${SBATCH_SCRIPT}" <<EOF
#!/bin/bash
#SBATCH --job-name=build-stdlibs
#SBATCH --output=build-stdlibs-%j.out
#SBATCH --error=build-stdlibs-%j.err
#SBATCH --time=04:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=${SLURM_CPUS:-4}
#SBATCH --mem=${SLURM_MEM:-14G}
#SBATCH --account=${SLURM_ACCOUNT:-csmpi}
#SBATCH --partition=${SLURM_PARTITION:-cncz}

set -euo pipefail
echo "Node: \$(hostname)   Started: \$(date -Iseconds)"

build_stdlib_with () {
  local sac2c="\$1"
  local builddir="\$2"
  echo "==== building Stdlib at \${builddir} using \${sac2c} ===="
  rm -rf "\${builddir}"
  mkdir -p "\${builddir}"
  cd "\${builddir}"
  cmake -DTARGETS='seq;mt_pth' -DSAC2C_EXEC="\${sac2c}" "${STDLIB_SRC_SLURM}"
  make -j "\${SLURM_CPUS_PER_TASK}"
  echo "  -> \${builddir}/lib:"
  ls -l "\${builddir}/lib" | head
}

build_stdlib_with "${SAC2C_ORIG_SLURM}" "${STDLIB_BUILD_ORIG}"
build_stdlib_with "${SAC2C_NEW_SLURM}"  "${STDLIB_BUILD_NEW}"

echo "Finished: \$(date -Iseconds)"
EOF

chmod +x "${SBATCH_SCRIPT}"

echo "wrote ${SBATCH_SCRIPT}"
echo
echo "Submitting build job..."
JID="$(sbatch --parsable "${SBATCH_SCRIPT}")"
echo "  -> job ${JID}"
echo
echo "Watch with:"
echo "  squeue -u \$USER"
echo "  tail -f build-stdlibs-${JID}.out"
echo
echo "When the job is COMPLETED, verify:"
echo "  ls ${STDLIB_BUILD_NEW}/lib"
echo "  ls ${STDLIB_BUILD_ORIG}/lib"
echo
echo "Then run the benchmark: make"
