Results in /home/joosterveld/clover-runs/baseline-34733  (80 runs, 16 cases)

| case | deck | kernels | ranks | thr | n | best_wall_s | median_s | spread | grind_ns/cell | qa_dev_% | qa | reported |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| clover_bm16_short_fortran_r1_t128 | clover_bm16_short.in | fortran | 1 | 128 | 5 | 13.708 | 19.392 | 50.4% | 10.57 | 4.06e-11 | PASSED | Fortran |
| clover_bm16_short_c_r1_t128 | clover_bm16_short.in | c | 1 | 128 | 5 | 21.942 | 27.945 | 68.8% | 17.04 | 4.04e-11 | PASSED | C |
| clover_bm16_short_fortran_r2_t64 | clover_bm16_short.in | fortran | 2 | 64 | 5 | 13.552 | 15.588 | 23.0% | 10.53 | 6.81e-11 | PASSED | Fortran |
| clover_bm16_short_c_r2_t64 | clover_bm16_short.in | c | 2 | 64 | 5 | 16.566 | 18.697 | 19.2% | 12.90 | 6.80e-11 | PASSED | C |
| clover_bm16_short_fortran_r4_t32 | clover_bm16_short.in | fortran | 4 | 32 | 5 | 10.635 | 11.008 | 5.9% | 8.28 | 6.81e-11 | PASSED | Fortran |
| clover_bm16_short_c_r4_t32 | clover_bm16_short.in | c | 4 | 32 | 5 | 13.051 | 13.277 | 4.7% | 10.17 | 6.80e-11 | PASSED | C |
| clover_bm16_short_fortran_r8_t16 | clover_bm16_short.in | fortran | 8 | 16 | 5 | 10.431 | 10.456 | 0.8% | 8.13 | 6.81e-11 | PASSED | Fortran |
| clover_bm16_short_c_r8_t16 | clover_bm16_short.in | c | 8 | 16 | 5 | 12.464 | 12.485 | 0.3% | 9.71 | 6.80e-11 | PASSED | C |
| clover_bm16_short_fortran_r16_t8 | clover_bm16_short.in | fortran | 16 | 8 | 5 | 9.455 | 9.460 | 0.8% | 7.37 | 5.87e-11 | PASSED | Fortran |
| clover_bm16_short_c_r16_t8 | clover_bm16_short.in | c | 16 | 8 | 5 | 11.456 | 11.516 | 0.6% | 8.92 | 5.86e-11 | PASSED | C |
| clover_bm16_short_fortran_r32_t4 | clover_bm16_short.in | fortran | 32 | 4 | 5 | 9.435 | 9.449 | 0.8% | 7.35 | 5.87e-11 | PASSED | Fortran |
| clover_bm16_short_c_r32_t4 | clover_bm16_short.in | c | 32 | 4 | 5 | 11.390 | 11.410 | 0.6% | 8.87 | 5.86e-11 | PASSED | C |
| clover_bm16_short_fortran_r64_t2 | clover_bm16_short.in | fortran | 64 | 2 | 5 | 9.314 | 9.319 | 1.0% | 7.25 | 3.95e-11 | PASSED | Fortran |
| clover_bm16_short_c_r64_t2 | clover_bm16_short.in | c | 64 | 2 | 5 | 11.233 | 11.292 | 0.7% | 8.75 | 3.95e-11 | PASSED | C |
| clover_bm16_short_fortran_r128_t1 | clover_bm16_short.in | fortran | 128 | 1 | 5 | 9.636 | 9.657 | 0.3% | 7.50 | 3.95e-11 | PASSED | Fortran |
| clover_bm16_short_c_r128_t1 | clover_bm16_short.in | c | 128 | 1 | 5 | 11.626 | 11.644 | 1.1% | 9.06 | 3.95e-11 | PASSED | C |

C relative to Fortran (best wall, ratio > 1 means C slower)
| deck | ranks | thr | fortran_s | c_s | c/fortran |
|---|---|---|---|---|---|
| clover_bm16_short.in | 1 | 128 | 13.708 | 21.942 | 1.601 |
| clover_bm16_short.in | 128 | 1 | 9.636 | 11.626 | 1.207 |
| clover_bm16_short.in | 16 | 8 | 9.455 | 11.456 | 1.212 |
| clover_bm16_short.in | 2 | 64 | 13.552 | 16.566 | 1.222 |
| clover_bm16_short.in | 32 | 4 | 9.435 | 11.390 | 1.207 |
| clover_bm16_short.in | 4 | 32 | 10.635 | 13.051 | 1.227 |
| clover_bm16_short.in | 64 | 2 | 9.314 | 11.233 | 1.206 |
| clover_bm16_short.in | 8 | 16 | 10.431 | 12.464 | 1.195 |

Profiler split of best repetition (seconds, % of wall); sections under 1% omitted

| section | clover_bm16_short_fortran_r1_t128 | clover_bm16_short_c_r1_t128 | clover_bm16_short_fortran_r2_t64 | clover_bm16_short_c_r2_t64 | clover_bm16_short_fortran_r4_t32 | clover_bm16_short_c_r4_t32 | clover_bm16_short_fortran_r8_t16 | clover_bm16_short_c_r8_t16 | clover_bm16_short_fortran_r16_t8 | clover_bm16_short_c_r16_t8 | clover_bm16_short_fortran_r32_t4 | clover_bm16_short_c_r32_t4 | clover_bm16_short_fortran_r64_t2 | clover_bm16_short_c_r64_t2 | clover_bm16_short_fortran_r128_t1 | clover_bm16_short_c_r128_t1 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Timestep | 0.54 (4%) | 1.07 (5%) | 0.54 (4%) | 0.89 (5%) | 0.49 (5%) | 0.84 (6%) | 0.50 (5%) | 0.72 (6%) | 0.57 (6%) | 0.74 (6%) | 0.57 (6%) | 0.73 (6%) | 0.53 (6%) | 0.67 (6%) | 0.53 (6%) | 0.72 (6%) |
| Ideal Gas | 0.60 (4%) | 0.86 (4%) | 0.48 (4%) | 0.72 (4%) | 0.47 (4%) | 0.55 (4%) | 0.49 (5%) | 0.57 (5%) | 0.40 (4%) | 0.50 (4%) | 0.40 (4%) | 0.50 (4%) | 0.41 (4%) | 0.50 (4%) | 0.40 (4%) | 0.49 (4%) |
| Viscosity | 0.44 (3%) | 0.57 (3%) | 0.48 (4%) | 0.58 (3%) | 0.34 (3%) | 0.35 (3%) | 0.34 (3%) | 0.34 (3%) | 0.43 (5%) | 0.44 (4%) | 0.43 (5%) | 0.45 (4%) | 0.34 (4%) | 0.36 (3%) | 0.37 (4%) | 0.38 (3%) |
| PdV | 1.56 (11%) | 2.23 (10%) | 1.66 (12%) | 2.18 (13%) | 1.48 (14%) | 1.70 (13%) | 1.46 (14%) | 1.69 (14%) | 1.23 (13%) | 1.42 (12%) | 1.19 (13%) | 1.35 (12%) | 1.17 (13%) | 1.32 (12%) | 1.21 (13%) | 1.34 (12%) |
| Revert | 0.20 (1%) | 0.18 (1%) | 0.17 (1%) | 0.16 (1%) | 0.17 (2%) | 0.16 (1%) | 0.17 (2%) | 0.16 (1%) | 0.17 (2%) | 0.17 (2%) | 0.17 (2%) | 0.17 (2%) | 0.19 (2%) | 0.19 (2%) | 0.18 (2%) | 0.18 (2%) |
| Acceleration | 0.72 (5%) | 0.86 (4%) | 0.77 (6%) | 0.91 (5%) | 0.63 (6%) | 0.65 (5%) | 0.64 (6%) | 0.64 (5%) | 0.58 (6%) | 0.62 (5%) | 0.59 (6%) | 0.62 (5%) | 0.55 (6%) | 0.56 (5%) | 0.56 (6%) | 0.60 (5%) |
| Fluxes | 0.51 (4%) | 0.74 (3%) | 0.59 (4%) | 0.81 (5%) | 0.43 (4%) | 0.38 (3%) | 0.43 (4%) | 0.38 (3%) | 0.40 (4%) | 0.37 (3%) | 0.40 (4%) | 0.37 (3%) | 0.40 (4%) | 0.38 (3%) | 0.40 (4%) | 0.37 (3%) |
| Cell Advection | 2.60 (19%) | 4.48 (20%) | 2.61 (19%) | 3.33 (20%) | 2.06 (19%) | 2.80 (21%) | 2.06 (20%) | 2.65 (21%) | 1.78 (19%) | 2.43 (21%) | 1.76 (19%) | 2.44 (21%) | 1.78 (19%) | 2.43 (22%) | 1.79 (19%) | 2.49 (21%) |
| Momentum Advection | 5.08 (37%) | 9.40 (43%) | 4.98 (37%) | 5.51 (33%) | 3.43 (32%) | 4.37 (33%) | 3.41 (33%) | 4.26 (34%) | 3.34 (35%) | 4.20 (37%) | 3.37 (36%) | 4.23 (37%) | 3.39 (36%) | 4.22 (38%) | 3.55 (37%) | 4.47 (38%) |
| Reset | 0.59 (4%) | 0.65 (3%) | 0.46 (3%) | 0.54 (3%) | 0.37 (3%) | 0.35 (3%) | 0.34 (3%) | 0.31 (3%) | 0.33 (3%) | 0.33 (3%) | 0.32 (3%) | 0.31 (3%) | 0.34 (4%) | 0.33 (3%) | 0.31 (3%) | 0.29 (3%) |
| Self Halo Exchange | 0.77 (6%) | 0.81 (4%) | 0.04 (0%) | 0.04 (0%) | 0.03 (0%) | 0.03 (0%) | 0.04 (0%) | 0.03 (0%) | 0.01 (0%) | 0.01 (0%) | 0.02 (0%) | 0.00 (0%) | 0.00 (0%) | 0.00 (0%) | 0.00 (0%) | 0.00 (0%) |
| MPI Halo Exchange | 0.00 (0%) | 0.00 (0%) | 0.73 (5%) | 0.86 (5%) | 0.71 (7%) | 0.83 (6%) | 0.52 (5%) | 0.68 (5%) | 0.18 (2%) | 0.20 (2%) | 0.19 (2%) | 0.20 (2%) | 0.19 (2%) | 0.23 (2%) | 0.30 (3%) | 0.25 (2%) |
| Total | 13.67 (100%) | 21.90 (100%) | 13.55 (100%) | 16.56 (100%) | 10.63 (100%) | 13.05 (100%) | 10.43 (100%) | 12.46 (100%) | 9.45 (100%) | 11.45 (100%) | 9.43 (100%) | 11.39 (100%) | 9.31 (100%) | 11.23 (100%) | 9.64 (100%) | 11.63 (100%) |

