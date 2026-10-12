#!/bin/bash
# Compile the microbenchmarks into $BIN_DIR and record compiler, flags and whether the
# FMA loop really became fused vector instructions (fmla on aarch64, vfmadd on x86).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
mkdir -p "$BIN_DIR"
log=$BIN_DIR/build.log
{
  echo "date:   $(date -Is)"
  echo "host:   $(hostname)"
  echo "cc:     $CC ($("$CC" --version | head -1))"
  echo "cflags: $CFLAGS"
} > "$log"
for src in membw peak_fma; do
  "$CC" $CFLAGS -o "$BIN_DIR/$src" "$_roofline_dir/src/$src.c" -lm
  echo "built:  $src" >> "$log"
done
# aarch64: fmla = vector FMA, fmadd = scalar FMA; x86: vfmadd* (ymm/zmm = vector).
vec=$(objdump -d "$BIN_DIR/peak_fma" | grep -cE '\bfmla\b|vfmadd[0-9]+[ps]d.*(ymm|zmm)' || true)
sca=$(objdump -d "$BIN_DIR/peak_fma" | grep -cE '\bfmadd\b|vfmadd[0-9]+sd' || true)
echo "peak_fma: $vec vector FMA, $sca scalar FMA instructions" | tee -a "$log"
[ "$vec" -gt 0 ] || die "peak_fma has no vector FMA instructions; check CFLAGS=$CFLAGS (see $log)"
# Keep the outlined OpenMP body (the hot loop) in the log so the code can be checked
# without an aarch64 objdump at hand.
{ echo; echo "---- peak_fma hot loop (main._omp_fn.*) ----"
  objdump -d --no-show-raw-insn "$BIN_DIR/peak_fma" | awk '/<main\._omp_fn/{p=1} p&&/^$/{exit} p' ; } >> "$log"
echo "binaries in $BIN_DIR, log in $log"
