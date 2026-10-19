"""Lab 7 ex2: results/<partition>_<n>node_<jobid>/ring.csv -> tables/tab_ring.tex, figures/fig_ring.{pdf,png}.

Run from lab_7/report:  python make_ring.py     (needs matplotlib; reads ../ex2/results)
Every number in the table is the median over the trials of that run; the min-max spread is printed.
"""
import csv
import re
import statistics
from pathlib import Path

import matplotlib
import numpy as np
matplotlib.use("Agg")
import matplotlib.pyplot as plt

HERE = Path(__file__).resolve().parent
RESULTS = HERE.parent / "ex2" / "results"
FIG, TAB = HERE / "figures", HERE / "tables"
FIG.mkdir(exist_ok=True)
TAB.mkdir(exist_ok=True)

# column order of the table: (partition, nodes, header)
CONFIGS = [("cn-ib", 1, "cn-ib, same node"), ("cn-ib", 2, "cn-ib, two nodes"),
           ("cn-eth", 1, "cn-eth, same node"), ("cn-eth", 2, "cn-eth, two nodes")]
COLOR = {"cn-ib": "#2a78d6", "cn-eth": "#eb6834"}   # identity = partition
STYLE = {1: ("-", "o"), 2: ("--", "s")}              # placement: solid same node, dashed two nodes
INK, MUTED, GRID = "#1f2328", "#59636e", "#d8dee4"


def load():
    """{(partition, nodes): {size: {'lat': [...], 'bw': [...]}}}, newest job wins per configuration."""
    runs = {}
    for d in sorted(RESULTS.glob("*_*node_*")):
        m = re.fullmatch(r"(.+)_(\d)node_(\d+)", d.name)
        f = d / "ring.csv"
        if not m or not f.exists():
            continue
        key = (m.group(1), int(m.group(2)))
        if key in runs and runs[key][0] > int(m.group(3)):
            continue
        rows = [r for r in csv.DictReader(l for l in f.open() if not l.startswith("#"))]
        data = {}
        for r in rows:
            s = data.setdefault(int(r["size_bytes"]), {"lat": [], "bw": [], "M": int(r["M"])})
            s["lat"].append(float(r["time_per_exchange_us"]))
            s["bw"].append(float(r["bw_MBps"]))
        hosts = [l.split(" on ")[1].strip() for l in f.open() if l.startswith("# rank")]
        runs[key] = (int(m.group(3)), data, hosts)
    return runs


def main():
    runs = load()
    missing = [c[:2] for c in CONFIGS if c[:2] not in runs]
    if missing:
        raise SystemExit(f"missing results for {missing} in {RESULTS}")
    sizes = sorted(runs[CONFIGS[0][:2]][1])

    def med(key, size, what):
        return statistics.median(runs[key][1][size][what])

    # ---- table: per size, median time per exchange [us] and bandwidth [MB/s] per configuration
    L = [r"\begin{table}[ht]", r"\centering", r"\small",
         r"\begin{tabular}{r" + "rr" * len(CONFIGS) + "}", r"\toprule",
         " & " + " & ".join(rf"\multicolumn{{2}}{{c}}{{{h}}}" for _, _, h in CONFIGS) + r" \\"]
    L.append("".join(rf"\cmidrule(lr){{{2 + 2 * i}-{3 + 2 * i}}}" for i in range(len(CONFIGS))))
    L.append(r"size [B] & " + " & ".join([r"$\mu$s", "MB/s"] * len(CONFIGS)) + r" \\ \midrule")
    for s in sizes:
        cells = []
        for p, n, _ in CONFIGS:
            lat, bw = med((p, n), s, "lat"), med((p, n), s, "bw")
            cells += [f"{lat:.2f}", f"{bw:.0f}"]
        L.append(f"{s} & " + " & ".join(cells) + r" \\")
    L += [r"\bottomrule", r"\end{tabular}",
          r"\caption{Ring benchmark with two ranks (\texttt{MPI\_Sendrecv}): median time per exchange "
          r"in $\mu$s and bandwidth, i.e.\ payload one rank sends per second, in MB/s ($10^6$~B/s). "
          r"Median of the 10 trials per message size.}",
          r"\label{tab:ring}", r"\end{table}"]
    (TAB / "tab_ring.tex").write_text("\n".join(L) + "\n", encoding="utf8")

    # ---- figure: latency and bandwidth versus message size
    plt.rcParams.update({"font.size": 9, "axes.edgecolor": MUTED, "axes.labelcolor": INK,
                         "xtick.color": MUTED, "ytick.color": MUTED, "text.color": INK})
    fig, axes = plt.subplots(1, 2, figsize=(7.2, 2.9))
    for ax, what, ylabel in ((axes[0], "lat", r"time per exchange [$\mu$s]"),
                             (axes[1], "bw", "bandwidth [MB/s]")):
        for p, n, label in CONFIGS:
            ls, mk = STYLE[n]
            y = [med((p, n), s, what) for s in sizes]
            lo = [min(runs[(p, n)][1][s][what]) for s in sizes]
            hi = [max(runs[(p, n)][1][s][what]) for s in sizes]
            ax.fill_between(sizes, lo, hi, color=COLOR[p], alpha=0.15, lw=0)
            ax.plot(sizes, y, ls, marker=mk, ms=5, lw=2, color=COLOR[p], mec="white", mew=1, label=label)
        ax.set_xscale("log", base=2)
        ax.set_yscale("log")
        ticks = [0.3, 0.5, 1, 2, 3, 5] if what == "lat" else [50, 100, 200, 500, 1000, 2000, 4000]
        ax.set_yticks(ticks)
        ax.set_yticklabels([f"{t:g}" for t in ticks])
        ax.minorticks_off()
        ax.set_xticks(sizes)
        ax.set_xticklabels([str(s) for s in sizes])
        ax.set_xlabel("message size [B]")
        ax.set_ylabel(ylabel)
        ax.grid(True, which="major", color=GRID, lw=0.6)
        ax.set_axisbelow(True)
        for sp in ("top", "right"):
            ax.spines[sp].set_visible(False)
    axes[1].legend(frameon=False, fontsize=8, loc="lower right")
    fig.tight_layout()
    fig.savefig(FIG / "fig_ring.pdf")
    fig.savefig(FIG / "fig_ring.png", dpi=200)

    # ---- numbers for the text
    print("hosts:", {c[:2]: runs[c[:2]][2] for c in CONFIGS})
    print("jobs :", {c[:2]: runs[c[:2]][0] for c in CONFIGS})
    print(f"{'size':>6} " + " ".join(f"{h:>24}" for _, _, h in CONFIGS))
    for s in sizes:
        print(f"{s:>6} " + " ".join(
            f"{med((p, n), s, 'lat'):7.2f}us {med((p, n), s, 'bw'):8.1f}MB/s" for p, n, _ in CONFIGS))
    for p, n, h in CONFIGS:
        spread = max((max(runs[(p, n)][1][s]["lat"]) - min(runs[(p, n)][1][s]["lat"])) /
                     med((p, n), s, "lat") for s in sizes)
        print(f"{h}: worst min-max spread of the trials {100 * spread:.1f} % of the median")
    # least-squares fit  t(n) = alpha + n / beta  to the medians (alpha = latency, beta = asymptotic rate)
    for p, n, h in CONFIGS:
        ns = np.array(sizes, float)
        ts = np.array([med((p, n), s, "lat") for s in sizes])
        slope, alpha = np.polyfit(ns, ts, 1)
        resid = np.max(np.abs(ts - (alpha + slope * ns)) / ts)
        print(f"fit {h}: alpha = {alpha:.2f} us, 1/beta = {slope * 1e3:.3f} ns/B -> beta = {1e-3 / slope:.2f} GB/s,"
              f" max residual {100 * resid:.0f} %")
    for s in (sizes[0], sizes[-1]):
        print(f"{s} B: two nodes / same node latency  ib {med(('cn-ib', 2), s, 'lat') / med(('cn-ib', 1), s, 'lat'):.1f}x"
              f"   eth {med(('cn-eth', 2), s, 'lat') / med(('cn-eth', 1), s, 'lat'):.1f}x;"
              f"  eth/ib two nodes {med(('cn-eth', 2), s, 'lat') / med(('cn-ib', 2), s, 'lat'):.2f}x")


if __name__ == "__main__":
    main()
