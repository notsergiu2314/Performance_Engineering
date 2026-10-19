#!/bin/bash
#SBATCH -J m3_stream_ddrc
#SBATCH -p cn-ib
#SBATCH -N 1
#SBATCH --exclusive
#SBATCH --ntasks-per-node=128
#SBATCH --cpus-per-task=1
#SBATCH -t 00:45:00
#SBATCH -o perf/results/%x_%j.log
# M3 prerequisite: settle the write-allocate question and fix the hardware memory
# ceiling (comparison report, point 1).
#   * STREAM at 128 threads, close-bound, with THP disabled for the process (nothp) so the
#     arrays are first-touched evenly over the four NUMA domains: this is the best-case run
#     that gave 267 GB/s (STREAM-counted) in M2. Every repetition runs under system-wide
#     DDR-controller counters, so the hardware bytes of the same run are known.
#   * the same with THP on (the M2 default, median 135 GB/s) for contrast
#   * membw (perf/microbench/membw.c, the M2 jort ceiling of 263 GB/s) under nothp + DDRC
#   * every way of reading the DIMM speed that might work without root (dmidecode, lshw,
#     DMI tables, EDAC sysfs); the analysis also derives a lower bound on the DIMM speed
#     from the measured hardware bandwidth (16 channels x 8 B).
# analysis/stream_ddrc.py turns the raw files into summary.txt and ceilings_rows.csv
# (rows for report/data/ceilings.csv: dram_node_hw, wa_ratio, dimm_mts_min).
# Submit from CloverLeaf_ref: sbatch perf/jobs/m3_stream_ddrc.sbatch
set -uo pipefail
source "$SLURM_SUBMIT_DIR/perf/jobs/common.sh"

OUT="$PERF_ROOT/results/m3_stream_ddrc_$SLURM_JOB_ID"
REPS="${REPS:-10}"
N="${STREAM_N:-100000000}"          # doubles per array: 800 MB, > 4x the node's caches
NTIMES="${STREAM_NTIMES:-20}"
SRC="$PERF_ROOT/microbench/STREAM"
mkdir -p "$OUT"
record_system "$OUT"
{
  echo "== THP"; cat /sys/kernel/mm/transparent_hugepage/enabled
  echo "== pagesize"; getconf PAGESIZE
} >> "$OUT/system.txt"

# DIMM speed: all of these normally need root; whatever answers is kept.
{
  echo "== dmidecode -t 17";      dmidecode -t 17 2>&1 | grep -E 'Speed|Size|Type:|Locator|Manufacturer' | head -60
  echo "== sudo -n dmidecode";    sudo -n dmidecode -t 17 2>&1 | grep -E 'Speed|Size|Type:' | head -60
  echo "== lshw -C memory";       lshw -C memory 2>&1 | grep -E 'clock|size|description|product' | head -60
  echo "== /sys/firmware/dmi";    ls -l /sys/firmware/dmi/tables /sys/firmware/dmi/entries 2>&1 | head -8
  echo "== edac";                 for d in /sys/devices/system/edac/mc/mc*/dimm*; do
                                    [ -d "$d" ] && echo "$d: $(cat "$d/dimm_label" "$d/dimm_mem_type" "$d/size" 2>/dev/null | tr '\n' ' ')"
                                  done | head -40
  echo "== ddrc PMU events";      perf list 2>/dev/null | grep -E 'hisi_sccl[0-9]+_ddrc' | head -60
  echo "== numactl -H";           numactl -H 2>&1 | grep -E 'size' | head -8
} > "$OUT/dimm.txt" 2>&1

DDRC="$(ddrc_events)"
if [ -z "$DDRC" ]; then echo "no DDRC events visible to perf; aborting"; exit 1; fi
STAT="perf stat -a -e $DDRC -x,"

gcc -O2 "$PERF_ROOT/microbench/nothp.c" -o "$OUT/nothp" || exit 1
[ -f "$SRC/stream.c" ] || git clone --depth 1 https://github.com/jeffhammond/STREAM.git "$SRC"
gcc -O3 -mcpu=native -fopenmp -DSTREAM_ARRAY_SIZE="$N" -DNTIMES="$NTIMES" \
  "$SRC/stream.c" -o "$OUT/stream" || exit 1
gcc -O3 -march=native -funroll-loops -fopenmp -ffp-contract=fast \
  "$PERF_ROOT/microbench/membw.c" -o "$OUT/membw" -lm || exit 1

export OMP_NUM_THREADS=128 OMP_PLACES=cores OMP_PROC_BIND=close NOTHP_VERBOSE=1
echo "N=$N NTIMES=$NTIMES REPS=$REPS threads=128" > "$OUT/params.txt"

for rep in $(seq 1 "$REPS"); do
  $STAT -o "$OUT/stream_nothp_rep$rep.ddrc.csv" "$OUT/nothp" "$OUT/stream" > "$OUT/raw_stream_nothp_rep$rep.txt" 2>&1
  grep -h "^Triad:" "$OUT/raw_stream_nothp_rep$rep.txt" | sed "s/^/[nothp rep $rep] /"
done
for rep in $(seq 1 "$REPS"); do
  $STAT -o "$OUT/stream_default_rep$rep.ddrc.csv" "$OUT/stream" > "$OUT/raw_stream_default_rep$rep.txt" 2>&1
  grep -h "^Triad:" "$OUT/raw_stream_default_rep$rep.txt" | sed "s/^/[default rep $rep] /"
done
for rep in 1 2 3; do
  $STAT -o "$OUT/membw_nothp_rep$rep.ddrc.csv" "$OUT/nothp" "$OUT/membw" "$N" "$NTIMES" > "$OUT/raw_membw_nothp_rep$rep.txt" 2>&1
  grep -h "triad_gbs" "$OUT/raw_membw_nothp_rep$rep.txt" | sed "s/^/[membw nothp rep $rep] /"
done

python3 "$PERF_ROOT/analysis/stream_ddrc.py" "$OUT" --n "$N" --ntimes "$NTIMES" | tee "$OUT/summary.txt"
echo "results in $OUT (summary.txt, ceilings_rows.csv, dimm.txt)"
