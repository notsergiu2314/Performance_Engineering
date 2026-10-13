#!/bin/bash
#SBATCH -J m3_papi
#SBATCH -p cn-ib
#SBATCH -N 1
#SBATCH --exclusive
#SBATCH --ntasks-per-node=128
#SBATCH --cpus-per-task=1
#SBATCH -t 01:00:00
#SBATCH -o perf/results/%x_%j.log
# Per-kernel hardware counters (kernels/papi_prof.c) at the M3 baseline layout 64x2 and at
# the pure-OpenMP reference 1x128 with THP off (perf/baseline/matrix.papi), through the
# same harness as m3_baseline so placement is identical. Three event sets as in M1
# (m1_papi.sbatch): ipc, mix, stall. One base-binary run per layout gives the
# instrumentation overhead. Output: $OUT/<set>/<tag>/papi_prof_<pid>.csv (one per rank)
# and summary.txt (analysis/papi_summary.py, max over threads and ranks).
# Submit from CloverLeaf_ref: sbatch perf/jobs/m3_papi.sbatch
set -eo pipefail
source "$SLURM_SUBMIT_DIR/perf/jobs/common.sh"
set -u
OUT="$PERF_ROOT/results/m3_papi_$SLURM_JOB_ID"
mkdir -p "$OUT"
record_system "$OUT"
papi_avail -a > "$OUT/papi_avail.txt" 2>&1 || true

export NOTHP="$OUT/nothp"
gcc -O2 "$PERF_ROOT/microbench/nothp.c" -o "$NOTHP"
export REPS=1 DDRC=off
MATRIX="$PERF_ROOT/baseline/matrix.papi"

declare -A SETS=(
  [ipc]="PAPI_TOT_CYC,PAPI_TOT_INS"
  [mix]="PAPI_TOT_INS,PAPI_LD_INS,PAPI_SR_INS,PAPI_FP_INS,PAPI_VEC_INS,PAPI_BR_MSP"
  [stall]="PAPI_TOT_CYC,STALL_BACKEND,STALL_FRONTEND,BUS_ACCESS,MEM_ACCESS"
)
for set in ipc mix stall; do
  export PROF_EVENTS="${SETS[$set]}"
  CLOVER_BIN="$PERF_ROOT/bin/clover_papi" OUT_DIR="$OUT/$set" bash "$PERF_ROOT/baseline/baseline.sh" "$MATRIX"
done
unset PROF_EVENTS
# overhead check: same layouts, uninstrumented binary
CLOVER_BIN="$PERF_ROOT/bin/clover_base" OUT_DIR="$OUT/base" bash "$PERF_ROOT/baseline/baseline.sh" "$MATRIX"

{
  for set in ipc mix stall; do
    for d in "$OUT/$set"/clover_*/; do
      echo "=== $set $(basename "$d")"
      python3 "$PERF_ROOT/analysis/papi_summary.py" "$d"
    done
  done
  echo "=== wall clock, PAPI build (ipc set) vs base build"
  for f in "$OUT/ipc/results.csv" "$OUT/base/results.csv"; do
    echo "-- $f"; cut -d, -f1,8,12 "$f"
  done
} > "$OUT/summary.txt" 2>&1
cat "$OUT/summary.txt"
