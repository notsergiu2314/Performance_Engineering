# Benchmark Comparison: jort vs sergiu branches

Oct 13, 2026 · @EVAbits

## Summary

Both branches measured CloverLeaf on the same HAICGU Kunpeng 920 node, on the same 3840² × 87-step problem, and reach the same verdict: the code is memory-bound everywhere (arithmetic intensity 0.2–0.27 flop/B against a ridge point of 5 flop/B), and further speed-up has to come from moving fewer bytes. Where the two branches overlap, their numbers agree to within a few percent: STREAM triad 263 vs 267 GB/s, FMA peak 1329 vs 1330 GFLOP/s, C kernels at 4×32 ranks×threads 13.05 vs 13.02 s, and a modelled 24.8 vs 24.9 GB of DRAM traffic per time step.

The branches differ in what they went deep on, and the two sets of findings are complementary:

- **jort branch (`jort-test`)**: wide layout sweep (8 rank×thread layouts × C and Fortran kernels, 5 repetitions), Fortran vs C comparison, and a per-section roofline. Found the best layout is 64×2 (C 11.23 s, Fortran 9.31 s), that Fortran is 17–20 % faster than C at every layout, and that Fortran already runs at 88 % of STREAM triad while C runs at 73 %.
- **sergiu branch (`sergiu-test`)**: hardware-counter analysis of the C kernels (PAPI per kernel, `perf`, DDR-controller counters), strong scaling from 1 to 128 cores, and a root-cause investigation of the pure-OpenMP variance. Found that transparent huge pages (512 MB pages) place CloverLeaf's arrays unevenly across the four NUMA domains, costing 1.7× in 1×128 runs; disabling THP per process restores balance (23.1 → 13.5 s). Validated the analytic byte model against DDR counters to within 1–5 %, and found 12.5 % of cycles in OpenMP barriers.

Two results need reconciling. First, the jort branch saw the same 1×128 variance (spread 50–69 % over 5 reps) but did not explain it; the sergiu THP finding explains it. Second, the sergiu branch derives a memory-bound floor of 10.5 s for 87 steps from the measured C-kernel DRAM traffic, yet the jort Fortran build runs in 9.31 s at 64×2, below that floor. The Fortran build must therefore move fewer hardware bytes than the C build (or the write-allocate assumption does not hold for it); DDR counters on the Fortran binary would settle this.

Both branches independently arrive at the same optimisation list: hoist the direction-only helper sweeps in momentum advection, keep cell-advection temporaries in registers, drop the dead `pre_vol`/`post_vol` stores, fuse the `calc_dt` reduction. The sergiu branch adds THP-off as a zero-source-change 1.7× win and `nowait`/`-fno-math-errno` as time-only changes; the jort branch adds 64×2 as the layout to measure against and has an earlier, unmeasured six-patch series for the Fortran kernels that also removes the Reset/Revert copies (1.4 GB per step) and parallelises over tiles.

## Setup and methodology

The two branches ran the same binary configuration on the same hardware, so their numbers can be compared directly. Both used one exclusive HAICGU compute node (TaiShan 2280: 2 × Kunpeng 920 / TaiShan-v110, 64 cores per socket, 128 physical cores, no SMT, 2.6 GHz, 4 NUMA domains of 32 cores, 4 × 32 MB L3, 16 DDR4-2666 channels, 128 GB), GCC 14.1.0 with `-O3 -march=native -funroll-loops -fopenmp`, OpenMPI 5.0.3, and the same CloverLeaf input (3840² cells, 87 steps, `test_problem 4` so every run has a built-in pass/fail check). The jort branch calls this deck `clover_bm16_short.in`; the sergiu branch calls it `bm3840.in` with `use_c_kernels` and `profiler_on` set inside the deck. The jort branch also benchmarked the smaller 960² deck on a laptop (Ryzen 7 5825U, 8 cores) as a pipeline check; the sergiu branch ran 960² (`bm960.in`) on the cluster for cache-resident contrast.

|  | jort branch | sergiu branch |
| --- | --- | --- |
| Kernels measured | C **and** Fortran | C only |
| Layouts (ranks × threads, all 128 cores) | 1×128, 2×64, 4×32, 8×16, 16×8, 32×4, 64×2, 128×1 | 1×128, 2×64, 4×32 |
| Strong scaling below 128 cores | no | 1×1 to 1×64 |
| Repetitions per case | 5 (best and median reported) | 3 (median reported) |
| Pinning | `--map-by slot:PE=T --bind-to core`, `OMP_PROC_BIND=close OMP_PLACES=cores` | same, via `jobs/common.sh` |
| Timing | CloverLeaf internal profiler sections | internal profiler + PAPI regions inside each kernel |
| Hardware counters | none | PAPI (IPC, instruction mix, back-end stalls), `perf record/stat`, DDR-controller (SCCL) counters |
| Memory ceiling | own STREAM-style `membw.c`, best of 3, pinned, per core / NUMA / socket / node | STREAM 100M doubles, 10 runs × 20 repetitions, 1 to 128 threads, plus per-NUMA and spread placements |
| Compute ceiling | `peak_fma.c` (FP64 FMA chains) | `peak_flops.c` (vector FMA, scalar FMA, vector divide) |
| Byte/flop model | `kernel_model.py`, one row per loop nest, no write-allocate | `kernel_model.py`, per cell, with and without write-allocate, validated against DDR counters |
| Placement experiments | none | THP on/off (`prctl` launcher), `numactl --interleave=all`, 1×120 |
| Optimisation work | six patches drafted (`patches/01`–`06`), not yet measured | optimisation plan with model-predicted byte savings, not yet implemented |
| Write-up | `jort_notes.md` + READMEs | LaTeX report draft (`report/main.tex`), M1 and M2 written, M3 placeholder |

Sources: `cloverleaf/perf-investigation/jort_notes.md`, `baseline/results/baseline-cluster/environment.txt` (job 34733, cn15, 2026-10-12) on `jort-test`; `CloverLeaf_ref/perf/README.md`, `report/main.tex`, `report/data/*.csv` (jobs 34741, 34743, 34752, m3 runs) on `sergiu-test`.

## Memory bandwidth (STREAM)

The two independent STREAM measurements agree on every scope once the sergiu best-of-10 is compared with the jort pinned best-of-3: about 13–15 GB/s per core, 66–67 GB/s per NUMA domain, 132–134 GB/s per socket and 263–267 GB/s per node (77–78 % of the theoretical 341 GB/s). Both branches note that the site-quoted 140 GB/s is wrong by a factor of two.

| Scope (threads) | jort triad, best of 3 (GB/s) | sergiu triad, median of 10 (GB/s) | sergiu triad, best of 10 (GB/s) |
| --- | --- | --- | --- |
| 1 core (1) | 13.0 | 14.9 | 14.9 |
| 1 NUMA domain (32) | 65.5 | 67.2 | 67.2 |
| 1 socket (64) | 132.1 | 133.7 | 133.9 |
| Full node (128) | 262.9 | 135.5 | 266.7 |
| Full node, read-only (128) | 295.7 |  |  |

The one place the branches diverge is the full-node median. The jort harness saw a spread under 1 % at 128 threads; the sergiu sweep saw the median collapse to 135.5 GB/s (half of best) at 96 and 128 threads, with runs ranging 135–267 GB/s. The sergiu branch traces this to the same transparent-huge-page placement effect it found in CloverLeaf (see the application section): with 512 MB huge pages and `THP=always`, where an 800 MB STREAM array lands depends on which thread first touches it. The jort `membw.c` run was not affected, most plausibly because it allocates and first-touches differently; the two harnesses have not been run side by side with THP disabled, so this stays an open point. For the roofline both branches use the pinned/best value (263 and 267 GB/s respectively).

The sergiu per-NUMA sweep also shows the four domains are symmetric (67.2, 68.8, 67.4, 68.8 GB/s) and that bandwidth scales linearly with domains used, which is why 4×32 (one rank per domain) is a safe layout. Sources: `roofline/results/roofline-34735/machine.csv` (cn15, 2026-10-12) on `jort-test`; `report/data/stream.csv` and `ceilings.csv` (jobs `m2_stream_*`) on `sergiu-test`.

## Roofline and compute ceilings

Both branches measured the same FP64 peak, 1329–1330 GFLOP/s per node (10.4 GFLOP/s per core, 4 flop/cycle at 2.6 GHz), and both independently found that the first assumption of 8 flop/cycle was wrong. The jort branch got there by fixing its microbenchmark: two early runs (jobs 34735, 34739) reported 6.2 GFLOP/s per core because GCC 14 compiled `v = v*x + y` into an `fmla` plus two SIMD moves; the accumulate form `v = v + v*x` reaches 99.9 % of the 4 flop/cycle theoretical (job 34746, spread 0.0 %). The sergiu branch adds two ceilings the jort branch lacks: scalar FMA reaches the same 10.4 GFLOP/s per core as NEON FMA (two scalar FMAs per cycle vs one 2-lane vector FMA), so vectorisation on this core saves instructions rather than raising peak flops; and vector divide runs at only 0.19 GFLOP/s per core (24.6 GFLOP/s per node), which matters for `viscosity`, `calc_dt` and `pdv`.

With STREAM triad at 263–267 GB/s the node ridge point is 5.1 flop/B. Every CloverLeaf kernel sits far left of it, so both branches conclude the compute roof plays no role.

**Byte and flop model.** Both branches count bytes per loop nest from the C kernel source and get the same traffic: the jort model gives 24.79 GB and 6.61 GFLOP per time step at 3840² (AI 0.27 flop/B); the sergiu model gives 1688 B and 451 flop per cell, which is 24.9 GB and 6.65 GFLOP per step for the same mesh. The sergiu model goes one step further and adds write-allocate traffic (a store that misses reads the line first): 2186 B per cell, AI 0.21, and 2.80 TB for the 87-step run. The DDR-controller counters measured 2.83 TB (1×128 THP off), 2.87 TB (4×32) and 2.94 TB (1×128 default), 1–5 % above the model, with a read:write ratio of 2.6–2.9 that also matches. This validates the write-allocate version of the model for the C build on Kunpeng 920, and means the jort no-write-allocate bytes understate hardware traffic by about 30 %.

| Section | Share of bytes (jort) | AI, no WA (jort) | AI, with WA (sergiu) | Fortran vs STREAM roof, 64×2 (jort) | C vs STREAM roof, 64×2 (jort) | Time share at 1×128, C (sergiu) |
| --- | --- | --- | --- | --- | --- | --- |
| Momentum advection | 41.0 % | 0.19 | 0.18 | 99 % | 80 % | 44.0 % |
| Cell advection | 21.4 % | 0.22 | 0.18 | 99 % | 72 % | 19.4 % |
| PdV (predict + correct) | 12.4 % | 0.39 | 0.28 / 0.24 | 87 % | 77 % | 9.6 % |
| Timestep (calc\_dt) | 4.8 % | 0.56 | 0.35 | 73 % | 58 % | 4.8 % |
| Acceleration | 4.8 % | 0.48 | 0.39 | 71 % | 69 % | 4.1 % |
| Ideal gas | 3.8 % | 0.34 | 0.19 | 76 % | 62 % | 4.7 % |
| Fluxes | 3.8 % | 0.19 | 0.12 | 78 % | 82 % | 3.0 % |
| Reset (copy) | 3.8 % | 0 | 0 | 92 % of copy | 94 % of copy | 3.2 % |
| Viscosity | 2.4 % | 1.03 | 0.83 | 58 % | 55 % | 2.2 % |
| Revert (copy) | 1.9 % | 0 | 0 | 84 % of copy | 84 % of copy | 1.3 % |
| **Whole step** | 100 % | 0.27 | 0.21 | **88 %** | **73 %** |  |

The two roofline readings are consistent but measure different things. The jort roofline uses the best 64×2 run and modelled (no-WA) bytes against STREAM-counted bytes, the apples-to-apples comparison, and finds Fortran at 88 % of triad with both advection kernels at 99 %, so Fortran is at the roof and only fewer bytes can help. C runs the same traffic 20–28 % slower in advection and 40 % slower in Timestep and Ideal Gas, which the jort branch attributes to the instruction side (no `omp simd` on the upwind sweeps, data-dependent indexing). The sergiu PAPI data confirms that diagnosis from the counters: the advection kernels execute only 12–16 % vector instructions, `calc_dt`, `ideal_gas` and `viscosity` execute none (their `sqrt` blocks GCC vectorisation without `-fno-math-errno`), and the whole run has IPC 0.19 with 79–97 % back-end stall cycles at 128 cores. The sergiu roofline places the whole C application at 46 % of attainable with default THP and 78–80 % with THP off or 4×32, using hardware bytes; its per-kernel points (38–56 % of ceiling) were taken from the unbalanced default-THP 1×128 run and should be re-plotted on the THP-off baseline.

Sources: `roofline/results/roofline-34746/machine.txt`, `roofline/results/roofline_bm16_short.csv`, `jort_notes.md` (jort-test); `report/data/ceilings.csv`, `report/tables/tab_model.tex`, `tab_kernels.tex`, `main.tex` §6 (sergiu-test).

## Application benchmarks and scaling

On the three layouts both branches ran, the C-kernel wall times agree within 3 % (1×128: 27.9 vs 24.8 s medians with large spread on both sides; 2×64: 18.7 vs 17.1 s; 4×32: 13.3 vs 13.0 s). The wider jort sweep shows the time keeps falling past 4×32: every layout with 8 or more ranks lands within 4 % of each other, and 64×2 is the best for both kernel sets (C 11.23 s best / 11.29 s median, Fortran 9.31 / 9.32 s, spread about 1 %). The sergiu THP-off run moves 1×128 from 24.8 s to 13.5 s, on par with 4×32 but still 20 % slower than the jort 64×2 C result.

&#91;embedded content: jort-test: baseline/results/baseline-cluster/summary.md (job 34733, 5 reps) · sergiu-test: report/data/scaling.csv (job 34741, 3 reps) and placement.csv (m3\_thp, THP off)\]

The run-to-run spread tells the same story from both sides. In the jort data the 1×128 and 2×64 cases have spreads of 50–69 % and 19–23 % over 5 repetitions, while everything from 4×32 up is below 6 % and from 8×16 up below 1.1 %. In the sergiu data 1×128 ranges 21.1–27.4 s and 2×64 15.4–20.4 s over 3 repetitions, while 4×32 is 12.9–13.2 s. The sergiu DDR-controller counters identify the cause as uneven first-touch placement under 512 MB transparent huge pages: in default 1×128 runs the busiest memory-controller group carried 1.26–1.45× the mean and the split changed from run to run (e.g. 27/33/13/27 % and 22/28/14/36 %), whereas every multi-rank layout and the THP-off run split 25/25/25/25. Interleaving all pages (`numactl --interleave=all`) balanced the controllers but was slower still (29.2 s) because three quarters of accesses became remote, and 1×120 did not help. Once each rank's data lives in its own domain, which 4 or more ranks guarantee, the problem disappears, and that is why the jort layouts with many ranks are both fast and stable.

**Fortran vs C (jort only).** Fortran is faster than C at every layout, by 19–23 % from 2×64 upward and by 60 % at 1×128. At 64×2 the gap is concentrated in Cell Advection (1.78 vs 2.43 s, +37 %) and Momentum Advection (3.39 vs 4.22 s, +24 %); PdV is +13 %, Timestep +26 %, Ideal Gas +22 %, and the copy kernels Reset and Revert are identical. Both builds pass the built-in correctness check with a deviation of 4×10⁻¹¹ %.

**Below 128 cores (sergiu only).** Single-core time for the C build is 528 s; speed-up is near-linear to 8 threads (5.6×), then flattens as one NUMA domain's bandwidth saturates (32 threads: 10.6×, 50 s), and 1×128 reaches only 21× with default THP. The best 128-core results are 40.6× (4×32) and 39.1× (1×128 THP off). On the small 960² deck, which partly fits in the 2 × 64 MB L3, 1×128 (1.45 s) is slower than 1×64 (1.20 s), halo exchange takes half the time, and 2×64 is fastest (0.69 s). The `perf record` profile of the 128-thread run also shows 12.5 % of all cycles in the OpenMP team barrier (`gomp_team_barrier_wait_end`), since every kernel is a chain of worksharing loops each ending in an implicit barrier.

**Where the time goes.** Both branches agree on the ranking: Momentum Advection first (jort 36–38 % of the step at 64×2; sergiu 44 % at 1×128 and 29 % on one core), Cell Advection second (19–22 %), PdV third (9–13 %). The sergiu counters add that Momentum Advection scales worst of the large kernels (14× from 1 to 128 cores against 22–59× for the others), which is why its share grows with core count, and that the scalar kernels `calc_dt`, `ideal_gas` and `viscosity` are latency-bound on one core (divide and square root, using 2–3 of 15 GB/s) but shrink to about 12 % of the run at full node.

## Side-by-side comparison

Everything the two branches both measured agrees to within a few percent, which is strong evidence that both tool chains are sound. The differences are in coverage and in three points of interpretation that need settling before the optimisation work.

| Quantity | jort branch | sergiu branch | Difference |
| --- | --- | --- | --- |
| STREAM triad, node (GB/s) | 262.9 (best of 3) | 266.7 (best of 10) | 1.4 % |
| STREAM triad, NUMA domain (GB/s) | 65.5 | 67.2 | 2.6 % |
| FP64 FMA peak, node (GFLOP/s) | 1329.3 | 1329.8 | 0.0 % |
| C kernels, 4×32, median (s) | 13.28 | 13.02 | 2.0 % |
| C kernels, 2×64, median (s) | 18.70 | 17.07 | 9 % (both noisy) |
| C kernels, 1×128, median (s) | 27.95 | 24.76 | 13 % (both noisy) |
| Modelled DRAM bytes per step, no write-allocate (GB) | 24.79 | 24.89 | 0.4 % |
| Arithmetic intensity, no write-allocate (flop/B) | 0.27 | 0.27 | 0 |
| Momentum advection share of step (C, 128 cores) | 38 % (64×2) | 44 % (1×128) | layout-dependent |

**Where they agree.** The code is memory-bound everywhere; momentum advection, cell advection and PdV are the three kernels that matter (about 68–75 % of the step); the pure-OpenMP 1×128 layout is slow and unstable; the site-quoted STREAM figure is half the real value; the Kunpeng 920 core does 4 not 8 flop/cycle; and the byte-reduction candidates are the same (hoist the direction-only sweeps in momentum advection, keep cell-advection temporaries in registers, drop the dead stores, fuse the `calc_dt` reduction).

**Where they disagree or need reconciling.**

1. **Write-allocate traffic.** The jort notes reject write-allocate accounting for the Kunpeng 920 on the grounds that a triad of 263 GB/s plus a write-allocate read would imply 350 GB/s of bus traffic, above the 341 GB/s theoretical. The sergiu DDR-controller calibration on STREAM found the counters match the with-write-allocate byte count to 2 %, and the CloverLeaf counts match the with-write-allocate model to 1–5 % (2.83–2.94 TB measured vs 2.80 TB modelled, against 2.16 TB without). The counter evidence is the more direct, but the bus-ceiling argument has not been answered: the calibration run was probably a median (135 GB/s) run where 4/3 × bandwidth still fits. A DDR-counter reading on a best-case 267 GB/s STREAM run, plus a check of the actual DIMM speed (the 341 GB/s assumes DDR4-2666), would close this.
2. **The memory floor and the Fortran build.** The sergiu floor of 10.5 s (2.80 TB at 267 GB/s) is derived from the C build's hardware traffic. The jort Fortran build runs 87 steps in 9.31 s at 64×2, 11 % below that floor, and its advection kernels sit at 99 % of STREAM triad using no-write-allocate bytes. Either the Fortran build moves fewer bytes (the jort notes suggest partial L2/L3 reuse at 1.8 MB per array per rank with 64 ranks), or the write-allocate assumption does not hold for it. DDR counters on Fortran and C at 64×2 would show which. Until then the floor should be quoted as a floor for the C build at few ranks.
3. **Best layout.** The sergiu scaling stops at 4×32 and proposes 1×128 with THP off (13.5 s) as the M3 baseline. The jort sweep shows every layout from 8×16 to 128×1 beats that by 7–16 %, with 64×2 best at 11.23 s for C. THP off brings nothing once there are 4 or more ranks (sergiu: 4×32 13.2 → 13.1 s), so the many-rank layouts are the faster and the stabler choice, and the M3 baseline should be 64×2.
4. **Bandwidth-utilisation convention.** The jort figures (Fortran 88 %, C 73 % of triad) divide modelled no-write-allocate bytes by STREAM-counted bandwidth; the sergiu figures (78–82 %) divide hardware-counted bytes by the same STREAM-counted bandwidth. For the same 4×32 C run the two conventions give 63 % and 82 %. One convention has to be chosen for the joint report; the consistent pair is either both counted (jort) or both hardware (sergiu, which then needs the hardware bandwidth of STREAM, see point 1).
5. **Optimisation patches vs plan.** The six patches on the jort branch (`patches/01`–`06`) are an earlier series against the **Fortran** kernels, are unmeasured, and are not applied to the tree; the project scope on both branches is the C kernels. They map onto the sergiu plan as follows: 01 and 05 = hoist and dead stores; 02 and 03 = remove the Revert and Reset copies by pointer swap, which the sergiu plan omits (1.4 GB per step, 5.6 % of traffic); 04 = scalar geometry on a uniform mesh, which the sergiu plan omits and which is only valid for uniform meshes; 06 = tile-level OpenMP, which addresses the 12.5 % barrier share the sergiu profile found. The sergiu plan adds `nowait` and `-fno-math-errno`, which the jort branch lacks.
6. **Correctness check.** The jort job 34729 shows `clover_bm.in` (960², 2955 steps) failing the built-in test at 0.018 % deviation for both Fortran and C at 128×1 and 4×32, unacknowledged in the notes. The sergiu branch relies on `test_problem 4` of the 3840² deck, which passes everywhere. The jort plan to use `clover_bm.in` as the parallel-correctness test therefore needs a reference answer that is valid for this compiler and decomposition first.
7. **Measurement coverage.** The jort branch alone has the Fortran baseline, the 8-layout sweep, 5 repetitions and the laptop pipeline check; the sergiu branch alone has single-core to 128-core scaling, PAPI instruction mix and stall cycles, the `perf` barrier profile, DDR-controller traffic, THP root cause and the per-process THP-off launcher. The 1×128 variance both saw has the same cause (the jort 1×128 case ran unbound, the sergiu one bound to cores, and both were noisy, so binding is not the explanation; the sergiu THP evidence is).

Minor documentation drift to fix when merging: the jort notes still cite GCC 12.1.0 and OpenMPI 4.1.3 while every run used GCC 14.1.0 and OpenMPI 5.0.3; the sergiu `perf/README.md` names branch `project`; the sergiu raw job outputs are gitignored, only hand-transcribed CSVs are committed, and the per-kernel roofline points were taken from the unbalanced default-THP run.

## Conclusions and next steps

The two branches together make a complete M1/M2 picture: the jort branch supplies the layout sweep, the Fortran reference and the per-section roofline; the sergiu branch supplies the counters, the DRAM-traffic validation of the model and the THP root cause. The LaTeX draft on `sergiu-test` (`report/main.tex`, authored by both group members) is already the joint report and lacks exactly the jort material: the 8-layout sweep, the Fortran-vs-C comparison, the 64×2 result and the patch inventory.

Combined conclusions:

- CloverLeaf on the Kunpeng 920 node is bandwidth-bound in every kernel (AI 0.2–0.27 flop/B vs a 5.1 flop/B ridge). Compute-side work cannot pay off; bytes and barriers can.
- The fastest baseline measured on either branch is 64×2: 11.23 s for C, 9.31 s for Fortran, both stable to about 1 %. The sergiu THP-off fix is the right explanation for the slow and noisy few-rank layouts, but the many-rank layouts avoid the problem without it and are faster.
- The C kernels carry two separable deficits: an instruction-side one (20–40 % slower than Fortran at equal bytes, no vectorisation in the upwind sweeps and the `sqrt` kernels) worth about 22 ms of the 129 ms C step at 64×2, and a byte-side one shared with Fortran (about 8 GB of the 24.8 GB per step is dead stores, repeated sweeps, spilled temporaries and copies) worth about 30 ms at 263 GB/s.
- The analytic byte model is trustworthy (1–5 % against DDR counters for C) and both branches' versions of it agree, so predicted savings can be used to rank the M3 changes.

Next steps, in order:

1. Fix the M3 baseline as the C kernels at 64×2 on the 3840² deck, 5 repetitions, reporting median and spread; run it once with the THP-off launcher to confirm there is no further gain at 64 ranks.
2. Run the DDR-controller counters on four cases: C 64×2, Fortran 64×2, and a pinned best-case STREAM run; check the DIMM speed with `dmidecode`. This settles write-allocate (comparison point 1), the Fortran-below-floor puzzle (point 2) and fixes the bandwidth convention (point 4) in one job.
3. Resolve the `clover_bm.in` test failure (0.018 % at 2955 steps) or replace it with a long run of the 3840² deck as the correctness gate, before any kernel is changed.
4. Implement the byte reductions in the C kernels in predicted-benefit order and verify each with the quality check and the DDR counters: momentum-advection hoisting (−13 % bytes), cell-advection temporaries (−6 %), Reset/Revert removal by pointer swap (−6 %), dead `pre_vol`/`post_vol` stores (−4 %), `calc_dt` fusion (−1 %). Port the logic of jort patches 01, 02, 03 and 05 rather than re-deriving it.
5. Address the C instruction deficit in parallel: `omp simd` or restructured upwind indexing in the advection flux sweeps, `-fno-math-errno` for the `sqrt` kernels, `nowait` between independent loops (12.5 % of cycles in barriers) or the tile-level parallelism of patch 06.
6. Merge the tooling onto one branch: the jort baseline harness (matrix file, repetitions, Fortran and C, `summarize.py`) plus the sergiu PAPI instrumentation, DDR-counter scripts and THP launcher, and a single `kernel_model.py` with a write-allocate switch. Commit the sergiu raw job outputs or archive them beside the CSVs.
7. Update the joint report: add the layout sweep and Fortran comparison to the analysis section, re-plot the per-kernel roofline from the THP-off or 64×2 run, state the write-allocate decision explicitly, and correct the compiler and MPI versions in the jort notes.
