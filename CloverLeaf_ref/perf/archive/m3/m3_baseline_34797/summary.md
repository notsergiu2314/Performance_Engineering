Results in CloverLeaf_ref/perf/results/m3_baseline_34797  (75 runs, 15 cases)

| case | deck | kernels | ranks | thr | thp | n | best_wall_s | median_s | spread | grind_ns/cell | qa_dev_% | qa | reported | dram_TB | hw_GB/s | busiest/mean | %hw_roof |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| clover_bm16_short_c_r64_t2 | clover_bm16_short.in | c | 64 | 2 | on | 5 | 11.243 | 11.316 | 0.8% | 8.76 | 3.95e-11 | PASSED | C | 2.828 | 250 | 1.00 | 94% |
| clover_bm16_short_c_r64_t2_thpoff | clover_bm16_short.in | c | 64 | 2 | off | 5 | 11.239 | 11.251 | 0.7% | 8.76 | 3.95e-11 | PASSED | C | 2.828 | 251 | 1.00 | 94% |
| clover_bm16_short_c_r1_t128 | clover_bm16_short.in | c | 1 | 128 | on | 5 | 17.442 | 26.906 | 67.4% | 13.47 | 4.04e-11 | PASSED | C | 2.989 | 111 | 1.66 | 42% |
| clover_bm16_short_c_r1_t128_thpoff | clover_bm16_short.in | c | 1 | 128 | off | 5 | 13.276 | 13.311 | 4.8% | 10.34 | 4.04e-11 | PASSED | C | 2.828 | 212 | 1.00 | 80% |
| clover_bm16_short_c_r4_t32 | clover_bm16_short.in | c | 4 | 32 | on | 5 | 12.762 | 12.996 | 3.5% | 9.94 | 6.80e-11 | PASSED | C | 2.873 | 221 | 1.01 | 83% |
| clover_bm16_short_c_r4_t32_thpoff | clover_bm16_short.in | c | 4 | 32 | off | 5 | 12.707 | 12.768 | 1.6% | 9.90 | 6.80e-11 | PASSED | C | 2.863 | 224 | 1.00 | 84% |
| clover_bm16_short_c_r32_t4 | clover_bm16_short.in | c | 32 | 4 | on | 5 | 11.407 | 11.464 | 0.6% | 8.89 | 5.86e-11 | PASSED | C | 2.795 | 244 | 1.00 | 91% |
| clover_bm16_short_c_r32_t4_thpoff | clover_bm16_short.in | c | 32 | 4 | off | 5 | 11.395 | 11.400 | 0.7% | 8.88 | 5.86e-11 | PASSED | C | 2.794 | 245 | 1.00 | 92% |
| clover_bm16_short_c_r128_t1 | clover_bm16_short.in | c | 128 | 1 | on | 5 | 11.632 | 11.660 | 1.1% | 9.06 | 3.95e-11 | PASSED | C | 2.952 | 253 | 1.00 | 95% |
| clover_bm16_short_c_r128_t1_thpoff | clover_bm16_short.in | c | 128 | 1 | off | 5 | 11.645 | 11.733 | 1.1% | 9.07 | 3.95e-11 | PASSED | C | 2.952 | 252 | 1.00 | 94% |
| clover_bm16_short_fortran_r64_t2 | clover_bm16_short.in | fortran | 64 | 2 | on | 5 | 9.331 | 9.333 | 1.0% | 7.27 | 3.95e-11 | PASSED | Fortran | 2.355 | 252 | 1.00 | 95% |
| clover_bm16_short_fortran_r1_t128 | clover_bm16_short.in | fortran | 1 | 128 | on | 5 | 18.404 | 20.627 | 40.8% | 14.30 | 4.05e-11 | PASSED | Fortran | 2.439 | 118 | 1.45 | 44% |
| clover_bm16_short_fortran_r4_t32 | clover_bm16_short.in | fortran | 4 | 32 | on | 5 | 10.778 | 10.879 | 4.1% | 8.40 | 6.81e-11 | PASSED | Fortran | 2.385 | 219 | 1.00 | 82% |
| clover_bm16_short_fortran_r32_t4 | clover_bm16_short.in | fortran | 32 | 4 | on | 5 | 9.443 | 9.462 | 0.8% | 7.36 | 5.87e-11 | PASSED | Fortran | 2.303 | 243 | 1.00 | 91% |
| clover_bm16_short_fortran_r128_t1 | clover_bm16_short.in | fortran | 128 | 1 | on | 5 | 9.662 | 9.757 | 1.1% | 7.51 | 3.95e-11 | PASSED | Fortran | 2.456 | 252 | 1.00 | 94% |

dram_TB: DDR-controller bytes (32 B/count, includes write-allocate), median over reps; hw_GB/s = dram / median wall; busiest/mean = load of the busiest NUMA controller group (1.00 = balanced); %hw_roof vs 266 GB/s hardware STREAM

C relative to Fortran (best wall, ratio > 1 means C slower; Fortran for reference only)
| deck | ranks | thr | thp | fortran_s | c_s | c/fortran |
|---|---|---|---|---|---|---|
| clover_bm16_short.in | 1 | 128 | on | 18.404 | 17.442 | 0.948 |
| clover_bm16_short.in | 128 | 1 | on | 9.662 | 11.632 | 1.204 |
| clover_bm16_short.in | 32 | 4 | on | 9.443 | 11.407 | 1.208 |
| clover_bm16_short.in | 4 | 32 | on | 10.778 | 12.762 | 1.184 |
| clover_bm16_short.in | 64 | 2 | on | 9.331 | 11.243 | 1.205 |

Profiler split of best repetition (seconds, % of wall); sections under 1% omitted
| section | clover_bm16_short_c_r64_t2 | clover_bm16_short_c_r64_t2_thpoff | clover_bm16_short_c_r1_t128 | clover_bm16_short_c_r1_t128_thpoff | clover_bm16_short_c_r4_t32 | clover_bm16_short_c_r4_t32_thpoff | clover_bm16_short_c_r32_t4 | clover_bm16_short_c_r32_t4_thpoff | clover_bm16_short_c_r128_t1 | clover_bm16_short_c_r128_t1_thpoff | clover_bm16_short_fortran_r64_t2 | clover_bm16_short_fortran_r1_t128 | clover_bm16_short_fortran_r4_t32 | clover_bm16_short_fortran_r32_t4 | clover_bm16_short_fortran_r128_t1 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Timestep | 0.68 (6%) | 0.68 (6%) | 0.97 (6%) | 0.73 (5%) | 0.72 (6%) | 0.71 (6%) | 0.74 (7%) | 0.74 (6%) | 0.72 (6%) | 0.72 (6%) | 0.64 (7%) | 0.71 (4%) | 0.50 (5%) | 0.58 (6%) | 0.65 (7%) |
| Ideal Gas | 0.50 (4%) | 0.50 (4%) | 0.77 (4%) | 0.56 (4%) | 0.53 (4%) | 0.53 (4%) | 0.49 (4%) | 0.49 (4%) | 0.49 (4%) | 0.49 (4%) | 0.44 (5%) | 1.39 (8%) | 0.47 (4%) | 0.40 (4%) | 0.42 (4%) |
| Viscosity | 0.36 (3%) | 0.36 (3%) | 0.51 (3%) | 0.45 (3%) | 0.35 (3%) | 0.35 (3%) | 0.45 (4%) | 0.45 (4%) | 0.39 (3%) | 0.38 (3%) | 0.27 (3%) | 0.70 (4%) | 0.34 (3%) | 0.43 (5%) | 0.30 (3%) |
| PdV | 1.32 (12%) | 1.32 (12%) | 2.01 (12%) | 1.64 (12%) | 1.66 (13%) | 1.65 (13%) | 1.35 (12%) | 1.35 (12%) | 1.34 (12%) | 1.35 (12%) | 1.18 (13%) | 2.94 (16%) | 1.42 (13%) | 1.20 (13%) | 1.25 (13%) |
| Revert | 0.19 (2%) | 0.19 (2%) | 0.21 (1%) | 0.17 (1%) | 0.17 (1%) | 0.16 (1%) | 0.17 (2%) | 0.17 (2%) | 0.18 (2%) | 0.18 (2%) | 0.19 (2%) | 0.43 (2%) | 0.17 (2%) | 0.17 (2%) | 0.18 (2%) |
| Acceleration | 0.56 (5%) | 0.56 (5%) | 0.80 (5%) | 0.64 (5%) | 0.61 (5%) | 0.61 (5%) | 0.62 (5%) | 0.62 (5%) | 0.60 (5%) | 0.60 (5%) | 0.56 (6%) | 1.19 (6%) | 0.62 (6%) | 0.59 (6%) | 0.54 (6%) |
| Fluxes | 0.38 (3%) | 0.38 (3%) | 0.69 (4%) | 0.39 (3%) | 0.37 (3%) | 0.37 (3%) | 0.37 (3%) | 0.37 (3%) | 0.37 (3%) | 0.37 (3%) | 0.40 (4%) | 0.74 (4%) | 0.43 (4%) | 0.40 (4%) | 0.38 (4%) |
| Cell Advection | 2.43 (22%) | 2.44 (22%) | 3.98 (23%) | 2.90 (22%) | 2.72 (21%) | 2.72 (21%) | 2.44 (21%) | 2.44 (21%) | 2.49 (21%) | 2.50 (21%) | 1.79 (19%) | 3.23 (18%) | 2.07 (19%) | 1.76 (19%) | 1.74 (18%) |
| Momentum Advection | 4.23 (38%) | 4.24 (38%) | 6.14 (35%) | 4.59 (35%) | 4.27 (33%) | 4.30 (34%) | 4.25 (37%) | 4.22 (37%) | 4.47 (38%) | 4.47 (38%) | 3.25 (35%) | 5.33 (29%) | 3.42 (32%) | 3.37 (36%) | 3.38 (35%) |
| Reset | 0.33 (3%) | 0.33 (3%) | 0.54 (3%) | 0.37 (3%) | 0.35 (3%) | 0.35 (3%) | 0.31 (3%) | 0.32 (3%) | 0.30 (3%) | 0.30 (3%) | 0.38 (4%) | 0.82 (4%) | 0.37 (3%) | 0.31 (3%) | 0.35 (4%) |
| Self Halo Exchange | 0.00 (0%) | 0.00 (0%) | 0.74 (4%) | 0.77 (6%) | 0.10 (1%) | 0.10 (1%) | 0.00 (0%) | 0.02 (0%) | 0.00 (0%) | 0.00 (0%) | 0.03 (0%) | 0.80 (4%) | 0.11 (1%) | 0.02 (0%) | 0.00 (0%) |
| MPI Halo Exchange | 0.24 (2%) | 0.22 (2%) | 0.00 (0%) | 0.00 (0%) | 0.88 (7%) | 0.83 (7%) | 0.18 (2%) | 0.19 (2%) | 0.26 (2%) | 0.26 (2%) | 0.19 (2%) | 0.00 (0%) | 0.83 (8%) | 0.18 (2%) | 0.41 (4%) |
| Total | 11.24 (100%) | 11.24 (100%) | 17.41 (100%) | 13.25 (100%) | 12.76 (100%) | 12.70 (100%) | 11.41 (100%) | 11.39 (100%) | 11.63 (100%) | 11.64 (100%) | 9.33 (100%) | 18.36 (100%) | 10.78 (100%) | 9.44 (100%) | 9.66 (100%) |

