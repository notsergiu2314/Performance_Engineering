#!/bin/bash
# Machine ceilings (STREAM-style bandwidth + FP64 FMA peak) on one exclusive HAICGU node.
# Submit from CloverLeaf_ref:
#   sbatch perf/roofline/machine.sbatch                        # matrix.machine, 3 reps
#   REPS=5 sbatch perf/roofline/machine.sbatch perf/roofline/matrix.peak
# Builds the benchmarks (perf/microbench/membw.c, peak_fma.c) on the compute node itself
# (same CPU; -march=native). Output: perf/results/roofline_<jobid>/machine.csv.
# For the hardware-byte ceiling (DDR-controller counters around STREAM) use
# perf/jobs/m3_stream_ddrc.sbatch instead; this job measures STREAM-counted bytes.
#SBATCH --job-name=clover-roofline
#SBATCH --partition=cn-ib               # cn[09-18]; cn-eth is the alternative. Never cn-kube.
#SBATCH --nodes=1
#SBATCH --exclusive
#SBATCH --ntasks-per-node=128
#SBATCH --cpus-per-task=1
#SBATCH --time=00:30:00
#SBATCH --output=perf/results/%x_%j.log

set -eo pipefail
root=${SLURM_SUBMIT_DIR:-$(cd "$(dirname "$(readlink -f "$0")")/../.." && pwd)}
[ -f "$root/perf/jobs/common.sh" ] || { echo "perf/jobs/common.sh not found under $root -- submit from CloverLeaf_ref" >&2; exit 1; }
source "$root/perf/jobs/common.sh"          # modules via env.sh, same as the clover_leaf build
set -u

here=$PERF_ROOT/roofline
export OUT_DIR=${OUT_DIR:-$PERF_ROOT/results/roofline_$SLURM_JOB_ID}
export BIN_DIR=${BIN_DIR:-$OUT_DIR/bin}
export MACHINE_PROFILE=${MACHINE_PROFILE:-haicgu}
export REPS=${REPS:-3}
mkdir -p "$OUT_DIR"
echo "job $SLURM_JOB_ID on $SLURM_JOB_NODELIST, results -> $OUT_DIR"

"$here/build.sh"
"$here/machine.sh" "${1:-$here/matrix.machine}"
echo "done: $OUT_DIR/machine.csv"
