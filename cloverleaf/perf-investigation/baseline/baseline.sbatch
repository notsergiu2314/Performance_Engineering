#!/bin/bash
# Full CloverLeaf C-vs-Fortran baseline on one exclusive HAICGU compute node
# (https://haicgu.github.io/): 2 x Kunpeng 920, 128 physical cores, no SMT.
#   sbatch baseline.sbatch                 # matrix.cluster, 5 reps
#   REPS=3 sbatch baseline.sbatch          # quicker first pass
#   sbatch baseline.sbatch my.matrix       # another matrix file
# Submit from the dev node (guoehi-dev). Build clover_leaf there first with
# the same modules: module load GCC OpenMPI; make clean && make COMPILER=GNU
#SBATCH --job-name=clover-baseline
#SBATCH --partition=cn-ib               # cn[09-18]; cn-eth is the alternative. Never cn-kube.
#SBATCH --nodes=1
#SBATCH --exclusive
#SBATCH --ntasks-per-node=128
#SBATCH --cpus-per-task=1
#SBATCH --time=02:00:00
#SBATCH --output=clover-baseline-%j.log

set -eo pipefail
# Lmod's init script references unset variables (LD_PRELOAD), so 'set -u' is
# enabled only after the modules are loaded.
module purge
# Documented stage-2022a modules: GCC/12.1.0 and OpenMPI/4.1.3 (the only MPI).
# Unversioned names pick the defaults; environment.txt records what actually ran.
module load GCC OpenMPI
set -u

# Slurm executes a copy of this script from its spool directory, so $0 does not
# point at the harness. Use the directory sbatch was run from (submit from the
# baseline directory) or set BASELINE_DIR explicitly.
here=${BASELINE_DIR:-${SLURM_SUBMIT_DIR:-$(dirname "$(readlink -f "$0")")}}
[ -f "$here/baseline.sh" ] || { echo "baseline.sh not found in $here -- run sbatch from perf-investigation/baseline or set BASELINE_DIR" >&2; exit 1; }
export CLOVER_BIN=${CLOVER_BIN:-$here/../../cloverleaf_b5e598d/clover_leaf}
# No $SCRATCH on HAICGU. Output is a few MB per matrix, so /home (NFS) is fine;
# /mnt/lustre-storage/$USER is the alternative for bigger runs.
export OUT_DIR=${OUT_DIR:-$HOME/clover-runs/baseline-$SLURM_JOB_ID}
export REPS=${REPS:-5}

[ -x "$CLOVER_BIN" ] || { echo "binary missing: $CLOVER_BIN -- build on guoehi-dev with 'module load GCC OpenMPI; make clean && make COMPILER=GNU'" >&2; exit 1; }
mkdir -p "$OUT_DIR"
echo "job $SLURM_JOB_ID on $SLURM_JOB_NODELIST, results -> $OUT_DIR"

# Topology and placement sanity check at the top of the job log: four ranks
# with 32 cores each should land on four distinct NUMA domains / two packages.
lscpu | grep -E 'Model name|^CPU\(s\)|Socket|Thread|NUMA'
OMP_NUM_THREADS=32 mpirun -np 4 --map-by slot:PE=32 --bind-to core --report-bindings true 2>&1 | head -4

"$here/baseline.sh" "${1:-$here/matrix.cluster}"
echo "done: $OUT_DIR/summary.txt"
