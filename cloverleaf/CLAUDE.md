# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`CloverLeaf/` is a checkout of the UK-MAC CloverLeaf mini-app (2D structured-grid Lagrangian-Eulerian explicit hydrodynamics, Fortran 90 + C, GPLv3). Each `CloverLeaf_*` directory is a separate **git submodule** with its own history. The work here is performance engineering on **`CloverLeaf/CloverLeaf_ref`** — the hybrid MPI+OpenMP reference version (v1.3) from which Serial/OpenMP/MPI variants are derived. Ignore the other variants unless asked. The outer `/home/jort/cloverleaf` directory is not itself a git repo; commit inside `CloverLeaf/CloverLeaf_ref`.

All commands below are run from `CloverLeaf/CloverLeaf_ref/`.

## Build

```sh
make clean && OMPI_CC=gcc-13 make COMPILER=GNU        # optimised, OpenMP on
OMPI_CC=gcc-13 make COMPILER=GNU DEBUG=1              # -O0 -g -fbounds-check
OMPI_CC=gcc-13 make COMPILER=GNU IEEE=1               # -ffloat-store, for bitwise reproducibility work
OMPI_CC=gcc-13 make COMPILER=GNU OPTIONS="-fopt-info-vec-missed" C_OPTIONS="..."   # extra Fortran / C flags
```

Things that will bite you:

- **Always pass `COMPILER=GNU`.** Without it there is no `-fopenmp`, and because of a missing newline at the end of the `FLAGS_XL` line in the Makefile, `FLAGS_` is never defined — the Fortran is compiled with *no optimisation flags at all* (C still gets `-O3`). A plain `make` gives a silently slow, single-threaded binary.
- **`OMPI_CC=gcc-13`**: on this machine `/usr/bin/gcc` is currently a GCC 15.2.1 driver with no `cc1` (`gcc: fatal error: cannot execute 'cc1'`), so `mpicc` fails. Pointing OpenMPI's wrapper at `gcc-13` (matches gfortran 13.3) works. Drop this if `gcc --version` reports 13.x again.
- **Always `make clean` when changing flags.** The Makefile has no per-file dependency tracking: one rule compiles all C kernels to `.o` in the top dir, a second compiles every `.f90` in one `mpif90` invocation in a hand-ordered list (module dependency order — new Fortran files must be inserted in the right place, new C kernels added to both lists).
- `CFLAGS_GNU` carries a local `-fPIE` addition (uncommitted; Ubuntu's gfortran links PIE by default, so the C objects must be PIC/PIE); keep it.
- There is no linter and no unit-test suite. Validation is the built-in QA check below.

## Run, validate, measure

The binary takes no arguments; it reads `./clover.in` and writes `./clover.out` (stdout/stderr only get progress). If `clover.in` is missing it *creates* a tiny default deck and runs a sub-second self-test (`test_problem 1`). The checked-in `clover.in` is currently a locally modified 400x400 explosion demo with `visit_frequency=10` — it writes ~1.5 MB VTK files per rank per dump and is **not** a benchmark. Remove `visit_frequency` for any timing run.

```sh
cp InputDecks/clover_bm_short.in clover.in            # then add a line ` profiler_on` before *endclover
OMP_NUM_THREADS=8 OMP_PROC_BIND=close OMP_PLACES=cores mpirun -np 1 --bind-to none ./clover_leaf
OMP_NUM_THREADS=1 mpirun -np 8 --bind-to core ./clover_leaf
grep -A18 "Profiler Output" clover.out; grep "PASSED\|FAILED\|Wall clock" clover.out
```

Correctness gate: decks containing `test_problem N` compare final kinetic energy against a stored value in `field_summary.f90` and print `PASSED` if within 0.001%. Volume and mass must stay constant through a run; KE is the most sensitive quantity. Answers are *not* bitwise identical across compilers, flag sets, or Fortran-vs-C kernels — always re-run the QA deck after an optimisation and report the `is within ...%` figure, not just PASSED.

| Deck | Mesh | Steps | test_problem | Expected KE | Use |
|---|---|---|---|---|---|
| `clover_bm_short.in` | 960² | 87 | 2 | 0.1193E+01 | quick iteration (~5.5 s here) |
| `clover_bm.in` | 960² | 2955 | 3 | 0.2590E+01 | shock crosses all chunk boundaries — best parallel-correctness test |
| `clover_bm16_short.in` | 3840² | 87 | 4 | 0.3075E+00 | "socket" test, memory-bound regime |
| `clover_bm16.in` | 3840² | 2955 | 5 | 0.4854E+01 | long |

`clover_bmN*.in` are the weak-scaling series; `clover_bm_short_c.in` is the same as bm_short but with `use_c_kernels`.

Machine: Ryzen 7 5825U, 8 cores / 16 SMT threads, single socket, laptop with boost enabled (expect run-to-run noise from thermals/DVFS; repeat measurements). Use ≤8 compute threads total — SMT does not help this FP/memory-bound code, and ranks × threads > 16 oversubscribes (the last `clover.out` in the tree was 8 ranks × 4 threads, hence its poor grind time). Baseline with `COMPILER=GNU`, bm_short: 1×8 ≈ 5.5 s, 8×1 ≈ 5.9 s. Profile split: momentum advection ~36%, cell advection ~19%, PdV ~13%, everything else ≤6% each; halo exchange is negligible at this scale.

The code is memory-bandwidth-bound on this machine: bm_short wall time is flat from 2 to 8 threads (~7 s at 1 thread, ~5 s at 2–8). Optimisations pay off by removing array sweeps/streams (dead work, work arrays, 2D geometry arrays that are constant on the uniform mesh, cache-sized tiles), not by adding threads or FLOP-level tuning. `../../perf-investigation/` holds `bench.sh` (best-of-N harness with QA check) and a measured, result-preserving patch series from an earlier investigation (Fortran kernels only, not applied to the tree).

`clover.out` also prints per-step "Average time per cell" (grind time) — the standard cross-run metric. "First step overhead" is reported separately so start-up cost can be excluded on short decks.

Input-deck switches relevant to performance (parsed in `read_input.f90`): `use_fortran_kernels` (default) / `use_c_kernels`, `profiler_on`, `tiles_per_chunk`, `tiles_per_problem` (divided by rank count), `visit_frequency`, `summary_frequency`.

## Architecture

**Three-layer structure, per physics step:** control routine → driver (`X.f90`, module `X_module`) → kernel (`kernels/X_kernel.f90` and `kernels/X_kernel_c.c`). Drivers own all knowledge of the data structures, profiler timing, and halo-exchange requests; kernels are pure loop nests that receive bounds plus bare arrays. Every kernel exists twice (Fortran and C, selected at runtime by the deck), except `update_tile_halo_kernel` which is Fortran-only. **A change to a kernel's maths or loop structure must be mirrored in both languages**, and both should be QA'd (`clover_bm_short.in` and `clover_bm_short_c.in`).

**Main loop** (`hydro.f90`): `timestep` (ideal_gas → halo → viscosity → halo → calc_dt → `MPI_Allreduce` min) → `PdV` predictor (then ideal_gas, halo, revert) → `accelerate` → `PdV` corrector → `flux_calc` → `advection` → `reset_field`. `advection.f90` does a directionally split sweep — cell advection then x- and y-momentum advection in one direction, then the same in the other — and `advect_x` flips every step, so the x-first/y-first order alternates. Any per-step timing comparison should span an even number of steps.

**Data model** (`definitions.f90`): one `chunk` per MPI rank (2D block decomposition in `clover_decompose`), holding `tiles(1:tiles_per_chunk)`; each tile owns a `field_type` of separately allocated 2D `REAL(8)` arrays (structure-of-arrays, column-major, `j`=x inner / `k`=y outer). All arrays have a 2-cell halo: cell-centred `(x_min-2:x_max+2, y_min-2:y_max+2)`, node-centred (velocities, work arrays) `+3` in both, face-centred fluxes `+3` in one dimension. Kernels redeclare these explicit shapes on their dummy arguments; C kernels index the same memory through `FTNREF2D(j,k,stride,x_lb,y_lb)` in `kernels/ftocmacros.h`, where the stride (`x_max+4` vs `x_max+5`) must match the array's centring. Getting a stride wrong compiles fine and corrupts results.

`work_array1..7` are scratch arrays reused under different names by different kernels (aliases listed in comments in `definitions.f90`: `pre_vol`, `post_vol`, `node_flux`, `mom_flux`, …). v1.3 already replaced several work arrays with loop-private scalars and fused loops for cache efficiency; the advection kernels are where the remaining multi-pass, work-array-heavy structure (and most of the runtime) lives.

**Threading model:** OpenMP lives *inside* kernels — each kernel opens one `!$OMP PARALLEL` region with `!$OMP DO` on the outer `k` loop and `!$OMP SIMD` / `#pragma omp simd` (or `ivdep`) on the inner `j` loop. Drivers loop over tiles **serially**. Consequences: with `tiles_per_chunk>1` each tile is a smaller fork-join region rather than tiles running concurrently, and every kernel call is a separate parallel region (fork/join + implicit barriers between loops). First-touch NUMA placement is done in `build_field.f90` with the same `k`-loop static schedule, so changing a kernel's schedule or parallelised loop level breaks the locality assumption.

**Halo exchange** (`update_halo.f90`): callers set a `fields(NUM_FIELDS)` mask (indices `FIELD_*` in `data.f90`) and a depth (1 or 2), then three phases run in order, each separately profiled: (1) tile↔tile copies within the chunk (`update_tile_halo`), (2) MPI exchange (`clover_exchange` in `clover.f90`), (3) reflective physical boundaries (`update_halo_kernel`). The MPI phase aggregates all requested fields into one buffer per face (offset tables computed per call), does left/right `Isend/Irecv` + `MPI_Waitall`, then bottom/top — the ordering is what propagates corner cells, so the two phases cannot be merged or overlapped naively. `clover.f90` is ~3700 lines almost entirely because pack/unpack is written out per face × per field × Fortran/C kernel; the actual logic is in `clover_exchange` and `kernels/pack_kernel.*`.

**Reductions and sync points per step:** `clover_min(dt)` in `timestep`, `clover_check_error` after PdV, and `clover_sum` ×N in `field_summary` (only every `summary_frequency` steps). The profiler (`profiler_on`) uses wall-clock `timer()` around driver sections with no barriers, so MPI wait time caused by load imbalance shows up under whichever phase blocks first (usually "MPI Halo Exchange"); the final table reports the slowest rank's numbers.

## Repo hygiene

Runs drop `clover.out`, `clover.in.tmp`, `clover.visit` and `clover.*.vtk` into the run directory. `.gitignore` covers build products, `clover.in.tmp`, but **not** `*.vtk`, `clover.out` or `clover.visit` — there are currently ~400 MB of VTK files in `CloverLeaf_ref/`. Don't add them to commits; prefer running benchmarks from a scratch directory containing a copy/symlink of `clover_leaf` and a `clover.in`.
