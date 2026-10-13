#!/bin/bash
#SBATCH -J lab_6
#SBATCH -p cn-ib
#SBATCH -N 1
#SBATCH --exclusive
#SBATCH -t 01:30:00
#SBATCH -o /home/joosterveld/lab_6/lab_6_out/%x_%j.log

set -uo pipefail

OUT="/home/joosterveld/lab_6/lab_6_out/lab_6_$SLURM_JOB_ID"
mkdir -p $OUT
SRC="$LAB6_ROOT"

gcc -O3 -mcpu=native -fopenmp "$SRC/openmp_ex2.c" -o "$OUT/parallel_matvec"

# Run with max threads and large enough matrix/vector
export OMP_NUM_THREADS=128
M=
N=
ITERS=100

echo "threads: "
echo $OMP_NUM_THREADS

$OUT/parallel_matvec $M $N $ITERS