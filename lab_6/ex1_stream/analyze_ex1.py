#!/usr/bin/env python3
"""Lab 6, exercise 1: tables and figures from run_ex1.sh.

  python analyze_ex1.py results/ex1_<jobid> [--out figures]

Bandwidth is "best" = bytes / min time over the timed iterations of one run (the
STREAM convention); every point is the median over the repetitions, error bars
span min..max of the repetitions.
"""
import argparse
import os
import sys

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

# validated categorical order (dataviz reference palette, light surface)
COL = ["#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4"]
INK, GRID = "#0b0b0b", "#d9d8d4"
SIZE_LABEL = {1024: "N = 1024 (24 KB, fits L1D)",
              4194304: r"N = $2^{22}$ (96 MB)",
              100000000: r"N = $10^8$ (2.4 GB)"}
BIND_ORDER = ["false", "true", "master", "close", "spread"]
THP_LS = {"off": "-", "on": "--"}
THP_MK = {"off": "o", "on": "s"}

plt.rcParams.update({
    "font.size": 9, "axes.edgecolor": GRID, "axes.labelcolor": INK, "text.color": INK,
    "xtick.color": INK, "ytick.color": INK, "axes.grid": True, "grid.color": GRID,
    "grid.linewidth": 0.6, "axes.spines.top": False, "axes.spines.right": False,
    "legend.frameon": False, "figure.dpi": 130, "lines.linewidth": 1.6,
})


def load(path):
    df = pd.read_csv(os.path.join(path, "stream.csv"))
    df["best"] = df.bytes / df.tmin_s / 1e9
    df["avg"] = df.bytes / df.tavg_s / 1e9
    return df


def agg(df, col="best"):
    keys = ["exp", "thp", "bind", "threads", "n", "kernel"]
    g = df.groupby(keys)[col]
    out = pd.DataFrame({"med": g.median(), "lo": g.min(), "hi": g.max(), "runs": g.size()})
    return out.reset_index()


def savefig(fig, out, name):
    os.makedirs(out, exist_ok=True)
    for ext in ("pdf", "png"):
        fig.savefig(os.path.join(out, f"{name}.{ext}"), bbox_inches="tight")
    plt.close(fig)
    print(f"wrote {out}/{name}.pdf")


def fig_scaling(a, out, kernel="triad"):
    sizes = sorted(a.n.unique())
    fig, axs = plt.subplots(1, len(sizes), figsize=(3.2 * len(sizes), 3.0))
    axs = np.atleast_1d(axs)
    for ax, n in zip(axs, sizes):
        for bi, bind in enumerate(["close", "spread"]):
            for thp in ("off", "on"):
                d = a[(a.exp == "scaling") & (a.n == n) & (a.kernel == kernel) &
                      (a.bind == bind) & (a.thp == thp)].sort_values("threads")
                if d.empty:
                    continue
                ax.errorbar(d.threads, d.med, yerr=[d.med - d.lo, d.hi - d.med],
                            color=COL[bi], ls=THP_LS[thp], marker=THP_MK[thp], ms=3.5,
                            capsize=1.5, elinewidth=0.7, label=f"{bind}, THP {thp}")
        ax.set_xscale("log", base=2)
        ax.set_yscale("log" if n == 1024 else "linear")
        ax.set_xlabel("threads")
        ax.set_title(SIZE_LABEL.get(n, f"N = {n}"), fontsize=9)
    axs[0].set_ylabel(f"{kernel} bandwidth [GB/s]")
    axs[0].legend(fontsize=7.5, loc="best")
    fig.tight_layout()
    savefig(fig, out, "fig_ex1_scaling")


def fig_small(df, a, out, n=1024):
    """N = 1024: where does the time go? Left: time per call [us]; right: bandwidth."""
    thp = "off" if "off" in set(df.thp) else df.thp.iloc[0]
    d = df[(df.exp == "scaling") & (df.n == n) & (df.bind == "close") & (df.thp == thp)]
    if d.empty:
        return
    fig, axs = plt.subplots(1, 2, figsize=(6.8, 3.0))
    ax = axs[0]
    series = [("triad", "triad, fork/join per call"), ("triad_pr", "triad, one parallel region"),
              ("parregion", "empty parallel region"), ("barrier", "barrier")]
    for i, (k, lab) in enumerate(series):
        t = d[d.kernel == k].groupby("threads").tmin_s.median() * 1e6
        ax.plot(t.index, t.values, marker="o", ms=3.5, color=COL[i], label=lab)
    ax.set_xscale("log", base=2)
    ax.set_yscale("log")
    ax.set_xlabel("threads")
    ax.set_ylabel("time per call [$\mu$s]")
    ax.legend(fontsize=7.5)
    ax = axs[1]
    for i, (k, lab) in enumerate([("triad", "fork/join per call"), ("triad_pr", "one region")]):
        dk = a[(a.exp == "scaling") & (a.n == n) & (a.bind == "close") & (a.thp == thp) &
               (a.kernel == k)].sort_values("threads")
        ax.errorbar(dk.threads, dk.med, yerr=[dk.med - dk.lo, dk.hi - dk.med], marker="o", ms=3.5,
                    color=COL[i], capsize=1.5, elinewidth=0.7, label=lab)
    ax.set_xscale("log", base=2)
    ax.set_yscale("log")
    ax.set_xlabel("threads")
    ax.set_ylabel("triad bandwidth [GB/s]")
    ax.set_title("N = 1024, close binding", fontsize=9)
    ax.legend(fontsize=7.5)
    fig.tight_layout()
    savefig(fig, out, "fig_ex1_small_n")


def overhead_table(df):
    d = df[(df.exp == "scaling") & (df.bind == "close") & df.kernel.isin(["parregion", "barrier"])]
    d = d.assign(us=d.tmin_s * 1e6)
    t = d.groupby(["thp", "threads", "kernel"]).us.median().unstack("kernel")
    return t


def fig_bind(a, out, kernel="triad"):
    sizes = sorted(a.n.unique())
    thps = [t for t in ("off", "on") if t in set(a.thp)]
    fig, axs = plt.subplots(len(thps), len(sizes), figsize=(3.3 * len(sizes), 2.7 * len(thps)),
                            squeeze=False, sharex="col")
    for r, thp in enumerate(thps):
        for c, n in enumerate(sizes):
            ax = axs[r][c]
            d = a[(a.exp == "bind") & (a.n == n) & (a.kernel == kernel) & (a.thp == thp)]
            ts = sorted(d.threads.unique())
            w = 0.8 / len(BIND_ORDER)
            for bi, bind in enumerate(BIND_ORDER):
                db = d[d.bind == bind].set_index("threads").reindex(ts)
                x = np.arange(len(ts)) + (bi - (len(BIND_ORDER) - 1) / 2) * w
                ax.bar(x, db.med, width=w * 0.9, color=COL[bi], label=bind,
                       yerr=[(db.med - db.lo).fillna(0), (db.hi - db.med).fillna(0)],
                       error_kw=dict(elinewidth=0.7, capsize=1.2))
            ax.set_xticks(np.arange(len(ts)))
            ax.set_xticklabels(ts)
            ax.set_yscale("log" if n == 1024 else "linear")
            if r == 0:
                ax.set_title(SIZE_LABEL.get(n, f"N = {n}"), fontsize=9)
            if r == len(thps) - 1:
                ax.set_xlabel("threads")
            if c == 0:
                ax.set_ylabel(f"THP {thp}\n{kernel} [GB/s]")
    h, l = axs[0][0].get_legend_handles_labels()
    fig.legend(h, l, title="OMP_PROC_BIND", loc="upper center", ncol=len(l), fontsize=8,
               title_fontsize=8, bbox_to_anchor=(0.5, 1.08))
    fig.tight_layout()
    savefig(fig, out, "fig_ex1_bind")


def print_tables(a, df):
    pd.set_option("display.width", 200, "display.max_columns", 50, "display.max_rows", 500)
    for kernel in ("copy", "triad"):
        d = a[(a.exp == "scaling") & (a.kernel == kernel)]
        t = d.pivot_table(index=["n", "thp", "bind", "threads"], values="med").unstack("threads")
        t.columns = [c[1] for c in t.columns]
        print(f"\n== scaling, {kernel}, median best GB/s ==")
        print(t.round(1).to_string())
    d = a[(a.exp == "bind") & (a.kernel == "triad")]
    for (n, thp), g in d.groupby(["n", "thp"]):
        t = g.pivot_table(index="bind", columns="threads", values="med").reindex(BIND_ORDER)
        s = g.pivot_table(index="bind", columns="threads", values="hi").reindex(BIND_ORDER) / \
            g.pivot_table(index="bind", columns="threads", values="lo").reindex(BIND_ORDER)
        print(f"\n== bind, triad, n={n}, THP {thp}: median GB/s (max/min over reps below) ==")
        print(t.round(1).to_string())
        print(s.round(2).to_string())
    print("\n== overheads, median over reps of the minimum, us (close binding) ==")
    print(overhead_table(df).round(2).to_string())


def affinity_report(path):
    p = os.path.join(path, "affinity.csv")
    if not os.path.exists(p):
        return
    af = pd.read_csv(p)
    af = af[af.exp == "bind"]
    print("\n== thread -> cpu maps (first repetition, THP off, N=10^8 or the largest N) ==")
    nmax = af.n.max()
    thp = "off" if "off" in set(af.thp) else af.thp.iloc[0]
    for bind in BIND_ORDER:
        for t in (16, 32):
            r = af[(af.bind == bind) & (af.threads == t) & (af.n == nmax) & (af.thp == thp)]
            for _, row in r.iterrows():
                cpus = [int(x) for x in str(row.cpus).split()]
                doms = sorted({c // 32 for c in cpus if c >= 0})
                print(f"  {bind:7s} T={t:3d} {row.when:5s} NUMA domains used: {doms}  "
                      f"distinct cpus: {len(set(cpus))}  first: {cpus[:8]}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dir")
    ap.add_argument("--out", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "figures"))
    args = ap.parse_args()
    df = load(args.dir)
    a = agg(df)
    print_tables(a, df)
    affinity_report(args.dir)
    fig_scaling(a, args.out)
    fig_small(df, a, args.out)
    fig_bind(a, args.out)
    a.to_csv(os.path.join(args.dir, "summary.csv"), index=False)


if __name__ == "__main__":
    sys.exit(main())
