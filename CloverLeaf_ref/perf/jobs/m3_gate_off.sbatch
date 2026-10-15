#!/bin/bash
#SBATCH -J gate_off
#SBATCH -p cn-ib
#SBATCH -N 1
#SBATCH --exclusive
#SBATCH --ntasks-per-node=128
#SBATCH --cpus-per-task=1
#SBATCH -t 00:40:00
#SBATCH -o perf/results/%x_%j.log
# Equivalence gate with fused multiply-add switched off: the original kernels (59cdd3b) and the
# checked-out commit are built with -ffp-contract=off and run on clover_bm.in at three layouts.
# Equivalent code must print the same (tiny) deviation and CloverLeaf's own PASSED
# (jobs 34936: 1.99e-13 % for the original, the edits and the merged tip).
# Submit from CloverLeaf_ref: sbatch perf/jobs/m3_gate_off.sbatch
# Result: perf/results/gate_off_<jobid>.txt
set -eo pipefail
source "$SLURM_SUBMIT_DIR/perf/jobs/common.sh"
set -u
REPO=$(git -C "$SLURM_SUBMIT_DIR" rev-parse --show-toplevel)
W=$PERF_ROOT/results/gate_off_$SLURM_JOB_ID
mkdir -p "$W/bin" "$W/src"
declare -A REV=( [orig]=59cdd3b [final]=$(git -C "$REPO" rev-parse --short HEAD) )
OFF="-O3 -march=native -funroll-loops -ffp-contract=off"
build() {  # name rev
  mkdir -p "$W/src/$1"; git -C "$REPO" archive "$2" CloverLeaf_ref | tar -x -C "$W/src/$1"
  ( cd "$W/src/$1/CloverLeaf_ref" && make COMPILER=GNU OPTIONS="-g" C_OPTIONS="-g" CFLAGS_GNU="$OFF" > "$W/build_$1.log" 2>&1 \
    && cp clover_leaf "$W/bin/$1" )
}
for v in orig final; do build "$v" "${REV[$v]}" & done
wait
printf 'c 64 2 clover_bm.in on\nc 1 128 clover_bm.in on\nc 4 32 clover_bm.in on\n' > "$W/matrix"
: > "$W/summary.txt"
for v in orig final; do
  OUT_DIR="$W/run_$v" CLOVER_BIN="$W/bin/$v" MATRIX="$W/matrix" REPS=1 DDRC=off \
    bash "$PERF_ROOT/baseline/baseline.sbatch" > "$W/run_$v.log" 2>&1 || true
  awk -F, -v v="$v" -v r="${REV[$v]}" 'NR>1{print v, r, $4"x"$5, "qa_pct="$11, $12}' "$W/run_$v/results.csv" >> "$W/summary.txt"
done
echo "== summary"; cat "$W/summary.txt"
cp "$W/summary.txt" "$PERF_ROOT/results/gate_off_$SLURM_JOB_ID.txt"
