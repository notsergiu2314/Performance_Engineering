#!/bin/bash
# Pre-flight check before submitting the M1/M2 jobs. Every run has a timeout,
# so a hang shows up as "TIMEOUT" instead of blocking the terminal.
# Submit from the repository root:  sbatch perf/smoke.sh   (output: perf/results/smoke_<jobid>.log)
#SBATCH -J smoke
#SBATCH -p cn-ib
#SBATCH -N 1
#SBATCH -t 00:15:00
#SBATCH -o perf/results/smoke_%j.log
set -uo pipefail
source "${SLURM_SUBMIT_DIR:-$(pwd)}/perf/jobs/common.sh"

OUT="$PERF_ROOT/results/smoke_$(date +%H%M%S)"
mkdir -p "$OUT"
BASE="$PERF_ROOT/bin/clover_base"
PAPI="$PERF_ROOT/bin/clover_papi"

# $1 label, $2 binary, $3 threads, $4 PROF_EVENTS ("-" = leave unset), $5 deck
try() {
  local label="$1" bin="$2" thr="$3" ev="$4" deck="${5:-quick}" rc
  local d="$OUT/$label"
  if [ "$ev" = "-" ]; then unset PROF_EVENTS; else export PROF_EVENTS="$ev"; fi
  PROF_DEBUG=1 run_clover "$bin" "$deck" "1x$thr" "$d" timeout 90 > "$d.log" 2>&1
  rc=$?
  # run_clover returns the status of its last pipeline (grep); get timeout's
  # status from the run itself:
  if ! grep -q "Wall clock" "$d/clover.out" 2>/dev/null; then rc=TIMEOUT-or-crash; else rc=ok; fi
  printf '%-34s thr=%-3s events=%-28s -> %s\n' "$label" "$thr" "$ev" "$rc"
  [ "$rc" = ok ] || { echo "   last output:"; tail -n 4 "$d/stdout.txt" | sed 's/^/   | /'; }
}

echo "== MPI/Slurm environment (a second MPI start inside one srun step can hang on PMIx)"
env | grep -E '^(PMIX|SLURM_MPI|SLURM_STEP_ID|OMPI_MCA)' | sort | head -10
echo "== events PAPI can count here"
papi_avail -a 2>&1 | grep -E "^ *PAPI_(TOT_CYC|TOT_INS|L1_DCM|L1_DCA|L2_DCM|L2_DCA|LD_INS|SR_INS|FP_INS|VEC_INS|BR_MSP)" | head -20

echo; echo "== quick runs (3 steps, 960^2): where does the PAPI build stop working?"
try base_1t                 "$BASE" 1 -
try base_1t_again           "$BASE" 1 -
try papi_notimer_1t         "$PAPI" 1 ""
try papi_cyc_1t             "$PAPI" 1 "PAPI_TOT_CYC"
try papi_cyc_ins_1t         "$PAPI" 1 "PAPI_TOT_CYC,PAPI_TOT_INS"
try papi_cyc_ins_4t         "$PAPI" 4 "PAPI_TOT_CYC,PAPI_TOT_INS"

echo; echo "== trace of the 4-thread PAPI run (PROF_DEBUG)"
grep -h "papi_prof" "$OUT/papi_cyc_ins_4t/stdout.txt" | head -30
echo; echo "== summary of the 4-thread PAPI run"
python3 "$PERF_ROOT/analysis/papi_summary.py" "$OUT/papi_cyc_ins_4t" 2>&1 | head -20
echo; echo "results in $OUT"
