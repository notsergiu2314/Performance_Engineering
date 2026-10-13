#!/bin/bash

# Lab 6, exercise 1a: STREAM bandwidth as a function of the number of threads.
#
# stream.c is McCalpin's reference benchmark (unmodified), built with OpenMP.
# Two array lengths:
#   N = 1024       3 arrays x 8 KB = 24 KB, fits in L1D
#   N = 100000000  3 arrays x 800 MB, far beyond the last level cache
# Every (N, threads) pair is run RUNS times; one row per run and kernel set is
# written to stream_threads.csv (MB/s, best of NTIMES iterations, as printed by
# STREAM).
#
# Thread placement is left at the OpenMP defaults (OMP_PROC_BIND / OMP_PLACES
# are only recorded, see system.txt); exercise 1b studies them.
#
# Usage:  ./run_threads.sh              (on the compute node, e.g. via sbatch)

set -euo pipefail
cd "$(dirname "$0")"

SIZES=(1024 100000000)
NTIMES_FOR=(1000 20)          # iterations per run, one entry per size
THREADS=(1 2 4 8 16 32 64 128)
RUNS=10

# aarch64 (Kunpeng 920) has no -mcmodel=medium; its small model covers the 2.4 GB of static arrays
if [ "$(uname -m)" = x86_64 ]; then
    FLAGS="${FLAGS:--march=native -mcmodel=medium}"
else
    FLAGS="${FLAGS:--mcpu=native}"
fi

set +e    # the system description must not abort the run
{
    echo "== date";    date
    echo "== host";    hostname
    echo "== gcc";     gcc --version | head -1
    echo "== flags";   echo "-O3 -fopenmp $FLAGS"
    echo "== THP";     cat /sys/kernel/mm/transparent_hugepage/enabled 2>&1
    echo "== OMP env"; env | grep '^OMP_' || echo "(no OMP_* variables set)"
    echo "== lscpu";   lscpu
} > system.txt 2>&1
set -e

echo "size,threads,run,copy_MBs,scale_MBs,add_MBs,triad_MBs" > stream_threads.csv

for i in "${!SIZES[@]}"; do
    size=${SIZES[$i]}
    ntimes=${NTIMES_FOR[$i]}

    echo "Compiling for N=$size, NTIMES=$ntimes ..."
    gcc -O3 -fopenmp $FLAGS -DSTREAM_ARRAY_SIZE="$size" -DNTIMES="$ntimes" stream.c -o stream_$size

    for t in "${THREADS[@]}"; do
        for run in $(seq 1 $RUNS); do
            OMP_NUM_THREADS=$t ./stream_$size > out.txt
            copy=$(awk '/^Copy:/  {print $2}' out.txt)
            scale=$(awk '/^Scale:/ {print $2}' out.txt)
            add=$(awk '/^Add:/   {print $2}' out.txt)
            triad=$(awk '/^Triad:/ {print $2}' out.txt)
            echo "$size,$t,$run,$copy,$scale,$add,$triad" >> stream_threads.csv
        done
        echo "N=$size threads=$t done: triad (last run) = $triad MB/s"
    done
done

rm -f out.txt stream_1024 stream_100000000
echo "Done! Results saved to stream_threads.csv."
