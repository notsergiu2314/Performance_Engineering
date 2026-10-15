#!/bin/bash
# Run one configuration REPS times and record results.
# usage: run_case.sh KERNELS RANKS THREADS [DECK] [THP]
#   KERNELS: fortran | c      DECK: file name in $DECK_DIR (default clover_bm_short.in)
#   THP: on (default) | off   off runs every rank under $NOTHP (perf/microbench/nothp.c),
#        which disables transparent huge pages for the process tree; the tag gets "_thpoff".
# When DDRC_EVENTS is set (comma-separated hisi_sccl*_ddrc*/flux_* events, see
# jobs/common.sh ddrc_events) every repetition runs under system-wide `perf stat -a`
# and the DRAM bytes moved are recorded next to the wall time.
# Output (under $OUT_DIR):
#   results.csv              one row per repetition (last column: build variant, lib.sh VARIANT)
#   profiler.csv             one row per profiler section per repetition
#   <tag>/rep<i>.out         full clover.out of every repetition
#   <tag>/rep<i>.log         mpirun stdout/stderr, including the core bindings
#   <tag>/rep<i>.ddrc.csv    perf stat output of the DDR-controller counters (if enabled)
#   <tag>/clover.in          the deck actually run
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

[ $# -ge 3 ] || { sed -n 2,7p "$0"; exit 1; }
kernels=$1 ranks=$2 threads=$3 deck=${4:-clover_bm_short.in} thp=${5:-on}
thp=${thp#thp=}
[ -x "$CLOVER_BIN" ] || die "binary not found/executable: $CLOVER_BIN"
[ -f "$DECK_DIR/$deck" ] || die "deck not found: $DECK_DIR/$deck"

tag="${deck%.in}_${kernels}_r${ranks}_t${threads}"
case $thp in
  on) ;;
  off) [ -x "${NOTHP:-}" ] || die "THP off requested but NOTHP is not an executable launcher (build perf/microbench/nothp.c)"
       LAUNCH_PREFIX="$LAUNCH_PREFIX $NOTHP"; tag="${tag}_thpoff" ;;
  *) die "THP must be on or off, got '$thp'" ;;
esac
case_dir=$OUT_DIR/$tag
mkdir -p "$case_dir"
make_deck "$DECK_DIR/$deck" "$case_dir/clover.in" "$kernels"
export PROF_DIR=$case_dir          # where a PAPI build (clover_papi) writes papi_prof_<pid>.csv

hdr="tag,deck,kernels,ranks,threads,thp,rep,wall,grind,first_step,qa_pct,qa,kernels_reported,dram_GB,busiest_over_mean,host,date,variant"
[ -f "$OUT_DIR/results.csv" ] || echo "$hdr" > "$OUT_DIR/results.csv"
[ -f "$OUT_DIR/profiler.csv" ] || echo "tag,rep,section,time,pct" > "$OUT_DIR/profiler.csv"

cd "$case_dir"
for i in $(seq 1 "$REPS"); do
  rm -f clover.out clover.in.tmp "rep$i.ddrc.csv"
  outer=$OUTER_PREFIX
  [ -n "${DDRC_EVENTS:-}" ] && outer="$OUTER_PREFIX perf stat -a -e $DDRC_EVENTS -x, -o rep$i.ddrc.csv"
  OUTER_PREFIX=$outer launch "$ranks" "$threads" "$CLOVER_BIN" > "rep$i.log" 2>&1 || echo "  warning: mpirun exit $? (see $case_dir/rep$i.log)" >&2
  [ -f clover.out ] || { echo "  rep $i: no clover.out produced" >&2; continue; }
  mv clover.out "rep$i.out"
  read -r wall grind first qa passed kern < <(parse_out "rep$i.out")
  read -r dram busiest < <(parse_ddrc "rep$i.ddrc.csv")
  echo "$tag,$deck,$kernels,$ranks,$threads,$thp,$i,$wall,$grind,$first,$qa,$passed,$kern,$dram,$busiest,$(hostname),$(date -Is),$VARIANT" >> "$OUT_DIR/results.csv"
  parse_profiler "rep$i.out" | sed "s/^/$tag,$i,/" >> "$OUT_DIR/profiler.csv"
  printf '  %-44s rep %d  wall=%-8.3f grind=%s  qa=%s %s  dram=%s GB  (%s kernels)\n' "$tag" "$i" "$wall" "$grind" "$qa" "$passed" "$dram" "$kern"
done
rm -f clover.in.tmp
