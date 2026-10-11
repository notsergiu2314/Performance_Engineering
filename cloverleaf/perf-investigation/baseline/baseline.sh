#!/bin/bash
# Run every configuration listed in a matrix file, then summarise.
# usage: baseline.sh [MATRIX_FILE]      (default: matrix.default)
# Matrix file: one case per line "KERNELS RANKS THREADS [DECK]"; '#' comments.
# Runs unchanged inside a batch allocation: mpirun picks the allocated nodes up
# from the scheduler, so an sbatch script only needs to load modules, set
# OUT_DIR and call this file.
#
# Environment knobs (all optional, defaults in lib.sh):
#   CLOVER_BIN   path to clover_leaf           DECK_DIR     directory with the .in decks
#   REPS         repetitions per case (5)      OUT_DIR      where results go
#   MPIRUN       launcher executable           MPIRUN_ARGS  extra mpirun flags
#   OMP_PROC_BIND / OMP_PLACES / OMP_DYNAMIC   thread pinning (close / cores / false)
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$here/lib.sh"
matrix=${1:-$here/matrix.default}
[ -f "$matrix" ] || die "matrix file not found: $matrix"
[ -x "$CLOVER_BIN" ] || die "binary not found/executable: $CLOVER_BIN"
mkdir -p "$OUT_DIR"

{
  echo "date:        $(date -Is)"
  echo "host:        $(hostname)   cpus: $(nproc)"
  [ -n "${SLURM_JOB_ID:-}" ] && echo "slurm:       job $SLURM_JOB_ID on ${SLURM_JOB_NODELIST:-?}"
  echo "binary:      $CLOVER_BIN  ($(md5sum "$CLOVER_BIN" | cut -c1-12))"
  echo "git:         $(git -C "$(dirname "$CLOVER_BIN")" rev-parse --short HEAD 2>/dev/null || echo n/a)"
  echo "mpirun:      $("$MPIRUN" --version 2>/dev/null | head -1)  args: --map-by slot:PE=<threads> --bind-to core $MPIRUN_ARGS"
  echo "omp:         OMP_PROC_BIND=$OMP_PROC_BIND OMP_PLACES=$OMP_PLACES OMP_DYNAMIC=$OMP_DYNAMIC"
  echo "reps:        $REPS"
  echo "matrix:      $matrix"
  echo "compiler:    $(mpif90 --version 2>/dev/null | head -1)"
  command -v lscpu >/dev/null && lscpu | grep -E 'Model name|Architecture|^CPU\(s\)|Thread|Socket|NUMA|L3' | sed 's/^/  /'
} | tee "$OUT_DIR/environment.txt"
echo

# Matrix is read on fd 3 so nothing a child process does to stdin can skip cases.
while read -r -u 3 kernels ranks threads deck; do
  echo "== $kernels kernels, $ranks rank(s) x $threads thread(s) ${deck:+deck=$deck}"
  "$here/run_case.sh" "$kernels" "$ranks" "$threads" ${deck:+"$deck"}
done 3< <(grep -v -E '^\s*(#|$)' "$matrix")

echo
python3 -I "$here/summarize.py" "$OUT_DIR" | tee "$OUT_DIR/summary.txt"
python3 -I "$here/summarize.py" "$OUT_DIR" --md > "$OUT_DIR/summary.md"
