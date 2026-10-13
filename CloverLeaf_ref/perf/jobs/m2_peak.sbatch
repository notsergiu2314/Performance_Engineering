#!/bin/bash
#SBATCH -J m2_peak
#SBATCH -p cn-ib
#SBATCH -N 1
#SBATCH --exclusive
#SBATCH -t 00:30:00
#SBATCH -o perf/results/%x_%j.log
# M2: attainable floating-point throughput (roofline compute ceilings).
# Submit from the repository root: sbatch perf/jobs/m2_peak.sbatch
set -uo pipefail
source "$SLURM_SUBMIT_DIR/perf/jobs/common.sh"

OUT="$PERF_ROOT/results/m2_peak_$SLURM_JOB_ID"
record_system "$OUT"

SRC="$PERF_ROOT/microbench/peak_flops.c"
FLAGS="-O3 -mcpu=native -fno-tree-vectorize -fopenmp"
gcc $FLAGS "$SRC" -o "$OUT/peak_flops" -lm
gcc $FLAGS -S "$SRC" -o "$OUT/peak_flops.s"
# The vector kernels must use fmla/fmul/fdiv on v*.2d registers:
grep -cE 'fmla\s+v[0-9]+\.2d' "$OUT/peak_flops.s" | sed 's/^/fmla .2d instructions: /' | tee "$OUT/asm_check.txt"
# Inner loop of the 8-accumulator FMA kernels, for the report (and to check that
# vacc has fmla only, while vfma needs extra register copies):
for k in vacc_8 vfma_8; do awk -v k="^$k:" '$0 ~ k, /ret/' "$OUT/peak_flops.s" > "$OUT/asm_$k.txt"; done

for t in 1 32 64 128; do
  OMP_NUM_THREADS=$t "$OUT/peak_flops" > "$OUT/peak_${t}.csv"
done
head -1 "$OUT/peak_1.csv" > "$OUT/peak.csv"
tail -q -n +2 "$OUT"/peak_[0-9]*.csv >> "$OUT/peak.csv"
column -s, -t "$OUT/peak.csv"
