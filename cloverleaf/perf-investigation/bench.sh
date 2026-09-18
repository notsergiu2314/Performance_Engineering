#!/bin/bash
# usage: bench.sh <dir-with-clover_leaf> <threads> <ranks> <reps> [deck]
D=$1; T=$2; R=$3; N=${4:-3}; DECK=${5:-clover_bm_short.in}
RUN=$(mktemp -d)
cd $RUN
sed 's/^\*endclover/ profiler_on\n*endclover/' $D/InputDecks/$DECK > clover.in
best=999999
for i in $(seq $N); do
  if [ $R -eq 1 ]; then B="--bind-to none"; else B="--bind-to core"; fi
  OMP_NUM_THREADS=$T OMP_PROC_BIND=close OMP_PLACES=cores mpirun -np $R $B $D/clover_leaf >/dev/null 2>&1
  w=$(grep "Wall clock" clover.out | tail -1 | awk '{print $3}')
  q=$(grep -m1 "is within" clover.out | awk '{print $6}')
  echo "run $i wall=$w qa_diff=$q $(grep -c PASSED clover.out | sed 's/[1-9].*/PASSED/;s/^0$/NOT-PASSED/')"
  if (( $(echo "$w < $best" | bc -l) )); then best=$w; cp clover.out best.out; fi
done
echo "BEST $best"
grep -A17 "Profiler Output" best.out | awk '$NF+0>=2.0'
cd /; rm -rf $RUN
