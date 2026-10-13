#!/bin/bash
# Lab 6, exercise 1: STREAM bandwidth vs. threads (a) and vs. OMP_PROC_BIND (b).
# Runs on one (exclusive) node; called by ex1_stream.sbatch, or by hand:
#   REPS=1 TLIST="1 4" SIZES="1024" THPS=on ./run_ex1.sh      # quick local test
#
# Output: $OUT/stream.csv    one row per measured operation and run
#         $OUT/affinity.csv  thread -> cpu maps (first repetition of each config)
#         $OUT/system.txt    node description
#
# THP: HAICGU runs 64 KB pages with THP=always, i.e. 512 MB huge pages, so first
# touch places data at 512 MB granularity. Every configuration is therefore run
# with THP default ("on") and disabled for the process tree ("off", nothp).
set -o pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

OUT="${OUT:-$HERE/results/ex1_${SLURM_JOB_ID:-local}}"
REPS="${REPS:-5}"
TLIST="${TLIST:-1 2 4 8 12 16 24 32 48 64 96 128}"       # scaling experiment
BTLIST="${BTLIST:-8 16 32 64 128}"                        # binding experiment
SIZES="${SIZES:-1024 4194304 100000000}"                  # L1D / 2^22 / 800 MB per array
THPS="${THPS:-off on}"
BINDS="${BINDS:-false true master close spread}"
PLACES="${PLACES:-cores}"
mkdir -p "$OUT/raw"

# ---- build ------------------------------------------------------------------
if [ "$(uname -m)" = aarch64 ]; then ARCH=-mcpu=native; else ARCH=-march=native; fi
BIN="$OUT/stream_omp"
gcc -O3 -fopenmp $ARCH stream_omp.c -o "$BIN" || exit 1
NOTHP="$OUT/nothp"
if [ -f nothp.c ] && gcc -O2 nothp.c -o "$NOTHP" 2> /dev/null; then :; else
  echo "no nothp launcher (not Linux?): THP=off runs are skipped"
  THPS="${THPS//off/}"
fi

# ---- system description -------------------------------------------------------
{
  echo "== date";      date
  echo "== hostname";  hostname
  echo "== uname";     uname -a
  echo "== gcc";       gcc --version | head -1
  echo "== lscpu";     lscpu 2>&1
  echo "== numactl";   numactl --hardware 2>&1
  echo "== meminfo";   head -3 /proc/meminfo 2>&1
  echo "== THP";       cat /sys/kernel/mm/transparent_hugepage/enabled 2>&1
  echo "== pagesize";  getconf PAGESIZE 2>&1
  echo "== cpufreq";   cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor \
                           /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>&1
  echo "== modules";   module -t list 2>&1
  echo "== settings";  echo "REPS=$REPS TLIST=$TLIST BTLIST=$BTLIST SIZES=$SIZES THPS=$THPS BINDS=$BINDS PLACES=$PLACES"
} > "$OUT/system.txt" 2>&1

CSV="$OUT/stream.csv"
AFF="$OUT/affinity.csv"
echo "exp,thp,bind,places,threads,n,rep,kernel,reps,ntimes,bytes,tmin_s,tavg_s,tmax_s" > "$CSV"
echo "exp,thp,bind,threads,n,when,cpus" > "$AFF"
: > "$OUT/failures.txt"

# samples per run: small arrays are cheap, big ones are not
ntimes() { if [ "$1" -le 65536 ]; then echo 100; elif [ "$1" -le 16777216 ]; then echo 50; else echo 20; fi; }

# run_one <exp> <thp> <bind> <threads> <n> <rep>
run_one() {
  local exp="$1" thp="$2" bind="$3" t="$4" n="$5" rep="$6"
  local raw="$OUT/raw/${exp}_${thp}_${bind}_${t}_${n}_${rep}.txt"
  local pre=""
  [ "$thp" = off ] && pre="$NOTHP"
  OMP_NUM_THREADS="$t" OMP_PROC_BIND="$bind" OMP_PLACES="$PLACES" \
    $pre "$BIN" "$n" "$(ntimes "$n")" 60 > "$raw" 2>&1
  local rc=$?
  if [ $rc -ne 0 ]; then
    echo "FAILED rc=$rc $exp thp=$thp bind=$bind t=$t n=$n rep=$rep" >> "$OUT/failures.txt"
    return
  fi
  awk -F, -v p="$exp,$thp,$bind,$PLACES,$t,$n,$rep" \
      '!/^#/ && NF==9 {print p "," $1 "," $4 "," $5 "," $6 "," $7 "," $8 "," $9}' "$raw" >> "$CSV"
  if [ "$rep" = 1 ]; then
    awk -v p="$exp,$thp,$bind,$t,$n" \
        '/^# cpus_start:/ {sub(/^# cpus_start: */,""); print p ",start,\"" $0 "\""}
         /^# cpus_end:/   {sub(/^# cpus_end: */,"");   print p ",end,\""   $0 "\""}' "$raw" >> "$AFF"
  fi
  rm -f "$raw"
}

# Repetition is the outermost loop so that slow drifts of the node (other
# users' traffic on the fabric, thermal state) do not bias one configuration.
for rep in $(seq 1 "$REPS"); do
  echo "=== repetition $rep / $REPS  ($(date +%T))"
  for thp in $THPS; do
    for n in $SIZES; do
      # (a) bandwidth vs. number of threads: threads packed on consecutive cores
      #     ("close") and spread over the sockets / NUMA domains ("spread")
      for bind in close spread; do
        for t in $TLIST; do run_one scaling "$thp" "$bind" "$t" "$n" "$rep"; done
      done
      # (b) the five OMP_PROC_BIND settings at large thread counts
      for bind in $BINDS; do
        for t in $BTLIST; do run_one bind "$thp" "$bind" "$t" "$n" "$rep"; done
      done
    done
  done
done
echo "done: $(($(wc -l < "$CSV") - 1)) rows in $CSV, $(wc -l < "$OUT/failures.txt") failures"
