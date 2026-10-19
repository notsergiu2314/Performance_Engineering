#!/bin/bash
#SBATCH -J l7_ex1
#SBATCH -p cn-ib
#SBATCH -N 1
#SBATCH --exclusive
#SBATCH -t 00:45:00
#SBATCH -o slurm_%x_%j.log
# Submit from this directory: sbatch run.sbatch   -> results/<jobid>/
cd "$SLURM_SUBMIT_DIR"
if ! type module > /dev/null 2>&1; then
  for f in /etc/profile.d/lmod.sh /opt/ohpc/admin/lmod/lmod/init/bash; do
    [ -f "$f" ] && . "$f" && break
  done
fi
module load GCC || true
g++ --version | head -1
make -B CXXFLAGS="-O2 -std=c++17 -mcpu=native"
OUT="results/$SLURM_JOB_ID" bash ./run.sh
