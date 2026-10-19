# M3 baseline on one exclusive HAICGU node (2 x Kunpeng 920, 128 cores, 4 NUMA domains).
# KERNELS RANKS THREADS DECK THP. clover_bm16_short.in = 3840^2 cells, 87 steps, test_problem 4
# (identical to perf/inputs/bm3840.in). Every row runs REPS times (5) under the DDR-controller
# counters, so results.csv carries the hardware bytes of each repetition.
#
# C kernels are the subject: 64x2 is the baseline layout; 1x128, 4x32, 32x4 and 128x1 are the
# comparison points; each layout with transparent huge pages on (system default, THP=always,
# 512 MB pages) and off (nothp launcher per rank).
c       64  2   clover_bm16_short.in on
c       64  2   clover_bm16_short.in off
c       1   128 clover_bm16_short.in on
c       1   128 clover_bm16_short.in off
c       4   32  clover_bm16_short.in on
c       4   32  clover_bm16_short.in off
c       32  4   clover_bm16_short.in on
c       32  4   clover_bm16_short.in off
c       128 1   clover_bm16_short.in on
c       128 1   clover_bm16_short.in off
# Fortran kernels for reference only (same layouts, THP on).
fortran 64  2   clover_bm16_short.in on
fortran 1   128 clover_bm16_short.in on
fortran 4   32  clover_bm16_short.in on
fortran 32  4   clover_bm16_short.in on
fortran 128 1   clover_bm16_short.in on
