#!/usr/bin/env python3
"""Analytic flop and memory-traffic model of the CloverLeaf C kernels.

Derived by reading kernels/*_kernel_c.c (commit b5e598d). For every loop nest
we list the 2D arrays it reads and writes and the flops per cell.

Traffic assumptions (state them in the report):
  * The grid does not fit in cache (bm3840: ~118 MB per array), so every loop
    nest streams each array it touches from DRAM once.
  * Stencil neighbours (j+-1, k+-1) hit in cache (layer condition: a few rows
    of 3840 doubles = 30 KB fit in the 512 KB L2).
  * Bytes per cell = 8 * (reads + writes + WA * written-but-not-read arrays),
    WA = 1 if a store first reads the line (write-allocate), 0 if not.
  * 1D arrays (celldx, vertexdx, ...) and halo cells are ignored.

Flop convention: + - * / and sqrt count as 1 flop; comparisons, fabs, MIN,
MAX, SIGN count 0; loop-invariant constants (0.25*dt*0.5) are hoisted.
Branchy kernels use the common path; deviations are noted per loop.
These counts are estimates: check them against the source before relying on
them (the CPU has no flop counter, so they cannot be measured directly).

Usage:  python3 kernel_model.py            # prints the per-kernel table
"""

from dataclasses import dataclass, field


@dataclass
class Loop:
    reads: tuple
    writes: tuple
    flops: float
    note: str = ""

    def bytes_per_cell(self, wa):
        r, w = set(self.reads), set(self.writes)
        return 8 * (len(r) + len(w) + wa * len(w - r))


@dataclass
class Kernel:
    name: str
    category: str            # matching line of CloverLeaf's profiler output
    calls_per_step: float
    loops: list = field(default_factory=list)
    # Kernels whose loops differ between calls (sweep 1 / sweep 2) list
    # (fraction of calls, loops) pairs instead of a single loop list.
    variants: list = field(default_factory=list)

    def _variants(self):
        return self.variants or [(1.0, self.loops)]

    def all_loops(self):
        return [l for _, loops in self._variants() for l in loops]

    def flops_per_cell(self):
        return sum(w * sum(l.flops for l in loops) for w, loops in self._variants())

    def bytes_per_cell(self, wa):
        return sum(w * sum(l.bytes_per_cell(wa) for l in loops) for w, loops in self._variants())

    def ai(self, wa):
        return self.flops_per_cell() / self.bytes_per_cell(wa)


# ---------------------------------------------------------------- kernels
IDEAL_GAS = Kernel("ideal_gas", "Ideal Gas", 2.1, [
    # 2 calls per step (timestep + PdV predictor) + 1 per field_summary
    # (every 10 steps). 1/rho, 0.4*rho, *e, rho*p, v*v*(p*pbe-pbv), sqrt.
    Loop(("density", "energy"), ("pressure", "soundspeed"), 9),
])

VISCOSITY = Kernel("viscosity", "Viscosity", 1, [
    Loop(("xvel0", "yvel0", "pressure", "density0"), ("viscosity",), 40,
         "+13 flops in compressed cells (else branch)"),
])

CALC_DT = Kernel("calc_dt", "Timestep", 1, [
    Loop(("soundspeed", "viscosity", "density0", "xvel0", "yvel0",
          "xarea", "yarea", "volume"), ("dt_min",), 31),
    Loop(("dt_min",), (), 0, "min reduction over dt_min"),
])

PDV_PREDICT = Kernel("pdv_predict", "PdV", 1, [
    Loop(("xarea", "yarea", "volume", "density0", "energy0", "pressure",
          "viscosity", "xvel0", "yvel0"),
         ("volume_change", "energy1", "density1"), 33,
         "min_cell_volume is computed but unused (dead code)"),
])

PDV_CORRECT = Kernel("pdv_correct", "PdV", 1, [
    Loop(("xarea", "yarea", "volume", "density0", "energy0", "pressure",
          "viscosity", "xvel0", "yvel0", "xvel1", "yvel1"),
         ("volume_change", "energy1", "density1"), 33),
])

REVERT = Kernel("revert", "Revert", 1, [
    Loop(("density0",), ("density1",), 0),
    Loop(("energy0",), ("energy1",), 0),
])

ACCELERATE = Kernel("accelerate", "Acceleration", 1, [
    Loop(("density0", "volume", "xarea", "yarea", "pressure", "viscosity",
          "xvel0", "yvel0"), ("xvel1", "yvel1"), 37),
])

FLUX_CALC = Kernel("flux_calc", "Fluxes", 1, [
    Loop(("xarea", "xvel0", "xvel1"), ("vol_flux_x",), 5),
    Loop(("yarea", "yvel0", "yvel1"), ("vol_flux_y",), 5),
])

# advec_cell: 2 calls per step (sweep 1 in one direction, sweep 2 in the
# other). Loop 1 differs between sweeps; "flux" is the direction's flux.
_cell_l1_s1 = Loop(("volume", "vol_flux_x", "vol_flux_y"), ("pre_vol", "post_vol"), 6,
                   "sweep 1; post_vol is stored but never read in advec_cell")
_cell_l1_s2 = Loop(("volume", "vol_flux"), ("pre_vol", "post_vol"), 2, "sweep 2")
_cell_l2 = Loop(("vol_flux", "pre_vol", "density1", "energy1"), ("mass_flux", "ener_flux"), 31,
                "upwind/limiter with data-dependent (gather) indexing and no omp simd: check bin/vec_report.txt")
_cell_l3 = Loop(("density1", "energy1", "pre_vol", "mass_flux", "ener_flux", "vol_flux"),
                ("pre_mass", "post_mass", "post_ener", "advec_vol", "density1", "energy1"), 10,
                "pre_mass/post_mass/post_ener/advec_vol are temporaries stored to memory")
ADVEC_CELL = Kernel("advec_cell", "Cell Advection", 2, variants=[
    (0.5, [_cell_l1_s1, _cell_l2, _cell_l3]),
    (0.5, [_cell_l1_s2, _cell_l2, _cell_l3]),
])

# advec_mom: 4 calls per step (xvel and yvel, for each of the 2 sweeps).
# Loops 0-3 only depend on the direction, not on the velocity component, so
# they are computed twice with identical results (xvel call and yvel call).
_mom_l0_s1 = Loop(("volume", "vol_flux_x", "vol_flux_y"), ("post_vol", "pre_vol"), 4,
                  "sweep 1; pre_vol is stored but never read in advec_mom")
_mom_l0_s2 = Loop(("volume", "vol_flux"), ("post_vol", "pre_vol"), 2, "sweep 2")
_mom_l1 = Loop(("mass_flux",), ("node_flux",), 4)
_mom_l2 = Loop(("density1", "post_vol"), ("node_mass_post",), 8)
_mom_l3 = Loop(("node_mass_post", "node_flux"), ("node_mass_pre",), 2)
_mom_l4 = Loop(("node_flux", "node_mass_pre", "vel1"), ("mom_flux",), 18,
               "upwind/limiter with data-dependent (gather) indexing and no omp simd: check bin/vec_report.txt")
_mom_l5 = Loop(("vel1", "node_mass_pre", "mom_flux", "node_mass_post"), ("vel1",), 4)
ADVEC_MOM = Kernel("advec_mom", "Momentum Advection", 4, variants=[
    (0.5, [_mom_l0_s1, _mom_l1, _mom_l2, _mom_l3, _mom_l4, _mom_l5]),
    (0.5, [_mom_l0_s2, _mom_l1, _mom_l2, _mom_l3, _mom_l4, _mom_l5]),
])

RESET_FIELD = Kernel("reset_field", "Reset", 1, [
    Loop(("density1",), ("density0",), 0),
    Loop(("energy1",), ("energy0",), 0),
    Loop(("xvel1",), ("xvel0",), 0),
    Loop(("yvel1",), ("yvel0",), 0),
])

FIELD_SUMMARY = Kernel("field_summary", "Summary", 0.1, [
    Loop(("volume", "density0", "energy0", "pressure", "xvel0", "yvel0"), (), 22,
         "reductions; every summary_frequency=10 steps; flops approximate"),
])

KERNELS = [IDEAL_GAS, VISCOSITY, CALC_DT, PDV_PREDICT, PDV_CORRECT, REVERT,
           ACCELERATE, FLUX_CALC, ADVEC_CELL, ADVEC_MOM, RESET_FIELD, FIELD_SUMMARY]


def per_category(cells, steps, wa):
    """Total flops and bytes of each profiler category over a run."""
    out = {}
    for k in KERNELS:
        n = cells * steps * k.calls_per_step
        f, b = out.get(k.category, (0.0, 0.0))
        out[k.category] = (f + n * k.flops_per_cell(), b + n * k.bytes_per_cell(wa))
    return out


def per_kernel(cells, steps, wa):
    """Total flops and bytes of each kernel (papi_prof region names) per run."""
    out = {}
    for k in KERNELS:
        n = cells * steps * k.calls_per_step
        out[k.name] = (n * k.flops_per_cell(), n * k.bytes_per_cell(wa))
    return out


def main():
    print(f"{'kernel':14s} {'calls/step':>10s} {'flop/cell':>9s} "
          f"{'B/cell':>7s} {'B/cell+WA':>9s} {'AI':>6s} {'AI+WA':>6s}")
    tot_f = tot_b0 = tot_b1 = 0.0
    for k in KERNELS:
        f, b0, b1 = k.flops_per_cell(), k.bytes_per_cell(0), k.bytes_per_cell(1)
        tot_f += f * k.calls_per_step
        tot_b0 += b0 * k.calls_per_step
        tot_b1 += b1 * k.calls_per_step
        print(f"{k.name:14s} {k.calls_per_step:10.1f} {f:9.1f} {b0:7.0f} {b1:9.0f} "
              f"{f / b0:6.3f} {f / b1:6.3f}")
    print(f"{'per step':14s} {'':10s} {tot_f:9.1f} {tot_b0:7.0f} {tot_b1:9.0f} "
          f"{tot_f / tot_b0:6.3f} {tot_f / tot_b1:6.3f}   (per cell, all calls)")
    print("\nNotes from the source:")
    seen = set()
    for k in KERNELS:
        for l in k.all_loops():
            if l.note and (k.name, l.note) not in seen:
                seen.add((k.name, l.note))
                print(f"  {k.name}: {l.note}")


if __name__ == "__main__":
    main()
