#!/bin/bash
#SBATCH -J l6_stream
#SBATCH -p cn-ib
#SBATCH -N 1
#SBATCH --exclusive
#SBATCH -t 02:00:00
#SBATCH -o slurm_%x_%j.log
# Lab 6, exercise 1: STREAM vs. threads and vs. OMP_PROC_BIND on a Kunpeng 920
# node (2 sockets x 64 cores, 4 NUMA domains of 32 cores, no SMT).
# Submit from this directory:   sbatch ex1_stream.sbatch
# Shorter test run:             REPS=1 sbatch --export=ALL,REPS=1 ex1_stream.sbatch
module load GCC 2> /dev/null || true
echo "gcc: $(gcc --version | head -1)"
cd "$SLURM_SUBMIT_DIR"
bash ./run_ex1.sh
