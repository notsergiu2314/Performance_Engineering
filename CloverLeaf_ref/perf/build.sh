#!/bin/bash
# Builds one CloverLeaf binary per source variant into perf/bin/, plus the PAPI-instrumented
# twin when PAPI is available, and records the build environment and the compiler's
# vectorisation report per variant.
#   bash perf/build.sh                 # every variant exported under perf/src/ (export_variants.sh)
#   bash perf/build.sh base opt        # a selection
#   bash perf/build.sh tree            # the checkout itself (CloverLeaf_ref), named "tree"
# Output: bin/clover_<v>, bin/clover_<v>_papi, bin/build_info_<v>.txt, bin/vec_report_<v>.txt.
# The binary that measured the M3 baseline (job 34797, md5 a753b7bd...) is kept as
# bin/clover_base.34797 instead of being overwritten.
# Knobs: PAPI=off skips the instrumented builds (default auto: built when papi.h is found),
# PAPI_DIR (from env.sh), SRC_ROOT (perf/src).
set -euo pipefail
source "$(dirname "$0")/env.sh"
BIN="$PERF_ROOT/bin"
SRC_ROOT="${SRC_ROOT:-$PERF_ROOT/src}"
mkdir -p "$BIN"

variants=("$@")
if [ ${#variants[@]} -eq 0 ]; then
  for d in "$SRC_ROOT"/*/; do [ -f "$d/Makefile" ] && variants+=("$(basename "$d")"); done
  [ ${#variants[@]} -gt 0 ] || { echo "no sources under $SRC_ROOT: run perf/export_variants.sh locally and rsync, or 'build.sh tree'" >&2; exit 1; }
fi

# Never destroy the binary the M3 baseline was measured with.
if [ -f "$BIN/clover_base" ] && [ "$(md5sum "$BIN/clover_base" | cut -c1-12)" = a753b7bda3ef ] && [ ! -f "$BIN/clover_base.34797" ]; then
  mv "$BIN/clover_base" "$BIN/clover_base.34797"
  echo "kept the job-34797 baseline binary as $BIN/clover_base.34797"
fi

papi=0
if [ "${PAPI:-auto}" != off ]; then
  if [ -f "${PAPI_DIR:-/nonexistent}/include/papi.h" ] || echo '#include <papi.h>' | mpicc -E - > /dev/null 2>&1; then papi=1
  else echo "notice: papi.h not found (PAPI_DIR=${PAPI_DIR:-unset}); the *_papi binaries are skipped"; fi
fi

for v in "${variants[@]}"; do
  if [ "$v" = tree ]; then src="$CLOVER_ROOT"; else src="$SRC_ROOT/$v"; fi
  [ -f "$src/Makefile" ] || { echo "no Makefile in $src (variant '$v')" >&2; exit 1; }
  echo "== $v  ($src)"
  (
    cd "$src"
    make clean > /dev/null
    rm -f "$BIN/vec_report_$v.txt"
    # -g only adds debug info (for perf annotate); GCC code generation is unchanged. The
    # vectorisation report uses the Makefile's own CFLAGS (the C kernels are one mpicc call).
    make COMPILER=GNU OPTIONS="-g" C_OPTIONS="-g -fopt-info-vec-all=$BIN/vec_report_$v.txt" > "$BIN/make_$v.log" 2>&1 \
      || { tail -30 "$BIN/make_$v.log"; echo "build of $v failed, log: $BIN/make_$v.log" >&2; exit 1; }
    mv clover_leaf "$BIN/clover_$v"
    if [ "$papi" = 1 ]; then
      make clean > /dev/null
      make COMPILER=GNU OPTIONS="-g" C_OPTIONS="-g" PAPI=1 PAPI_DIR="$PAPI_DIR" >> "$BIN/make_$v.log" 2>&1 \
        || { tail -30 "$BIN/make_$v.log"; echo "PAPI build of $v failed, log: $BIN/make_$v.log" >&2; exit 1; }
      mv clover_leaf "$BIN/clover_${v}_papi"
    else
      rm -f "$BIN/clover_${v}_papi"
    fi
    make clean > /dev/null
  )
  {
    [ -f "$src/SOURCE.txt" ] && cat "$src/SOURCE.txt" || {
      echo "variant:     $v"; echo "source:      $src"
      echo "commit:      $(git -C "$src" rev-parse HEAD 2>/dev/null || echo n/a) ($(git -C "$src" status --porcelain 2>/dev/null | wc -l) dirty files)"; }
    echo "built:       $(date -Is) on $(hostname)"
    grep -E '^(FLAGS_GNU|CFLAGS_GNU) ' "$src/Makefile" | sed 's/^/flags:       /'
    echo "papi:        $([ "$papi" = 1 ] && echo "yes$([ -d "${PAPI_DIR:-}" ] && echo " (PAPI_DIR=$PAPI_DIR)")" || echo no)"
    if type module > /dev/null 2>&1; then (set +u; module -t list 2>&1) | grep -v "^$" | sed "s/^/module:      /"; fi
    mpicc --version | head -1 | sed 's/^/mpicc:       /'
    mpif90 --version | head -1 | sed 's/^/mpif90:      /'
    for b in "$BIN/clover_$v" "$BIN/clover_${v}_papi"; do
      [ -f "$b" ] && echo "md5:         $(md5sum "$b" | cut -c1-12)  $(basename "$b")"
    done
  } > "$BIN/build_info_$v.txt"
  sed 's/^/   /' "$BIN/build_info_$v.txt"
done
echo "binaries in $BIN"
