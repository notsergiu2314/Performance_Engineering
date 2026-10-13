#!/usr/bin/env python3
"""Analytical FLOP and DRAM-byte model of one CloverLeaf time step, per profiler section.

One row per mesh sweep. A sweep covers (X+nx)*(Y+ny) elements of REAL(8). `reads` and
`writes` are the number of distinct arrays streamed once through that sweep: stencil
neighbours of an array count once (a row of 3840 doubles is 30 KB, the 2-3 rows a stencil
touches stay in L2), every array is far larger than L3 at 3840^2 (118 MB each), so each
sweep streams its arrays from DRAM. Dead stores (post_vol in advec_cell, pre_vol in
advec_mom) are counted: they cost bandwidth. 1-D arrays (celldx, vertexdx, ...) are ignored.

`flops` is the operation count per element on the common path (+ - * / sqrt fabs min max
sign compare, one each; constant chains like *0.25*dt*0.5 are not folded without
fast-math). Data-dependent limiter branches in the advection kernels are only taken in
non-uniform cells, so the cheap path is weighted. FLOP counts carry maybe +-30%; for a
memory-bound kernel that moves its point along a line of slope 1, i.e. parallel to the
bandwidth roof, so the distance to the bandwidth roof depends on bytes and time only.

`calls` is the number of times the sweep runs per time step. Sources are the C kernels in
cloverleaf_b5e598d/kernels/ (the Fortran kernels have the same loop structure). The
per-step call sequence is in hydro.f90 / timestep.f90 / PdV.f90 / advection.f90.

Stdlib only, so it runs on the cluster as well as inside the plotting venv.
"""
import argparse
from collections import namedtuple

Sweep = namedtuple("Sweep", "name src nx ny reads writes flops calls")

# Section names exactly as printed under "Profiler Output" in clover.out.
SECTIONS = {
    "Ideal Gas": [
        # timestep.f90:60 (density0/energy0) and PdV.f90:122 (density1/energy1); the extra
        # call from field_summary every summary_frequency steps is ignored (~0.1 call/step).
        Sweep("eos", "ideal_gas_kernel_c.c:48-59", 0, 0, 2, 2, 11, 2),
    ],
    "Viscosity": [
        # reads xvel0, yvel0 (2x2 nodes), pressure (5-point), density0; common path, the
        # shock-cell else-branch (+22 flops) is rare.
        Sweep("viscosity", "viscosity_kernel_c.c:52-105", 0, 0, 4, 1, 41, 1),
    ],
    "Timestep": [
        # reads soundspeed, viscosity, density0, volume, xvel0, yvel0, xarea, yarea
        Sweep("calc_dt", "calc_dt_kernel_c.c:95-136", 0, 0, 8, 1, 44, 1),
        Sweep("dt_min_reduce", "calc_dt_kernel_c.c:139-144", 0, 0, 1, 0, 1, 1),
    ],
    "PdV": [
        # predictor reads xarea,yarea,volume,density0,energy0,pressure,viscosity,xvel0,yvel0
        # (9); corrector also xvel1,yvel1 (11). Writes volume_change(work_array1),
        # energy1, density1. Each face flux: 3 add + 4 mul; 4 faces = 28, rest ~12.
        Sweep("pdv_predictor", "PdV_kernel_c.c:66-115", 0, 0, 9, 3, 40, 1),
        Sweep("pdv_corrector", "PdV_kernel_c.c:119-168", 0, 0, 11, 3, 40, 1),
    ],
    "Revert": [
        Sweep("copy_density", "revert_kernel_c.c:49-53", 0, 0, 1, 1, 0, 1),
        Sweep("copy_energy", "revert_kernel_c.c:57-61", 0, 0, 1, 1, 0, 1),
    ],
    "Acceleration": [
        # reads density0, volume, pressure, viscosity, xarea, yarea, xvel0, yvel0;
        # writes xvel1, yvel1 (each written twice in the iteration, stays in register).
        Sweep("accelerate", "accelerate_kernel_c.c:57-95", 1, 1, 8, 2, 38, 1),
    ],
    "Fluxes": [
        Sweep("vol_flux_x", "flux_calc_kernel_c.c:52-61", 1, 0, 3, 1, 6, 1),
        Sweep("vol_flux_y", "flux_calc_kernel_c.c:64-73", 0, 1, 3, 1, 6, 1),
    ],
    "Cell Advection": [
        # Two calls per step, one per direction (sweep_number 1 then 2). Sweep A covers the
        # whole array incl. halo; sweep 1 reads volume + both vol_flux, sweep 2 only one.
        # post_vol (work_array2) is written and never read: a dead store.
        Sweep("pre_post_vol_s1", "advec_cell_kernel_c.c:74-87 / 185-198", 5, 5, 3, 2, 6, 1),
        Sweep("pre_post_vol_s2", "advec_cell_kernel_c.c:92-100 / 204-212", 5, 5, 2, 2, 2, 1),
        # Flux sweep: reads vol_flux, pre_vol, density1, energy1 (3-point stencils);
        # writes mass_flux, ener_flux. 21 flops on the cheap path, 51 with both limiters.
        Sweep("flux_x", "advec_cell_kernel_c.c:104-154", 3, 0, 4, 2, 25, 1),
        Sweep("flux_y", "advec_cell_kernel_c.c:217-268", 0, 3, 4, 2, 25, 1),
        # Update: reads density1, energy1, pre_vol, mass_flux, ener_flux, vol_flux; writes
        # pre_mass, post_mass, post_ener, advec_vol (work arrays), density1, energy1.
        Sweep("update", "advec_cell_kernel_c.c:157-177 / 271-291", 0, 0, 6, 6, 10, 2),
    ],
    "Momentum Advection": [
        # Four calls per step: xvel and yvel for each of the two directions. Sweep A covers
        # the whole array; mom_sweep 1/2 (first direction) reads volume + both vol_flux,
        # mom_sweep 3/4 reads volume + one. pre_vol (work_array5) is a dead store.
        Sweep("pre_post_vol_s1", "advec_mom_kernel_c.c:75-98", 5, 5, 3, 2, 4, 2),
        Sweep("pre_post_vol_s2", "advec_mom_kernel_c.c:101-120", 5, 5, 2, 2, 2, 2),
        # x direction (2 calls: xvel1 and yvel1)
        Sweep("x_node_flux", "advec_mom_kernel_c.c:125-134", 5, 1, 1, 1, 4, 2),
        Sweep("x_node_mass_post", "advec_mom_kernel_c.c:136-149", 4, 1, 2, 1, 8, 2),
        Sweep("x_node_mass_pre", "advec_mom_kernel_c.c:151-157", 4, 1, 2, 1, 2, 2),
        # mom_flux: reads node_flux, node_mass_pre, vel1; 10 flops cheap, 26 with limiter
        Sweep("x_mom_flux", "advec_mom_kernel_c.c:159-189", 3, 1, 3, 1, 12, 2),
        Sweep("x_vel_update", "advec_mom_kernel_c.c:192-201", 1, 1, 4, 1, 4, 2),
        # y direction (2 calls)
        Sweep("y_node_flux", "advec_mom_kernel_c.c:205-214", 1, 5, 1, 1, 4, 2),
        Sweep("y_node_mass_post", "advec_mom_kernel_c.c:216-229", 1, 4, 2, 1, 8, 2),
        Sweep("y_node_mass_pre", "advec_mom_kernel_c.c:231-237", 1, 4, 2, 1, 2, 2),
        Sweep("y_mom_flux", "advec_mom_kernel_c.c:239-269", 1, 3, 3, 1, 12, 2),
        Sweep("y_vel_update", "advec_mom_kernel_c.c:271-280", 1, 1, 4, 1, 4, 2),
    ],
    "Reset": [
        Sweep("copy_density", "reset_field_kernel_c.c:50-55", 0, 0, 1, 1, 0, 1),
        Sweep("copy_energy", "reset_field_kernel_c.c:57-62", 0, 0, 1, 1, 0, 1),
        Sweep("copy_xvel", "reset_field_kernel_c.c:64-69", 1, 1, 1, 1, 0, 1),
        Sweep("copy_yvel", "reset_field_kernel_c.c:71-76", 1, 1, 1, 1, 0, 1),
    ],
}

# Profiler sections with no mesh sweep (boundary-only, reductions, I/O). Their time is
# reported but they get no point on the roofline.
UNMODELLED = ["Tile Halo Exchange", "Self Halo Exchange", "MPI Halo Exchange",
              "Summary", "Visit", "The Rest"]


def elements(x, y, s):
    return (x + s.nx) * (y + s.ny)


def sweep_bytes(x, y, s, write_allocate=False):
    """DRAM bytes per step for one sweep. With write_allocate every store also costs a
    read-for-ownership line fill, so a written array moves 16 B/element instead of 8."""
    return 8 * elements(x, y, s) * (s.reads + s.writes * (2 if write_allocate else 1)) * s.calls


def sweep_flops(x, y, s):
    return elements(x, y, s) * s.flops * s.calls


def section_totals(x, y, write_allocate=False):
    """{section: {"flops", "bytes", "sweeps", "calls"}} per time step."""
    out = {}
    for sec, sweeps in SECTIONS.items():
        out[sec] = {
            "flops": sum(sweep_flops(x, y, s) for s in sweeps),
            "bytes": sum(sweep_bytes(x, y, s, write_allocate) for s in sweeps),
            "sweeps": sum(s.calls for s in sweeps),
            "calls": max(s.calls for s in sweeps),
        }
    return out


def step_totals(x, y, write_allocate=False):
    t = section_totals(x, y, write_allocate)
    return {"flops": sum(v["flops"] for v in t.values()),
            "bytes": sum(v["bytes"] for v in t.values()),
            "sweeps": sum(v["sweeps"] for v in t.values())}


def _table(hdr, rows, md):
    if md:
        print("| " + " | ".join(hdr) + " |")
        print("|" + "---|" * len(hdr))
        for r in rows:
            print("| " + " | ".join(str(c) for c in r) + " |")
    else:
        w = [max(len(str(c)) for c in col) for col in zip(hdr, *rows)]
        for r in [hdr] + rows:
            print("  ".join(str(c).ljust(n) for c, n in zip(r, w)))
    print()


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--x", type=int, default=3840, help="x_cells (default 3840)")
    ap.add_argument("--y", type=int, default=3840, help="y_cells (default 3840)")
    ap.add_argument("--write-allocate", action="store_true",
                    help="count a read-for-ownership on every store (16 B per written element)")
    ap.add_argument("--md", action="store_true", help="markdown tables")
    ap.add_argument("--audit", action="store_true", help="also print one row per sweep")
    a = ap.parse_args()

    tot = section_totals(a.x, a.y, a.write_allocate)
    step = step_totals(a.x, a.y, a.write_allocate)
    print(f"CloverLeaf step model, {a.x} x {a.y} cells, "
          f"write-allocate {'on' if a.write_allocate else 'off'}\n")
    rows = []
    for sec, v in tot.items():
        rows.append([sec, v["sweeps"], f"{v['flops']/1e9:.3f}", f"{v['bytes']/1e9:.3f}",
                     f"{v['flops']/v['bytes']:.3f}", f"{100*v['bytes']/step['bytes']:.1f}"])
    rows.append(["Total (modelled)", step["sweeps"], f"{step['flops']/1e9:.3f}",
                 f"{step['bytes']/1e9:.3f}", f"{step['flops']/step['bytes']:.3f}", "100.0"])
    _table(["section", "sweeps/step", "GFLOP/step", "GB/step", "AI FLOP/B", "% bytes"], rows, a.md)

    if a.audit:
        rows = []
        for sec, sweeps in SECTIONS.items():
            for s in sweeps:
                rows.append([sec, s.name, s.src, f"(X+{s.nx})(Y+{s.ny})", s.reads, s.writes,
                             s.flops, s.calls, f"{sweep_bytes(a.x, a.y, s, a.write_allocate)/1e9:.3f}"])
        _table(["section", "sweep", "source", "extent", "reads", "writes", "flop/elem",
                "calls/step", "GB/step"], rows, a.md)


if __name__ == "__main__":
    main()
