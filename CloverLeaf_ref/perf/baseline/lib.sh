#!/bin/bash
# Shared helpers for the CloverLeaf baseline harness (mpirun launcher). Sourced, not executed.
# Every knob is an environment variable with a default chosen for a reproducible
# cluster benchmark; override any of them on the command line.

_baseline_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
: "${PERF_ROOT:=$(cd "$_baseline_dir/.." && pwd)}"      # CloverLeaf_ref/perf
: "${CLOVER_ROOT:=$(cd "$PERF_ROOT/.." && pwd)}"        # CloverLeaf_ref
: "${CLOVER_BIN:=$PERF_ROOT/bin/clover_base}"           # what perf/build.sh produces
: "${DECK_DIR:=$CLOVER_ROOT/InputDecks}"
: "${REPS:=5}"                       # best-of-5; median is reported as well
: "${OUT_DIR:=$PWD/results}"
: "${MPIRUN:=mpirun}"                # launcher executable (e.g. a full path from a module)
: "${MPIRUN_ARGS:=--report-bindings}" # extra flags; bindings are logged to rep<i>.log
# Placement for a single rank. OpenMPI refuses "--map-by slot:PE=N --bind-to
# core" when N spans more than one package (1x128 on a two-socket node), so a
# lone rank is left unbound and the OpenMP runtime pins one thread per core
# over the whole node instead (OMP_PLACES=cores then lists every core the
# process may use). For this case --report-bindings is printed by MPI_Init
# rather than by mpirun, and libgomp has already pinned the main thread to
# place 0 by then, so the log says "rank 0 bound to ... core 0". That is the
# main thread only; the worker threads sit on their own cores (verify with
# OMP_DISPLAY_AFFINITY=true, forwarded through MPIRUN_ARGS="-x OMP_DISPLAY_AFFINITY").
: "${SINGLE_RANK_PLACEMENT:=--bind-to none}"
: "${OMP_PROC_BIND:=close}"          # pin threads to the cores mpirun hands each rank
: "${OMP_PLACES:=cores}"
: "${OMP_DYNAMIC:=false}"            # never let the runtime shrink the team
# Wrappers (both optional, word-split on purpose):
#   OUTER_PREFIX  wraps the whole mpirun, e.g. "perf stat -a -e <ddrc events> -x, -o f.csv"
#                 (system-wide DDR-controller counters around the run)
#   LAUNCH_PREFIX runs inside every rank, between mpirun and the binary, e.g. the
#                 nothp launcher (perf/microbench/nothp.c: THP off for the process tree)
: "${OUTER_PREFIX:=}"
: "${LAUNCH_PREFIX:=}"

die() { echo "error: $*" >&2; exit 1; }

# make_deck SRC DST KERNELS
# Copies SRC to DST, removes any existing kernel-selection / profiler / visit
# lines, and inserts the requested kernel keyword plus profiler_on before
# *endclover. KERNELS is "fortran" or "c".
make_deck() {
  local src=$1 dst=$2 kernels=$3 kw
  case $kernels in
    fortran) kw=use_fortran_kernels ;;
    c)       kw=use_c_kernels ;;
    *) die "unknown kernel set '$kernels' (fortran|c)" ;;
  esac
  grep -v -i -E '^\s*(use_[a-z]+_kernels|profiler_on|visit_frequency)' "$src" \
    | sed "s/^\*endclover/ $kw\n profiler_on\n*endclover/" > "$dst"
  grep -q "^ $kw" "$dst" || die "failed to insert $kw into $dst (no *endclover line?)"
}

# placement RANKS THREADS -> prints the mpirun mapping/binding flags.
# Each rank is bound to THREADS consecutive cores (--map-by slot:PE=THREADS),
# and the OpenMP runtime pins one thread per core inside that set. This gives
# the same placement for Nx1 and hybrid layouts on one or many nodes. A single
# rank (pure OpenMP) uses $SINGLE_RANK_PLACEMENT, see above.
placement() {
  local ranks=$1 threads=$2
  if [ "$ranks" -eq 1 ]; then echo "$SINGLE_RANK_PLACEMENT"
  else echo "--map-by slot:PE=$threads --bind-to core"; fi
}

# launch RANKS THREADS BIN [ARGS...]  -- runs the binary in the current directory.
# Stdin is /dev/null so mpirun cannot consume a caller's input stream.
# OpenMP pinning variables are always forwarded; PAPI profiler variables
# (PROF_DIR, PROF_EVENTS, PROF_DEBUG) and OMP_WAIT_POLICY only when set.
launch() {
  local ranks=$1 threads=$2 bin=$3 v
  shift 3
  export OMP_NUM_THREADS=$threads OMP_PROC_BIND OMP_PLACES OMP_DYNAMIC
  local fwd=(-x OMP_NUM_THREADS -x OMP_PROC_BIND -x OMP_PLACES -x OMP_DYNAMIC)
  for v in PROF_DIR PROF_EVENTS PROF_DEBUG OMP_WAIT_POLICY; do
    [ -n "${!v:-}" ] && { export "$v"; fwd+=(-x "$v"); }
  done
  # shellcheck disable=SC2046,SC2086  # placement flags, prefixes and MPIRUN_ARGS are word-split on purpose
  $OUTER_PREFIX "$MPIRUN" -np "$ranks" $(placement "$ranks" "$threads") \
    "${fwd[@]}" $MPIRUN_ARGS $LAUNCH_PREFIX "$bin" "$@" < /dev/null
}

# parse_out FILE -> prints: wall grind first_step qa_pct passed kernels_reported
parse_out() {
  local f=$1
  local wall grind first qa passed kern
  wall=$(grep "Wall clock" "$f" | tail -1 | awk '{print $3}')
  grind=$(grep "Average time per cell" "$f" | tail -1 | awk '{print $5}')
  first=$(grep "First step overhead" "$f" | tail -1 | awk '{print $4}')
  qa=$(grep -m1 "is within" "$f" | awk '{print $6}' | sed 's/%//')
  passed=$(grep -q "considered PASSED" "$f" && echo PASSED || echo FAILED)
  kern=$(grep -m1 "Using .* Kernels" "$f" | awk '{print $2}')
  echo "${wall:-NA} ${grind:-NA} ${first:-NA} ${qa:-NA} $passed ${kern:-NA}"
}

# parse_profiler FILE -> lines "section,time,pct"
parse_profiler() {
  local f=$1
  awk '/Profiler Output/{p=1;next} p&&/:/{ name=$0; sub(/ *:.*/,"",name); gsub(/^ +| +$/,"",name);
        n=split($0,a,":"); split(a[2],v," "); printf "%s,%s,%s\n", name, v[1], v[2] }
       p&&!/:/{ if (seen) exit } p{seen=1}' "$f"
}

# parse_ddrc FILE -> prints "dram_GB busiest_over_mean" from a `perf stat -x,` CSV of the
# HiSilicon DDR-controller flux events (32 B per count, see analysis/ddrc_summary.py).
# Prints "NA NA" when the file is missing or holds no DDRC rows.
parse_ddrc() {
  local f=$1 row
  [ -s "$f" ] || { echo "NA NA"; return; }
  row=$(python3 -I "$PERF_ROOT/analysis/ddrc_summary.py" --csv-row "$f" 2>/dev/null) || { echo "NA NA"; return; }
  # csv-row: rd_GB,wr_GB,total_GB,busiest_over_mean,seconds
  echo "$row" | awk -F, '{print $3, $4}'
}
