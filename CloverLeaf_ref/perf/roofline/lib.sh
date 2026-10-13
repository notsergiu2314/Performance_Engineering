#!/bin/bash
# Shared helpers for the roofline microbenchmarks. Sourced, not executed.
# Reuses the baseline harness (mpirun launch, OpenMP pinning, environment block);
# every knob is an environment variable with a default.
_roofline_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
: "${REPS:=3}"                        # whole-benchmark repetitions, best is kept
source "$_roofline_dir/../baseline/lib.sh"   # MPIRUN, MPIRUN_ARGS, OMP_*, launch, placement, die

: "${BIN_DIR:=$_roofline_dir/bin}"
: "${CC:=gcc}"                        # GCC on the cluster comes from 'module load GCC'
: "${CFLAGS:=-O3 -march=native -funroll-loops -fopenmp -ffp-contract=fast}"  # same base flags as clover_leaf
: "${ARRAY_ELEMS:=134217728}"         # 2^27 doubles = 1 GiB per array (3 GiB total), far above any L3
: "${NTIMES:=20}"                     # membw inner repetitions, best after the first is reported
: "${FMA_ITERS:=400000000}"           # peak_fma loop trips per thread (~1-2 s per run)
: "${MACHINE_PROFILE:=haicgu}"        # machine.<profile>.env supplies the theoretical constants
: "${OUT_DIR:=$_roofline_dir/results/machine-$(hostname -s)}"

# profile_env -> sources machine.$MACHINE_PROFILE.env (GHZ, FLOP_PER_CYCLE, cores, memory)
profile_env() {
  local f=$_roofline_dir/machine.$MACHINE_PROFILE.env
  [ -f "$f" ] || die "no profile $f (set MACHINE_PROFILE)"
  # shellcheck disable=SC1090
  source "$f"
}

# run_bench KIND THREADS PLACES -> stdout of one benchmark run (key=value lines).
# PLACES is an OMP_PLACES value: {0} one core, {0}:32 NUMA domain 0, {0}:64 socket 0,
# cores the whole node. One rank, unbound by mpirun (placement() for ranks=1), so the
# OpenMP runtime pins thread i to place i and first-touch lands on the same cores.
run_bench() {
  local kind=$1 threads=$2 places=$3 args
  case $kind in
    membw)    args="$ARRAY_ELEMS $NTIMES" ;;
    peak_fma) args="$FMA_ITERS ${FLOP_PER_CYCLE:-8}" ;;
    *) die "unknown benchmark '$kind' (membw|peak_fma)" ;;
  esac
  [ -x "$BIN_DIR/$kind" ] || die "$BIN_DIR/$kind missing: run build.sh"
  # shellcheck disable=SC2086
  OMP_PLACES=$places launch 1 "$threads" "$BIN_DIR/$kind" $args
}

# parse_bench KIND -> reads key=value lines on stdin, prints "quantity,value,unit" rows
parse_bench() {
  local kind=$1
  awk -F= -v kind="$kind" '
    kind=="membw"    && $1 ~ /_gbs$/            { q=$1; sub(/_gbs$/,"",q); printf "stream_%s,%s,GB/s\n", q, $2 }
    kind=="peak_fma" && $1=="gflops_total"      { printf "peak_fma,%s,GFLOP/s\n", $2 }
    kind=="peak_fma" && $1=="gflops_per_thread" { printf "peak_fma_per_thread,%s,GFLOP/s\n", $2 }
    kind=="peak_fma" && $1=="implied_ghz"       { printf "implied_ghz,%s,GHz\n", $2 }'
}
