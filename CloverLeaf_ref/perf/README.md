# Performance engineering of CloverLeaf_ref on HAICGU (Kunpeng 920)

Branch `M3_dev`: the merge of the M1/M2 work of both group members (`jort-test`: layout
sweep, Fortran reference, roofline; `sergiu-test`: PAPI, perf, DDR-controller counters, THP
root cause, LaTeX report). One source tree (`CloverLeaf_ref/`, commit `b5e598d` + PAPI hooks
that compile to nothing without `make PAPI=1`), one tooling directory (this one), one report
(`../../report/`). The comparison of the two branches that led to this layout is in
`../../report/benchmark_comparison_jort_vs_sergiu.md`.

Subject of the work: the **C kernels** (`use_c_kernels`). Fortran runs are kept for reference
only. Baseline build: GCC 14.1.0 (HAICGU default module) `-O3 -march=native -funroll-loops
-fopenmp` + `-g`, OpenMPI 5.0.3.

## Conventions fixed for M3

| Topic | Decision |
|---|---|
| Benchmark deck | `InputDecks/clover_bm16_short.in` = `inputs/bm3840.in`: 3840² cells, 87 steps, `test_problem 4` (~3.5 GB, memory resident) |
| Baseline layout | **64 ranks × 2 threads** (fastest and stable, jort sweep); compared with 1×128, 4×32, 32×4, 128×1, each with THP on and off |
| Repetitions | 5 per case, median and spread reported (`baseline/summarize.py`) |
| Bytes | **hardware bytes** from the DDR-controller counters (`hisi_sccl*_ddrc*/flux_{rd,wr}`, 32 B/count), recorded per repetition; bandwidth = bytes / wall; roof = hardware STREAM ceiling (`jobs/m3_stream_ddrc.sbatch`) |
| Byte model | `analysis/kernel_model.py` (per cell, write-allocate option, validated against the counters to 1–5 %); the loop-nest audit `roofline/kernel_model.py` is kept for cross-checks |
| Correctness gate | `InputDecks/clover_bm.in` (960², 2955 steps) must reproduce the baseline deviation in `archive/m3/correctness_baseline.csv` (`baseline/qa_check.py`); CloverLeaf's own 0.001 % threshold fails on this system for the unmodified code, so it is reported but not used as the gate |
| Optimisation plan | `analysis/plan_bytes.py` predicts every planned C change on the same byte model (`../../report/data/plan.csv`) |

## What is where

| Path | Purpose |
|---|---|
| `env.sh`, `build.sh` | modules; builds `bin/clover_base` and `bin/clover_papi`, vectorisation report, `bin/build_info.txt` |
| `smoke.sh` | pre-flight job (quick deck, base and PAPI builds) |
| `inputs/` | decks used by the sergiu-style jobs (`bm3840`, `bm960`, `quick`, `clover_bm`) |
| `baseline/` | matrix harness (mpirun only, env-var configured): `baseline.sh` → `run_case.sh` → `lib.sh`, `summarize.py`, `qa_check.py`, `baseline.sbatch`, matrices `matrix.m3`, `matrix.correctness`, `matrix.papi`, `matrix.cluster` (M1 sweep), `matrix.laptop` |
| `jobs/` | Slurm jobs. M3: `m3_stream_ddrc`, `m3_baseline`, `m3_correctness`, `m3_papi`. M1/M2 (historical, still runnable): `m1_baseline`, `m1_perf`, `m1_papi`, `m2_stream`, `m2_peak`, `m3_numa`, `m3_thp`; `common.sh` = `run_clover`, `record_system`, `ddrc_events` |
| `microbench/` | `nothp.c` (THP off per process tree), `peak_flops.c` (FMA/mul/div ceilings), `membw.c` + `peak_fma.c` (jort STREAM-style and FMA ceilings) |
| `roofline/` | jort ceilings harness (`machine.sbatch`, `machine.sh`, `build.sh`) and `roofline.py` (per-section roofline; `--hw` mode for hardware bytes) |
| `analysis/` | `clover_profile.py`, `papi_summary.py`, `ddrc_summary.py`, `stream_summary.py`, `stream_ddrc.py`, `kernel_model.py`, `plan_bytes.py`, `roofline.py` (sergiu per-kernel roofline) |
| `archive/` | committed results: `baseline/` (jobs 34729, 34733 = `baseline-cluster`, laptop), `roofline/` (jobs 34735/34739/34746, `roofline_bm16_short.*`), `m3/` (correctness baseline; M3 jobs 34795 stream+DDRC, 34796 correctness, 34797 baseline, 34798 PAPI: summaries, `results.csv`, `profiler.csv`, hardware roofline), `jort_notes.md` |
| `results/` | job output, not tracked; copy summaries into `archive/` and aggregated rows into `../../report/data/` |

The Fortran patch series of the jort branch (`patches/01`–`06`, unmeasured) was dropped; its
ideas live on as rows of `plan_bytes.py`: 01 + 05 → hoist the direction-only sweeps of
`advec_mom` and drop the dead `pre_vol`/`post_vol` stores; 02 + 03 → Revert/Reset by pointer
swap; 06 → tile-level parallelism (time only); 04 (scalar geometry) is valid on uniform
meshes only and is not planned.

## Runbook (HAICGU, from `CloverLeaf_ref/`)

All four M3 jobs ran on 2026-10-13 (smoke 34794; `m3_stream_ddrc` 34795, `m3_correctness` 34796,
`m3_baseline` 34797, `m3_papi` 34798); their summaries are in `archive/m3/` and the aggregated
rows in `../../report/data/`. Rerun them after every optimisation; `STREAM_HW_GBS=266.5`.

```bash
mkdir -p perf/results
. perf/env.sh                                     # GCC 14.1.0, OpenMPI 5.0.3, PAPI
srun -p cn-ib -N 1 -t 00:20:00 bash perf/build.sh # build on a compute node
sbatch perf/smoke.sh                              # ~1 min; then cat perf/results/smoke_<id>.log

sbatch perf/jobs/m3_stream_ddrc.sbatch            # write-allocate + hardware STREAM ceiling (~15 min)
sbatch perf/jobs/m3_correctness.sbatch            # clover_bm.in deviation vs archive/m3 baseline (~5 min)
sbatch perf/jobs/m3_baseline.sbatch               # 5 layouts x THP on/off x 5 reps, Fortran ref (~40 min)
sbatch perf/jobs/m3_papi.sbatch                   # per-kernel counters at 64x2 and 1x128 THP off (~15 min)
# once m3_stream_ddrc has run, pass its ceiling to the baseline for the %-of-roof column:
STREAM_HW_GBS=<dram_node_hw> sbatch perf/jobs/m3_baseline.sbatch
```

**Run everything with `sbatch`, never `srun bash job`:** a second MPI program inside one
`srun` step hangs in `MPI_Init` on HAICGU (seen 2026-10-12). `srun` is fine for non-MPI
commands (`build.sh`, `lscpu`). All jobs are independent and can be queued at once.

Every M3 job writes `perf/results/<job>_<id>/` with `system.txt` (lscpu, numactl, THP,
modules), `environment.txt`, `results.csv` (one row per repetition: wall, grind, QA
deviation, `dram_GB`, `busiest_over_mean`), `profiler.csv`, `summary.txt`/`summary.md`, and
per case `rep<i>.out`, `rep<i>.log`, `rep<i>.ddrc.csv`.

Then, on any machine with Python 3 (+ matplotlib for the figures):

```bash
python3 -I perf/analysis/plan_bytes.py --csv report/data/plan.csv
python3 -I perf/baseline/summarize.py perf/results/m3_baseline_<id> --md --stream-hw-gbs <dram_node_hw>
python3 -I perf/baseline/qa_check.py perf/results/m3_correctness_<id>/results.csv perf/archive/m3/correctness_baseline.csv
python3 perf/roofline/roofline.py --machine perf/archive/roofline/roofline-34735/machine.csv \
    --machine perf/archive/roofline/roofline-34746/machine.csv \
    --results perf/results/m3_baseline_<id> --kernels c --hw --hw-roof <dram_node_hw>
```

## Harness (`baseline/`)

Matrix lines are `KERNELS RANKS THREADS DECK [THP]`. The deck is copied, any
`use_*_kernels`, `profiler_on` and `visit_frequency` lines are stripped, and the requested
kernel keyword plus `profiler_on` are inserted. Placement: every rank is bound to THREADS
consecutive cores (`--map-by slot:PE=THREADS --bind-to core`), OpenMP pins one thread per
core (`OMP_PROC_BIND=close OMP_PLACES=cores OMP_DYNAMIC=false`); a single rank (1×128)
runs `--bind-to none` and the OpenMP runtime pins thread *i* to core *i*. `THP=off` wraps
every rank in `nothp` (`prctl(PR_SET_THP_DISABLE)`, no root) and the case tag gets
`_thpoff`. With `DDRC_EVENTS` set (the sbatch does it when `perf list` shows the HiSilicon
DDRC PMU) each repetition runs under `perf stat -a`, and `results.csv` gets the DRAM bytes
and the load of the busiest memory-controller group (1.00 = balanced over the 4 domains).
Knobs: `CLOVER_BIN`, `DECK_DIR`, `REPS`, `OUT_DIR`, `MPIRUN`, `MPIRUN_ARGS`,
`SINGLE_RANK_PLACEMENT`, `OMP_*`, `NOTHP`, `DDRC_EVENTS`, `OUTER_PREFIX`, `LAUNCH_PREFIX`,
`PROF_EVENTS` (PAPI build), `STREAM_HW_GBS`. Laptop check: `cd perf/baseline &&
NOTHP=../bin/nothp REPS=1 ./baseline.sh matrix.laptop`.

## Correctness checks of the tools (from M1, still required)

1. **QA**: every bm3840 run says `PASSED`; every `clover_bm.in` run reproduces the baseline
   deviation (`qa_check.py`); the PAPI build gives the same answer as the base build.
2. **Timers vs PAPI**: per-kernel PAPI region times match the internal profiler categories.
3. **PAPI vs perf**: total `PAPI_TOT_CYC`/`PAPI_TOT_INS` slightly below `perf stat` whole-run counts.
4. **Clock**: cycles / time ≈ 2.6 GHz.
5. **Overhead**: `m3_papi` reruns the base binary; the wall-clock difference is the instrumentation cost.
6. **DDR counters**: calibrated on STREAM (`m3_stream_ddrc`: counts × 32 B against the
   with/without write-allocate byte models) before they are used on CloverLeaf.
7. **Placement**: `busiest_over_mean` ≈ 1.00 for every multi-rank and THP-off case.

## M3 baseline in short (jobs 34795–34798, details in the report)

* **Hardware ceiling = counted STREAM triad: 266.5 GB/s.** The DDR controllers count 1.04× the
  bytes STREAM counts and 0.74× the write-allocate model, in all 20 STREAM runs and in `membw`:
  a streaming store does not read the line first on this CPU. DIMM clock not readable without
  root (EDAC: 16 × registered DDR4 8 GB); 266.5 GB/s needs ≥ 2082 MT/s, DDR4-2666 is consistent.
* **64×2 C: 11.25 s median (spread 0.7 %), 2.83 TB, 250 GB/s = 94 % of the ceiling.** 32×4 11.40 s,
  128×1 11.7 s, 4×32 12.8–13.0 s, 1×128 13.3 s THP off / 26.9 s THP on (busiest controller
  group 1.66× mean; 1.00 everywhere else). THP off changes nothing for ≥ 4 ranks.
* **The C/Fortran gap is a byte gap:** Fortran 64×2 9.33 s, 2.36 TB, 252 GB/s (95 %). Both
  saturate the DRAM; C moves 20 % more bytes. C reads = 1.34× the model's demand reads (its
  stores pay a read-for-ownership on ~70 % of the written volume), Fortran 1.15× (~40 %).
* Correctness gate: `clover_bm.in` deviation reproduced 7 of 7 (C 0.5726209E-02 %, Fortran
  0.1787088E-01 %, tol 1e-6 %) at every layout. PAPI build 11.30 s vs base 11.34 s at 64×2.
* Plan (`analysis/plan_bytes.py`, floor at 266.5 GB/s): five byte changes −29 % (floor 10.5 → 7.4 s);
  new sixth lever: streaming stores, bound −23 % alone, −41 % on top. Time-only items pay off only
  after the bytes shrink.

## M1/M2 results in short (details in the report)

* Memory-bound everywhere: AI 0.21 flop/B (write-allocate) against a 5 flop/B ridge.
* Ceilings: FMA 1329 GFLOP/s per node (4 flop/cycle, one 128-bit FMA per cycle);
  STREAM triad 263–267 GB/s per node (pinned / best), 67 GB/s per NUMA domain.
* Transparent huge pages (512 MB on 64 KB base pages) unbalance 1×128 runs: 23 s vs 13.5 s
  with THP off; 4 or more ranks avoid the problem (first touch per domain).
* jort sweep: 64×2 fastest, C 11.23 s / Fortran 9.31 s. (M1 attributed the C penalty to
  vectorisation "at equal bytes"; the M3 counters show it is bytes, see above.)
* Analytic model within 1–5 % of the measured DRAM traffic (2.80 TB vs 2.83–2.94 TB).
