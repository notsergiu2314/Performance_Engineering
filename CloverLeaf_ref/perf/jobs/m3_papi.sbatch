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
# (m1_papi.sbatch): ipc, mix, stall. One uninstrumented run per layout gives the
# instrumentation overhead. Output: $OUT/<set>/<tag>/papi_prof_<pid>.csv (one per rank),
# $OUT/<set>/<tag>.papi.csv (analysis/papi_summary.py --csv, one row per region) and
# summary.txt (max over threads and ranks).
# Knobs: VARIANT (opt): binaries perf/bin/clover_<VARIANT>_papi and clover_<VARIANT>
# (perf/build.sh); output perf/results/m3_papi_<VARIANT>_<jobid>. The baseline run is job
# 34798 (variant base). Note for the optimised kernels: both halves of the split advec_mom
# kernel count under region advec_mom (696 calls instead of 348), and reset_field/revert
# have no C region any more (field swap, no kernel call).
# Submit from CloverLeaf_ref: VARIANT=opt sbatch perf/jobs/m3_papi.sbatch
set -eo pipefail
source "$SLURM_SUBMIT_DIR/perf/jobs/common.sh"
set -u
VARIANT="${VARIANT:-opt}"
OUT="$PERF_ROOT/results/m3_papi_${VARIANT}_$SLURM_JOB_ID"
PAPI_BIN="$PERF_ROOT/bin/clover_${VARIANT}_papi"
BASE_BIN="$PERF_ROOT/bin/clover_$VARIANT"
for b in "$PAPI_BIN" "$BASE_BIN"; do
  [ -x "$b" ] || { echo "missing $b: run 'srun -p cn-ib -N 1 bash perf/build.sh $VARIANT'" >&2; exit 1; }
done
export REPS=1 DDRC=off
prepare_harness "$OUT"
papi_avail -a > "$OUT/papi_avail.txt" 2>&1 || true
echo "job $SLURM_JOB_ID on $SLURM_JOB_NODELIST: variant $VARIANT -> $OUT"
MATRIX="$PERF_ROOT/baseline/matrix.papi"

declare -A SETS=(
  [ipc]="PAPI_TOT_CYC,PAPI_TOT_INS"
  [mix]="PAPI_TOT_INS,PAPI_LD_INS,PAPI_SR_INS,PAPI_FP_INS,PAPI_VEC_INS,PAPI_BR_MSP"
  [stall]="PAPI_TOT_CYC,STALL_BACKEND,STALL_FRONTEND,BUS_ACCESS,MEM_ACCESS"
)
for set in ipc mix stall; do
  export PROF_EVENTS="${SETS[$set]}"
  CLOVER_BIN="$PAPI_BIN" VARIANT="$VARIANT" OUT_DIR="$OUT/$set" bash "$PERF_ROOT/baseline/baseline.sh" "$MATRIX"
done
unset PROF_EVENTS
# overhead check: same layouts, the uninstrumented binary of the same variant
CLOVER_BIN="$BASE_BIN" VARIANT="$VARIANT" OUT_DIR="$OUT/uninstrumented" bash "$PERF_ROOT/baseline/baseline.sh" "$MATRIX"

{
  for set in ipc mix stall; do
    for d in "$OUT/$set"/clover_*/; do
      echo "=== $set $(basename "$d")"
      python3 -I "$PERF_ROOT/analysis/papi_summary.py" "$d" --csv "${d%/}.papi.csv"
    done
  done
  echo "=== wall clock, PAPI build (ipc set) vs uninstrumented build"
  for f in "$OUT/ipc/results.csv" "$OUT/uninstrumented/results.csv"; do
    echo "-- $f"; cut -d, -f1,8,12 "$f"
  done
} > "$OUT/summary.txt" 2>&1
cat "$OUT/summary.txt"
