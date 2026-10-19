Results in /home/joosterveld/CloverLeaf_ref/perf/results/m3_correctness_34937/cell  (1 runs, 1 cases)

| case | deck | kernels | ranks | thr | thp | n | best_wall_s | median_s | spread | grind_ns/cell | qa_dev_% | qa | reported |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| clover_bm_c_r64_t2 | clover_bm.in | c | 64 | 2 | on | 1 | 14.382 | 14.382 | 0.0% | 5.28 | 3.84e-02 | FAILED | C |

Profiler split of best repetition (seconds, % of wall); sections under 1% omitted
| section | clover_bm_c_r64_t2 |
|---|---|
| Timestep | 1.50 (10%) |
| Ideal Gas | 0.58 (4%) |
| Viscosity | 1.00 (7%) |
| PdV | 1.68 (12%) |
| Acceleration | 0.59 (4%) |
| Fluxes | 0.24 (2%) |
| Cell Advection | 2.20 (15%) |
| Momentum Advection | 4.05 (28%) |
| MPI Halo Exchange | 2.52 (18%) |
| Total | 14.37 (100%) |

