#!/bin/bash

# Lab 6, exercise 1b: impact of thread affinity (OMP_PROC_BIND) on STREAM.
#
# Same unmodified stream.c and array lengths as run_threads.sh. For each
# OMP_PROC_BIND setting and a large number of threads, RUNS runs are written to
# stream_bind.csv (MB/s). OMP_PLACES=cores: one place per core (no SMT here), so
# "close" / "spread" / "master" are defined in terms of cores.
#
# Besides the bandwidth, one extra run per configuration at N = 10^8 records on
# which CPU each thread runs (ps snapshot one second after the start), saved in
# placement.txt. Kunpeng 920 node: 128 cores, NUMA domain = cpu / 32.
#
# Usage:  ./run_bind.sh            (on the compute node, e.g. via sbatch)

set -euo pipefail
cd "$(dirname "$0")"

SIZES=(1024 100000000)
NTIMES_FOR=(1000 20)
BINDS=(false true master close spread)
THREADS=(32 64 128)
RUNS=10

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
    echo "== numactl"; numactl --hardware 2>&1
    echo "== lscpu";   lscpu
} > system_bind.txt 2>&1
set -e

export OMP_PLACES=cores

echo "size,bind,threads,run,copy_MBs,scale_MBs,add_MBs,triad_MBs" > stream_bind.csv
echo "# bind threads | CPU of each thread one second into a N=1e8 run" > placement.txt

for i in "${!SIZES[@]}"; do
    size=${SIZES[$i]}
    ntimes=${NTIMES_FOR[$i]}

    echo "Compiling for N=$size, NTIMES=$ntimes ..."
    gcc -O3 -fopenmp $FLAGS -DSTREAM_ARRAY_SIZE="$size" -DNTIMES="$ntimes" stream.c -o stream_$size
    # "master" puts all threads on one core: every parallel region then costs
    # time slices of the scheduler, so a short run is used for the tiny array
    gcc -O3 -fopenmp $FLAGS -DSTREAM_ARRAY_SIZE="$size" -DNTIMES=10 stream.c -o stream_${size}_short

    for bind in "${BINDS[@]}"; do
        for t in "${THREADS[@]}"; do
            bin=stream_$size
            runs=$RUNS
            if [ "$bind" = master ] && [ "$size" = 1024 ]; then
                bin=stream_${size}_short
                runs=3
            fi
            for run in $(seq 1 $runs); do
                # timeout: a pathological configuration must not eat the job
                OMP_NUM_THREADS=$t OMP_PROC_BIND=$bind timeout 300 ./$bin > out.txt || true
                copy=$(awk '/^Copy:/  {print $2}' out.txt)
                scale=$(awk '/^Scale:/ {print $2}' out.txt)
                add=$(awk '/^Add:/   {print $2}' out.txt)
                triad=$(awk '/^Triad:/ {print $2}' out.txt)
                echo "$size,$bind,$t,$run,$copy,$scale,$add,$triad" >> stream_bind.csv
            done

            if [ "$size" = 100000000 ]; then
                OMP_NUM_THREADS=$t OMP_PROC_BIND=$bind ./stream_$size > /dev/null &
                pid=$!
                sleep 1
                cpus=$(ps -L -o psr= -p $pid | sort -n | tr -s ' \n' ' ')
                echo "$bind $t | $cpus" >> placement.txt
                wait $pid
            fi
            echo "N=$size bind=$bind threads=$t done: triad (last run) = $triad MB/s"
        done
    done
done

rm -f out.txt stream_1024 stream_1024_short stream_100000000 stream_100000000_short
echo "Done! Results in stream_bind.csv and placement.txt."
