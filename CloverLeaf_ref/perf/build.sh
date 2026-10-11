#!/bin/bash
# Builds the baseline and the PAPI-instrumented CloverLeaf into perf/bin/ and
# records the build environment plus the compiler's vectorisation report.
#   bash perf/build.sh
set -euo pipefail
source "$(dirname "$0")/env.sh"

BIN="$PERF_ROOT/bin"
mkdir -p "$BIN"
cd "$CLOVER_ROOT"

# -g only adds debug info (for perf annotate); GCC code generation is unchanged.
make clean
make COMPILER=GNU OPTIONS="-g" C_OPTIONS="-g"
mv clover_leaf "$BIN/clover_base"

make clean
make COMPILER=GNU OPTIONS="-g" C_OPTIONS="-g" PAPI=1 PAPI_DIR="$PAPI_DIR"
mv clover_leaf "$BIN/clover_papi"

# Vectorisation report for the C kernels, same flags as the Makefile (GNU).
mpicc -O3 -march=native -funroll-loops -fopenmp -c kernels/*_kernel_c.c \
  -fopt-info-vec-optimized="$BIN/vec_optimized.txt" \
  -fopt-info-vec-missed="$BIN/vec_missed.txt"
make clean

{
  echo "date:      $(date -Is)"
  echo "host:      $(hostname)"
  echo "git:       $(git rev-parse HEAD) ($(git rev-parse --abbrev-ref HEAD))"
  echo "dirty:     $(git status --porcelain | wc -l) changed files"
  echo "PAPI_DIR:  $PAPI_DIR"
  module -t list 2>&1 | sed 's/^/module:    /'
  mpicc --version | head -1 | sed 's/^/mpicc:     /'
  mpif90 --version | head -1 | sed 's/^/mpif90:    /'
} > "$BIN/build_info.txt"
cat "$BIN/build_info.txt"
