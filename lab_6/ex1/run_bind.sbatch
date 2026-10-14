#!/bin/bash
#SBATCH -J l6_bind
#SBATCH -p cn-ib
#SBATCH -N 1
#SBATCH --exclusive
#SBATCH -t 01:00:00
#SBATCH -o slurm_%x_%j.log
# Submit from this directory: sbatch run_bind.sbatch
cd "$SLURM_SUBMIT_DIR"
bash ./run_bind.sh
