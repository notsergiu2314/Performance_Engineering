Results in /home/joosterveld/CloverLeaf_ref/perf/results/m3_papi_optnf_35004/uninstrumented  (2 runs, 2 cases)

| case | deck | kernels | ranks | thr | thp | n | best_wall_s | median_s | spread | grind_ns/cell | qa_dev_% | qa | reported |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| clover_bm16_short_c_r64_t2 | clover_bm16_short.in | c | 64 | 2 | on | 1 | 8.516 | 8.516 | 0.0% | 6.63 | 3.95e-11 | PASSED | C |
| clover_bm16_short_c_r1_t128_thpoff | clover_bm16_short.in | c | 1 | 128 | off | 1 | 10.196 | 10.196 | 0.0% | 7.94 | 4.04e-11 | PASSED | C |

Profiler split of best repetition (seconds, % of wall); sections under 1% omitted
| section | clover_bm16_short_c_r64_t2 | clover_bm16_short_c_r1_t128_thpoff |
|---|---|---|
| Timestep | 0.65 (8%) | 0.60 (6%) |
| Ideal Gas | 0.49 (6%) | 0.57 (6%) |
| Viscosity | 0.40 (5%) | 0.45 (4%) |
| PdV | 1.44 (17%) | 1.66 (16%) |
| Acceleration | 0.62 (7%) | 0.64 (6%) |
| Fluxes | 0.38 (4%) | 0.39 (4%) |
| Cell Advection | 1.63 (19%) | 2.06 (20%) |
| Momentum Advection | 2.68 (32%) | 3.00 (29%) |
| Self Halo Exchange | 0.00 (0%) | 0.74 (7%) |
| MPI Halo Exchange | 0.20 (2%) | 0.00 (0%) |
| Total | 8.52 (100%) | 10.17 (100%) |

