#!/bin/bash
# Submit the four configurations of lab 7 ex2 (run from this directory on HAICGU):
#   same node / different nodes  x  cn-ib / cn-eth
# Each job writes results/<partition>_<nodes>node_<jobid>/ring.csv
cd "$(dirname "$0")"
for part in cn-ib cn-eth; do
  sbatch -p "$part" --nodes=1 --ntasks-per-node=2 -J "l7_ex2_${part}_same" run.sbatch
  sbatch -p "$part" --nodes=2 --ntasks-per-node=1 -J "l7_ex2_${part}_diff" run.sbatch
done
