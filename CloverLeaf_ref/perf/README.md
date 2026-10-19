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
| `env.sh`, `build.sh` | modules; `build.sh [VARIANT...]` builds `bin/clover_<variant>` and `bin/clover_<variant>_papi` from `src/<variant>/`, with `bin/build_info_<variant>.txt` and `bin/vec_report_<variant>.txt` |
| `variants.conf`, `export_variants.sh`, `sync.sh` | the commit ladder of the M3 optimisations (`base`, `flags`, `cell`, `mom`, `opt`, `optnf`; `pdv` = the merged tip with the unmeasured PdV change); `export_variants.sh` exports each ref's sources into `src/<variant>/` (gitignored) because the cluster copy has no git; `sync.sh` rsyncs the tree to the cluster |
| `archive.sh` | copies job summaries into `archive/m3/<job>/` and, with `--report`, the aggregated rows into `../../report/data/` (`analysis/report_data.py`) |
| `smoke.sh` | pre-flight job (quick deck, base and PAPI builds) |
| `inputs/` | decks used by the sergiu-style jobs (`bm3840`, `bm960`, `quick`, `clover_bm`) |
| `baseline/` | matrix harness (mpirun only, env-var configured): `baseline.sh` → `run_case.sh` → `lib.sh`, `summarize.py`, `qa_check.py`, `baseline.sbatch`, matrices `matrix.m3`, `matrix.layouts` (C at the five layouts, THP off only at 1x128), `matrix.ladder` (C 64x2), `matrix.m3_64x2` (bm3840 at 64x2 only, quick A/B of one binary), `matrix.correctness`, `matrix.papi`, `matrix.cluster` (M1 sweep), `matrix.laptop`. Every row of `results.csv` carries the build `variant` (last column) |
| `jobs/` | Slurm jobs. M3: `m3_stream_ddrc`, `m3_baseline`, `m3_correctness` (per variant), `m3_opt` (ladder + layouts, base against opt in one job), `m3_papi` (per variant), `m3_flagbisect` (3 source revisions x 3 C-flag sets on `clover_bm.in` at 64x2, job 34936), `m3_gate_off` (equivalence gate of the checked-out commit against the original kernels with `-ffp-contract=off`, three layouts). M1/M2 (historical, still runnable): `m1_baseline`, `m1_perf`, `m1_papi`, `m2_stream`, `m2_peak`, `m3_numa`, `m3_thp`; `common.sh` = `run_clover`, `record_system`, `ddrc_events`, `prepare_harness` |
| `microbench/` | `nothp.c` (THP off per process tree), `peak_flops.c` (FMA/mul/div ceilings), `membw.c` + `peak_fma.c` (jort STREAM-style and FMA ceilings) |
| `roofline/` | jort ceilings harness (`machine.sbatch`, `machine.sh`, `build.sh`) and `roofline.py` (per-section roofline; `--hw` mode for hardware bytes) |
| `analysis/` | `variants.py` (base vs optimised: `optimised.csv`, `ladder.csv`, `compare.md`), `report_data.py` (into `report/data/`), `clover_profile.py`, `papi_summary.py`, `ddrc_summary.py`, `stream_summary.py`, `stream_ddrc.py`, `kernel_model.py`, `plan_bytes.py`, `roofline.py` (sergiu per-kernel roofline) |
| `archive/` | committed results: `baseline/` (jobs 34729, 34733 = `baseline-cluster`, laptop), `roofline/` (jobs 34735/34739/34746, `roofline_bm16_short.*`), `m3/` (correctness baseline; M3 jobs 34795 stream+DDRC, 34796 correctness, 34797 baseline, 34798 PAPI: summaries, `results.csv`, `profiler.csv`, hardware roofline), `jort_notes.md` |
| `results/` | job output, not tracked; `archive.sh <job dirs> --report` copies the summaries into `archive/m3/` and the aggregated rows into `../../report/data/` |

The Fortran patch series of the jort branch (`patches/01`–`06`, unmeasured) was dropped; its
ideas live on as rows of `plan_bytes.py`: 01 + 05 → hoist the direction-only sweeps of
`advec_mom` and drop the dead `pre_vol`/`post_vol` stores; 02 + 03 → Revert/Reset by pointer
swap; 06 → tile-level parallelism (time only); 04 (scalar geometry) is valid on uniform
meshes only and is not planned.

## Runbook (HAICGU, from `CloverLeaf_ref/`)

Submit from the dev node (`ssh guoehi-dev`, a login shell): the login node `guoehi` has no
`/software` mount and its `MODULEPATH` lacks the Stages/2024 tree, and a batch job inherits the
submitting shell's `MODULEPATH`, so a job submitted there fails in `env.sh` with "GCC unknown"
(jobs 35014/35015). From the laptop: `ssh guoehi-dev 'bash -lc "cd ~/CloverLeaf_ref && sbatch ..."'`.

The M3 baseline jobs ran on 2026-10-13 (smoke 34794; `m3_stream_ddrc` 34795, `m3_correctness` 34796,
`m3_baseline` 34797, `m3_papi` 34798); their summaries are in `archive/m3/` and the aggregated
rows in `../../report/data/`. The hardware ceiling is `STREAM_HW_GBS=266.5`.

### Optimised kernels against the baseline

Build variants (`variants.conf`): `base` = 3c20f85 (baseline source and CFLAGS, job 34797),
`flags` = 59cdd3b (`-fno-math-errno -fno-trapping-math` only), `cell` = ff83119 (flags +
advec_cell temporaries and dead store + reset/revert field swap), `mom` = 88fce34 (flags +
advec_mom hoist and dead store + calc_dt fused reduction), `opt` = 787baa1 (everything, with the
T2 flags; measured in jobs 34937-34939), `optnf` = 8d7d81f (opt with the baseline CFLAGS: the T2
flags bought nothing and alone move the `clover_bm.in` deviation, jobs 34937/34999; branch-free
upwind loop and nowait kept), `pdv` = 51dd171 (the merged tip: optnf + Sergiu's PdV change d2b00e6,
`volume_change` kept in a register, model -1.5 % bytes; measured in jobs 35012/35016/35017, the reported build). The cluster copy is an rsync copy without git, so the sources are
exported locally first.

```bash
# laptop (git checkout)
bash perf/export_variants.sh                      # -> perf/src/<variant>/ (+ SOURCE.txt), gitignored
CLUSTER=<ssh host> bash perf/sync.sh              # rsync CloverLeaf_ref/ (no results, no binaries)

# cluster, from CloverLeaf_ref/
mkdir -p perf/results
. perf/env.sh                                     # GCC 14.1.0, OpenMPI 5.0.3, PAPI
srun -p cn-ib -N 1 -t 00:30:00 bash perf/build.sh # all variants -> perf/bin/clover_<v>[_papi]
sbatch perf/jobs/m3_correctness.sbatch            # gate per variant (~25 min): $OUT/qa_check.txt, correctness_rows.csv
sbatch perf/jobs/m3_opt.sbatch                    # ladder at 64x2 + base/opt at 5 layouts, DDRC bytes (~25 min)
VARIANT=opt sbatch perf/jobs/m3_papi.sbatch       # per-kernel counters of the optimised build (~15 min)
# with the correctness job's rows the qa_ok column is the gate verdict:
QA=perf/results/m3_correctness_<id>/correctness_rows.csv sbatch perf/jobs/m3_opt.sbatch

# afterwards (cluster or laptop, after copying perf/results back):
python3 -I perf/analysis/variants.py --run perf/results/m3_opt_<id> \
    --qa perf/results/m3_correctness_<id>/correctness_rows.csv --stream-hw-gbs 266.5   # rewrite compare.md etc.
bash perf/archive.sh perf/results/m3_opt_<id> perf/results/m3_correctness_<id> \
    perf/results/m3_papi_opt_<id> --report       # -> archive/m3/<job>/, report/data/{optimised,ladder,correctness,kernels_papi}.csv
/usr/bin/python3 ../report/make_assets.py         # tab_results, tab_ladder, tab_kernels_opt, fig_m3_layouts
```

Knobs: `m3_opt`: `LADDER` ("base flags cell mom opt"), `VARIANTS` ("base opt"), `REPS` (5),
`STREAM_HW_GBS`, `DDRC`, `QA`. `m3_correctness`: `VARIANTS` ("opt flags cell mom"), `FULL` ("base opt
optnf": these run the full `matrix.correctness`, the others its C 64x2 row), `BASELINE`, `TOL`
(1e-6 %); a mismatch is recorded in the `gate` column, it does not abort the job. `m3_papi`:
`VARIANT` (opt). `build.sh`: `PAPI=off`, `SRC_ROOT`. `export_variants.sh`: `CONF`, `SRC_ROOT`.
`sync.sh`: `CLUSTER`, `REMOTE`, `RSYNC_ARGS`. `archive.sh`: `ARCHIVE`, `REPORT_DATA`, `VARIANT`.
`analysis/variants.py`: `--opt` (the variant compared with the archive and the plan, default opt).
`report/make_assets.py`: `OPT_VARIANT` (env, default opt: the build the Results section shows).

### The no-flags build (`optnf`)
```bash
bash perf/export_variants.sh optnf && CLUSTER=<host> bash perf/sync.sh        # laptop
srun -p cn-ib -N 1 -t 00:30:00 bash perf/build.sh optnf                        # cluster, from CloverLeaf_ref/
VARIANTS=optnf sbatch perf/jobs/m3_correctness.sbatch                          # full matrix; expect 0.5726209E-02 %
LADDER="base opt optnf" VARIANTS="base optnf" sbatch perf/jobs/m3_opt.sbatch   # bytes and time without the flags
VARIANT=optnf sbatch perf/jobs/m3_papi.sbatch                                  # per-kernel counters (optional)
# laptop, after copying perf/results back:
python3 -I perf/analysis/variants.py --run perf/results/m3_opt_<id> --opt optnf \
    --qa perf/results/m3_correctness_<id>/correctness_rows.csv --stream-hw-gbs 266.5
VARIANT=optnf bash perf/archive.sh perf/results/m3_correctness_<id> perf/results/m3_opt_<id> \
    [perf/results/m3_papi_optnf_<id>] --report
OPT_VARIANT=optnf /usr/bin/python3 ../report/make_assets.py                    # Results section from the optnf rows
```
Outcome (jobs 35002 correctness, 35003 m3_opt, 35004 m3_papi, cn16, 2026-10-19, archived): `optnf` passes
the gate 7 of 7 at every layout, keeps the bytes (2.052 vs 2.043 TB) and is 3.6 % slower than `opt` at 64x2
(8.56 vs 8.25 s; the vectorised sqrt of calc_dt and ideal_gas). `optnf` was the reported build until `pdv`
(below; `OPT_VARIANT=<variant>`, columns `*_64x2_<variant>` in `kernels_papi.csv`); `data/ladder.csv` and
`data/optimised.csv` keep the job-34938 rows and carry the optnf rows next to them (`report_data.py`
appends variants instead of overwriting).

Mechanism of the flag effect (Sergiu's bisect, job 34936, `jobs/m3_flagbisect.sbatch`): built with
`-ffp-contract=off`, the original kernels (59cdd3b), the advec_cell edits (ff83119) and the merged tip
(787baa1) all give 1.99e-13 %, so the kernel edits are arithmetically the originals and both
deviations (0.0057 % baseline flags, 0.038 % with the two flags) are what GCC's default
`-ffp-contract=fast` makes of the code; the flags change where it fuses. `jobs/m3_gate_off.sbatch`
runs that equivalence check (original vs checked-out commit, contraction off, three layouts) for a new commit.

### The PdV build (`pdv`, the reported build)
Commit d2b00e6 (merged in 51dd171, after the optnf measurements) keeps `volume_change` in a register in
both PdV passes: -32 B/cell/step, model -1.5 % of the bytes. Same procedure as optnf; gate first
(submit from the dev node, see the top of the runbook):
```bash
bash perf/export_variants.sh pdv && CLUSTER=<host> bash perf/sync.sh          # laptop
srun -p cn-ib -N 1 -t 00:30:00 bash perf/build.sh pdv                          # cluster, from CloverLeaf_ref/
VARIANTS=pdv FULL="base opt optnf pdv" sbatch perf/jobs/m3_correctness.sbatch  # full matrix; expect 0.5726209E-02 %
LADDER="base optnf pdv" VARIANTS="base pdv" sbatch perf/jobs/m3_opt.sbatch     # bytes and time
VARIANT=pdv sbatch perf/jobs/m3_papi.sbatch                                    # per-kernel counters (optional)
# laptop, after copying perf/results back:
python3 -I perf/analysis/variants.py --run perf/results/m3_opt_<id> --opt pdv \
    --qa perf/results/m3_correctness_<id>/correctness_rows.csv --stream-hw-gbs 266.5
VARIANT=pdv bash perf/archive.sh perf/results/m3_correctness_<id> perf/results/m3_opt_<id> \
    [perf/results/m3_papi_pdv_<id>] --report
OPT_VARIANT=pdv /usr/bin/python3 ../report/make_assets.py                      # Results section from the pdv rows
```
Outcome (jobs 35012 correctness, 35016 m3_opt on cn15, 35017 m3_papi on cn16, 2026-10-19, archived):
`pdv` passes the gate 7 of 7 at every layout; 64x2: 8.25 s and 2.012 TB against its own base rerun
(11.22 s), -28.8 % bytes and -26.5 % time, 1.37x against the archived baseline (1.36-1.37x at the
balanced layouts, 1.33x at 1x128 THP on, 1.35x THP off), 244 GB/s = 91 % of the ceiling, 9 % above
its floor (7.55 s). Per kernel (PAPI): both PdV passes 1.13x, advec_mom 1.60x, advec_cell 1.45x. The
PdV bytes buy back exactly what the flags were worth: `pdv` without the flags equals `opt` with them
(8.25 s). `pdv` is the reported build (`OPT_VARIANT=pdv`, `*_64x2_pdv` columns). Jobs 35014/35015
were the same two jobs submitted from the login node; they failed in `env.sh` (no module tree).

Read first: `m3_correctness_<id>/qa_check.txt` (does every variant reproduce the baseline
deviation 0.5726209E-02 %? Job 34999 showed that the `base` binary does at every layout and that
every build with `-fno-math-errno -fno-trapping-math` gives 0.3835202E-01 %: the flags, not the
kernel changes, move the value; `optnf`, the kernel changes with the baseline CFLAGS, passes, job
35002) and `m3_opt_<id>/compare.md` (archive 34797 vs the same-job base
rerun vs opt per layout, the ladder at 64x2, the plan prediction -29.3 % bytes / 1.983 TB).
`optimised.csv` has one row per (variant, layout, THP); `make_assets.py` shows variant `opt`, THP on.
In the optimised build both halves of the split advec_mom kernel count under the PAPI region
`advec_mom` (696 calls) and `reset_field`/`revert` have no C region (field swap).

### Baseline jobs (rerun only if the machine or the toolchain changes)

```bash
sbatch perf/smoke.sh                              # ~1 min; then cat perf/results/smoke_<id>.log
sbatch perf/jobs/m3_stream_ddrc.sbatch            # write-allocate + hardware STREAM ceiling (~15 min)
STREAM_HW_GBS=266.5 sbatch perf/jobs/m3_baseline.sbatch   # 5 layouts x THP on/off x 5 reps, Fortran ref (~40 min)
```

**Run everything with `sbatch`, never `srun bash job`:** a second MPI program inside one
`srun` step hangs in `MPI_Init` on HAICGU (seen 2026-10-12). `srun` is fine for non-MPI
commands (`build.sh`, `lscpu`). All jobs are independent and can be queued at once.

Every M3 job writes `perf/results/<job>_<id>/` with `system.txt` (lscpu, numactl, THP,
modules), `environment.txt` (binary md5, variant, build info), `results.csv` (one row per
repetition: wall, grind, QA deviation, `dram_GB`, `busiest_over_mean`, `variant`), `profiler.csv`,
`summary.txt`/`summary.md`, and per case `rep<i>.out`, `rep<i>.log`, `rep<i>.ddrc.csv`.
`m3_opt` and `m3_correctness` nest one such directory per variant (`layouts/<v>/`, `ladder/<v>/`, `<v>/`).

Other analysis commands (Python 3; matplotlib only for the figures):

```bash
python3 -I perf/analysis/plan_bytes.py --csv report/data/plan.csv
python3 -I perf/baseline/summarize.py perf/results/m3_opt_<id>/layouts/opt --md --stream-hw-gbs 266.5
python3 -I perf/baseline/qa_check.py perf/results/m3_correctness_<id>/opt/results.csv perf/archive/m3/correctness_baseline.csv
python3 perf/roofline/roofline.py --machine perf/archive/roofline/roofline-34735/machine.csv \
    --machine perf/archive/roofline/roofline-34746/machine.csv \
    --results perf/results/m3_opt_<id>/layouts/opt --kernels c --hw --hw-roof 266.5
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
