# Notes for Performance Engineering project -- Jort

## Focus of this project

In this project, we focus on the C kernels of the cloverleaf_ref implementation. The reason for this, is time constraints. We are not familiar with FORTRAN, so focussing on only optimizing the C kernels saves time. The C kernels are ported from FORTRAN with the same structure, so optimizations made to these kernels could be ported back in the future without much difficulty.

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

## TODO

- run base benchmark on cluster
- determine best paralellism parameters
- Identify performance-critical kernels
- 