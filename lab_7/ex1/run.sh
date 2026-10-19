#!/bin/bash
# Lab 7 ex1 driver: runs every case under `perf stat` and stores one CSV per run in $OUT.
# Runs unchanged inside a Slurm allocation (see run.sbatch) or on any machine with perf.
# Knobs (environment, all optional):
#   BIN     directory with the variant binaries (bin)
#   OUT     output directory (results/<timestamp>)
#   TRIALS  repetitions of every perf run, the summary takes the median (3)
#   PERF    perf command; empty = run without counters, timing only
#   CPU     core the benchmark is pinned to with taskset (2)
#   EVGROUPS newline-separated perf event lists; <= 5 programmable counters + cycles each, so
#           the ARM PMU (6 counters) does not multiplex
#   CASES   newline-separated "<variant> <count> <reps>"; every (variant,count) is also run
#           with reps=0 (allocate + initialise only) as the baseline that summarize.py subtracts
# Files: $OUT/<variant>.<count>.<reps>.t<trial>.g<group>.csv (perf -x,) and .out (benchmark line).
set -euo pipefail
BIN=${BIN:-bin}
OUT=${OUT:-results/$(date +%Y%m%d_%H%M%S)}
TRIALS=${TRIALS:-3}
PERF=${PERF-perf}
CPU=${CPU:-2}
EVGROUPS=${EVGROUPS:-"task-clock,cycles,instructions,L1-dcache-loads,L1-dcache-load-misses,l2d_cache_refill,dTLB-load-misses
task-clock,cycles,l2d_cache,ll_cache_rd,ll_cache_miss_rd,stall_backend,branch-misses"}
CASES=${CASES:-"small_base 16384 2000
small_opt 16384 2000
small_base 1048576 20
small_opt 1048576 20
big_base 16384 4
big_opt 16384 4"}

mkdir -p "$OUT"
{
  echo "host=$(hostname)"; echo "date=$(date -Is)"; echo "cpu=$CPU"; echo "trials=$TRIALS"
  echo "perf=$PERF"; echo "evgroups:"; echo "$EVGROUPS"; echo "cases:"; echo "$CASES"
  echo "lscpu:"; lscpu | grep -E 'Model name|^CPU\(s\)|L1d|L2|L3|Architecture' || true
  echo "pagesize=$(getconf PAGESIZE)"
} > "$OUT/meta.txt"

run_one() {  # variant count reps trial group-index events
  local v=$1 c=$2 r=$3 t=$4 gi=$5 ev=$6
  local tag="$OUT/$v.$c.$r.t$t.g$gi"
  if [ -n "$PERF" ]; then
    taskset -c "$CPU" $PERF stat -x, -o "$tag.csv" -e "$ev" -- "$BIN/$v" "$c" "$r" > "$tag.out"
  else
    taskset -c "$CPU" "$BIN/$v" "$c" "$r" > "$tag.out"
  fi
  echo "[$(date +%T)] $(cat "$tag.out")"
}

while read -r v c r; do
  [ -z "${v:-}" ] && continue
  for reps in 0 "$r"; do
    for t in $(seq 1 "$TRIALS"); do
      gi=0
      while IFS= read -r ev; do
        [ -z "$ev" ] && continue
        gi=$((gi + 1))
        run_one "$v" "$c" "$reps" "$t" "$gi" "$ev"
        [ -z "$PERF" ] && break
      done <<< "$EVGROUPS"
    done
  done
done <<< "$CASES"
echo "done: $OUT"
