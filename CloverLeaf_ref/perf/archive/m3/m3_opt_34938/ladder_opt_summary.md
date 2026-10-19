Results in /home/joosterveld/CloverLeaf_ref/perf/results/m3_opt_34938/ladder/opt  (5 runs, 1 cases)

| case | deck | kernels | ranks | thr | thp | n | best_wall_s | median_s | spread | grind_ns/cell | qa_dev_% | qa | reported | dram_TB | hw_GB/s | busiest/mean | %hw_roof |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| clover_bm16_short_c_r64_t2 | clover_bm16_short.in | c | 64 | 2 | on | 5 | 8.231 | 8.252 | 1.2% | 6.41 | 3.95e-11 | PASSED | C | 2.043 | 248 | 1.00 | 93% |

dram_TB: DDR-controller bytes (32 B/count, everything the controllers moved incl. read-for-ownership), median over reps; hw_GB/s = dram / median wall; busiest/mean = load of the busiest NUMA controller group (1.00 = balanced); %hw_roof vs 266 GB/s hardware STREAM

Profiler split of best repetition (seconds, % of wall); sections under 1% omitted
| section | clover_bm16_short_c_r64_t2 |
|---|---|
| Timestep | 0.51 (6%) |
| Ideal Gas | 0.42 (5%) |
| Viscosity | 0.35 (4%) |
| PdV | 1.37 (17%) |
| Acceleration | 0.58 (7%) |
| Fluxes | 0.38 (5%) |
| Cell Advection | 1.63 (20%) |
| Momentum Advection | 2.74 (33%) |
| MPI Halo Exchange | 0.19 (2%) |
| Total | 8.23 (100%) |

