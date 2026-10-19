#!/bin/bash
#SBATCH -J flagbisect
#SBATCH -p cn-ib
#SBATCH -N 1
#SBATCH --exclusive
#SBATCH --ntasks-per-node=128
#SBATCH --cpus-per-task=1
#SBATCH -t 01:30:00
#SBATCH -o perf/results/%x_%j.log
# Which change moves the clover_bm.in kinetic-energy deviation on aarch64?
# 3 source revisions x 3 C-flag sets, built from `git archive` (working tree not used),
# each run once at 64x2 on clover_bm.in. Result table: perf/results/flagbisect_<jobid>/summary.txt
# Submit from CloverLeaf_ref after `git fetch origin` (the revisions must exist locally).
set -eo pipefail
source "$SLURM_SUBMIT_DIR/perf/jobs/common.sh"
set -u
REPO=$(git -C "$SLURM_SUBMIT_DIR" rev-parse --show-toplevel)
W=$PERF_ROOT/results/flagbisect_$SLURM_JOB_ID
mkdir -p "$W/bin" "$W/src"

# revisions: o = original kernels (59cdd3b), e = + advec_cell edits and field swap (ff83119),
#            t = + Jort's advec_mom / calc_dt (787baa1)
declare -A REV=( [o]=59cdd3b [e]=ff83119 [t]=787baa1 )
OLD="-O3 -march=native -funroll-loops"                           # flags of the original baseline
declare -A FL=( [old]="$OLD"
                [new]="$OLD -fno-math-errno -fno-trapping-math"   # flags of M3_dev
                [off]="$OLD -ffp-contract=off" )                  # no fused multiply-add at all

build() {  # name rev flags
  mkdir -p "$W/src/$1"
  git -C "$REPO" archive "$2" CloverLeaf_ref | tar -x -C "$W/src/$1"
  ( cd "$W/src/$1/CloverLeaf_ref" \
    && make COMPILER=GNU OPTIONS="-g" C_OPTIONS="-g" CFLAGS_GNU="$3" > "$W/build_$1.log" 2>&1 \
    && cp clover_leaf "$W/bin/$1" )
}
for r in o e t; do
  git -C "$REPO" cat-file -e "${REV[$r]}" || { echo "revision ${REV[$r]} not in the repo: run git fetch origin" >&2; exit 1; }
  for f in old new off; do build "${r}_$f" "${REV[$r]}" "${FL[$f]}" & done
done
wait
ls "$W/bin" | wc -l | sed 's/^/binaries built: /'

printf 'c 64 2 clover_bm.in on\n' > "$W/matrix"
: > "$W/summary.txt"
for r in o e t; do for f in old new off; do
  v="${r}_$f"
  [ -x "$W/bin/$v" ] || { echo "$v BUILD-FAILED" >> "$W/summary.txt"; continue; }
  OUT_DIR="$W/run_$v" CLOVER_BIN="$W/bin/$v" MATRIX="$W/matrix" REPS=1 DDRC=off \
    bash "$PERF_ROOT/baseline/baseline.sbatch" > "$W/run_$v.log" 2>&1 || true
  qa=$(awk -F, 'NR==2{print $11}' "$W/run_$v/results.csv" 2>/dev/null)
  echo "$v rev=${REV[$r]} flags='${FL[$f]}' qa_pct=${qa:-RUN-FAILED}" >> "$W/summary.txt"
done; done
echo; echo "== summary ($W/summary.txt)"; cat "$W/summary.txt"
cp "$W/summary.txt" "$PERF_ROOT/results/flagbisect_$SLURM_JOB_ID.txt"
