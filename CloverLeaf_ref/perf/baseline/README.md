# CloverLeaf baseline harness

Measures C versus Fortran kernels for a matrix of rank/thread layouts with
mpirun and records wall time, grind time, QA deviation and the profiler split.

    ./baseline.sh                              # matrix.laptop, 5 reps, results/
    OUT_DIR=/scratch/$USER/run1 ./baseline.sh my.matrix
    ./run_case.sh c 1 8 clover_bm16_short.in   # a single case
    python3 -I summarize.py results --md       # re-summarise, markdown tables

On HAICGU (https://haicgu.github.io/): on the dev node `guoehi-dev` run
`module load GCC OpenMPI`, build with `make clean && make COMPILER=GNU` (same
Kunpeng 920 CPU as the compute nodes, so `-march=native` is safe), then
`sbatch perf/baseline/baseline.sbatch` from `CloverLeaf_ref/` (or the M3 wrappers in
`perf/jobs/`). It writes to `perf/results/<jobname>_<jobid>/`. mpirun reads the
allocation from Slurm. The binary defaults to `perf/bin/clover_base` (`perf/build.sh`).

Files: `lib.sh` (deck generation, mpirun launch, output parsing),
`run_case.sh` (one case, N reps), `baseline.sh` (matrix driver + summary),
`summarize.py`, `qa_check.py` (correctness gate against `../archive/m3/correctness_baseline.csv`),
`matrix.laptop` (4 quick laptop cases), `matrix.cluster` (M1 sweep, 16 cases), `matrix.m3`
(M3 baseline: 5 layouts x THP on/off + Fortran reference), `matrix.correctness`, `matrix.papi`,
`baseline.sbatch` (HAICGU Slurm wrapper around `baseline.sh`: builds `nothp`, detects the DDRC events).

Matrix lines are `KERNELS RANKS THREADS [DECK] [THP]` (THP `on`, default, or `off`: every rank
runs under the `nothp` launcher, tag suffix `_thpoff`). The deck is copied, any
`use_*_kernels`, `profiler_on` and `visit_frequency` lines are stripped, and
the requested kernel keyword plus `profiler_on` are inserted, so one source
deck serves both kernel sets and no VTK output is ever written.

Placement: every rank is bound to THREADS consecutive cores
(`--map-by slot:PE=THREADS --bind-to core`) and OpenMP pins one thread per
core inside that set (`OMP_PROC_BIND=close OMP_PLACES=cores OMP_DYNAMIC=false`).
The OpenMP variables are forwarded to remote nodes with `-x`. Bindings are
written to each `rep<i>.log` by `--report-bindings`; check them once per
machine. A single rank (pure OpenMP, e.g. 1x128) cannot be bound this way:
OpenMPI refuses to bind one process across more than one package. That case
runs with `SINGLE_RANK_PLACEMENT` (default `--bind-to none`) and the OpenMP
runtime pins thread *i* to core *i* over the whole node. Its `rep<i>.log`
still shows "rank 0 bound to ... core 0": MPI_Init reports the main thread,
which libgomp has already pinned to place 0. The worker threads are on their
own cores; verify once with
`OMP_DISPLAY_AFFINITY=true MPIRUN_ARGS="--report-bindings -x OMP_DISPLAY_AFFINITY" ./run_case.sh fortran 1 128`.

Environment knobs: `CLOVER_BIN`, `DECK_DIR`, `REPS` (5), `OUT_DIR`,
`MPIRUN`, `MPIRUN_ARGS`, `SINGLE_RANK_PLACEMENT`, `OMP_PROC_BIND`, `OMP_PLACES`,
`OMP_DYNAMIC`, `NOTHP` (launcher for THP=off rows), `DDRC_EVENTS` (DDR-controller perf events:
every rep runs under `perf stat -a`, `results.csv` gets `dram_GB` and `busiest_over_mean`),
`OUTER_PREFIX` (wraps mpirun), `LAUNCH_PREFIX` (wraps each rank), `PROF_EVENTS` (PAPI build),
`STREAM_HW_GBS` (hardware STREAM ceiling for the summary's %-of-roof column).

Outputs in `OUT_DIR`: `environment.txt`, `results.csv` (one row per run: wall, grind, QA
deviation, `thp`, `dram_GB`, `busiest_over_mean`),
`profiler.csv` (one row per profiler section per run), `summary.txt` /
`summary.md`, and `<case>/rep<i>.out` + `rep<i>.log` for every run.
