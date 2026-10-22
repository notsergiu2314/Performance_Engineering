# Notes

## cluster data

- 64MB L3 per socket

## terms

**stall cycles**:

- hw counter STALL_BACKEND
- frontend has instr ready, but backend cannot execute yet. (In our case, we assume wait for memory fetch)

## observations

- 25 arrays of ~118MB on bm3840 set.

- very heavily memory bound: fewer cores should produce close performance to full node (32x2 should come within 15%) if we look at STREAM. Could test this for future work

- C kernels move more bytes, mostly read-for-ownership
  - kunpeng 920 skips read-for-ownership if core writes sequential cache lines. Fortran compiles differently most likely, and does not mix memory streams with these writes. For answer, need to inspect assembly.

- the more the bytes drop in the same size problem, proportionally the less the performance increases.
  - because of startup and barriers for openMP

- the -fno-math-errno flag removes an asm library call, and allows the compiler to use the sqrt instruction directly and vectorize. this code has different multiply-add pairs than the library call, so it fuses differently, and the rounding is changed.
  - 3.6% increase in speed, but reproducability compared to baseline is reduced. Still consistent with itself every run.

- model:
  - assumptions:
    - stencil neighbours at j+1, k+1 hit in L2.
    - no cached values between loop nests (every array loaded from DRAM once per loop)
    - read-for-ownership for every value that is stored but not also read
    - ignore halo cells and 1D coordinate arrays

- loop blocking (loop tiling)
  - 3 MB per rank (2MB from L3 pool + 2x512kB L2 per core)
  - possible for back-to-back loops without halo exchange.
  - stencil loops need a lag for consecutive loops (next loop reads prev loop's value).

## Questions about the project

- why tested on max threads only? because memory bound from baseline runs, strong scaling stops halving at about 16 threads

- Why measured one size array only?
- because we test on large problems only, weak scaling not tested future work perhaps when expanding to multiple nodes to run

- Why 64x2 is best vs 32x4 and other layouts?
- everything with a rank count that can be evenly split over the 4 numa domains (at least 4, max 128) will be efficient for first-touch. The 64x2 layout happens to balance OMP synchronization barrier cost, and is very close to 4x32. We tried nowait, but did not have much impact.

- what is the THP effect?
- when we have less than 4 ranks, the threads of one rank are split across NUMA domains. The array is then won by different threads, so the entire array is put in one of the NUMA domains, causing load imbalance. Smaller pages allow the individual rows of the array to be placed in the same domain as the thread that will use them. If we use 4 or more ranks, the threads are split inside of one NUMA domain, removing this race entirely, since the pages will always get placed in the correct NUMA domain.

- How have we handled cache usage?
- we use the large 3840♤2 problem, we modelled the byte model for cache misses. We focus on the larger problems

- Why no MPI scalasca benchmarking?
- MPI is cheap, from our 128 rank run, and we do not do multiple nodes. Less interesting, but can be done in the future

- why 8x16 and 16x8 missing?
- because the rest cover the region around the optimum, there was no need to add them after the initial orientation runs. Future work could add them for completeness.

- If there is so much memory dependency and stall cycles, why not just fuse the kernels so they have more work? 
- yeah, that is exactly the plan for future work. Also reducing the synchronization barriers by adding nowait will help.
