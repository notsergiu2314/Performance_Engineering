#!/bin/bash
# 1-minute check before submitting the M1/M2 jobs: both binaries run, QA says
# PASSED, PAPI counts events on this node, and the profile files parse.
#   srun -p cn-ib -N 1 bash perf/smoke.sh
set -uo pipefail
source "$(dirname "$0")/jobs/common.sh"

OUT="$PERF_ROOT/results/smoke_$(date +%H%M%S)"
mkdir -p "$OUT"
echo "== events PAPI can count here (first lines)"
papi_avail -a 2>&1 | grep -E "^ *PAPI_(TOT_CYC|TOT_INS|L1_DCM|L1_DCA|L2_DCM|L2_DCA|LD_INS|SR_INS|FP_INS|VEC_INS|BR_MSP)" | head -20
echo "== native events with STALL/BUS/MEM_ACCESS (for the 'stall' set)"
papi_native_avail 2>&1 | grep -E "STALL_BACKEND|STALL_FRONTEND|BUS_ACCESS|MEM_ACCESS" | head -8

echo "== base binary, 4 threads"
run_clover "$PERF_ROOT/bin/clover_base" bm960 1x4 "$OUT/base"
echo "== papi binary, 4 threads"
PROF_EVENTS="PAPI_TOT_CYC,PAPI_TOT_INS" run_clover "$PERF_ROOT/bin/clover_papi" bm960 1x4 "$OUT/papi"
grep -h "papi_prof" "$OUT/papi/stdout.txt" | head
python3 "$PERF_ROOT/analysis/papi_summary.py" "$OUT/papi" | head -20
echo "== internal profiler"
python3 "$PERF_ROOT/analysis/clover_profile.py" "$OUT"
echo "results in $OUT"
