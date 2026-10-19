#!/bin/bash
#SBATCH -J m1_perf
#SBATCH -p cn-ib
#SBATCH -N 1
#SBATCH --exclusive
#SBATCH -t 01:30:00
#SBATCH -o perf/results/%x_%j.log
# M1: Linux perf, the second, independent tool.
#  1. perf record  -> sampled hot spots per function (OpenMP outlined bodies are
#     named <kernel>_kernel_c_._omp_fn.N, so samples map onto kernels)
#  2. perf annotate -> instruction mix of the hottest kernels (NEON or scalar?)
#  3. perf stat    -> whole-run counters, cross-check against PAPI totals
#  4. DDR controller uncore counters (if exposed) -> measured DRAM traffic
# Submit from the repository root: sbatch perf/jobs/m1_perf.sbatch
set -uo pipefail
source "$SLURM_SUBMIT_DIR/perf/jobs/common.sh"

OUT="$PERF_ROOT/results/m1_perf_$SLURM_JOB_ID"
BIN="$PERF_ROOT/bin/clover_base"
DECK=bm3840
record_system "$OUT"
perf --version > "$OUT/perf_version.txt" 2>&1
perf list > "$OUT/perf_list.txt" 2>&1

# Keep only the events this kernel/PMU actually knows, so perf stat never
# aborts on an unknown name.
WANTED="cycles instructions task-clock L1-dcache-loads L1-dcache-load-misses \
stall_backend stall_frontend l2d_cache l2d_cache_refill l2d_cache_wb \
mem_access bus_access inst_spec ase_spec vfp_spec ld_spec st_spec br_mis_pred"
EVENTS=""
for e in $WANTED; do
  if perf stat -e "$e" -x, -- true > /dev/null 2>&1; then EVENTS="$EVENTS${EVENTS:+,}$e"; fi
done
echo "perf stat events: $EVENTS" | tee "$OUT/events.txt"

for cfg in 1x1 1x64 1x128; do
  d="$OUT/record_$cfg"
  run_clover "$BIN" "$DECK" "$cfg" "$d" perf record -F 999 -o "$d/perf.data"
  perf report -i "$d/perf.data" --stdio --no-children --sort symbol \
    --percent-limit 0.3 > "$d/report.txt" 2>&1
  # Annotated assembly for the five hottest symbols.
  grep -E '^\s+[0-9.]+%' "$d/report.txt" | head -5 | awk '{print $NF}' | while read -r sym; do
    perf annotate -i "$d/perf.data" --stdio -s "$sym" > "$d/annotate_${sym//[^A-Za-z0-9_]/_}.txt" 2>&1
  done

  d="$OUT/stat_$cfg"
  run_clover "$BIN" "$DECK" "$cfg" "$d" perf stat -e "$EVENTS" -x, -o "$d/perf_stat.csv"
done

# DRAM traffic from the HiSilicon DDR controller PMU. Needs system-wide mode
# (-a), i.e. perf_event_paranoid <= 0; otherwise this just logs the error.
DDRC="$(ddrc_events)"
echo "ddrc events: ${DDRC:-none}" | tee -a "$OUT/events.txt"
if [ -n "$DDRC" ]; then
  d="$OUT/ddrc_1x128"
  run_clover "$BIN" "$DECK" 1x128 "$d" perf stat -a -e "$DDRC" -x, -o "$d/perf_stat.csv"
fi
