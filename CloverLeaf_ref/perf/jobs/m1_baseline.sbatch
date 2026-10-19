#!/bin/bash
#SBATCH -J m1_baseline
#SBATCH -p cn-ib
#SBATCH -N 1
#SBATCH --exclusive
#SBATCH -t 03:00:00
#SBATCH -o perf/results/%x_%j.log
# M1: baseline timings from CloverLeaf's internal profiler (profiler_on).
#  - thread scaling 1..128 (OMP_PROC_BIND=close fills NUMA domain 0 first)
#  - hybrid MPI+OpenMP layouts on the full node
#  - two problem sizes: bm3840 (~3.5 GB, memory resident) and bm960 (~0.2 GB,
#    partly fits in the 2 x 64 MB L3)
# Submit from the repository root: sbatch perf/jobs/m1_baseline.sbatch
set -uo pipefail
source "$SLURM_SUBMIT_DIR/perf/jobs/common.sh"

REPS="${REPS:-3}"
OUT="$PERF_ROOT/results/m1_baseline_$SLURM_JOB_ID"
record_system "$OUT"

for deck in bm3840 bm960; do
  for cfg in 1x1 1x2 1x4 1x8 1x16 1x32 1x64 1x128 2x64 4x32; do
    for rep in $(seq 1 "$REPS"); do
      run_clover "$PERF_ROOT/bin/clover_base" "$deck" "$cfg" "$OUT/$deck/$cfg/rep$rep"
    done
  done
done

python3 "$PERF_ROOT/analysis/clover_profile.py" "$OUT" > "$OUT/summary.txt"
cat "$OUT/summary.txt"
