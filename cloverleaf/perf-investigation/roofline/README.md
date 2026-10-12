# CloverLeaf roofline harness

Builds a roofline model of CloverLeaf on one node: measured ceilings (STREAM-style
bandwidth and FP64 FMA peak) plus theoretical ones, and one point per profiler section
with the arithmetic intensity taken from an analytical count of the kernel sweeps.

    ./build.sh                                   # compile src/membw.c, src/peak_fma.c into bin/
    ./machine.sh [matrix.machine]                # run the ceilings matrix -> $OUT_DIR/machine.csv
    python3 -I kernel_model.py --x 3840 --y 3840 --audit    # FLOP / byte table per section
    ../../../.venv/bin/python roofline.py --machine results/roofline-<job>/machine.csv \
        --results ../baseline/results/baseline-cluster      # -> results/roofline_bm16_short.{csv,png,_bw.png}

On HAICGU: `rsync` this directory to `guoehi-dev` (the baseline rsync command in
`../jort_notes.md` covers it), then from this directory `sbatch machine.sbatch`. The job
builds on the compute node, runs `matrix.machine` (bandwidth at 1/32/64/128 threads,
FMA peak at 1/64/128) and writes `~/clover-runs/roofline-<jobid>/`. Copy that directory
into `results/` and run `roofline.py` on the laptop. The roofline points come from the
baseline results (`../baseline/results/baseline-cluster`), not from this job.

## Files

- `lib.sh` sources `../baseline/lib.sh` (mpirun launch, OpenMP pinning) and adds the
  benchmark knobs. `build.sh` compiles and checks with `objdump` that the FMA loop became
  vector FMA instructions. `machine.sh` is the matrix driver; `machine_summary.py` reduces
  the raw runs and adds the theoretical rows from `machine.<profile>.env`.
- `src/membw.c`: copy, scale, add, triad and a pure read, OpenMP, first-touch init, best of
  NTIMES. Bytes counted the STREAM way (copy/scale 16 B, add/triad 24 B, read 8 B per
  element, no write-allocate). `src/peak_fma.c`: 12 independent FMA chains per thread on
  native-width vectors held in named variables, written in the accumulate form
  `v = v + v*x`. Two earlier versions under-reported Kunpeng 920 at 2.4 FLOP/cycle: an
  `acc[]` array, and then the form `v*x + y`, which GCC compiles to `fmla` with `y` loaded
  into the destination plus a copy back, two SIMD register moves per FMA that share the
  FMA pipes. `build.log` now contains the hot loop so this can be checked on any build.
- `matrix.machine` (HAICGU node), `matrix.peak` (FMA peak only, one minute, layered on a
  full run with a second `--machine`), `matrix.laptop` (8-core smoke test). Lines are
  `KIND THREADS PLACES SCOPE`; PLACES is an `OMP_PLACES` value (`{0}` one core, `{0}:32`
  NUMA domain 0, `{0}:64` socket 0, `cores` all), SCOPE is `core|numa|socket|node`.
- `machine.haicgu.env`, `machine.laptop.env`: GHz, FLOP/cycle, cores, memory channels.
- `kernel_model.py`: the sweep table, one row per loop nest with the kernel file and lines.
- `roofline.py`: picks the fastest layout per kernel set for the deck (lowest best wall, same
  rule as `summarize.py`), takes the best repetition's profiler times, divides by the steps
  actually run (last `Step N` line of `rep<i>.out`), and plots.

Knobs (env vars, defaults in `lib.sh`): `BIN_DIR`, `CC` (gcc), `CFLAGS`
(`-O3 -march=native -funroll-loops -fopenmp -ffp-contract=fast`), `ARRAY_ELEMS` (2^27
doubles = 1 GiB per array), `NTIMES` (20), `FMA_ITERS` (4e8), `REPS` (3), `OUT_DIR`,
`MACHINE_PROFILE` (haicgu|laptop), plus the baseline knobs `MPIRUN`, `MPIRUN_ARGS`,
`SINGLE_RANK_PLACEMENT`, `OMP_PROC_BIND`, `OMP_PLACES`, `OMP_DYNAMIC`.

## CSV schemas

- `machine_raw.csv`: `kind,quantity,threads,scope,rep,value,unit,host,date` (every run).
- `machine.csv`: `quantity,threads,scope,value,unit,source,note`. quantity in
  `stream_copy|stream_scale|stream_add|stream_triad|stream_read|peak_fma|peak_fma_per_thread|
  implied_ghz|peak_flops|dram_bw`; source in `measured|theoretical|site`.
- `roofline_<deck>.csv`: `tag,kernels,ranks,threads,x_cells,y_cells,steps,section,
  calls_per_step,time_per_step_s,flops_per_step,bytes_per_step,ai,gflops,gbs,frac_bw_roof,
  roof_gflops,frac_roof,write_allocate,scope`. `frac_bw_roof` = achieved GB/s over the
  measured STREAM triad (the number to read for a memory-bound kernel); `frac_roof` =
  GFLOP/s over `min(peak, AI x triad)`.

## Model assumptions

- Each sweep streams every array it touches once from DRAM: stencil neighbours count once,
  1-D arrays are ignored, dead stores (`post_vol` in advec_cell, `pre_vol` in advec_mom) are
  counted. Valid when the per-rank arrays do not fit in cache. At 3840^2 an array is
  118 MB; with 64 ranks it is 1.8 MB per rank against 0.5 MB L2 per core and 32 MB L3 per
  32-core NUMA domain, so some reuse between consecutive sweeps of one kernel is possible
  and the model is an upper bound on DRAM traffic.
- `--write-allocate` counts 16 B per stored element (read-for-ownership) and rescales the
  measured STREAM ceilings the same way (copy/scale x1.5, add/triad x4/3). On the Kunpeng
  920 this is refuted by the data: the rescaled copy ceiling would be 396 GB/s, above the
  341 GB/s bus limit, so the core does not fetch lines for these streaming stores
  (write-streaming) and the plain accounting is the right one there. Keep the flag for
  machines where copy x1.5 stays below the bus limit.
- FLOP counts are per element on the common path and carry maybe +-30%. For a
  memory-bound section an error in FLOPs moves the point along a line parallel to the
  bandwidth roof, so its distance to that roof (`frac_bw_roof`) is unaffected.
- Profiler times are the slowest rank's (`hydro.f90`), so a point is the slowest rank's
  rate against the whole node's ceiling. Load imbalance shows up as distance from the roof.
- Halo exchange, summary and "The Rest" have no mesh sweep and get no point; their share of
  the step is printed as "modelled sections N% of Total".

## Verification checklist

Machine (cluster):
- `peak_fma`: measured 10.40 GFLOP/s per core and 1329 GFLOP/s per node (job 34746,
  cn18, spread 0.0%), i.e. exactly 4 FLOP/cycle at 2.6 GHz: the Kunpeng 920 core retires
  one 128-bit FP64 FMA per cycle, not two as first assumed. `machine.haicgu.env` carries
  `FLOP_PER_CYCLE=4`, so the theoretical node peak is 1331 GFLOP/s and `implied_ghz`
  reads 2.6. `build.log` must report vector FMA instructions and its hot-loop listing
  must be `fmla` only, no `mov v..16b` between them (jobs 34735/34739 had 2 moves per
  FMA and reported 6.2 GFLOP/s per core). The site's own HPL (722 GFLOP/s at 8x16,
  "not optimised") is 54% of this peak.
- `stream_triad` node: measured 263 GB/s on cn15 (job 34735), 77% of the theoretical
  341 GB/s, with socket 132 and NUMA 65.5 GB/s, i.e. exactly half and a quarter; copy 264,
  read 296 GB/s; spread across reps under 1%. The site's quoted 140 GB/s is far too low
  and is drawn only as a reference line.

Model:
- Revert and Reset are pure copies and must sit near the STREAM copy ceiling in the
  bandwidth figure. Well above it: bytes over-counted or cache reuse. Well below: time
  the model does not see (fork/join, imbalance, NUMA misplacement). On the cluster
  (64x2, 3840^2) they reach 84% and 92% of STREAM copy, so the model and the ceilings
  agree. Momentum and cell advection in Fortran reach 99% of STREAM triad, which is
  consistent with some L2/L3 reuse between the sweeps of one kernel (per-rank arrays are
  1.8 MB at 64 ranks): treat those two as at the bandwidth roof.
- Fortran and C points of one section share the same AI; their vertical gap is the
  per-section C/Fortran ratio and must match `summary.md`.
- "Kernels only" vs "Whole step" shows the halo/other share.

Laptop smoke test (`MACHINE_PROFILE=laptop ./machine.sh matrix.laptop`, then
`roofline.py --results ../baseline/results/baseline-laptop --deck clover_bm_short.in`):
exercises the whole pipeline. Its numbers are not a roofline of anything useful: at 960^2
each array is 7.4 MB and the 16 MB L3 holds two of them, so most sections appear above the
measured bandwidth roof. The laptop bandwidth measured here (copy 19, triad 21, read 30
GB/s STREAM-counted, about 30 GB/s of hardware traffic) is what a threaded `memcpy` also
gives; the 45-52 GB/s in `lab_2` could not be reproduced and exceeds the 51.2 GB/s bus
limit once read-for-ownership is included.
