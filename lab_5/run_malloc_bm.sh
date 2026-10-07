#!/bin/bash
# Build and run the malloc/free overhead benchmark (exercise 3), then
# regenerate the figures in report/.  Results land in benchmark_malloc.csv.
set -e
cd "$(dirname "$0")"

make benchmark_malloc

# pin to one core to reduce scheduler noise
taskset -c 2 ./benchmark_malloc

python3 generate_figures.py
