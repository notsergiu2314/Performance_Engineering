Results in /home/joosterveld/CloverLeaf_ref/perf/results/m3_papi_pdv_35017/uninstrumented  (2 runs, 2 cases)

| case | deck | kernels | ranks | thr | thp | n | best_wall_s | median_s | spread | grind_ns/cell | qa_dev_% | qa | reported |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| clover_bm16_short_c_r64_t2 | clover_bm16_short.in | c | 64 | 2 | on | 1 | 8.295 | 8.295 | 0.0% | 6.46 | 3.95e-11 | PASSED | C |
| clover_bm16_short_c_r1_t128_thpoff | clover_bm16_short.in | c | 1 | 128 | off | 1 | 10.019 | 10.019 | 0.0% | 7.81 | 4.04e-11 | PASSED | C |

Profiler split of best repetition (seconds, % of wall); sections under 1% omitted
| section | clover_bm16_short_c_r64_t2 | clover_bm16_short_c_r1_t128_thpoff |
|---|---|---|
| Timestep | 0.65 (8%) | 0.61 (6%) |
| Ideal Gas | 0.49 (6%) | 0.55 (6%) |
| Viscosity | 0.37 (4%) | 0.44 (4%) |
| PdV | 1.21 (15%) | 1.46 (15%) |
| Acceleration | 0.62 (8%) | 0.65 (6%) |
| Fluxes | 0.38 (5%) | 0.39 (4%) |
| Cell Advection | 1.67 (20%) | 2.03 (20%) |
| Momentum Advection | 2.66 (32%) | 3.04 (30%) |
| Self Halo Exchange | 0.00 (0%) | 0.76 (8%) |
| MPI Halo Exchange | 0.22 (3%) | 0.00 (0%) |
| Total | 8.29 (100%) | 9.98 (100%) |

