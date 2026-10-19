Results in /home/joosterveld/CloverLeaf_ref/perf/results/m3_opt_34938/layouts/base  (30 runs, 6 cases)

| case | deck | kernels | ranks | thr | thp | n | best_wall_s | median_s | spread | grind_ns/cell | qa_dev_% | qa | reported | dram_TB | hw_GB/s | busiest/mean | %hw_roof |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| clover_bm16_short_c_r64_t2 | clover_bm16_short.in | c | 64 | 2 | on | 5 | 11.231 | 11.245 | 0.2% | 8.75 | 3.95e-11 | PASSED | C | 2.827 | 251 | 1.00 | 94% |
| clover_bm16_short_c_r1_t128 | clover_bm16_short.in | c | 1 | 128 | on | 5 | 22.313 | 23.998 | 22.0% | 17.34 | 4.04e-11 | PASSED | C | 2.959 | 123 | 1.51 | 46% |
| clover_bm16_short_c_r1_t128_thpoff | clover_bm16_short.in | c | 1 | 128 | off | 5 | 13.248 | 13.336 | 1.1% | 10.32 | 4.05e-11 | PASSED | C | 2.828 | 212 | 1.00 | 80% |
| clover_bm16_short_c_r4_t32 | clover_bm16_short.in | c | 4 | 32 | on | 5 | 12.825 | 12.953 | 1.2% | 9.99 | 6.80e-11 | PASSED | C | 2.866 | 221 | 1.00 | 83% |
| clover_bm16_short_c_r32_t4 | clover_bm16_short.in | c | 32 | 4 | on | 5 | 11.394 | 11.416 | 0.7% | 8.88 | 5.86e-11 | PASSED | C | 2.795 | 245 | 1.00 | 92% |
| clover_bm16_short_c_r128_t1 | clover_bm16_short.in | c | 128 | 1 | on | 5 | 11.629 | 11.653 | 1.0% | 9.06 | 3.95e-11 | PASSED | C | 2.952 | 253 | 1.00 | 95% |

dram_TB: DDR-controller bytes (32 B/count, everything the controllers moved incl. read-for-ownership), median over reps; hw_GB/s = dram / median wall; busiest/mean = load of the busiest NUMA controller group (1.00 = balanced); %hw_roof vs 266 GB/s hardware STREAM

Profiler split of best repetition (seconds, % of wall); sections under 1% omitted
| section | clover_bm16_short_c_r64_t2 | clover_bm16_short_c_r1_t128 | clover_bm16_short_c_r1_t128_thpoff | clover_bm16_short_c_r4_t32 | clover_bm16_short_c_r32_t4 | clover_bm16_short_c_r128_t1 |
|---|---|---|---|---|---|---|
| Timestep | 0.68 (6%) | 1.06 (5%) | 0.72 (5%) | 0.72 (6%) | 0.73 (6%) | 0.72 (6%) |
| Ideal Gas | 0.52 (5%) | 1.06 (5%) | 0.56 (4%) | 0.53 (4%) | 0.49 (4%) | 0.48 (4%) |
| Viscosity | 0.35 (3%) | 0.60 (3%) | 0.44 (3%) | 0.35 (3%) | 0.45 (4%) | 0.38 (3%) |
| PdV | 1.33 (12%) | 2.41 (11%) | 1.65 (12%) | 1.68 (13%) | 1.35 (12%) | 1.34 (12%) |
| Revert | 0.19 (2%) | 0.23 (1%) | 0.17 (1%) | 0.16 (1%) | 0.17 (2%) | 0.18 (2%) |
| Acceleration | 0.56 (5%) | 0.91 (4%) | 0.64 (5%) | 0.61 (5%) | 0.62 (5%) | 0.60 (5%) |
| Fluxes | 0.38 (3%) | 0.71 (3%) | 0.39 (3%) | 0.37 (3%) | 0.37 (3%) | 0.37 (3%) |
| Cell Advection | 2.43 (22%) | 4.62 (21%) | 2.90 (22%) | 2.73 (21%) | 2.44 (21%) | 2.49 (21%) |
| Momentum Advection | 4.17 (37%) | 9.18 (41%) | 4.54 (34%) | 4.27 (33%) | 4.21 (37%) | 4.48 (38%) |
| Reset | 0.35 (3%) | 0.68 (3%) | 0.38 (3%) | 0.34 (3%) | 0.32 (3%) | 0.29 (3%) |
| Self Halo Exchange | 0.03 (0%) | 0.78 (3%) | 0.78 (6%) | 0.02 (0%) | 0.02 (0%) | 0.00 (0%) |
| MPI Halo Exchange | 0.21 (2%) | 0.00 (0%) | 0.00 (0%) | 1.00 (8%) | 0.20 (2%) | 0.25 (2%) |
| Total | 11.23 (100%) | 22.29 (100%) | 13.21 (100%) | 12.82 (100%) | 11.39 (100%) | 11.63 (100%) |

