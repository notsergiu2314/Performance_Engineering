#!/usr/bin/env python3
"""Lab 6, exercise 1: figures and numbers for the report.

Reads stream_threads.csv, stream_bind.csv and placement.txt (this directory),
writes the figures to ../report/sources/ and prints the numbers used in the
report. Bandwidth is STREAM's triad (best of NTIMES iterations), median of the
runs; error bars span min..max of the runs.

  python plot_ex1.py
"""
import os

import matplotlib

matplotlib.use("Agg")
import matplotlib.ticker
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "report", "sources")
os.makedirs(OUT, exist_ok=True)

COL = ["#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4"]   # fixed categorical order
INK, GRID = "#0b0b0b", "#d9d8d4"
plt.rcParams.update({
    "font.size": 9, "axes.edgecolor": GRID, "axes.labelcolor": INK, "text.color": INK,
    "xtick.color": INK, "ytick.color": INK, "axes.grid": True, "grid.color": GRID,
    "grid.linewidth": 0.6, "axes.spines.top": False, "axes.spines.right": False,
    "legend.frameon": False, "figure.dpi": 150, "lines.linewidth": 1.6,
})

TICK_GBS = 24 * 1024 / (2**-20) / 1e9   # triad at one timer tick (~0.95 us) in GB/s
BYTES_TRIAD = {1024: 24 * 1024, 100000000: 24 * 100000000}
SIZE_TITLE = {1024: "N = 1024 (3 x 8 KB, fits L1D)", 100000000: r"N = $10^8$ (3 x 800 MB)"}


def stats(df, keys):
    g = df.groupby(keys).triad_MBs
    return pd.DataFrame({"med": g.median() / 1e3, "lo": g.min() / 1e3, "hi": g.max() / 1e3,
                         "n": g.size()}).reset_index()


def fig_scaling(th):
    s = stats(th.replace([np.inf], np.nan).dropna(subset=["triad_MBs"]), ["size", "threads"])
    fig, axs = plt.subplots(1, 2, figsize=(7.2, 3.1))
    for ax, n in zip(axs, (1024, 100000000)):
        d = s[s["size"] == n].sort_values("threads")
        ax.errorbar(d.threads, d.med, yerr=[d.med - d.lo, d.hi - d.med], color=COL[0], marker="o",
                    ms=4, capsize=2, elinewidth=0.8, label="median, min-max")
        ax.set_xscale("log", base=2)
        ax.set_xticks([1, 2, 4, 8, 16, 32, 64, 128])
        ax.get_xaxis().set_major_formatter(matplotlib.ticker.ScalarFormatter())
        ax.set_xlabel("threads")
        ax.set_title(SIZE_TITLE[n], fontsize=9)
        if n == 1024:
            ax.set_yscale("log")
            # values at 1-4 threads are limited by the 1 us timer of stock STREAM
            ax.axvspan(0.8, 5.5, color=COL[3], alpha=0.15, lw=0)
            ax.text(1.0, 0.012, "timer-limited\n(< 1 us per call)", fontsize=7.5, va="bottom")
            ax.set_ylim(0.01, 60)
        else:
            t1 = d[d.threads == 1].med.iloc[0]
            ax.plot(d.threads, t1 * d.threads, color="#8d8c87", ls="--", lw=1.2,
                    label=f"ideal ({t1:.1f} GB/s x threads)")
            ax.axhline(341.2, color=COL[1], ls=":", lw=1.4,
                       label="node peak 341 GB/s")
            ax.set_ylim(0, 400)
    axs[0].set_ylabel("STREAM triad bandwidth [GB/s]")
    h, l = axs[1].get_legend_handles_labels()
    axs[1].legend(h, l, loc="center right", fontsize=7.5, frameon=True, framealpha=0.95,
                  facecolor="white", edgecolor=GRID)
    fig.tight_layout()
    for ext in ("pdf", "png"):
        fig.savefig(os.path.join(OUT, f"fig_ex1_threads.{ext}"), bbox_inches="tight")
    plt.close(fig)
    return s


BINDS = ["false", "true", "master", "close", "spread"]


def fig_bind(bd):
    s = stats(bd, ["size", "bind", "threads"])
    fig, axs = plt.subplots(1, 2, figsize=(7.2, 3.1))
    ts = [32, 64, 128]
    w = 0.8 / len(BINDS)
    for ax, n in zip(axs, (100000000, 1024)):
        for bi, b in enumerate(BINDS):
            d = s[(s["size"] == n) & (s.bind == b)].set_index("threads").reindex(ts)
            x = np.arange(len(ts)) + (bi - (len(BINDS) - 1) / 2) * w
            ax.bar(x, d.med, width=w * 0.9, color=COL[bi], label=b,
                   yerr=[d.med - d.lo, d.hi - d.med], error_kw=dict(elinewidth=0.8, capsize=1.5))
        ax.set_xticks(range(len(ts)))
        ax.set_xticklabels(ts)
        ax.set_xlabel("threads")
        ax.set_title(SIZE_TITLE[n], fontsize=9)
        if n == 1024:
            ax.set_yscale("log")
    axs[0].set_ylabel("STREAM triad bandwidth [GB/s]")
    h, l = axs[0].get_legend_handles_labels()
    fig.legend(h, l, title="OMP_PROC_BIND", loc="upper center", ncol=5, fontsize=8,
               title_fontsize=8, bbox_to_anchor=(0.5, 1.12))
    fig.tight_layout()
    for ext in ("pdf", "png"):
        fig.savefig(os.path.join(OUT, f"fig_ex1_bind.{ext}"), bbox_inches="tight")
    plt.close(fig)
    return s


def placement():
    rows = {}
    for line in open(os.path.join(HERE, "placement.txt")):
        if line.startswith("#"):
            continue
        head, cpus = line.split("|")
        bind, t = head.split()
        c = [int(x) for x in cpus.split()]
        rows[(bind, int(t))] = [sum(1 for x in c if x // 32 == d) for d in range(4)]
    return rows


def main():
    th = pd.read_csv(os.path.join(HERE, "stream_threads.csv"))
    bd = pd.read_csv(os.path.join(HERE, "stream_bind.csv"))
    pd.set_option("display.width", 200)

    s = fig_scaling(th)
    print("== 1a: triad, GB/s (median, min, max)")
    for n in (1024, 100000000):
        d = s[s["size"] == n].set_index("threads")
        for t, r in d.iterrows():
            tcall = BYTES_TRIAD[n] / (r.med * 1e9) * 1e6
            print(f"N={n:>9d} T={t:3d}  med={r.med:8.3f} lo={r.lo:8.3f} hi={r.hi:8.3f}  "
                  f"call={tcall:9.2f} us")
    n1 = th[th["size"] == 1024]
    print("inf runs at N=1024 per thread count:",
          n1[np.isinf(n1.triad_MBs)].groupby("threads").size().to_dict())

    b = fig_bind(bd)
    print("\n== 1b: triad, GB/s (median, min, max)")
    for n in (100000000, 1024):
        for bind in BINDS:
            row = []
            for t in (32, 64, 128):
                r = b[(b["size"] == n) & (b.bind == bind) & (b.threads == t)].iloc[0]
                row.append(f"{r.med:8.3f} ({r.lo:7.3f}-{r.hi:7.3f}, n={int(r.n)})")
            print(f"N={n:>9d} {bind:7s}", " | ".join(row))

    print("\n== threads per NUMA domain (domains 0..3), snapshot at N=1e8")
    for (bind, t), v in placement().items():
        print(f"{bind:7s} {t:3d}  {v}")


if __name__ == "__main__":
    main()
