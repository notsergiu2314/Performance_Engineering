#!/bin/bash
#SBATCH -J m3_correctness
#SBATCH -p cn-ib
#SBATCH -N 1
#SBATCH --exclusive
#SBATCH --ntasks-per-node=128
#SBATCH --cpus-per-task=1
#SBATCH -t 01:00:00
#SBATCH -o perf/results/%x_%j.log
# Correctness gate for every build variant (perf/variants.conf): clover_bm.in (960^2, 2955
# steps) and the reported kinetic-energy deviation compared with the baseline deviation in
# perf/archive/m3/correctness_baseline.csv (qa_check.py, deterministic: job 34729 gave the
# same digits at 128x1 and 4x32). "opt" and "base" run the full perf/baseline/matrix.correctness
# (M3 layouts, THP off, Fortran reference); the intermediate variants run its C 64x2 row.
# A mismatch is recorded (gate column), it does not abort the job: the verdict is data.
# Output: $OUT/<variant>/ (harness output + qa_check.txt), $OUT/qa_check.txt (all variants),
# $OUT/correctness_rows.csv (report/data/correctness.csv format + variant,gate).
# Knobs: VARIANTS ("opt flags cell mom"), FULL ("base opt optnf": the variants that run the whole
# matrix.correctness, the others only its C 64x2 row), BASELINE (the csv above), TOL (1e-6 %).
# Submit from CloverLeaf_ref: sbatch perf/jobs/m3_correctness.sbatch   (~25 min)
set -eo pipefail
source "$SLURM_SUBMIT_DIR/perf/jobs/common.sh"
set -u
OUT="$PERF_ROOT/results/m3_correctness_$SLURM_JOB_ID"
VARIANTS="${VARIANTS:-opt flags cell mom}"
FULL="${FULL:-base opt optnf}"
BASELINE="${BASELINE:-$PERF_ROOT/archive/m3/correctness_baseline.csv}"
TOL="${TOL:-1e-6}"
export REPS=1 DDRC=off

for v in $VARIANTS; do
  [ -x "$PERF_ROOT/bin/clover_$v" ] || { echo "missing perf/bin/clover_$v: run 'srun -p cn-ib -N 1 bash perf/build.sh'" >&2; exit 1; }
done
prepare_harness "$OUT"
full="$PERF_ROOT/baseline/matrix.correctness"
grep -E '^c[[:space:]]+64[[:space:]]+2[[:space:]]+[^[:space:]]+[[:space:]]+on' "$full" > "$OUT/matrix.correctness.64x2"
echo "job $SLURM_JOB_ID on $SLURM_JOB_NODELIST: variants [$VARIANTS], tol $TOL % -> $OUT"

rows="$OUT/correctness_rows.csv"
bad=0
for v in $VARIANTS; do
  case " $FULL " in *" $v "*) m=$full ;; *) m="$OUT/matrix.correctness.64x2" ;; esac
  echo; echo "#### variant $v, matrix $(basename "$m")"
  CLOVER_BIN="$PERF_ROOT/bin/clover_$v" VARIANT="$v" OUT_DIR="$OUT/$v" bash "$PERF_ROOT/baseline/baseline.sh" "$m"
  echo "== qa_check $v against $BASELINE"
  if python3 -I "$PERF_ROOT/baseline/qa_check.py" "$OUT/$v/results.csv" "$BASELINE" --tol "$TOL" \
       --csv "$rows" --source "job $SLURM_JOB_ID (m3_correctness)" > "$OUT/$v/qa_check.txt" 2>&1
  then echo "variant $v: gate ok"
  else echo "variant $v: gate MISMATCH (see $OUT/$v/qa_check.txt)"; bad=$((bad + 1)); fi
  { echo "=== $v"; cat "$OUT/$v/qa_check.txt"; } | tee -a "$OUT/qa_check.txt"
done
echo; echo "$bad of $(wc -w <<< "$VARIANTS") variants fail the gate; rows in $rows (pass QA=$rows to m3_opt.sbatch)"
