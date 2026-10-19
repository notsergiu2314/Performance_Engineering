Results in /home/joosterveld/CloverLeaf_ref/perf/results/m3_opt_35003/layouts/base  (30 runs, 6 cases)

| case | deck | kernels | ranks | thr | thp | n | best_wall_s | median_s | spread | grind_ns/cell | qa_dev_% | qa | reported | dram_TB | hw_GB/s | busiest/mean | %hw_roof |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| clover_bm16_short_c_r64_t2 | clover_bm16_short.in | c | 64 | 2 | on | 5 | 11.243 | 11.244 | 0.2% | 8.76 | 3.95e-11 | PASSED | C | 2.828 | 252 | 1.00 | 94% |
| clover_bm16_short_c_r1_t128 | clover_bm16_short.in | c | 1 | 128 | on | 5 | 17.266 | 27.610 | 67.2% | 13.35 | 4.05e-11 | PASSED | C | 2.991 | 108 | 1.43 | 41% |
| clover_bm16_short_c_r1_t128_thpoff | clover_bm16_short.in | c | 1 | 128 | off | 5 | 13.233 | 13.392 | 1.6% | 10.31 | 4.04e-11 | PASSED | C | 2.829 | 211 | 1.00 | 79% |
| clover_bm16_short_c_r4_t32 | clover_bm16_short.in | c | 4 | 32 | on | 5 | 13.012 | 13.155 | 1.7% | 10.14 | 6.80e-11 | PASSED | C | 2.870 | 218 | 1.00 | 82% |
| clover_bm16_short_c_r32_t4 | clover_bm16_short.in | c | 32 | 4 | on | 5 | 11.397 | 11.401 | 0.7% | 8.88 | 5.86e-11 | PASSED | C | 2.794 | 245 | 1.00 | 92% |
| clover_bm16_short_c_r128_t1 | clover_bm16_short.in | c | 128 | 1 | on | 5 | 11.646 | 11.756 | 1.2% | 9.07 | 3.95e-11 | PASSED | C | 2.952 | 251 | 1.00 | 94% |

dram_TB: DDR-controller bytes (32 B/count, everything the controllers moved incl. read-for-ownership), median over reps; hw_GB/s = dram / median wall; busiest/mean = load of the busiest NUMA controller group (1.00 = balanced); %hw_roof vs 266 GB/s hardware STREAM

Profiler split of best repetition (seconds, % of wall); sections under 1% omitted
| section | clover_bm16_short_c_r64_t2 | clover_bm16_short_c_r1_t128 | clover_bm16_short_c_r1_t128_thpoff | clover_bm16_short_c_r4_t32 | clover_bm16_short_c_r32_t4 | clover_bm16_short_c_r128_t1 |
|---|---|---|---|---|---|---|
| Timestep | 0.69 (6%) | 1.12 (7%) | 0.72 (5%) | 0.72 (6%) | 0.73 (6%) | 0.72 (6%) |
| Ideal Gas | 0.52 (5%) | 0.73 (4%) | 0.56 (4%) | 0.53 (4%) | 0.49 (4%) | 0.49 (4%) |
| Viscosity | 0.36 (3%) | 0.60 (4%) | 0.44 (3%) | 0.34 (3%) | 0.45 (4%) | 0.38 (3%) |
| PdV | 1.32 (12%) | 1.92 (11%) | 1.66 (13%) | 1.74 (13%) | 1.35 (12%) | 1.35 (12%) |
| Revert | 0.19 (2%) | 0.19 (1%) | 0.17 (1%) | 0.16 (1%) | 0.18 (2%) | 0.18 (2%) |
| Acceleration | 0.57 (5%) | 0.74 (4%) | 0.65 (5%) | 0.62 (5%) | 0.62 (5%) | 0.60 (5%) |
| Fluxes | 0.38 (3%) | 0.51 (3%) | 0.38 (3%) | 0.37 (3%) | 0.37 (3%) | 0.37 (3%) |
| Cell Advection | 2.44 (22%) | 3.70 (21%) | 2.93 (22%) | 2.74 (21%) | 2.45 (21%) | 2.49 (21%) |
| Momentum Advection | 4.16 (37%) | 6.28 (36%) | 4.55 (34%) | 4.30 (33%) | 4.22 (37%) | 4.43 (38%) |
| Reset | 0.36 (3%) | 0.47 (3%) | 0.38 (3%) | 0.35 (3%) | 0.31 (3%) | 0.30 (3%) |
| Self Halo Exchange | 0.03 (0%) | 0.93 (5%) | 0.74 (6%) | 0.09 (1%) | 0.00 (0%) | 0.00 (0%) |
| MPI Halo Exchange | 0.20 (2%) | 0.00 (0%) | 0.00 (0%) | 0.99 (8%) | 0.20 (2%) | 0.29 (3%) |
| Total | 11.24 (100%) | 17.24 (100%) | 13.20 (100%) | 13.01 (100%) | 11.40 (100%) | 11.65 (100%) |

