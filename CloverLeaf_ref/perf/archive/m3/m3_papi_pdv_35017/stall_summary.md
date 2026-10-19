Results in /home/joosterveld/CloverLeaf_ref/perf/results/m3_papi_pdv_35017/stall  (2 runs, 2 cases)

| case | deck | kernels | ranks | thr | thp | n | best_wall_s | median_s | spread | grind_ns/cell | qa_dev_% | qa | reported |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| clover_bm16_short_c_r64_t2 | clover_bm16_short.in | c | 64 | 2 | on | 1 | 8.256 | 8.256 | 0.0% | 6.43 | 3.95e-11 | PASSED | C |
| clover_bm16_short_c_r1_t128_thpoff | clover_bm16_short.in | c | 1 | 128 | off | 1 | 10.639 | 10.639 | 0.0% | 8.29 | 4.04e-11 | PASSED | C |

Profiler split of best repetition (seconds, % of wall); sections under 1% omitted
| section | clover_bm16_short_c_r64_t2 | clover_bm16_short_c_r1_t128_thpoff |
|---|---|---|
| Timestep | 0.65 (8%) | 0.62 (6%) |
| Ideal Gas | 0.52 (6%) | 0.58 (5%) |
| Viscosity | 0.32 (4%) | 0.47 (4%) |
| PdV | 1.22 (15%) | 1.50 (14%) |
| Acceleration | 0.59 (7%) | 0.69 (6%) |
| Fluxes | 0.38 (5%) | 0.42 (4%) |
| Cell Advection | 1.67 (20%) | 2.28 (21%) |
| Momentum Advection | 2.64 (32%) | 3.23 (30%) |
| Self Halo Exchange | 0.03 (0%) | 0.78 (7%) |
| MPI Halo Exchange | 0.20 (2%) | 0.00 (0%) |
| Total | 8.26 (100%) | 10.61 (100%) |

