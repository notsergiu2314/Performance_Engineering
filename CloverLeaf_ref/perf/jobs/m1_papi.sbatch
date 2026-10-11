#!/bin/bash
#SBATCH -J m1_papi
#SBATCH -p cn-ib
#SBATCH -N 1
#SBATCH --exclusive
#SBATCH -t 02:00:00
#SBATCH -o perf/results/%x_%j.log
# M1: per-kernel hardware counters with PAPI (kernels/papi_prof.c).
# The PMU has a limited number of counters, so events are measured in
# several passes, each with its own small event set. Events that do not
# exist on this CPU are skipped by papi_prof (see stdout.txt of each run).
# Submit from the repository root: sbatch perf/jobs/m1_papi.sbatch
set -uo pipefail
source "$SLURM_SUBMIT_DIR/perf/jobs/common.sh"

OUT="$PERF_ROOT/results/m1_papi_$SLURM_JOB_ID"
BIN="$PERF_ROOT/bin/clover_papi"
DECK=bm3840
record_system "$OUT"
papi_avail -a              > "$OUT/papi_avail.txt" 2>&1
papi_native_avail          > "$OUT/papi_native_avail.txt" 2>&1
papi_component_avail       > "$OUT/papi_component_avail.txt" 2>&1

declare -A SETS=(
  [ipc]="PAPI_TOT_CYC,PAPI_TOT_INS"
  [cache]="PAPI_L1_DCA,PAPI_L1_DCM,PAPI_L2_DCA,PAPI_L2_DCM"
  [mix]="PAPI_TOT_INS,PAPI_LD_INS,PAPI_SR_INS,PAPI_FP_INS,PAPI_VEC_INS,PAPI_BR_MSP"
  [stall]="PAPI_TOT_CYC,STALL_BACKEND,STALL_FRONTEND,BUS_ACCESS,MEM_ACCESS"
  [time]=""
)

for set in "${!SETS[@]}"; do
  export PROF_EVENTS="${SETS[$set]}"
  for cfg in 1x1 1x64 1x128; do
    run_clover "$BIN" "$DECK" "$cfg" "$OUT/$set/$cfg"
  done
done

# Load imbalance: with passive waiting, threads sleep in the barrier instead
# of spinning, so per-thread user-mode cycles count only real work
# (papi_summary.py reports max/mean as cyc_imbal).
export PROF_EVENTS="PAPI_TOT_CYC,PAPI_TOT_INS"
for cfg in 1x64 1x128; do
  OMP_WAIT_POLICY=passive run_clover "$BIN" "$DECK" "$cfg" "$OUT/imbalance/$cfg"
done

# Instrumentation overhead check: same run without PAPI.
run_clover "$PERF_ROOT/bin/clover_base" "$DECK" 1x128 "$OUT/overhead_base/1x128"

for d in "$OUT"/*/*/; do
  echo "=== $d"
  python3 "$PERF_ROOT/analysis/papi_summary.py" "$d"
done > "$OUT/summary.txt" 2>&1
cat "$OUT/summary.txt"
