# TODO 

## Kernels

**advec_mom_kernel_c.c**:

- Hoist first four loops (post_vol/pre_vol,
node_flux, node_mass_post, node_mass_pre) out of velocity loop, these do not need to be recalculated.
- `pre_vol` written over haloed grid, never read. Remove dead store
- velocity update write-allocate remove (no temporal store)

**advec_cell_kernel_c.c**:

- pre_mass, post_mass, post_ener and advec_vol as temporaries instead of writing and reading from memory in same iter.
- `post_vol` written over haloed grid, never read. Remove dead store

**revert_kernel_c.c/reset_field_kernel_c.c**:

- revert kernel without copy by swapping memory ownership

**calc_dt_kernel_c.c**:

- fused reduction to save a mesh store and reload for dt_min

## Report

- Add explanation of Arithmetic Intensity analysis for each kernel
- rewrite introduction
  - remove cloverleaf commit hash
- rewrite system description
  - add cloverleaf commit hash
- rewrite methodology for baseline
  - add method for AI estimation for kernels
- rewrite section ceilings/byte model for kernels/layouts
  - remove unnecessary tables/figures
  - add subsection computation of AI for kernels, verify
- rewrite baseline section
  - move table into section
- rewrite kernel improvements
  - remove percentages, say choose top 3 most time-consuming kernels and some obvious improvements across other kernels for bytes
  - include time-only compiler changes as compile command full old
  - include listings with old code and comment explaining what is inefficient and should be improved.
- write implementation section
  - listings with new code, explanation what is done
- write results section
  - same images / tables as baseline, with improved code results
  - for roofline kernel plot, decide how to plot based on results
- write section "concluding remarks"
  - did our improvements help?
  - what did we not do? (limitations)
  - is this useful in the cloverleaf use case?
  - if you think of something interesting to yap about

**Jort**:

Correctness gate, resolved 2026-10-19: the base binary reproduces the archived `clover_bm.in`
reference (job 34999); the builds with `-fno-math-errno -fno-trapping-math` give 0.3835202E-01 %
(job 34937); `optnf` (commit 8d7d81f, kernel changes with the baseline CFLAGS) passes 7 of 7
(job 35002), keeps the bytes and is 3.6 % slower than `opt` (job 35003: 8.56 vs 8.25 s, 1.32x
vs the archived baseline). `optnf` is the reported build; report, data, tables, figures and the
presentation were updated. `pdv` (51dd171 = optnf + Sergiu's PdV scalar d2b00e6) measured 2026-10-19
(jobs 35012/35016/35017): gate 7 of 7, 8.25 s, 2.012 TB, 1.37x at 64x2; it is the reported build
(`OPT_VARIANT=pdv make_assets.py`), report, data, tables, figures and slides carry its numbers. Open:
nothing on the cluster side; report polish (listings, conclusions prose), presentation rehearsal.

- advec_mom
- calc_dt

report:

- rewrite kernel improvements
  - remove percentages, say choose top 3 most time-consuming kernels and some obvious improvements across other kernels for bytes
  - include time-only compiler changes as compile command full old
  - include listings with old code and comment explaining what is inefficient and should be improved.
- write implementation section
  - listings with new code, explanation what is done
- write results section
  - same images / tables as baseline, with improved code results
  - for roofline kernel plot, decide how to plot based on results

**Sergiu**:

- advec_cell
- revert/reset field kernels

report:

- Add explanation of Arithmetic Intensity analysis for each kernel
- rewrite introduction
  - remove cloverleaf commit hash
- rewrite system description
  - add cloverleaf commit hash
- rewrite methodology for baseline
  - add method for AI estimation for kernels
- rewrite section ceilings/byte model for kernels/layouts
  - remove unnecessary tables/figures
  - add subsection computation of AI for kernels, verify
- rewrite baseline section
  - move table into section
