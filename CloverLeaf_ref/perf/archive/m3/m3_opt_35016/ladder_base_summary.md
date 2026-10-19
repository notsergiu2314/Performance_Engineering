Results in /home/joosterveld/CloverLeaf_ref/perf/results/m3_opt_35016/ladder/base  (5 runs, 1 cases)

| case | deck | kernels | ranks | thr | thp | n | best_wall_s | median_s | spread | grind_ns/cell | qa_dev_% | qa | reported | dram_TB | hw_GB/s | busiest/mean | %hw_roof |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| clover_bm16_short_c_r64_t2 | clover_bm16_short.in | c | 64 | 2 | on | 5 | 11.222 | 11.224 | 0.9% | 8.74 | 3.95e-11 | PASSED | C | 2.827 | 252 | 1.00 | 95% |

dram_TB: DDR-controller bytes (32 B/count, everything the controllers moved incl. read-for-ownership), median over reps; hw_GB/s = dram / median wall; busiest/mean = load of the busiest NUMA controller group (1.00 = balanced); %hw_roof vs 266 GB/s hardware STREAM

Profiler split of best repetition (seconds, % of wall); sections under 1% omitted
| section | clover_bm16_short_c_r64_t2 |
|---|---|
| Timestep | 0.68 (6%) |
| Ideal Gas | 0.50 (4%) |
| Viscosity | 0.36 (3%) |
| PdV | 1.32 (12%) |
| Revert | 0.19 (2%) |
| Acceleration | 0.56 (5%) |
| Fluxes | 0.38 (3%) |
| Cell Advection | 2.43 (22%) |
| Momentum Advection | 4.24 (38%) |
| Reset | 0.33 (3%) |
| MPI Halo Exchange | 0.21 (2%) |
| Total | 11.22 (100%) |

