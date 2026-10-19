Results in /home/joosterveld/CloverLeaf_ref/perf/results/m3_papi_pdv_35017/mix  (2 runs, 2 cases)

| case | deck | kernels | ranks | thr | thp | n | best_wall_s | median_s | spread | grind_ns/cell | qa_dev_% | qa | reported |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| clover_bm16_short_c_r64_t2 | clover_bm16_short.in | c | 64 | 2 | on | 1 | 8.340 | 8.340 | 0.0% | 6.50 | 3.95e-11 | PASSED | C |
| clover_bm16_short_c_r1_t128_thpoff | clover_bm16_short.in | c | 1 | 128 | off | 1 | 10.048 | 10.048 | 0.0% | 7.83 | 4.04e-11 | PASSED | C |

Profiler split of best repetition (seconds, % of wall); sections under 1% omitted
| section | clover_bm16_short_c_r64_t2 | clover_bm16_short_c_r1_t128_thpoff |
|---|---|---|
| Timestep | 0.69 (8%) | 0.60 (6%) |
| Ideal Gas | 0.52 (6%) | 0.58 (6%) |
| Viscosity | 0.32 (4%) | 0.42 (4%) |
| PdV | 1.24 (15%) | 1.46 (15%) |
| Acceleration | 0.59 (7%) | 0.66 (7%) |
| Fluxes | 0.38 (5%) | 0.39 (4%) |
| Cell Advection | 1.67 (20%) | 2.06 (20%) |
| Momentum Advection | 2.63 (31%) | 3.04 (30%) |
| Self Halo Exchange | 0.03 (0%) | 0.77 (8%) |
| MPI Halo Exchange | 0.24 (3%) | 0.00 (0%) |
| Total | 8.34 (100%) | 10.02 (100%) |

