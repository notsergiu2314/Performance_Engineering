#!/bin/bash
# CloverLeaf matrix benchmark on one exclusive HAICGU compute node
# (https://haicgu.github.io/): 2 x Kunpeng 920, 128 physical cores, no SMT.
# Submit from the CloverLeaf_ref directory (the jobs find perf/ through SLURM_SUBMIT_DIR):
#   sbatch perf/baseline/baseline.sbatch                       # matrix.cluster, 5 reps
#   REPS=3 sbatch perf/baseline/baseline.sbatch                # quicker first pass
#   sbatch perf/baseline/baseline.sbatch perf/baseline/my.matrix
# Build first on a compute node: srun -p cn-ib -N 1 bash perf/build.sh  (-> perf/bin/clover_base)
# Knobs: REPS, MATRIX (or $1), CLOVER_BIN, OUT_DIR, DDRC (auto|off: DDR-controller counters
# around every rep when perf exposes them), STREAM_HW_GBS (hardware STREAM ceiling for the
# summary's %-of-roof column). THP=off rows of the matrix use the nothp launcher built here.
#SBATCH --job-name=clover-baseline
#SBATCH --partition=cn-ib               # cn[09-18]; cn-eth is the alternative. Never cn-kube.
#SBATCH --nodes=1
#SBATCH --exclusive
#SBATCH --ntasks-per-node=128
#SBATCH --cpus-per-task=1
#SBATCH --time=02:00:00
#SBATCH --output=perf/results/%x_%j.log

set -eo pipefail
root=${SLURM_SUBMIT_DIR:-$(cd "$(dirname "$(readlink -f "$0")")/../.." && pwd)}
[ -f "$root/perf/jobs/common.sh" ] || { echo "perf/jobs/common.sh not found under $root -- submit from CloverLeaf_ref" >&2; exit 1; }
# env.sh (via common.sh) loads the modules; it relaxes 'set -u' itself around lmod.
source "$root/perf/jobs/common.sh"
set -u

here=$PERF_ROOT/baseline
matrix=${MATRIX:-${1:-$here/matrix.cluster}}
export CLOVER_BIN=${CLOVER_BIN:-$PERF_ROOT/bin/clover_base}
export OUT_DIR=${OUT_DIR:-$PERF_ROOT/results/${SLURM_JOB_NAME}_$SLURM_JOB_ID}
export REPS=${REPS:-5}
export STREAM_HW_GBS=${STREAM_HW_GBS:-}

[ -x "$CLOVER_BIN" ] || { echo "binary missing: $CLOVER_BIN -- run 'srun -p cn-ib -N 1 bash perf/build.sh' first" >&2; exit 1; }
mkdir -p "$OUT_DIR"
echo "job $SLURM_JOB_ID on $SLURM_JOB_NODELIST, matrix $matrix, results -> $OUT_DIR"

# THP-off launcher for the matrix rows that ask for it (prctl(PR_SET_THP_DISABLE) + exec).
export NOTHP=${NOTHP:-$OUT_DIR/nothp}
[ -x "$NOTHP" ] || gcc -O2 "$PERF_ROOT/microbench/nothp.c" -o "$NOTHP"
export NOTHP_VERBOSE=1

# DDR-controller counters (HiSilicon uncore PMU) around every repetition, if visible.
if [ "${DDRC:-auto}" != off ]; then
  DDRC_EVENTS=$(ddrc_events); export DDRC_EVENTS
  [ -n "$DDRC_EVENTS" ] || echo "warning: no hisi_sccl*_ddrc* events visible to perf; dram_GB will be NA"
fi
record_system "$OUT_DIR"

# Topology and placement sanity check at the top of the job log: four ranks
# with 32 cores each should land on four distinct NUMA domains / two packages.
lscpu | grep -E 'Model name|^CPU\(s\)|Socket|Thread|NUMA'
OMP_NUM_THREADS=32 mpirun -np 4 --map-by slot:PE=32 --bind-to core --report-bindings true 2>&1 | head -4

"$here/baseline.sh" "$matrix"
echo "done: $OUT_DIR/summary.txt"
