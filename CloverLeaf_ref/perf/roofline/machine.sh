#!/bin/bash
# Run the machine microbenchmarks for every line of a matrix file and summarise.
# usage: machine.sh [MATRIX_FILE]      (default: matrix.machine)
# Matrix line: "KIND THREADS PLACES SCOPE"; KIND membw|peak_fma, PLACES an OMP_PLACES value,
# SCOPE core|numa|socket|node. '#' comments. Runs unchanged inside a batch allocation.
# Outputs in $OUT_DIR: environment.txt, build.log, <kind>_<scope>_t<threads>.rep<i>.log,
# machine_raw.csv (every run), machine.csv (best of reps + theoretical rows).
#
# Knobs (defaults in lib.sh): BIN_DIR CC CFLAGS ARRAY_ELEMS NTIMES FMA_ITERS REPS OUT_DIR
#   MACHINE_PROFILE (haicgu|laptop -> machine.<profile>.env) MPIRUN MPIRUN_ARGS OMP_*
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$here/lib.sh"
profile_env
matrix=${1:-$here/matrix.machine}
[ -f "$matrix" ] || die "matrix file not found: $matrix"
[ -x "$BIN_DIR/membw" ] && [ -x "$BIN_DIR/peak_fma" ] || die "binaries missing in $BIN_DIR: run build.sh first"
mkdir -p "$OUT_DIR"
cp "$BIN_DIR/build.log" "$OUT_DIR/build.log" 2>/dev/null || true

{
  echo "date:        $(date -Is)"
  echo "host:        $(hostname)   cpus: $(nproc)"
  [ -n "${SLURM_JOB_ID:-}" ] && echo "slurm:       job $SLURM_JOB_ID on ${SLURM_JOB_NODELIST:-?}"
  echo "profile:     $MACHINE_PROFILE ($(tr '\n' ' ' < "$here/machine.$MACHINE_PROFILE.env" | sed 's/#[^A-Z]*//g'))"
  echo "cc:          $CC ($("$CC" --version 2>/dev/null | head -1))  cflags: $CFLAGS"
  echo "membw:       ARRAY_ELEMS=$ARRAY_ELEMS ($((ARRAY_ELEMS*8/1048576)) MiB/array) NTIMES=$NTIMES"
  echo "peak_fma:    FMA_ITERS=$FMA_ITERS"
  echo "mpirun:      $("$MPIRUN" --version 2>/dev/null | head -1)  single rank: $SINGLE_RANK_PLACEMENT $MPIRUN_ARGS"
  echo "omp:         OMP_PROC_BIND=$OMP_PROC_BIND OMP_DYNAMIC=$OMP_DYNAMIC (OMP_PLACES per matrix line)"
  echo "reps:        $REPS"
  echo "matrix:      $matrix"
  command -v lscpu >/dev/null && lscpu | grep -E 'Model name|Architecture|^CPU\(s\)|Thread|Socket|NUMA|L2|L3|MHz' | sed 's/^/  /'
  command -v numactl >/dev/null && numactl -H 2>/dev/null | grep -E 'available|size' | sed 's/^/  /'
} | tee "$OUT_DIR/environment.txt"
echo

raw=$OUT_DIR/machine_raw.csv
[ -f "$raw" ] || echo "kind,quantity,threads,scope,rep,value,unit,host,date" > "$raw"

while read -r -u 3 kind threads places scope; do
  echo "== $kind  threads=$threads  places=$places  scope=$scope"
  for i in $(seq 1 "$REPS"); do
    log=$OUT_DIR/${kind}_${scope}_t${threads}.rep$i.log
    if ! run_bench "$kind" "$threads" "$places" > "$log" 2>&1; then
      echo "  warning: $kind rep $i failed (see $log)" >&2; continue
    fi
    parse_bench "$kind" < "$log" | while IFS=, read -r q v u; do
      echo "$kind,$q,$threads,$scope,$i,$v,$u,$(hostname),$(date -Is)" >> "$raw"
    done
    printf '  rep %d  %s\n' "$i" "$(parse_bench "$kind" < "$log" | tr '\n' ' ')"
  done
done 3< <(grep -v -E '^\s*(#|$)' "$matrix")

echo
python3 -I "$here/machine_summary.py" "$OUT_DIR" "$here/machine.$MACHINE_PROFILE.env" | tee "$OUT_DIR/machine.txt"
echo "machine.csv in $OUT_DIR"
