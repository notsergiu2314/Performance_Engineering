# Notes for Performance Engineering project -- Jort

## Focus of this project

In this project, we focus on the C kernels of the cloverleaf_ref implementation. The reason for this, is time constraints. We are not familiar with FORTRAN, so focussing on only optimizing the C kernels saves time. The C kernels are ported from FORTRAN with the same structure, so optimizations made to these kernels could be ported back in the future without much difficulty.

We have chosen to benchmark on the `clover_bm_short.in` input deck. Our initial base benchmarking was done across the following input decks:

- `clover_bm_short.in`
- `clover_bm16_short.in`
- `clover_bm.in`

`clover_bm16_short.in` proved the best for benchmarking, since execution time was short enough to efficiently benchmark different parralellization configurations, while being long enough to measure computation performance instead of parralellization overhead. It generally produced consistent results with a low spread. This deck will be used in the rest of the performance analysis for determining the optimal configuration, identifying the performance-critical kernels, and finally for the benchmark comparison between the baseline and the modified kernels.

For verifying correctness of the results, the `clover_bm.in` deck is run once for the best configuration, and its results are compared to the reference using the built-in functionality from cloverleaf.

## Baseline Benchmark

The baseline benchmark was done on the `clover_bm_short.in` deck, and was run for both the FORTRAN and C kernels for completeness. We will solely be focussing on improving the C kernel performance for this project.

The results can be seen in the tables below:

### Parralellism results

C relative to Fortran (best wall, ratio > 1 means C slower)

| deck | ranks | thr | fortran_s | c_s | c/fortran |
|---|---|---|---|---|---|
| clover_bm16_short.in | 1 | 128 | 13.708 | 21.942 | 1.601 |
| clover_bm16_short.in | 128 | 1 | 9.636 | 11.626 | 1.207 |
| clover_bm16_short.in | 16 | 8 | 9.455 | 11.456 | 1.212 |
| clover_bm16_short.in | 2 | 64 | 13.552 | 16.566 | 1.222 |
| clover_bm16_short.in | 32 | 4 | 9.435 | 11.390 | 1.207 |
| clover_bm16_short.in | 4 | 32 | 10.635 | 13.051 | 1.227 |
| clover_bm16_short.in | 64 | 2 | 9.314 | 11.233 | 1.206 |
| clover_bm16_short.in | 8 | 16 | 10.431 | 12.464 | 1.195 |

### Kernel results (for r=64, t=2)

| section | clover_bm16_short_fortran_r64_t2 | clover_bm16_short_c_r64_t2 |
| --- | --- | --- |
| Timestep           | 0.53 (6%) | 0.67 (6%) |
| Ideal Gas          | 0.41 (4%) | 0.50 (4%) |
| Viscosity          | 0.34(4%) | 0.36 (3%) |
| PdV                | 1.17(13%) | 1.32 (12%) |
| Revert             | 0.19(2%) | 0.19 (2%) |
| Acceleration       | 0.55(6%) | 0.56 (5%) |
| Fluxes             | 0.40(4%) | 0.38 (3%) |
| Cell Advection     | 1.78(19%) | 2.43 (22%) |
| Momentum Advection | 3.39(36%) | 4.22 (38%) |
| Reset              | 0.34(4%) | 0.33 (3%) |
| Self Halo Exchange | 0.00(0%) | 0.00 (0%) |
| MPI Halo Exchange  | 0.19(2%) | 0.23 (2%) |
| Total              | 9.31(100%) | 11.23 (100%) |

## Performance critical kernels
From the initial benchmarking, we have observed that 


## Running on cluster

Cluster: HAICGU, Goethe University Frankfurt (https://haicgu.github.io/).
Standard compute node = Huawei TaiShan 200 (2280): **2 x Kunpeng 920 (ARMv8
AArch64), 64 cores per socket = 128 physical cores, no SMT**, 2.6 GHz, 128 GB
RAM, EDR InfiniBand. Expected 4 NUMA domains of 32 cores (2 dies per socket);
confirm in `environment.txt` / the job log. Site STREAM: ~140 GB/s triad per
node (128 threads). Rocky Linux 8, Slurm, EasyBuild modules (stage 2022a).

- Login/dev node: `guoehi-dev` (same Kunpeng 920 CPU as the compute nodes).
- Partitions: `cn-ib` (default, cn09-18, InfiniBand), `cn-eth` (cn19-28, RoCE).
  Never `cn-kube`. Time limits are unlimited.
- Modules: `module load GCC OpenMPI` (documented: `GCC/12.1.0`, `OpenMPI/4.1.3`,
  the only MPI). The module stack is hierarchical: OpenMPI appears only after GCC.
- Filesystems: `/home` (NFS, 8 TB), `/mnt/lustre-storage` (Lustre, 36 TB).
  There is no `$SCRATCH`. Baseline output is a few MB, so `~/clover-runs/` is fine.
- Observed: a 1x64 run bound to `package[0][core:0-63]`, i.e. exactly one
  socket of the 128-core node, so the harness sees the full node.

Harness: `perf-investigation/baseline/` (`baseline.sh`, `run_case.sh`, `lib.sh`,
`summarize.py`, `matrix.cluster`, `baseline.sbatch`; see its README). mpirun only.

1. Copy the source tree and the harness to the cluster. Do **not** copy the
   laptop binary: it is x86-64 and the cluster is AArch64.

```bash
rsync -av --exclude='*.o' --exclude='*.mod' --exclude='clover_leaf' \
      --exclude='*.vtk' --exclude='clover.out' --exclude='results/' \
      ~/Performance_Engineering/cloverleaf/ guoehi-dev:~/cloverleaf/
```

2. Build on `guoehi-dev` (same CPU as the compute nodes, so `-march=native`
   is safe there). No `OMPI_CC` override is needed.

```bash
module load GCC OpenMPI
cd ~/cloverleaf/cloverleaf_b5e598d
make clean && make COMPILER=GNU          # COMPILER=GNU is mandatory, see CLAUDE.md
```

3. Placement check once, then read the bindings. Four ranks of 32 cores
   should land on four distinct core ranges (one per NUMA domain); nothing
   may say "not bound".

```bash
cd ~/cloverleaf/perf-investigation/baseline
REPS=1 OUT_DIR=~/clover-runs/check ./run_case.sh fortran 4 32
grep "bound to" ~/clover-runs/check/*/rep1.log
```

4. Submit the full baseline from `guoehi-dev`, **from inside the baseline
   directory** (the script finds the harness via `$SLURM_SUBMIT_DIR`; or set
   `BASELINE_DIR=...`):

```bash
cd ~/cloverleaf/perf-investigation/baseline
sbatch baseline.sbatch                   # matrix.cluster, 5 reps per case, ~1 h
REPS=3 sbatch baseline.sbatch            # quicker first pass
sbatch baseline.sbatch my.matrix         # other matrix file
squeue --me
```

   Results: `~/clover-runs/baseline-<jobid>/` with `summary.txt` /
   `summary.md`, `results.csv` (one row per run), `profiler.csv`,
   `environment.txt`, and every `clover.out` + mpirun log per case.
   The job log (`clover-baseline-<jobid>.log`) starts with `lscpu` topology
   and a 4-rank binding report.

What the job requests: partition `cn-ib`, one exclusive node, 128 tasks x 1 cpu
(so mpirun sees 128 slots), 2 h limit. Every rank is bound to THREADS
consecutive cores (`--map-by slot:PE=THREADS --bind-to core`), OpenMP pins one
thread per core (`OMP_PROC_BIND=close OMP_PLACES=cores OMP_DYNAMIC=false`).

`matrix.cluster` (24 cases, all with a QA check; `clover_bm64*.in` have no
reference answer and are left out):

| deck | mesh / steps | layouts (ranks x threads) | kernels |
|---|---|---|---|
| `clover_bm_short.in` | 960^2, 87 | 1x128, 2x64, 4x32, 16x8, 128x1 | fortran, c |
| `clover_bm16_short.in` | 3840^2, 87 | 1x128, 2x64, 4x32, 16x8, 128x1 | fortran, c |
| `clover_bm.in` | 960^2, 2955 | 128x1, 4x32 | fortran, c |

Layout meaning: 1x128 pure OpenMP across both sockets, 2x64 one rank per
socket, 4x32 one rank per NUMA domain, 16x8 hybrid, 128x1 pure MPI.
`clover_bm16_short.in` is the main baseline at this scale (memory-bound
regime); `clover_bm_short.in` is small here (~7k cells per rank at 128x1) and
serves as the cross-run reference; `clover_bm.in` is the parallel-correctness
test (shock crosses every chunk boundary).

Laptop reference (Ryzen 7 5825U, 8 cores, bm_short, best of 5): Fortran 5.4 s,
C 6.4 s in both 1x8 and 8x1; C is ~20 % slower, almost all of it in Cell
Advection (+42 %) and Momentum Advection (+23 %). Both pass QA at 4e-12 %.
Full tables in `baseline/results/summary.md`. Expect the C/Fortran ratio to
differ on Kunpeng 920 (different compiler version, NEON instead of AVX2).

## Roofline model (perf-investigation/roofline/)

Ceilings are measured on the node (`machine.sbatch`: STREAM-style copy/scale/add/triad/read
and an FP64 FMA peak at core / NUMA / socket / node scope) next to the theoretical lines
(8 x DDR4-2666 = 170.6 GB/s per socket, 341 GB/s per node; 2.6 GHz x 8 FLOP/cycle x 128 =
2662 GFLOP/s). Points are one per profiler section for the fastest bm16_short layout of
each kernel set, with FLOPs and DRAM bytes per step from `kernel_model.py` (one row per
loop nest, audited against the C kernels; 24.8 GB and 6.6 GFLOP per step at 3840^2,
AI 0.27 FLOP/B, momentum advection 41% of the bytes). See the README there for the
recipe, the assumptions and the verification checklist.

Recipe: rsync the tree, `cd perf-investigation/roofline && sbatch machine.sbatch` on
guoehi-dev, copy `~/clover-runs/roofline-<jobid>` into `roofline/results/`, then on the
laptop `.venv/bin/python roofline.py --machine results/roofline-<jobid>/machine.csv
--results ../baseline/results/baseline-cluster` (add `--write-allocate` for hardware bytes).

```bash
rsync -r --exclude='clover.out' --exclude='results/' --exclude='bin/' ~/Performance_Engineering/cloverleaf/ guoehi-dev:~/cloverleaf/
```

```bash
cd ~/cloverleaf/perf-investigation/roofline && sbatch machine.sbatch
```

```bash
roofline.py --machine results/roofline-<jobid>/machine.csv --results ../baseline/results/baseline-cluster
```

To combine results for partial runs:
```bash
python roofline.py --machine results/roofline-<old>/machine.csv --machine results/roofline-<newjob>/machine.csv --results ../baseline/results/baseline-cluster
```

Cluster ceilings (job 34735, cn15, 2026-10-12): STREAM-style triad 263 GB/s per node
(77% of the 341 GB/s theoretical), 132 per socket, 65.5 per NUMA domain, 13 per core;
copy 264, read 296 GB/s; spread under 1%. The site's quoted 140 GB/s is wrong by ~2x.
FP64 peak, settled by job 34746 (cn18, `matrix.peak`): 10.40 GFLOP/s per core, 332.5
per NUMA domain, 664.7 per socket, 1329 per node, spread 0.0% and identical per thread
at every scale. That is exactly 4 FLOP/cycle at 2.6 GHz: the Kunpeng 920 (TaiShan v110)
core retires one 128-bit FP64 FMA per cycle, half of the 8 FLOP/cycle first assumed.
`machine.haicgu.env` now has `FLOP_PER_CYCLE=4` (theoretical 1331 GFLOP/s per node,
99.9% reached). Two earlier runs (34735, 34739) reported 6.2 GFLOP/s per core: the
disassembly showed GCC 14 compiling `v = v*x + y` to `fmla` with `y` moved into the
destination and the result moved back, two SIMD moves per FMA on the same pipes.
`peak_fma.c` uses the accumulate form `v = v + v*x` since, and `build.sh` writes the
hot loop into `build.log`. The site's own STREAM (141 GB/s, 80M elements, no pinning)
is half of ours; its HPL (722 GFLOP/s at 8x16, "not optimised") is 54% of the peak.
Ridge point of the node: 1329 / 263 = 5.1 FLOP/B; every CloverLeaf section has AI <= 1,
so the compute roof plays no role.

Roofline findings (bm16_short, 64x2, best rep; `roofline/results/roofline_bm16_short.*`):
the Fortran step runs at 232 GB/s of modelled traffic = 88% of STREAM triad; momentum
and cell advection are at 99%, PdV 87%, the copy kernels Revert/Reset at 84%/92% of
STREAM copy. Fortran is bandwidth-bound: the only lever is fewer bytes (dead stores
post_vol/pre_vol, work arrays, sweep fusion; cf. the `patches/` series). The C kernels
run the same traffic 20-28% slower in the advection kernels (72-80% of the roof) and
40% slower in Timestep/Ideal Gas, which is an instruction-side deficit (the advection
flux sweeps have no `omp simd` and data-dependent indexing), so C has headroom to catch
Fortran before byte reduction is needed.

Laptop smoke test (2026-10-12): FMA peak 386 GFLOP/s at 8 threads (all-core 3.1 GHz),
64 GFLOP/s on one core at 4.0 GHz; bandwidth copy 19 / triad 21 / read 30 GB/s. The
pipeline runs end to end on `baseline-laptop`, but at 960^2 two arrays fit in the 16 MB
L3, so most sections sit above the measured bandwidth roof there; only the cluster run
at 3840^2 is meaningful.

## FLOP and byte analysis per kernel (kernel_model.py, 3840^2, one time step)

Method: one row per loop nest in the C kernels (the Fortran kernels have the same loop
structure), counting the distinct arrays each sweep streams (8 B/element, stencil
neighbours count once, 1-D arrays ignored) and the floating-point operations per element
on the common path. Arrays are 118 MB each at 3840^2, so every sweep comes from DRAM.
Reproduce with `python3 -I roofline/kernel_model.py --x 3840 --y 3840 --audit`.

| section | sweeps/step | GFLOP/step | GB/step | AI FLOP/B | % of bytes | achieved, Fortran / C (% of STREAM) |
|---|---|---|---|---|---|---|
| Momentum Advection | 24 | 1.95 | 10.16 | 0.19 | 41.0 | 99 / 80 |
| Cell Advection | 6 | 1.15 | 5.31 | 0.22 | 21.4 | 99 / 72 |
| PdV | 2 | 1.18 | 3.07 | 0.39 | 12.4 | 87 / 77 |
| Timestep (calc_dt) | 2 | 0.66 | 1.18 | 0.56 | 4.8 | 73 / 58 |
| Acceleration | 1 | 0.56 | 1.18 | 0.48 | 4.8 | 71 / 69 |
| Ideal Gas | 2 | 0.32 | 0.94 | 0.34 | 3.8 | 76 / 62 |
| Fluxes | 2 | 0.18 | 0.94 | 0.19 | 3.8 | 78 / 82 |
| Reset | 4 | 0 | 0.94 | 0 | 3.8 | 92 / 94 (vs copy) |
| Viscosity | 1 | 0.61 | 0.59 | 1.03 | 2.4 | 58 / 55 |
| Revert | 2 | 0 | 0.47 | 0 | 1.9 | 84 / 84 (vs copy) |
| **Total** | 46 | 6.61 | 24.79 | 0.27 | 100 | 88 / 73 |

Every kernel has AI <= 1 FLOP/B against a ridge point of 5.1 FLOP/B (1329 GFLOP/s /
263 GB/s), i.e. the whole code is firmly memory-bound; the
FLOP counts (+-30%) only matter for the vertical position of the points, not for the
distance to the bandwidth roof.

Per kernel (reads / writes are distinct arrays per sweep, calls per step in brackets):

- **Momentum advection** [4 calls: xvel and yvel for each sweep direction], 6 sweeps per
  call. pre/post_vol over the whole (X+5)(Y+5) array: 3r/2w, 2-4 flop; node_flux 1r/1w,
  4 flop; node_mass_post 2r/1w, 8 flop; node_mass_pre 2r/1w, 2 flop; mom_flux 3r/1w,
  10 flop on the cheap path, 26 with the limiter (upwind indexing, no `omp simd`);
  velocity update 4r/1w, 4 flop. Dominant because of volume, not arithmetic: 10.2 GB per
  step for 1.9 GFLOP. Waste visible in the counts: `pre_vol` is written and never read
  (dead store, 1 of the 5 arrays of sweep A), and the xvel and yvel calls of the same
  sweep recompute identical pre/post_vol, node_flux, node_mass_post and node_mass_pre
  (only mom_flux and the update depend on the velocity), so 4 of the 6 sweeps run twice
  for nothing: ~3.3 GB of the 10.2 are repeat work.
- **Cell advection** [2 calls, one per direction], 3 sweeps per call. pre/post_vol over
  (X+5)(Y+5): 3r/2w (sweep 1) or 2r/2w (sweep 2), 2-6 flop, `post_vol` never read (dead
  store); flux sweep 4r/2w over (X+3)Y, 21 flop cheap / 51 with both limiters (upwind
  indexing, no `omp simd`); update sweep 6r/6w, 10 flop, writes four work arrays
  (pre_mass, post_mass, post_ener, advec_vol) that are only consumed inside the same
  iteration, so 4 of its 6 stores are avoidable.
- **PdV** [2: predictor + corrector], one fused sweep: 9 (predictor) / 11 (corrector)
  reads, 3 writes (energy1, density1, volume_change = work_array1 which is only reused
  in-iteration), ~40 flop (4 face fluxes of 3 add + 4 mul, 4 divisions). The predictor
  reads xvel0/yvel0 twice in the same expression and `min_cell_volume` is dead code
  (eliminated by the compiler).
- **Timestep / calc_dt** [1], 8r/1w, ~44 flop (6 div, 1 sqrt, min/max chain), then a
  second sweep re-reads dt_min for the min reduction (1r, 0.12 GB) that could be fused.
- **Acceleration** [1], one fused node sweep (X+1)(Y+1), 8r/2w, ~38 flop
  (nodal mass 8, 4 velocity updates of ~7).
- **Ideal gas** [2: density0/energy0 in timestep, density1/energy1 after the PdV
  predictor, plus one extra call per summary], 2r/2w, ~11 flop incl. 1 div and 1 sqrt.
- **Fluxes** [1], two face sweeps, 3r/1w each, 6 flop.
- **Viscosity** [1], 4r/1w (pressure 5-point, velocities 2x2), ~41 flop incl. ~6 div on
  the common path; highest AI of the code (1.0) and still memory-bound.
- **Reset** [1] four copies and **Revert** [1] two copies: 0 flop, 1.4 GB per step of
  pure copying. Reset could be removed by pointer-swapping the 0/1 field pairs; Revert
  exists only because the PdV predictor writes density1/energy1 that the corrector then
  overwrites (cf. patches 02 and 03 in `patches/`).

Byte-reduction potential that the counts expose (per step, out of 24.8 GB): dead stores
`pre_vol`/`post_vol` 1.6 GB; repeated advec_mom sweeps 3.3 GB; advec_cell intermediate
work arrays 1.9 GB; Reset/Revert copies 1.4 GB; calc_dt reduction re-read 0.1 GB.
Together ~8 GB, i.e. about a third of the traffic, which at the measured 263 GB/s is
worth ~30 ms of the 107 ms Fortran step.

## TODO

- run base benchmark on cluster
- determine best parralellism parameters
- Identify performance-critical kernels
- 