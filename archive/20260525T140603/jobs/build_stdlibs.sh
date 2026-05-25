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
  local prelude="$3"
  # Isolate HOME so this build's sac2crc doesn't bleed into the next build.
  # Also pre-write the prelude sac2crc so sac2c can find its own runtime libs
  # (without it sac2c fails with "Cannot find library sacprelude_p").
  local isolated_home; isolated_home="$(mktemp -d)"
  mkdir -p "${isolated_home}/.sac2crc"
  printf 'target add_local:\nTREEPATH       += "%s:"\nLIBPATH        += "%s:"\n\ntarget default_sbi :: add_local:\n' "${prelude}" "${prelude}" > "${isolated_home}/.sac2crc/sac2crc.release.prelude"
  cp "${isolated_home}/.sac2crc/sac2crc.release.prelude" "${isolated_home}/.sac2crc/sac2crc.debug.prelude"
  echo "==== building Stdlib at ${builddir} using ${sac2c} ===="
  echo "     isolated HOME : ${isolated_home}"
  echo "     prelude path  : ${prelude}"
  rm -rf "${builddir}"
  mkdir -p "${builddir}"
  cd "${builddir}"
  HOME="${isolated_home}" cmake -DTARGETS='seq;mt_pth' -DSAC2C_EXEC="${sac2c}" "/home/rhensen/Stdlib"
  HOME="${isolated_home}" make -j "${SLURM_CPUS_PER_TASK}"
  rm -rf "${isolated_home}"
  echo "  -> ${builddir}/lib:"
  ls -l "${builddir}/lib" | head
}

build_stdlib_with "/home/rhensen/sacoriginal/sac2c/build_p/sac2c_p" "/home/rhensen/Stdlib/build-orig" "/home/rhensen/sacoriginal/sac2c/build_p/runtime_build/src/runtime_libraries-build/lib/prelude"
build_stdlib_with "/home/rhensen/sac2c/build_p/sac2c_p"  "/home/rhensen/Stdlib/build-new"  "/home/rhensen/sac2c/build_p/runtime_build/src/runtime_libraries-build/lib/prelude"

echo "Finished: $(date -Iseconds)"
