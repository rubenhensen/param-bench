#!/bin/bash
#SBATCH --job-name=build-stdlibs
#SBATCH --output=build-stdlibs-%j.out
#SBATCH --error=build-stdlibs-%j.err
#SBATCH --time=04:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=14G
#SBATCH --account=csmpi
#SBATCH --partition=cncz

set -euo pipefail
echo "Node: $(hostname)   Started: $(date -Iseconds)"

build_stdlib_with () {
  local sac2c="$1"
  local builddir="$2"
  echo "==== building Stdlib at ${builddir} using ${sac2c} ===="
  rm -rf "${builddir}"
  mkdir -p "${builddir}"
  cd "${builddir}"
  cmake -DTARGETS='seq;mt_pth' -DSAC2C_EXEC="${sac2c}" "/home/rhensen/Stdlib"
  make -j "${SLURM_CPUS_PER_TASK}"
  echo "  -> ${builddir}/lib:"
  ls -l "${builddir}/lib" | head
}

build_stdlib_with "/home/rhensen/sacoriginal/sac2c/build_p/sac2c_p" "/home/rhensen/Stdlib/build-orig"
build_stdlib_with "/home/rhensen/sac2c/build_p/sac2c_p"  "/home/rhensen/Stdlib/build-new"

echo "Finished: $(date -Iseconds)"
