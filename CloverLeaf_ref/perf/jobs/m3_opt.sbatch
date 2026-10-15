#!/bin/bash
#SBATCH -J m3_opt
#SBATCH -p cn-ib
#SBATCH -N 1
#SBATCH --exclusive
#SBATCH --ntasks-per-node=128
#SBATCH --cpus-per-task=1
#SBATCH -t 01:00:00
#SBATCH -o perf/results/%x_%j.log
# Optimised C kernels against the baseline, one node, one allocation (so node-to-node
# variation cancels): (1) the commit ladder of perf/variants.conf at the baseline layout 64x2
# (perf/baseline/matrix.ladder) for per-change bytes and time; (2) base and opt at the five
# M3 layouts, THP on, plus 1x128 THP off (matrix.layouts). Every row REPS times under the
# DDR-controller counters (hardware bytes). Binaries: perf/bin/clover_<variant> from
# perf/build.sh. Ends with analysis/variants.py: optimised.csv, ladder.csv, compare.md.
# Knobs: LADDER ("base flags cell mom opt"), VARIANTS ("base opt"), REPS (5),
# STREAM_HW_GBS (266.5, hardware STREAM ceiling of job 34795), DDRC (auto|off),
# QA (correctness_rows.csv of an m3_correctness job: fills the qa_ok column).
# Submit from CloverLeaf_ref: sbatch perf/jobs/m3_opt.sbatch   (~25 min)
set -eo pipefail
source "$SLURM_SUBMIT_DIR/perf/jobs/common.sh"
set -u
OUT="$PERF_ROOT/results/m3_opt_$SLURM_JOB_ID"
LADDER="${LADDER:-base flags cell mom opt}"
VARIANTS="${VARIANTS:-base opt}"
export REPS="${REPS:-5}" STREAM_HW_GBS="${STREAM_HW_GBS:-266.5}"

for v in $LADDER $VARIANTS; do
  [ -x "$PERF_ROOT/bin/clover_$v" ] || { echo "missing perf/bin/clover_$v: export_variants.sh locally, rsync, then 'srun -p cn-ib -N 1 bash perf/build.sh'" >&2; exit 1; }
done
prepare_harness "$OUT"
echo "job $SLURM_JOB_ID on $SLURM_JOB_NODELIST: ladder [$LADDER] at 64x2, layouts [$VARIANTS], $REPS reps -> $OUT"
lscpu | grep -E 'Model name|^CPU\(s\)|Socket|Thread|NUMA'
OMP_NUM_THREADS=32 mpirun -np 4 --map-by slot:PE=32 --bind-to core --report-bindings true 2>&1 | head -4

run_variant() {   # run_variant <variant> <matrix file> <out dir>
  echo; echo "#### variant $1, matrix $(basename "$2") -> $3"
  CLOVER_BIN="$PERF_ROOT/bin/clover_$1" VARIANT="$1" OUT_DIR="$3" bash "$PERF_ROOT/baseline/baseline.sh" "$2"
}
for v in $LADDER;   do run_variant "$v" "$PERF_ROOT/baseline/matrix.ladder" "$OUT/ladder/$v"; done
for v in $VARIANTS; do run_variant "$v" "$PERF_ROOT/baseline/matrix.layouts"    "$OUT/layouts/$v"; done

echo; echo "#### comparison"
python3 -I "$PERF_ROOT/analysis/variants.py" --run "$OUT" --stream-hw-gbs "$STREAM_HW_GBS" ${QA:+--qa "$QA"}
echo "done: $OUT/compare.md  optimised.csv  ladder.csv   (archive with perf/archive.sh $OUT)"
