#!/bin/bash
#SBATCH -J l6_stream
#SBATCH -p cn-ib
#SBATCH -N 1
#SBATCH --exclusive
#SBATCH -t 00:30:00
#SBATCH -o slurm_%x_%j.log
# Submit from this directory: sbatch run_threads.sbatch
# (partition name taken from the earlier cluster jobs; adjust if needed)
cd "$SLURM_SUBMIT_DIR"
./run_threads.sh
