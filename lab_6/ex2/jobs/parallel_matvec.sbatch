#!/bin/bash
#SBATCH -J m2_stream
#SBATCH -p cn-ib
#SBATCH -N 1
#SBATCH --exclusive
#SBATCH -t 01:30:00
#SBATCH -o ~/lab_6_out/%x_%j.log

set -uo pipefail

OUT="~/lab_6_out/lab_6_$SLURM_JOB_ID"
SRC="$LAB6_ROOT"

gcc -O3 -mcpu=native -fopenmp "$SRC/openmp_ex2.c" -o "$OUT/parallel_matvec"

# Run with max threads and large enough matrix/vector
export OMP_NUM_THREADS=128
MATSIZE=10000
VECSIZE=10000
ITERS=100

$OUT/parallel_matvec $MATSIZE $VECSIZE $ITERS