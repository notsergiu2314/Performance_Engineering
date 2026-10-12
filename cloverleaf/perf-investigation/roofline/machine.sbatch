#!/bin/bash
# Machine ceilings (STREAM-style bandwidth + FP64 FMA peak) on one exclusive HAICGU node.
#   sbatch machine.sbatch                  # matrix.machine, 3 reps
#   REPS=5 sbatch machine.sbatch my.matrix
# Submit from this directory on the dev node (guoehi-dev). Builds the benchmarks on the
# compute node itself (same CPU; -march=native).
#SBATCH --job-name=clover-roofline
#SBATCH --partition=cn-ib               # cn[09-18]; cn-eth is the alternative. Never cn-kube.
#SBATCH --nodes=1
#SBATCH --exclusive
#SBATCH --ntasks-per-node=128
#SBATCH --cpus-per-task=1
#SBATCH --time=00:30:00
#SBATCH --output=clover-roofline-%j.log

set -eo pipefail
module purge
module load GCC OpenMPI          # same modules as the clover_leaf build
set -u

here=${ROOFLINE_DIR:-${SLURM_SUBMIT_DIR:-$(dirname "$(readlink -f "$0")")}}
[ -f "$here/machine.sh" ] || { echo "machine.sh not found in $here -- run sbatch from perf-investigation/roofline or set ROOFLINE_DIR" >&2; exit 1; }
export OUT_DIR=${OUT_DIR:-$HOME/clover-runs/roofline-$SLURM_JOB_ID}
export BIN_DIR=${BIN_DIR:-$OUT_DIR/bin}
export MACHINE_PROFILE=${MACHINE_PROFILE:-haicgu}
export REPS=${REPS:-3}
mkdir -p "$OUT_DIR"
echo "job $SLURM_JOB_ID on $SLURM_JOB_NODELIST, results -> $OUT_DIR"

"$here/build.sh"
"$here/machine.sh" "${1:-$here/matrix.machine}"
echo "done: $OUT_DIR/machine.csv"
