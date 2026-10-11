#!/usr/bin/env python3
"""Roofline model of the CloverLeaf kernels on one configuration.

Combines
  * measured kernel times (CloverLeaf profiler CSV from clover_profile.py, or
    a PAPI run directory for per-kernel regions),
  * the analytic flops/bytes of kernel_model.py,
  * measured ceilings: STREAM bandwidth (m2_stream) and peak_flops (m2_peak),
and prints, per kernel, the achieved bandwidth and GFLOP/s, the fraction of
the STREAM bandwidth reached and the attainable performance at that
arithmetic intensity. Optionally draws the roofline figure.

  python3 roofline.py --profile-csv m1.csv --deck bm3840 --config 1x128 \
      --bw 250 --peak 1300 --scalar 650 --div 90 --plot roofline.pdf
  python3 roofline.py --papi-dir results/m1_papi_X/ipc/1x128 --bw 250 --peak 1300
"""

import argparse
import csv
import re
import statistics
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import kernel_model  # noqa: E402
from clover_profile import parse_run  # noqa: E402

SKIP = {"Total", "The Rest", "Visit", "Tile Halo Exchange", "Self Halo Exchange",
        "MPI Halo Exchange"}


def times_from_profile(path, deck, config):
    per_cat = defaultdict(list)
    meta = None
    with open(path, newline="") as f:
        for r in csv.DictReader(f):
            if r["deck"] == deck and r["config"] == config:
                per_cat[r["category"]].append(float(r["time_s"]))
                meta = r
    if meta is None:
        sys.exit(f"no rows for deck={deck} config={config} in {path}")
    times = {c: statistics.median(v) for c, v in per_cat.items() if c not in SKIP}
    return times, int(meta["cells"]), int(meta["steps"]), "category"


def times_from_papi(run_dir):
    run_dir = Path(run_dir)
    times = defaultdict(float)
    for f in run_dir.glob("papi_prof_*.csv"):
        per_region = defaultdict(float)
        with open(f, newline="") as fh:
            for r in csv.DictReader(fh):
                per_region[r["region"]] = max(per_region[r["region"]], float(r["time_s"]))
        for k, v in per_region.items():   # MPI ranks run concurrently: take max
            times[k] = max(times[k], v)
    run = parse_run(run_dir)
    times.pop("update_halo", None)
    return dict(times), run["cells"], run["steps"], "kernel"


def table(times, model, bw, peak):
    rows = []
    for name, t in sorted(times.items(), key=lambda kv: -kv[1]):
        if name not in model or t <= 0:
            continue
        flops, nbytes = model[name]
        ai = flops / nbytes if nbytes else float("nan")
        gbs = nbytes / t * 1e-9
        gfs = flops / t * 1e-9
        attain = min(peak, ai * bw) if peak else ai * bw
        rows.append(dict(name=name, time=t, ai=ai, gbs=gbs, bw_frac=gbs / bw,
                         gflops=gfs, attain=attain, frac=gfs / attain if attain else 0))
    return rows


def plot(rows, args, out):
    import math
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    import numpy as np

    rows = [r for r in rows if r["gflops"] > 0]   # pure copies have no flops: table only
    ink, ink2, grid, point = "#0b0b0b", "#52514e", "#e4e3df", "#2a78d6"
    plt.rcParams.update({"font.size": 9, "axes.edgecolor": ink2, "axes.labelcolor": ink,
                         "xtick.color": ink2, "ytick.color": ink2})
    fig, ax = plt.subplots(figsize=(6.4, 4.2))

    xs = np.array([r["ai"] for r in rows])
    ys = np.array([r["gflops"] for r in rows])
    top = args.peak or ys.max() * 10
    ridge = top / args.bw
    x0 = 10 ** math.floor(math.log10(xs.min() / 3))
    x1 = 10 ** math.ceil(math.log10(max(ridge * 3, xs.max() * 30)))
    y0 = 10 ** math.floor(math.log10(min(ys.min() / 3, x0 * args.bw)))
    ax.set_xscale("log")
    ax.set_yscale("log")
    ax.set_xlim(x0, x1)
    ax.set_ylim(y0, top * 3)

    # Main roof: bandwidth slope up to the FMA peak.
    ai = np.logspace(math.log10(x0), math.log10(x1), 400)
    ax.plot(ai, np.minimum(top, ai * args.bw), color=ink, lw=2, zorder=2)
    if args.peak:
        ax.text(x1, top * 1.1, f"vector FMA peak {args.peak:.0f} GFLOP/s",
                ha="right", va="bottom", color=ink2, fontsize=8)
    # Lower ceilings: horizontal only, from where they meet the slope.
    for level, label, ls in ((args.scalar, "scalar FMA", "--"), (args.div, "vector divide", ":")):
        if level:
            ax.plot([level / args.bw, x1], [level, level], color=ink2, lw=1.2, ls=ls, zorder=1)
            ax.text(x1, level * 1.1, f"{label} {level:.0f}", ha="right", va="bottom",
                    color=ink2, fontsize=8)

    ax.set_xlabel("Arithmetic intensity (flop/byte, analytic model"
                  + (", with write-allocate)" if args.wa else ", no write-allocate)"))
    ax.set_ylabel("Performance (GFLOP/s)")
    ax.grid(True, which="major", color=grid, lw=0.6)
    for side in ("top", "right"):
        ax.spines[side].set_visible(False)
    if args.title:
        ax.set_title(args.title, loc="left", fontsize=10, color=ink)
    fig.tight_layout()
    # STREAM label along the slope, rotated to its on-screen angle.
    xl = x0 * 2.2
    p0, p1 = ax.transData.transform([(xl, xl * args.bw), (xl * 10, xl * 10 * args.bw)])
    angle = math.degrees(math.atan2(p1[1] - p0[1], p1[0] - p0[0]))
    ax.text(xl, xl * args.bw * 1.5, f"STREAM {args.bw:.0f} GB/s", rotation=angle,
            rotation_mode="anchor", color=ink2, fontsize=8)

    ax.scatter(xs, ys, s=64, color=point, edgecolor="white", linewidth=1.5, zorder=3)
    # Labels in a column right of the cluster, evenly spaced (log) in the
    # order of the points' heights, joined by thin leader lines.
    order = np.argsort(-ys)
    lx = xs.max() * 4
    hi, lo = math.log10(ys.max() * 2.5), math.log10(ys.min() / 2.5)
    span = max(hi - lo, 0.18 * (len(rows) - 1))
    mid = (hi + lo) / 2
    for i, idx in enumerate(order):
        ly = 10 ** (mid + span / 2 - (span * i / max(len(rows) - 1, 1)))
        ax.annotate(rows[idx]["name"], xy=(xs[idx], ys[idx]), xytext=(lx, ly),
                    fontsize=7.5, color=ink, va="center",
                    bbox=dict(boxstyle="square,pad=0.1", fc="white", ec="none"),
                    arrowprops=dict(arrowstyle="-", color=ink2, lw=0.5, shrinkA=0, shrinkB=4))

    fig.savefig(out, dpi=200)
    if not str(out).endswith(".png"):
        fig.savefig(re.sub(r"\.\w+$", ".png", str(out)), dpi=200)
    print(f"wrote {out}")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("--profile-csv", help="CSV from clover_profile.py --csv")
    src.add_argument("--papi-dir", help="one run directory with papi_prof_*.csv")
    ap.add_argument("--deck", default="bm3840")
    ap.add_argument("--config", default="1x128")
    ap.add_argument("--bw", type=float, required=True, help="STREAM GB/s (memory ceiling)")
    ap.add_argument("--peak", type=float, help="vector FMA GFLOP/s (compute ceiling)")
    ap.add_argument("--scalar", type=float, help="scalar FMA GFLOP/s (extra ceiling)")
    ap.add_argument("--div", type=float, help="vector divide GFLOP/s (extra ceiling)")
    ap.add_argument("--wa", type=int, default=1, choices=(0, 1),
                    help="count write-allocate traffic (default 1)")
    ap.add_argument("--plot", help="output figure (.pdf/.png)")
    ap.add_argument("--title")
    args = ap.parse_args()

    if args.profile_csv:
        times, cells, steps, level = times_from_profile(args.profile_csv, args.deck, args.config)
        model = kernel_model.per_category(cells, steps, args.wa)
    else:
        times, cells, steps, level = times_from_papi(args.papi_dir)
        model = kernel_model.per_kernel(cells, steps, args.wa)

    rows = table(times, model, args.bw, args.peak)
    print(f"cells={cells} steps={steps} wa={args.wa} bw={args.bw} GB/s peak={args.peak} GFLOP/s")
    print(f"{level:20s} {'time_s':>8s} {'AI':>6s} {'GB/s':>7s} {'%STREAM':>8s} "
          f"{'GFLOP/s':>8s} {'attain':>8s} {'%attain':>8s}")
    for r in rows:
        print(f"{r['name']:20s} {r['time']:8.3f} {r['ai']:6.3f} {r['gbs']:7.1f} "
              f"{100 * r['bw_frac']:7.0f}% {r['gflops']:8.2f} {r['attain']:8.1f} "
              f"{100 * r['frac']:7.0f}%")
    missing = sorted(set(model) - set(times))
    if missing:
        print("no time measured for:", ", ".join(missing))
    if args.plot:
        plot(rows, args, args.plot)


if __name__ == "__main__":
    main()
