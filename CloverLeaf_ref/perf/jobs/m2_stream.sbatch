#!/bin/bash
#SBATCH -J m2_stream
#SBATCH -p cn-ib
#SBATCH -N 1
#SBATCH --exclusive
#SBATCH -t 01:30:00
#SBATCH -o perf/results/%x_%j.log
# M2: attainable memory bandwidth (roofline memory ceiling) with STREAM.
#  - array size: 100M doubles = 800 MB per array, > 4x all caches of the node
#    (2 x 64 MB L3 + 128 x 512 KB L2), as the STREAM rules require
#  - thread sweep with close binding: saturation of one NUMA domain
#    (32 cores, 4 DDR4-2666 channels = 85.3 GB/s theoretical) and then
#    of 2, 3 and 4 domains (node theoretical peak 2 x 170.6 GB/s)
#  - one run per NUMA domain (numactl) to compare the domains
#  - optional: DDR controller counters during STREAM, to calibrate them
#    against a known byte count before using them on CloverLeaf
# Submit from the repository root: sbatch perf/jobs/m2_stream.sbatch
set -uo pipefail
source "$SLURM_SUBMIT_DIR/perf/jobs/common.sh"

OUT="$PERF_ROOT/results/m2_stream_$SLURM_JOB_ID"
REPS="${REPS:-10}"
N="${STREAM_N:-100000000}"
NTIMES="${STREAM_NTIMES:-20}"
SRC="$PERF_ROOT/microbench/STREAM"
record_system "$OUT"

[ -f "$SRC/stream.c" ] || git clone --depth 1 https://github.com/jeffhammond/STREAM.git "$SRC"
gcc -O3 -mcpu=native -fopenmp -DSTREAM_ARRAY_SIZE="$N" -DNTIMES="$NTIMES" \
  "$SRC/stream.c" -o "$OUT/stream"

CSV="$OUT/stream.csv"
echo "config,threads,rep,copy_MBs,scale_MBs,add_MBs,triad_MBs" > "$CSV"
stream_row() {   # stream_row <config> <threads> <rep> <cmd...>
  local cfg="$1" t="$2" rep="$3"; shift 3
  OMP_NUM_THREADS="$t" "$@" > "$OUT/raw_${cfg}_${t}_${rep}.txt" 2>&1
  awk -v c="$cfg" -v t="$t" -v r="$rep" '
    /^Copy:/  {cp=$2} /^Scale:/ {sc=$2} /^Add:/ {ad=$2} /^Triad:/ {tr=$2}
    END {print c "," t "," r "," cp "," sc "," ad "," tr}' \
    "$OUT/raw_${cfg}_${t}_${rep}.txt" >> "$CSV"
}

# Thread sweep over the whole node (fills NUMA domain 0, then 1, ...).
for t in 1 2 4 8 16 24 32 48 64 96 128; do
  for rep in $(seq 1 "$REPS"); do
    stream_row node "$t" "$rep" "$OUT/stream"
  done
done

# Same thread count, but spread over all domains (bandwidth per thread when
# every memory controller is used).
for t in 4 8 16 32 64; do
  for rep in $(seq 1 "$REPS"); do
    OMP_PROC_BIND=spread stream_row spread "$t" "$rep" "$OUT/stream"
  done
done

# Each NUMA domain on its own, memory bound to the same domain.
for node in $(numactl --hardware | awk '/^node [0-9]+ cpus:/ {print $2}'); do
  for rep in $(seq 1 "$REPS"); do
    stream_row "numa$node" 32 "$rep" numactl --cpunodebind="$node" --membind="$node" "$OUT/stream"
  done
done

# DDRC calibration. STREAM moves (per timed iteration) 2+2+3+3 = 10 arrays
# of N doubles as counted by STREAM; with write-allocate the 4 stores add
# 4 more arrays of reads. Initialisation and validation add a few more
# passes, so compare against the ratio, not the absolute number.
DDRC="$(ddrc_events)"
if [ -n "$DDRC" ]; then
  OMP_NUM_THREADS=128 perf stat -a -e "$DDRC" -x, -o "$OUT/ddrc_stream.csv" "$OUT/stream" \
    > "$OUT/ddrc_stream_stdout.txt" 2>&1
  awk -v n="$N" -v nt="$NTIMES" 'BEGIN {
    printf "STREAM-counted bytes (timed loop): %.3e\n", nt*10*n*8
    printf "with write-allocate:               %.3e\n", nt*14*n*8 }' > "$OUT/ddrc_expected.txt"
fi

python3 "$PERF_ROOT/analysis/stream_summary.py" "$CSV" | tee "$OUT/summary.txt"
