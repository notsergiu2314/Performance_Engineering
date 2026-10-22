# Talk script: Analysis and Optimisation of CloverLeaf on a Kunpeng 920 Node

Fifteen minutes of speaking: about 2000 words at 135 words per minute. "Starts" is the elapsed time when the
slide comes up; the same stamp opens the `\note{}` of every frame (`make notes`). Click straight through the
three section divider slides. Sentences in *[brackets]* can be dropped if you run late.

| # | slide | starts | length |
|---|---|---|---|
| | title | 0:00 | 0:20 |
| 1 | The application and the machine | 0:20 | 1:05 |
| 2 | Methodology | 1:25 | 1:10 |
| 3 | What CloverLeaf computes in one time step | 2:35 | 1:35 |
| 4 | Ceilings, byte model and roofline | 4:10 | 1:05 |
| 5 | Ceilings, byte model and roofline (figure) | 5:15 | 0:55 |
| 6 | Where the time goes | 6:10 | 1:15 |
| 7 | Baseline | 7:25 | 1:05 |
| 8 | Plan: five byte reductions | 8:30 | 1:00 |
| 9 | Data flow (1/2): work that was done twice | 9:30 | 1:00 |
| 10 | Data flow (2/2): round trips through DRAM | 10:30 | 0:55 |
| 11 | Ladder at 64×2 | 11:25 | 1:05 |
| 12 | Every layout, every kernel | 12:30 | 0:55 |
| 13 | Correctness, and what is still open | 13:25 | 0:55 |
| 14 | Conclusions | 14:20 | 0:40 |
| | end, questions | 15:00 | |

---

## Title (0:00, 0:20)

Hello, we are Jort Oosterveld and Sergiu-Adrian Preda, group 11. In short: we took the C kernels of
CloverLeaf, found that they were already running at the memory ceiling of the node, and still made them
1.37 times faster, by moving fewer bytes.

## 1. The application and the machine (0:20, 1:05)

CloverLeaf is a fluid dynamics mini-app: it solves the compressible Euler equations on a 2-D grid and
updates every cell in every time step. The reference version runs with MPI and OpenMP, and its compute
kernels exist in Fortran and in C. We optimise the C kernels and keep Fortran as the reference.

Our benchmark, bm3840, is a 3840 by 3840 grid for 87 steps: about 25 arrays of 118 megabytes, a 3 gigabyte
working set, more than twenty times the L3 cache. So every loop streams its arrays from DRAM.

The machine is one HAICGU node: two Kunpeng 920 sockets, 128 ARM cores, four NUMA domains. A layout
"r times t" means r MPI ranks with t OpenMP threads each.

Our question: how far is the baseline from what the hardware allows, and what does it take to close the gap?

## 2. Methodology (1:25, 1:10)

We measure on three levels. CloverLeaf's own profiler gives the wall clock per phase. PAPI, per kernel and
per thread, gives instructions per cycle, the instruction mix and the stall cycles. And Linux perf reads
the counters of the DDR controllers, so for every run we know the bytes that actually cross the memory
interface.

Every number is the median of five repetitions, with the minimum and maximum, and every repetition runs
under the DDR counters. One convention matters for the rest of the talk: a bandwidth is always hardware
bytes divided by wall clock, for STREAM and for CloverLeaf alike.

We also checked the tools themselves. The kernel times add up to the wall clock within one percent, the DDR
counters were calibrated on STREAM, and the traffic is spread evenly over the memory controllers. Finally,
every build has to pass a correctness gate: it must reproduce the check value of the baseline.

## 3. What CloverLeaf computes in one time step (2:35, 1:35)

Before the numbers: what does one time step compute? On the left, the grid is staggered. Density, energy,
pressure and viscosity live at the cell centres, the velocities at the corners, the fluxes on the faces.

A step has four phases, top to bottom. First the time step: `ideal_gas` computes pressure and sound speed,
`viscosity` adds artificial viscosity at shocks, and `calc_dt` takes the stability limit of every cell. The
minimum over all cells and all MPI ranks is the new delta t.

Second, the Lagrangian step, in which the mesh moves with the fluid. A predictor estimates density and
energy half a step ahead, which gives the pressure at the half step. `revert` throws the prediction away,
`accelerate` turns the pressure and viscosity gradients into new velocities, and the corrector takes the
full step with them.

Third, advection maps everything back onto the fixed mesh: fluxes per face, then the cell quantities and
the momentum, along x and then along y. The order swaps every step. Fourth, `reset_field` copies the new time
level over the old one.

The red bars are the halo exchanges between MPI ranks. Every box is one kernel: a few loops over almost
fifteen million cells. That is why the rest of this talk is about bytes.

## 4. Ceilings, byte model and roofline (4:10, 1:05)

To say how far the baseline is from the hardware, we need the ceilings. STREAM triad on all 128 threads
reaches 266.5 gigabytes per second, the FMA peak is 1330 gigaflops, so the ridge point is at 5 flops per
byte: a kernel needs five flops for every byte it moves before compute becomes the limit.

On the right is our analytic byte model. For every loop nest we count the arrays it reads and writes, and we
charge a write-allocate for every store. Over a whole step that is 451 flops and 2186 bytes per cell: an
arithmetic intensity of 0.21 flops per byte, about 24 times below the ridge.

For bm3840 the model predicts 2.80 terabytes and the DDR counters measure 2.83, one percent more. The reads
come to 1.34 times what the code asks for, because every C store first reads its cache line: a
read-for-ownership.

## 5. Ceilings, byte model and roofline: figure (5:15, 0:55)

Here is the model as a roofline: one core on the left, the full node on the right. Each dot is a kernel,
numbered as in our report, at its modelled intensity and its measured performance.

All kernels sit between 0.1 and 0.9 flops per byte, far to the left of the ridge. Number one, momentum
advection, and number two, cell advection, are at about 0.2; number seven, viscosity, is the most intense at
0.8. On the full node they all crowd against the bandwidth roof, and the orange diamond, the whole
application at 64 by 2, sits just under it.

So no kernel is compute-bound. The only questions are how close to the roof the code runs, and how many
bytes it moves.

## 6. Where the time goes (6:10, 1:15)

Where does the time go? The two advection kernels take 48 percent of the time on one core and 63 percent
on 128 cores, because `advec_mom` scales worst: fourteen times on 128 cores, against 22 to 59 times for
the other large kernels.

The counters show that nothing here is limited by compute. At 64 by 2 the IPC is between 0.1 and 0.5, and
81 to 96 percent of the cycles are back-end stalls: the cores are waiting for memory.

There are inefficiencies on the instruction side too. `calc_dt`, `ideal_gas` and `viscosity` run entirely
scalar, because GCC keeps `sqrt` as a library call that may set errno. The upwind loops in the advection
kernels pick their neighbours by the sign of the flow, so only 12 to 16 percent of their instructions are
vector instructions. And perf shows that 12.5 percent of all cycles are spent waiting in the OpenMP
barrier; those cycles also count in the IPC.

But while the cores are stalled on memory, none of these can pay off.

## 7. Baseline (7:25, 1:05)

This is the baseline at every layout, C on top and Fortran below. At 64 by 2 the C code runs 11.32 seconds
and moves 2.83 terabytes: 250 gigabytes per second over the whole run, start-up included. That is 94 percent
of the hardware ceiling. The memory floor, 2.83 terabytes at 266.5 gigabytes per second, is 10.6 seconds:
the baseline is within a second of it.

*[One outlier: one rank with 128 threads. First touch places whole arrays on one NUMA domain, so the busiest
memory controller group carries 1.66 times the mean; without transparent huge pages most of that goes away.]*

The Fortran kernels are 18 percent faster at the same layout, for one reason: they move fewer bytes, 2.35
instead of 2.83 terabytes.

So the finding: the memory system is already saturated, and the only way to go faster is to move fewer
bytes.

## 8. Plan: five byte reductions (8:30, 1:00)

So we planned byte reductions, and predicted each one with the byte model before changing any code. The
floor column is the time the bytes alone would take at 266.5 gigabytes per second.

The first five rows are the changes on the next two slides. One: helper loops in `advec_mom` that only
depend on the sweep direction ran once per velocity component; once per sweep is enough. Two: four
temporaries in `advec_cell` move into registers. Three: two arrays are written and never read. Four: reset
and revert swap arrays instead of copying them. Five: `calc_dt` fuses its minimum into the compute loop.

Together that is minus 29.3 percent, a floor of 7.44 seconds. Streaming stores could take up to another 23
percent; we did not do those. The time-only rows at the bottom wait until the bytes are gone.

## 9. Data flow (1/2): work that was done twice (9:30, 1:00)

The first two changes remove whole loop nests. On the left, `advec_mom`. For each sweep, four preparation
loops build eight node arrays: fluxes, masses and volumes. They depend only on the direction of the sweep,
but the code rebuilt them for the x velocity and again for the y velocity. Now they are built once and both
velocity passes read them: 12.8 percent of all traffic is gone.

On the right, reset and revert. Every step, reset copied density, energy and both velocities from time level
one into time level zero: four arrays of 118 megabytes, read, written and read for ownership. A copy is not
needed when only the name changes. Fortran's `MOVE_ALLOC` swaps the two allocations, three pointer moves per
field and no data. Revert disappears the same way: another 6.6 percent.

## 10. Data flow (2/2): round trips through DRAM (10:30, 0:55)

The other changes remove round trips through DRAM. In `advec_cell`, four temporaries were full-mesh arrays:
each value was stored, read for ownership, and read back by the next statement in the same iteration. As
scalars they never leave the registers. Same arithmetic, same order, 128 bytes less per cell and step.
Sergiu did the same for `volume_change` in both PdV passes.

Below that, dead stores: `post_vol` and `pre_vol` were written over the whole grid and never read, so
deleting them is free.

And on the right, `calc_dt`. It wrote a time-step limit for every cell into an array, and a second loop read
the array back to find the minimum. With an OpenMP min reduction it is one pass over the grid.

## 11. Ladder at 64×2 (11:25, 1:05)

Did the measurements follow the model? This ladder adds the changes one group at a time, at 64 by 2, five
repetitions each. The two compiler flags alone change nothing: 11.28 seconds. The `advec_cell` group removes
12 percent of the bytes and 12 percent of the time, the `advec_mom` group 15 and 16. All changes together:
minus 28 percent bytes, minus 27 percent time.

optnf is the same code without the two flags, and pdv adds Sergiu's PdV scalar: 2.01 terabytes, minus 28.8
percent of the bytes, against the 30.8 percent the model predicted. Every build still runs at 240 to 252
gigabytes per second, so it stays on the roof and the time falls with the bytes.

The flags were worth 3.6 percent on the optimised kernels, but they break the correctness gate. So pdv,
without them, is our final build: 1.37 times faster, from 11.32 down to 8.26 seconds.

## 12. Every layout, every kernel (12:30, 0:55)

The gain holds at every layout: 1.36 to 1.37 times at the four balanced layouts, and 1.33 at one rank with
128 threads, whose wall clock scatters by a third between runs. The same quarter of the traffic is gone
everywhere, so the speed-up is the same everywhere. The optimised C, in green, is now faster than the
Fortran reference, in grey, at every layout.

Per kernel, the two advection kernels gained most: 1.60 and 1.45 times. PdV gained 1.13, and reset and
revert are gone. `accelerate` and `flux_calc` we did not touch.

The application moved up the roof, not off it: it now runs at 91 percent of the ceiling, only 9 percent
above the floor of its own bytes.

## 13. Correctness, and what is still open (13:25, 0:55)

Correctness. Our gate runs `clover_bm.in`, a 960 squared grid for 2955 steps, and compares CloverLeaf's
check value with the archived reference. The baseline binary reproduces it at every layout. Every build with
the two compiler flags, even the flags-only build, gives one and the same other value, so the flags move it,
not our kernel changes. Sergiu's bisect traced it to GCC fusing multiplies and adds into FMAs. optnf and pdv,
without the flags, pass at all seven layouts. We chose reproducibility over 3.6 percent.

What is still open: we are still on the bandwidth roof, so the next gains are again bytes. `accelerate`,
`flux_calc` and `viscosity` are untouched, streaming stores could remove up to 23 percent more, and the
remaining instruction-side work in `advec_cell` is worth at most nine percent.

## 14. Conclusions (14:20, 0:40)

To conclude. The C kernels are memory-bound, at 0.2 flops per byte, and the baseline already used 94
percent of the memory bandwidth, so only fewer bytes could make it faster. Our byte model, checked against
the DDR counters to one percent, predicted minus 31 percent of the traffic; we measured minus 28.8. The wall
clock followed: 1.37 times at 64 by 2, faster than Fortran at every layout, and it passes the gate.

Thank you. We are happy to take your questions.
