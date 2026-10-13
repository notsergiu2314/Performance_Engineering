# Performance engineering of CloverLeaf_ref on HAICGU (Kunpeng 920)

Branch `project`, based on `b5e598d` (the commit named in the work plan).
Baseline = unmodified C kernels (`use_c_kernels`), GCC 14.1.0 (HAICGU default module) `-O3 -march=native
-funroll-loops -fopenmp`, plus `-g` for perf annotate.

## What is in here

| Path | Purpose |
|---|---|
| `kernels/papi_prof.[ch]` | Per-kernel PAPI counters. `PROF_BEGIN/END` sit inside each C kernel's `omp parallel` region; without `make PAPI=1` they compile to nothing. |
| `perf/inputs/bm3840.in` | Main deck: 3840², 87 steps, `test_problem 4` (prints PASSED if the final kinetic energy matches the reference, so it is the correctness check for every build). ~3.5 GB, so memory resident. |
| `perf/inputs/bm960.in` | 960², 87 steps, ~0.2 GB: partly fits in the 2 × 64 MB L3, for contrast. |
| `perf/env.sh`, `perf/build.sh` | Modules and builds `perf/bin/clover_base`, `perf/bin/clover_papi`, vectorisation reports, `build_info.txt`. |
| `perf/install_papi.sh` | Private PAPI install, only if there is no PAPI module. |
| `perf/jobs/m1_*.sbatch` | M1: internal profiler scaling, perf, PAPI. |
| `perf/jobs/m2_*.sbatch` | M2: STREAM sweep, peak FLOP microbenchmark. |
| `perf/microbench/peak_flops.c` | Vector FMA / scalar FMA / vector divide throughput (compute ceilings). |
| `perf/analysis/*.py` | Parsers, the analytic kernel model, and the roofline. |

## Runbook

All commands from the repository root on the HAICGU login node.

```bash
mkdir -p perf/results
. perf/env.sh && command -v papi_avail || \
  srun -p cn-ib -N 1 -t 00:30:00 bash perf/install_papi.sh   # only if no PAPI module
srun -p cn-ib -N 1 -t 00:20:00 bash perf/build.sh            # build on a compute node

# smoke test first (about a minute)
sbatch perf/smoke.sh               # then: cat perf/results/smoke_<jobid>.log

# M1 - initial profiling
sbatch perf/jobs/m1_baseline.sbatch   # internal timers, 1..128 threads, MPI layouts
sbatch perf/jobs/m1_perf.sbatch       # perf record/annotate/stat (+ DDR counters)
sbatch perf/jobs/m1_papi.sbatch       # PAPI per kernel, several event sets

# M2 - performance modelling
sbatch perf/jobs/m2_stream.sbatch     # memory ceiling
sbatch perf/jobs/m2_peak.sbatch       # compute ceilings
```

**Run everything with `sbatch`, not `srun bash ...`:** a second MPI program started inside one
`srun` step hangs in `MPI_Init` on HAICGU (seen with the PAPI build, 2026-10-12). `srun` is fine for
non-MPI commands (`lscpu`, `build.sh`).

The jobs only need `--exclusive` nodes and are independent, so all five can
be queued at once. Every run directory holds `meta.txt`, `clover.in`,
`clover.out` and `stdout.txt`; every job writes `system.txt` (lscpu, numactl,
perf_event_paranoid, ...) for the report's "systems used" section.

Then, on any machine with Python 3 + matplotlib:

```bash
python3 perf/analysis/clover_profile.py perf/results/m1_baseline_<id> --csv m1.csv
python3 perf/analysis/kernel_model.py
python3 perf/analysis/roofline.py --profile-csv m1.csv --deck bm3840 --config 1x128 \
    --bw <STREAM triad GB/s> --peak <vfma GFLOP/s, 128 thr> \
    --scalar <sfma> --div <vdiv> --plot roofline.pdf
python3 perf/analysis/roofline.py --papi-dir perf/results/m1_papi_<id>/ipc/1x128 --bw ... --peak ...
```

## Correctness checks of the tools (required by the assignment)

1. **QA**: every run must say `PASSED` (`clover_profile.py` prints a QA column);
   the PAPI build must give the same answer as the base build.
2. **Timers vs PAPI**: per-kernel PAPI region times must match the internal
   profiler categories (`PdV` = `pdv_predict + pdv_correct`, etc.).
3. **PAPI vs perf**: total `PAPI_TOT_CYC`/`PAPI_TOT_INS` over all regions
   should be slightly below the `perf stat` whole-run `cycles`/`instructions`
   (perf also sees init and halo code).
4. **Clock**: `GHz` in `papi_summary.py` (cycles / time) should be ~2.6.
5. **Overhead**: `m1_papi` reruns the base binary; wall clock difference =
   instrumentation overhead.
6. **DDR counters**: calibrated on STREAM (known bytes) before they are used
   on CloverLeaf. Their ratio to the model with and without write-allocate tells
   which traffic model holds on the Kunpeng cores.

## Model (analytic, `kernel_model.py`)

Bytes and flops per cell were counted from the C kernel source; assumptions
are in the file header. Per timestep, over all kernel calls:

| | flop/cell | byte/cell | AI (flop/B) |
|---|---|---|---|
| no write-allocate | 451 | 1688 | 0.27 |
| with write-allocate | 451 | 2186 | 0.21 |

All kernels are at 0.13–1.0 flop/byte, an order of magnitude below any
plausible ridge point, so the expectation is memory bound everywhere.
**Prediction to check**: bm3840 moves 1688–2186 B × 14.7 M cells × 87 steps =
2.2–2.8 TB. At a STREAM bandwidth B (GB/s), the full-node kernel time can't
drop below 2200/B to 2800/B seconds (≈ 9–11 s at 250 GB/s).

## Leads for M3 seen while building the model

- `advec_mom` runs 4×/step; its first 4 loops (`post_vol`, `node_flux`,
  `node_mass_post`, `node_mass_pre`) only depend on the direction, so they are
  computed twice (once for `xvel`, once for `yvel`). Hoisting them saves traffic.
- Stored but never read: `post_vol` in `advec_cell`, `pre_vol` in `advec_mom`.
- Temporaries stored to memory: `pre_mass`, `post_mass`, `post_ener`,
  `advec_vol` in `advec_cell`; loop fusion would keep them in registers.
- `calc_dt` writes `dt_min` and re-reads it for the reduction: fuse the loops.
- Upwind loops (`advec_cell` loop 2, `advec_mom` loop 4) use data-dependent
  indices and have no `omp simd`: check `perf/bin/vec_report.txt` and the
  annotated assembly from `m1_perf`.
- Write-allocate evasion (Laukemann et al. 2023, cited in the course
  tutorial) is relevant if the DDR counters show write-allocate traffic.
