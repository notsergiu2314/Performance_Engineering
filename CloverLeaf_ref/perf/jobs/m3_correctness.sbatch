#!/bin/bash
#SBATCH -J m3_correctness
#SBATCH -p cn-ib
#SBATCH -N 1
#SBATCH --exclusive
#SBATCH --ntasks-per-node=128
#SBATCH --cpus-per-task=1
#SBATCH -t 00:30:00
#SBATCH -o perf/results/%x_%j.log
# Correctness gate for every build (baseline and each M3 optimisation): clover_bm.in
# (960^2, 2955 steps) at the M3 layouts, one repetition each, and the reported
# kinetic-energy deviation compared with perf/archive/m3/correctness_baseline.csv.
# A changed kernel must reproduce the baseline deviation to 1e-6 % (the check is
# deterministic: job 34729 gave the same digits at 128x1 and 4x32).
# Knobs: CLOVER_BIN (perf/bin/clover_base), BASELINE (the csv above), TOL (1e-6).
# Submit from CloverLeaf_ref: sbatch perf/jobs/m3_correctness.sbatch
set -eo pipefail
source "$SLURM_SUBMIT_DIR/perf/jobs/common.sh"
set -u
export MATRIX="$PERF_ROOT/baseline/matrix.correctness"
export REPS=1 DDRC=off
export OUT_DIR="$PERF_ROOT/results/m3_correctness_$SLURM_JOB_ID"
bash "$PERF_ROOT/baseline/baseline.sbatch"

BASELINE="${BASELINE:-$PERF_ROOT/archive/m3/correctness_baseline.csv}"
echo; echo "== qa_check against $BASELINE"
python3 "$PERF_ROOT/baseline/qa_check.py" "$OUT_DIR/results.csv" "$BASELINE" --tol "${TOL:-1e-6}" \
  | tee "$OUT_DIR/qa_check.txt"
