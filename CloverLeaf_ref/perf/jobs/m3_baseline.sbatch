#!/bin/bash
#SBATCH -J m3_baseline
#SBATCH -p cn-ib
#SBATCH -N 1
#SBATCH --exclusive
#SBATCH --ntasks-per-node=128
#SBATCH --cpus-per-task=1
#SBATCH -t 01:30:00
#SBATCH -o perf/results/%x_%j.log
# M3 baseline: C kernels on bm3840 at 64x2 (the baseline layout) against 1x128, 4x32, 32x4
# and 128x1, each with THP on and off, 5 repetitions, every repetition under the
# DDR-controller counters (hardware bytes); Fortran at the same layouts for reference.
# Matrix: perf/baseline/matrix.m3. Harness: perf/baseline/ (baseline.sbatch does the work).
# Knobs: REPS (5), STREAM_HW_GBS (hardware STREAM ceiling from m3_stream_ddrc, for the
# %-of-roof column; pass it once that job has run), DDRC=off to skip the counters.
# Submit from CloverLeaf_ref: STREAM_HW_GBS=356 sbatch perf/jobs/m3_baseline.sbatch
export MATRIX="$SLURM_SUBMIT_DIR/perf/baseline/matrix.m3"
export REPS="${REPS:-5}"
exec bash "$SLURM_SUBMIT_DIR/perf/baseline/baseline.sbatch"
