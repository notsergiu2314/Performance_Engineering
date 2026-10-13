Results in results  (20 runs, 4 cases)

| case | deck | kernels | ranks | thr | n | best_wall_s | median_s | spread | grind_ns/cell | qa_dev_% | qa | reported |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| clover_bm_short_fortran_r1_t8 | clover_bm_short.in | fortran | 1 | 8 | 5 | 5.417 | 5.514 | 5.3% | 67.49 | 4.02e-12 | PASSED | Fortran |
| clover_bm_short_c_r1_t8 | clover_bm_short.in | c | 1 | 8 | 5 | 6.493 | 6.602 | 2.5% | 80.94 | 4.04e-12 | PASSED | C |
| clover_bm_short_fortran_r8_t1 | clover_bm_short.in | fortran | 8 | 1 | 5 | 5.305 | 5.455 | 4.4% | 66.12 | 4.55e-12 | PASSED | Fortran |
| clover_bm_short_c_r8_t1 | clover_bm_short.in | c | 8 | 1 | 5 | 6.362 | 6.415 | 2.7% | 79.32 | 4.55e-12 | PASSED | C |

C relative to Fortran (best wall, ratio > 1 means C slower)
| deck | ranks | thr | fortran_s | c_s | c/fortran |
|---|---|---|---|---|---|
| clover_bm_short.in | 1 | 8 | 5.417 | 6.493 | 1.199 |
| clover_bm_short.in | 8 | 1 | 5.305 | 6.362 | 1.199 |

Profiler split of best repetition (seconds, % of wall); sections under 1% omitted
| section | clover_bm_short_fortran_r1_t8 | clover_bm_short_c_r1_t8 | clover_bm_short_fortran_r8_t1 | clover_bm_short_c_r8_t1 |
|---|---|---|---|---|
| Timestep | 0.20 (4%) | 0.28 (4%) | 0.16 (3%) | 0.25 (4%) |
| Ideal Gas | 0.30 (6%) | 0.31 (5%) | 0.18 (3%) | 0.27 (4%) |
| Viscosity | 0.14 (3%) | 0.15 (2%) | 0.12 (2%) | 0.13 (2%) |
| PdV | 0.70 (13%) | 0.79 (12%) | 0.63 (12%) | 0.79 (12%) |
| Revert | 0.13 (2%) | 0.13 (2%) | 0.14 (3%) | 0.12 (2%) |
| Acceleration | 0.31 (6%) | 0.31 (5%) | 0.35 (7%) | 0.30 (5%) |
| Fluxes | 0.24 (5%) | 0.24 (4%) | 0.25 (5%) | 0.23 (4%) |
| Cell Advection | 1.06 (20%) | 1.50 (23%) | 0.97 (18%) | 1.46 (23%) |
| Momentum Advection | 1.98 (37%) | 2.44 (38%) | 2.20 (41%) | 2.37 (37%) |
| Reset | 0.29 (5%) | 0.29 (4%) | 0.18 (3%) | 0.28 (4%) |
| MPI Halo Exchange | 0.00 (0%) | 0.00 (0%) | 0.10 (2%) | 0.12 (2%) |
| Total | 5.41 (100%) | 6.49 (100%) | 5.30 (100%) | 6.36 (100%) |

