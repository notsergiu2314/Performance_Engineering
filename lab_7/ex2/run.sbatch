#!/bin/bash
#SBATCH -J l7_ex2
#SBATCH --exclusive
#SBATCH -t 00:20:00
#SBATCH -o slurm_%x_%j.log
# Partition and placement come from the command line (see submit_all.sh), e.g.
#   sbatch -p cn-ib  --nodes=1 --ntasks-per-node=2 run.sbatch    two ranks on one node
#   sbatch -p cn-eth --nodes=2 --ntasks-per-node=1 run.sbatch    two ranks on two nodes
# Results: results/<partition>_<nodes>node_<jobid>/ring.csv (+ environment.txt)
cd "$SLURM_SUBMIT_DIR"

if ! type module > /dev/null 2>&1; then
  for f in /etc/profile.d/lmod.sh /opt/ohpc/admin/lmod/lmod/init/bash; do
    [ -f "$f" ] && . "$f" && break
  done
fi
module load GCC || true
module load OpenMPI || true
command -v mpicc > /dev/null || { echo "mpicc not found after module load; loaded modules:"; module -t list; exit 1; }

make -B mpi_ring || exit 1

OUT="results/${SLURM_JOB_PARTITION}_${SLURM_JOB_NUM_NODES}node_${SLURM_JOB_ID}"
mkdir -p "$OUT"
{
  echo "job=$SLURM_JOB_ID partition=$SLURM_JOB_PARTITION nodes=$SLURM_JOB_NODELIST"
  echo "ntasks=$SLURM_NTASKS ntasks_per_node=${SLURM_NTASKS_PER_NODE:-?}"
  echo "date=$(date -Is)"
  mpicc --version | head -1
  mpiexec --version | head -1
  echo "--- network devices"
  ip -br link 2> /dev/null | head -20
  ibstat 2> /dev/null | grep -E "CA '|State|Rate" | head
  echo "--- MPI transports built in"
  ompi_info 2> /dev/null | grep -E "MCA (pml|btl|mtl)" | head -20
} > "$OUT/environment.txt" 2>&1

# One rank per core, ranks spread as Slurm allocated them (1 slot per node when ntasks-per-node=1).
# Verbose PML/BTL selection goes to a separate file so that the transport used is on record.
mpiexec -n "$SLURM_NTASKS" --bind-to core --mca pml_base_verbose 10 --mca btl_base_verbose 10 \
    ./mpi_ring "${M:-0}" "${TRIALS:-10}" ${SIZES:-128 256 512 1024 2048 4096} \
    > "$OUT/ring.csv" 2> "$OUT/transport.txt"
echo "exit status $?"
grep '^#' "$OUT/ring.csv"
head -5 "$OUT/ring.csv" | grep -v '^#'
echo "results in $OUT"
