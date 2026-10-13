#!/usr/bin/env python3
"""Re-evaluate the C-kernel optimisation plan on the validated byte model.

Each planned change is expressed as an edit of the loop table in kernel_model.py
(the same model that the DDR-controller counters confirmed to 1-5 % for bm3840),
so every prediction uses one byte convention: hardware bytes with write-allocate.
(m3_stream_ddrc, job 34795: a pure streaming store does NOT read the line first on this
CPU, STREAM's hardware bytes are its counted bytes; the CloverLeaf stores do pay the
read-for-ownership, m3_baseline job 34797 measured 2.83 TB = 1.01 x the WA model, reads
1.34 x the demand reads. The no-WA model is therefore the upper bound of what streaming
stores could save, reported as its own row.)

  python3 plan_bytes.py [--cells 14745600] [--steps 87] [--bw <GB/s>] [--csv report/data/plan.csv]

--bw   hardware memory ceiling used for the time floor (default: dram_node_hw from
       report/data/ceilings.csv, else dram_node_best x 4/3)

The jort-branch patch series (Fortran, discarded) maps onto these rows: patches 01 and 05
= "advec_mom helpers once per sweep" + "dead stores", 02 and 03 = "Revert/Reset by pointer
swap", 06 = "tile-level parallelism" (time only); patch 04 (scalar geometry, uniform mesh
only) is not planned.
"""
import argparse
import csv
import sys
from dataclasses import replace
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import kernel_model as km  # noqa: E402

CELLS = 3840 * 3840
STEPS = 87


def step_bytes(kernels, wa):
    return sum(k.calls_per_step * k.bytes_per_cell(wa) for k in kernels)


def step_flops(kernels):
    return sum(k.calls_per_step * k.flops_per_cell() for k in kernels)


def swap(kernels, old, new):
    return [new if k is old else k for k in kernels]


def without_writes(loop, names):
    return replace(loop, writes=tuple(w for w in loop.writes if w not in names))


# ------------------------------------------------------------------ changes
def advec_mom_hoist(kernels):
    """Loops 0-3 of advec_mom (post_vol/pre_vol, node_flux, node_mass_post, node_mass_pre)
    depend only on the sweep direction: compute them once per sweep instead of once for xvel
    and once for yvel. Per call, that halves their traffic; loops 4-5 stay per velocity."""
    k = km.ADVEC_MOM
    (w1, s1), (w2, s2) = k.variants
    helpers1, rest1 = s1[:4], s1[4:]
    helpers2, rest2 = s2[:4], s2[4:]
    new = replace(k, variants=[(w1 / 2, helpers1 + rest1), (w1 / 2, rest1),
                               (w2 / 2, helpers2 + rest2), (w2 / 2, rest2)])
    return swap(kernels, k, new)


def advec_cell_temporaries(kernels):
    """pre_mass, post_mass, post_ener, advec_vol are consumed in the same iteration that
    writes them: keep them in registers (loop fusion), no store and no write-allocate."""
    k = km.ADVEC_CELL
    temps = {"pre_mass", "post_mass", "post_ener", "advec_vol"}
    new = replace(k, variants=[(w, [without_writes(l, temps) if l is km._cell_l3 else l for l in loops])
                               for w, loops in k.variants])
    return swap(kernels, k, new)


def dead_stores(kernels):
    """post_vol in advec_cell and pre_vol in advec_mom are stored but never read."""
    out = kernels
    kc = next(k for k in out if k.name == "advec_cell")
    out = swap(out, kc, replace(kc, variants=[(w, [without_writes(l, {"post_vol"}) if "post_vol" in l.writes else l
                                                   for l in loops]) for w, loops in kc.variants]))
    kmom = next(k for k in out if k.name == "advec_mom")
    out = swap(out, kmom, replace(kmom, variants=[(w, [without_writes(l, {"pre_vol"}) if "pre_vol" in l.writes else l
                                                       for l in loops]) for w, loops in kmom.variants]))
    return out


def reset_revert_swap(kernels):
    """Reset copies the *1 fields back into *0 and Revert the *0 into *1: both become pointer
    swaps of the field pairs (no traffic). Revert exists only because the PdV predictor
    overwrites density1/energy1 that the corrector recomputes."""
    out = kernels
    for name in ("reset_field", "revert"):
        k = next(k for k in out if k.name == name)
        out = swap(out, k, replace(k, loops=[], variants=[]))
    return out


def calc_dt_fuse(kernels):
    """calc_dt writes dt_min per cell and re-reads it for the minimum: fuse the reduction
    into the first loop (no dt_min array at all)."""
    k = km.CALC_DT
    l1 = without_writes(k.loops[0], {"dt_min"})
    return swap(kernels, k, replace(k, loops=[l1]))


CHANGES = [
    ("advec_mom: direction-only helper loops once per sweep", advec_mom_hoist, "bytes"),
    ("advec_cell: keep 4 temporaries in registers", advec_cell_temporaries, "bytes"),
    ("drop dead stores post_vol / pre_vol", dead_stores, "bytes"),
    ("Reset/Revert copies by pointer swap", reset_revert_swap, "bytes"),
    ("calc_dt: fuse the min reduction", calc_dt_fuse, "bytes"),
]
TIME_ONLY = [
    ("nowait between independent worksharing loops", "12.5 % of cycles in gomp barrier (perf, 1x128)"),
    ("-fno-math-errno for the sqrt kernels", "calc_dt, ideal_gas, viscosity run scalar (0 % NEON)"),
    ("omp simd / restructured upwind indexing in advection flux sweeps",
     "only after the byte reductions: at 64x2 both C and Fortran run at 94-95 % of the hardware ceiling"),
    ("tile-level parallelism (jort patch 06)", "fork/join per tile per kernel"),
]


def ceiling_default():
    p = Path(__file__).resolve().parents[3] / "report" / "data" / "ceilings.csv"   # repo root / report
    if not p.exists():
        return None, "none"
    c = {}
    with open(p, newline="") as f:
        for r in csv.DictReader(line for line in f if not line.startswith("#")):
            c[r["name"]] = float(r["value"])
    if "dram_node_hw" in c:
        return c["dram_node_hw"], "dram_node_hw (DDRC-calibrated hardware STREAM)"
    if "dram_node_best" in c:
        return c["dram_node_best"] * 4 / 3, "dram_node_best x 4/3 (assumed write-allocate; run m3_stream_ddrc)"
    return None, "none"


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--cells", type=int, default=CELLS)
    ap.add_argument("--steps", type=int, default=STEPS)
    ap.add_argument("--bw", type=float, help="hardware memory ceiling, GB/s")
    ap.add_argument("--csv", help="write report/data/plan.csv-style rows here")
    a = ap.parse_args()
    bw, bw_src = (a.bw, "--bw") if a.bw else ceiling_default()

    base = list(km.KERNELS)
    b0 = step_bytes(base, 1)           # bytes per cell per step, with write-allocate
    n = a.cells * a.steps
    print(f"baseline: {b0:.0f} B/cell/step with write-allocate ({step_bytes(base, 0):.0f} without), "
          f"{b0 * n / 1e12:.2f} TB for {a.cells} cells x {a.steps} steps, AI {step_flops(base) / b0:.3f} flop/B")
    if bw:
        print(f"memory floor at {bw:.0f} GB/s ({bw_src}): {b0 * n / bw / 1e9:.2f} s\n")
    rows = []
    print(f"{'change':62s} {'B/cell':>7s} {'delta':>7s} {'TB':>6s} {'floor_s':>8s}")
    cumulative = base
    for label, fn, kind in CHANGES:
        single = fn(base)
        cumulative = fn(cumulative)
        b = step_bytes(single, 1)
        bc = step_bytes(cumulative, 1)
        floor = b * n / bw / 1e9 if bw else float("nan")
        print(f"{label:62s} {b:7.0f} {100 * (b - b0) / b0:+6.1f}% {b * n / 1e12:6.2f} {floor:8.2f}")
        rows.append(dict(change=label, kind=kind, bytes_per_cell_wa=f"{b:.0f}", delta_pct=f"{100 * (b - b0) / b0:.1f}",
                         pred_TB=f"{b * n / 1e12:.3f}", floor_s=f"{floor:.2f}" if bw else "",
                         cumulative_bytes_per_cell_wa=f"{bc:.0f}", cumulative_delta_pct=f"{100 * (bc - b0) / b0:.1f}",
                         rationale=fn.__doc__.strip().split("\n")[0]))
    bc = step_bytes(cumulative, 1)
    floor = bc * n / bw / 1e9 if bw else float("nan")
    print(f"{'all byte changes together':62s} {bc:7.0f} {100 * (bc - b0) / b0:+6.1f}% {bc * n / 1e12:6.2f} {floor:8.2f}")
    print(f"  without write-allocate the same changes remove {100 * (step_bytes(base, 0) - step_bytes(cumulative, 0)) / step_bytes(base, 0):.0f} % "
          f"of the bytes (the jort loop-nest audit estimated about a third of 24.8 GB per step)")
    rows.append(dict(change="all byte changes together", kind="bytes", bytes_per_cell_wa=f"{bc:.0f}",
                     delta_pct=f"{100 * (bc - b0) / b0:.1f}", pred_TB=f"{bc * n / 1e12:.3f}",
                     floor_s=f"{floor:.2f}" if bw else "", cumulative_bytes_per_cell_wa=f"{bc:.0f}",
                     cumulative_delta_pct=f"{100 * (bc - b0) / b0:.1f}", rationale="sum of the rows above"))
    # streaming stores: the no-write-allocate model is the bound (m3_stream_ddrc showed that STREAM's
    # stores move no read-for-ownership bytes on this CPU; CloverLeaf's stores currently do)
    bs = step_bytes(base, 0)
    bsc = step_bytes(cumulative, 0)
    fs = bs * n / bw / 1e9 if bw else float("nan")
    print(f"{'streaming stores (no read-for-ownership), upper bound':62s} {bs:7.0f} {100 * (bs - b0) / b0:+6.1f}% {bs * n / 1e12:6.2f} {fs:8.2f}")
    print(f"{'  ... on top of all byte changes':62s} {bsc:7.0f} {100 * (bsc - b0) / b0:+6.1f}% {bsc * n / 1e12:6.2f} "
          f"{(bsc * n / bw / 1e9 if bw else float('nan')):8.2f}")
    rows.append(dict(change="streaming stores (no read-for-ownership), upper bound", kind="bytes (bound)",
                     bytes_per_cell_wa=f"{bs:.0f}", delta_pct=f"{100 * (bs - b0) / b0:.1f}", pred_TB=f"{bs * n / 1e12:.3f}",
                     floor_s=f"{fs:.2f}" if bw else "", cumulative_bytes_per_cell_wa=f"{bsc:.0f}",
                     cumulative_delta_pct=f"{100 * (bsc - b0) / b0:.1f}",
                     rationale="STREAM's streaming stores move no read-for-ownership bytes on this CPU (m3_stream_ddrc); "
                               "CloverLeaf's stores do (m3_baseline reads = 1.34 x demand). Bound = no-WA model; cumulative = with all rows above"))
    print("\ntime-only changes (no byte effect in the model):")
    for label, why in TIME_ONLY:
        print(f"  {label}: {why}")
        rows.append(dict(change=label, kind="time", bytes_per_cell_wa="", delta_pct="", pred_TB="", floor_s="",
                         cumulative_bytes_per_cell_wa="", cumulative_delta_pct="", rationale=why))
    if a.csv:
        with open(a.csv, "w", newline="") as f:
            f.write(f"# Predicted DRAM traffic of the planned C-kernel changes, write-allocate byte model "
                    f"(perf/analysis/plan_bytes.py), {a.cells} cells x {a.steps} steps, floor at {bw or 0:.0f} GB/s ({bw_src}). "
                    f"Measured baseline (job 34797, 64x2): 2.828 TB, 11.25 s.\n")
            w = csv.DictWriter(f, fieldnames=list(rows[0]))
            w.writeheader()
            w.writerows(rows)
        print(f"\nwrote {a.csv}")


if __name__ == "__main__":
    main()
