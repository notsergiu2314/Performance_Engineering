# CloverLeaf baseline harness

Measures C versus Fortran kernels for a matrix of rank/thread layouts with
mpirun and records wall time, grind time, QA deviation and the profiler split.

    ./baseline.sh                              # matrix.default, 5 reps, results/
    OUT_DIR=/scratch/$USER/run1 ./baseline.sh my.matrix
    ./run_case.sh c 1 8 clover_bm16_short.in   # a single case
    python3 -I summarize.py results --md       # re-summarise, markdown tables

On HAICGU (https://haicgu.github.io/): on the dev node `guoehi-dev` run
`module load GCC OpenMPI`, build with `make clean && make COMPILER=GNU` (same
Kunpeng 920 CPU as the compute nodes, so `-march=native` is safe), then
`sbatch baseline.sbatch`. It runs `matrix.cluster` (128-core node, 24 cases) on
partition `cn-ib` and writes to `~/clover-runs/baseline-<jobid>/`. mpirun reads
the allocation from Slurm.

Files: `lib.sh` (deck generation, mpirun launch, output parsing),
`run_case.sh` (one case, N reps), `baseline.sh` (matrix driver + summary),
`summarize.py`, `matrix.default` (4 quick laptop cases), `matrix.cluster` (HAICGU 128-core
node, 24 cases), `baseline.sbatch` (HAICGU Slurm wrapper around `baseline.sh`).

Matrix lines are `KERNELS RANKS THREADS [DECK]`. The deck is copied, any
`use_*_kernels`, `profiler_on` and `visit_frequency` lines are stripped, and
the requested kernel keyword plus `profiler_on` are inserted, so one source
deck serves both kernel sets and no VTK output is ever written.

Placement: every rank is bound to THREADS consecutive cores
(`--map-by slot:PE=THREADS --bind-to core`) and OpenMP pins one thread per
core inside that set (`OMP_PROC_BIND=close OMP_PLACES=cores OMP_DYNAMIC=false`).
The OpenMP variables are forwarded to remote nodes with `-x`. Bindings are
written to each `rep<i>.log` by `--report-bindings`; check them once per
machine.

Environment knobs: `CLOVER_BIN`, `DECK_DIR`, `REPS` (5), `OUT_DIR`,
`MPIRUN`, `MPIRUN_ARGS`, `OMP_PROC_BIND`, `OMP_PLACES`, `OMP_DYNAMIC`.

Outputs in `OUT_DIR`: `environment.txt`, `results.csv` (one row per run),
`profiler.csv` (one row per profiler section per run), `summary.txt` /
`summary.md`, and `<case>/rep<i>.out` + `rep<i>.log` for every run.
