#!/bin/bash

# Lab 4, exercise 1: compile and run the loop unrolling benchmark pinned to
# one core. The results are written to loop_unrolling.csv.
#
# Usage:
#   ./run_benchmark.sh        # pinned to core 2
#   ./run_benchmark.sh 4      # pinned to another core

set -euo pipefail
cd "$(dirname "$0")"

CPU="${1:-2}"

# scalar kernels with separate multiply and add (see loop_unrolling.cpp)
g++ -std=c++17 -O2 -march=native -fno-tree-vectorize -ffp-contract=off \
    loop_unrolling.cpp -o loop_unrolling.out

taskset -c "$CPU" ./loop_unrolling.out | tee loop_unrolling.csv

rm -f loop_unrolling.out
