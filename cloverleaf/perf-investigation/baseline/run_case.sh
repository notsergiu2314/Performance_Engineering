#!/bin/bash
# Run one configuration REPS times and record results.
# usage: run_case.sh KERNELS RANKS THREADS [DECK]
#   KERNELS: fortran | c      DECK: file name in $DECK_DIR (default clover_bm_short.in)
# Output (under $OUT_DIR):
#   results.csv              one row per repetition
#   profiler.csv             one row per profiler section per repetition
#   <tag>/rep<i>.out         full clover.out of every repetition
#   <tag>/rep<i>.log         mpirun stdout/stderr, including the core bindings
#   <tag>/clover.in          the deck actually run
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

[ $# -ge 3 ] || { sed -n 2,5p "$0"; exit 1; }
kernels=$1 ranks=$2 threads=$3 deck=${4:-clover_bm_short.in}
[ -x "$CLOVER_BIN" ] || die "binary not found/executable: $CLOVER_BIN"
[ -f "$DECK_DIR/$deck" ] || die "deck not found: $DECK_DIR/$deck"

tag="${deck%.in}_${kernels}_r${ranks}_t${threads}"
case_dir=$OUT_DIR/$tag
mkdir -p "$case_dir"
make_deck "$DECK_DIR/$deck" "$case_dir/clover.in" "$kernels"

hdr="tag,deck,kernels,ranks,threads,rep,wall,grind,first_step,qa_pct,qa,kernels_reported,host,date"
[ -f "$OUT_DIR/results.csv" ] || echo "$hdr" > "$OUT_DIR/results.csv"
[ -f "$OUT_DIR/profiler.csv" ] || echo "tag,rep,section,time,pct" > "$OUT_DIR/profiler.csv"

cd "$case_dir"
for i in $(seq 1 "$REPS"); do
  rm -f clover.out clover.in.tmp
  launch "$ranks" "$threads" "$CLOVER_BIN" > "rep$i.log" 2>&1 || echo "  warning: mpirun exit $? (see $case_dir/rep$i.log)" >&2
  [ -f clover.out ] || { echo "  rep $i: no clover.out produced" >&2; continue; }
  mv clover.out "rep$i.out"
  read -r wall grind first qa passed kern < <(parse_out "rep$i.out")
  echo "$tag,$deck,$kernels,$ranks,$threads,$i,$wall,$grind,$first,$qa,$passed,$kern,$(hostname),$(date -Is)" >> "$OUT_DIR/results.csv"
  parse_profiler "rep$i.out" | sed "s/^/$tag,$i,/" >> "$OUT_DIR/profiler.csv"
  printf '  %-40s rep %d  wall=%-8.3f grind=%s  qa=%s %s  (%s kernels)\n' "$tag" "$i" "$wall" "$grind" "$qa" "$passed" "$kern"
done
rm -f clover.in.tmp
