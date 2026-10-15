# Helpers shared by the Slurm jobs. Sourced, not executed.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/env.sh"

# Run label -> MPI ranks x OpenMP threads. "1x64" = 1 rank, 64 threads.
#   run_clover <binary> <deck name> <ranks>x<threads> <out dir> [prefix cmd...]
# The prefix command (e.g. "perf stat ...") wraps the binary.
run_clover() {
  local bin="$1" deck="$2" cfg="$3" out="$4"; shift 4
  local ranks="${cfg%x*}" threads="${cfg#*x}"
  mkdir -p "$out"
  cp "$PERF_ROOT/inputs/$deck.in" "$out/clover.in"
  {
    echo "binary=$(basename "$bin")"
    echo "deck=$deck"
    echo "ranks=$ranks"
    echo "threads=$threads"
    echo "node=$(hostname)"
    echo "prefix=$*"
  } > "$out/meta.txt"
  (
    cd "$out"
    export OMP_NUM_THREADS="$threads"
    export PROF_DIR="$out"
    if [ "$ranks" -eq 1 ]; then
      "$@" "$bin" > stdout.txt 2>&1
    else
      # Every rank gets THREADS consecutive cores and pins its threads inside them
      # (slot:PE). For 2 and 4 ranks this is one rank per socket / per NUMA domain,
      # the same placement the earlier ppr:1:{package,numa} mapping gave; it also
      # works for 32, 64 and 128 ranks, which ppr:1:numa did not. Identical to
      # perf/baseline/lib.sh placement(), so both harnesses place ranks the same way.
      # OUTER_PREFIX (e.g. "perf stat -a -e ...") wraps the whole mpirun, not each rank.
      ${OUTER_PREFIX:-} mpirun -np "$ranks" --map-by "slot:PE=$threads" --bind-to core \
        -x OMP_NUM_THREADS -x OMP_PLACES -x OMP_PROC_BIND -x PROF_DIR -x PROF_EVENTS \
        "$@" "$bin" > stdout.txt 2>&1
    fi
  )
  grep -h "PASSED\|Wall clock" "$out/clover.out" | tail -2 | tr -s ' ' | paste -sd' ' \
    | sed "s|^|[$deck $cfg $(basename "$out")] |"
}

# Hardware/OS description for the report's "systems used" section.
record_system() {
  local out="$1"
  mkdir -p "$out"
  {
    echo "== hostname";  hostname
    echo "== uname";     uname -a
    echo "== lscpu";     lscpu
    echo "== numactl";   numactl --hardware 2>&1
    echo "== meminfo";   head -3 /proc/meminfo
    echo "== perf_event_paranoid"; cat /proc/sys/kernel/perf_event_paranoid
    echo "== cpufreq";   cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq \
                             /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>&1
    echo "== modules";   module -t list 2>&1
  } > "$out/system.txt" 2>&1
}

# One-time setup for jobs that run the matrix harness (perf/baseline/baseline.sh) one or
# more times in an allocation: THP-off launcher, DDR-controller events, system description.
#   prepare_harness <out dir>     exports NOTHP, NOTHP_VERBOSE, DDRC_EVENTS (unless DDRC=off)
prepare_harness() {
  local out="$1"
  mkdir -p "$out"
  export NOTHP=${NOTHP:-$out/nothp}
  [ -x "$NOTHP" ] || gcc -O2 "$PERF_ROOT/microbench/nothp.c" -o "$NOTHP"
  export NOTHP_VERBOSE=1
  if [ "${DDRC:-auto}" != off ]; then
    DDRC_EVENTS=$(ddrc_events); export DDRC_EVENTS
    [ -n "$DDRC_EVENTS" ] || echo "warning: no hisi_sccl*_ddrc* events visible to perf; dram_GB will be NA"
  fi
  record_system "$out"
}

# Comma separated list of the HiSilicon DDR controller flux events available
# to perf (empty if the uncore PMU is not exposed).
ddrc_events() {
  perf list 2>/dev/null | grep -oE 'hisi_sccl[0-9]+_ddrc[0-9]*/flux_(rd|wr)/' | sort -u | paste -sd,
}
