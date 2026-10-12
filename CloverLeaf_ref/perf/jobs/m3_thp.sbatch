#!/bin/bash
#SBATCH -J m3_thp
#SBATCH -p cn-ib
#SBATCH -N 1
#SBATCH --exclusive
#SBATCH -t 00:40:00
#SBATCH -o perf/results/%x_%j.log
# Hypothesis (m3_numa): with THP=always and 512 MB huge pages, CloverLeaf's
# arrays are placed in a few huge pages, each wholly on one NUMA domain, so
# the 1x128 OpenMP run is unbalanced and partly remote. Disable THP for the
# process only (microbench/nothp.c) and compare, with DDR counters around it.
#   A  1x128 default          control, same session
#   E  1x128 nothp            the test
#   D  4x32  default          reference
#   F  4x32  nothp            does it matter for MPI+OpenMP?
# Submit from the repository root: sbatch perf/jobs/m3_thp.sbatch
set -uo pipefail
source "$SLURM_SUBMIT_DIR/perf/jobs/common.sh"

OUT="$PERF_ROOT/results/m3_thp_$SLURM_JOB_ID"
BIN="$PERF_ROOT/bin/clover_base"
DECK=bm3840
REPS="${REPS:-3}"
record_system "$OUT"
{
  echo "== THP"; cat /sys/kernel/mm/transparent_hugepage/enabled
  echo "== pagesize"; getconf PAGESIZE
} >> "$OUT/system.txt"

gcc -O2 "$PERF_ROOT/microbench/nothp.c" -o "$OUT/nothp" || exit 1
NOTHP="$OUT/nothp"
export NOTHP_VERBOSE=1

DDRC="$(ddrc_events)"
if [ -z "$DDRC" ]; then echo "no DDRC events visible to perf; aborting"; exit 1; fi
STAT="perf stat -a -e $DDRC -x,"

for rep in $(seq 1 "$REPS"); do
  d="$OUT/A_1x128_default/rep$rep"; mkdir -p "$d"
  run_clover "$BIN" "$DECK" 1x128 "$d" $STAT -o "$d/perf_stat.csv"

  d="$OUT/E_1x128_nothp/rep$rep"; mkdir -p "$d"
  run_clover "$BIN" "$DECK" 1x128 "$d" $STAT -o "$d/perf_stat.csv" "$NOTHP"

  d="$OUT/D_4x32_default/rep$rep"; mkdir -p "$d"
  OUTER_PREFIX="$STAT -o $d/perf_stat.csv" run_clover "$BIN" "$DECK" 4x32 "$d"

  d="$OUT/F_4x32_nothp/rep$rep"; mkdir -p "$d"
  OUTER_PREFIX="$STAT -o $d/perf_stat.csv" run_clover "$BIN" "$DECK" 4x32 "$d" "$NOTHP"
done

for d in "$OUT"/*/rep1; do
  echo "=== $(basename "$(dirname "$d")") (rep1)"
  python3 "$PERF_ROOT/analysis/ddrc_summary.py" "$d/perf_stat.csv" --model-bytes 2.80e12
done > "$OUT/summary.txt" 2>&1
echo "=== wall clock per variant (s)" >> "$OUT/summary.txt"
for v in "$OUT"/*/; do
  [ -d "$v/rep1" ] || continue
  printf '%-22s' "$(basename "$v")" >> "$OUT/summary.txt"
  for r in "$v"rep*/; do
    grep -h "Wall clock" "$r/clover.out" | tail -1 | awk '{printf " %8.2f", $NF}' >> "$OUT/summary.txt"
  done
  echo >> "$OUT/summary.txt"
done
grep -h "nothp" "$OUT"/E_*/rep1/stdout.txt | head -2 >> "$OUT/summary.txt"
cat "$OUT/summary.txt"
