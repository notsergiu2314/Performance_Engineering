#!/bin/bash
#SBATCH -J m3_numa
#SBATCH -p cn-ib
#SBATCH -N 1
#SBATCH --exclusive
#SBATCH -t 00:40:00
#SBATCH -o perf/results/%x_%j.log
# Why is 1 rank x 128 threads slower than 4 ranks x 32 threads, and how much
# DRAM traffic does each really move? Every run is wrapped in system-wide DDR
# controller counters (perf stat -a), so we get per-NUMA-domain traffic and
# the node's bandwidth next to the wall clock.
#   A  1x128 default            baseline (traffic was 14/20/38/36 % per domain)
#   B  1x128 numactl --interleave=all   forces balanced controllers
#   C  1x120                    8 cores left idle: jitter / oversubscription test
#   D  4x32  (MPI)              reference: one rank per NUMA domain
# Submit from the repository root: sbatch perf/jobs/m3_numa.sbatch
set -uo pipefail
source "$SLURM_SUBMIT_DIR/perf/jobs/common.sh"

OUT="$PERF_ROOT/results/m3_numa_$SLURM_JOB_ID"
BIN="$PERF_ROOT/bin/clover_base"
DECK=bm3840
REPS="${REPS:-3}"
record_system "$OUT"

DDRC="$(ddrc_events)"
if [ -z "$DDRC" ]; then echo "no DDRC events visible to perf; aborting"; exit 1; fi
STAT="perf stat -a -e $DDRC -x,"

for rep in $(seq 1 "$REPS"); do
  d="$OUT/A_1x128_default/rep$rep"; mkdir -p "$d"
  run_clover "$BIN" "$DECK" 1x128 "$d" $STAT -o "$d/perf_stat.csv"

  d="$OUT/B_1x128_interleave/rep$rep"; mkdir -p "$d"
  run_clover "$BIN" "$DECK" 1x128 "$d" $STAT -o "$d/perf_stat.csv" numactl --interleave=all

  d="$OUT/C_1x120/rep$rep"; mkdir -p "$d"
  run_clover "$BIN" "$DECK" 1x120 "$d" $STAT -o "$d/perf_stat.csv"

  d="$OUT/D_4x32_mpi/rep$rep"; mkdir -p "$d"
  OUTER_PREFIX="$STAT -o $d/perf_stat.csv" run_clover "$BIN" "$DECK" 4x32 "$d"
done

for d in "$OUT"/*/rep1; do
  echo "=== $(basename "$(dirname "$d")") (rep1)"
  python3 "$PERF_ROOT/analysis/ddrc_summary.py" "$d/perf_stat.csv" --model-bytes 2.80e12
done > "$OUT/summary.txt" 2>&1
echo "=== wall clock per variant (s)" >> "$OUT/summary.txt"
for v in "$OUT"/*/; do
  printf '%-22s' "$(basename "$v")" >> "$OUT/summary.txt"
  for r in "$v"rep*/; do
    grep -h "Wall clock" "$r/clover.out" | tail -1 | awk '{printf " %8.2f", $NF}' >> "$OUT/summary.txt"
  done
  echo >> "$OUT/summary.txt"
done
cat "$OUT/summary.txt"
