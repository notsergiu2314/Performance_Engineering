#!/usr/bin/env python3
"""Generate every figure and table of the report from report/data/*.csv.

  python make_assets.py        (needs matplotlib + numpy; run from report/)

figures/*.pdf (and .png for quick looks) and tables/*.tex are \\input/\\includegraphics'd
by main.tex; nothing in them is typed by hand. The per-kernel flop and byte counts
come from the analytic model in ../CloverLeaf_ref/perf/analysis/kernel_model.py.
"""

import csv
import math
import statistics
import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

HERE = Path(__file__).parent
DATA, FIG, TAB = HERE / "data", HERE / "figures", HERE / "tables"
sys.path.insert(0, str(HERE.parent / "CloverLeaf_ref" / "perf" / "analysis"))
import kernel_model  # noqa: E402

CELLS = 3840 * 3840
STEPS = 87

# validated categorical slots 1-4 (light surface); ink tokens
BLUE, ORANGE, AQUA, YELLOW = "#2a78d6", "#eb6834", "#1baf7a", "#eda100"
INK, INK2, GRID = "#0b0b0b", "#52514e", "#e4e3df"

plt.rcParams.update({
    "font.size": 8, "axes.edgecolor": INK2, "axes.labelcolor": INK,
    "xtick.color": INK2, "ytick.color": INK2, "axes.titlesize": 9,
    "axes.titlelocation": "left", "legend.frameon": False,
    "pdf.fonttype": 42, "axes.spines.top": False, "axes.spines.right": False,
})


def rows(name):
    with open(DATA / name, newline="") as f:
        return list(csv.DictReader(line for line in f if not line.startswith("#")))


def save(fig, name):
    fig.savefig(FIG / f"{name}.pdf", bbox_inches="tight")
    fig.savefig(FIG / f"{name}.png", dpi=200, bbox_inches="tight")
    plt.close(fig)
    print("figure", name)


def tex(name, text):
    (TAB / name).write_text(text)
    print("table ", name)


# --------------------------------------------------------------- ceilings
C = {r["name"]: float(r["value"]) for r in rows("ceilings.csv")}
BW_CORE, BW_NODE = C["dram_1thread"], C["dram_node_best"]
FMA_CORE, FMA_NODE = C["fma_core"], C["fma_node"]
DIV_CORE, DIV_NODE = C["div_core"], C["div_node"]

# --------------------------------------------------------------- kernels
KP = {r["kernel"]: r for r in rows("kernels_papi.csv")}
MODEL = {k.name: k for k in kernel_model.KERNELS}
WA = 1


def kernel_perf(name, time_col):
    k = MODEL[name]
    n = CELLS * STEPS * k.calls_per_step
    flops, nbytes = n * k.flops_per_cell(), n * k.bytes_per_cell(WA)
    t = float(KP[name][time_col])
    return flops / nbytes if nbytes else 0.0, flops / t * 1e-9, nbytes / t * 1e-9


APP_FLOPS = sum(CELLS * STEPS * k.calls_per_step * k.flops_per_cell() for k in kernel_model.KERNELS)
APP_BYTES_MODEL = sum(CELLS * STEPS * k.calls_per_step * k.bytes_per_cell(WA) for k in kernel_model.KERNELS)
PL = {r["variant"]: r for r in rows("placement.csv")}


def wall(v):
    return statistics.median(float(PL[v][f"wall_{i}"]) for i in (1, 2, 3))


# ================================================================= figures
def fig_scaling():
    sc = [r for r in rows("scaling.csv") if r["deck"] == "bm3840"]
    omp = [r for r in sc if r["ranks"] == "1"]
    mpi = [r for r in sc if r["ranks"] != "1"]
    t1 = float(omp[0]["median_s"])

    fig, ax = plt.subplots(figsize=(3.3, 2.7))
    cores = np.array([1, 128])
    ax.plot(cores, t1 / cores, color=INK2, lw=1, ls="--", zorder=1)
    ax.text(1.25, t1 / 1.25 * 0.52, "ideal", color=INK2, fontsize=7, rotation=-31, rotation_mode="anchor")

    x = [int(r["threads"]) * int(r["ranks"]) for r in omp]
    y = [float(r["median_s"]) for r in omp]
    lo = [float(r["median_s"]) - float(r["min_s"]) for r in omp]
    hi = [float(r["max_s"]) - float(r["median_s"]) for r in omp]
    ax.errorbar(x, y, yerr=[lo, hi], fmt="o-", color=BLUE, ms=4, lw=1.4, capsize=2,
                mec="white", mew=1, label="OpenMP, 1 rank (THP on)", zorder=3)
    # three markers share x = 128 cores: separate them horizontally (log axis, multiplicative)
    ax.plot([128 * 0.88] * len(mpi), [float(r["median_s"]) for r in mpi], "s", color=ORANGE, ms=5,
            mec="white", mew=1, label="MPI x OpenMP (2x64, 4x32)", zorder=4)
    ax.plot([128 * 1.14], [wall("E")], "D", color=AQUA, ms=5, mec="white", mew=1,
            label="OpenMP, THP off", zorder=5)
    for r in mpi:
        ax.annotate(r["config"], (128 * 0.88, float(r["median_s"])),
                    xytext=(-5, -2), textcoords="offset points", fontsize=7, color=INK, ha="right")
    ax.set_xlim(0.85, 190)

    ax.set_xscale("log", base=2)
    ax.set_yscale("log")
    ax.set_xticks([1, 2, 4, 8, 16, 32, 64, 128])
    ax.set_xticklabels(["1", "2", "4", "8", "16", "32", "64", "128"])
    ax.set_xlabel("cores")
    ax.set_ylabel("wall clock, 87 steps (s)")
    ax.grid(True, which="major", color=GRID, lw=0.6)
    ax.legend(loc="lower left", fontsize=7)
    save(fig, "fig_scaling")


def fig_stream():
    st = rows("stream.csv")
    node = [r for r in st if r["config"] == "node"]
    spread = [r for r in st if r["config"] == "spread"]
    numa = [r for r in st if r["config"].startswith("numa")]

    fig, ax = plt.subplots(figsize=(3.3, 2.7))
    for series, col, mk, lab in ((node, BLUE, "o", "threads filled close (node order)"),
                                 (spread, ORANGE, "s", "threads spread over domains")):
        x = [int(r["threads"]) for r in series]
        y = [float(r["triad"]) for r in series]
        lo = [float(r["triad"]) - float(r["triad_min"]) for r in series]
        hi = [float(r["triad_max"]) - float(r["triad"]) for r in series]
        ax.errorbar(x, y, yerr=[lo, hi], fmt=mk + "-", color=col, ms=4, lw=1.2, capsize=2,
                    mec="white", mew=1, label=lab)
    ax.plot([32] * len(numa), [float(r["triad"]) for r in numa], "D", color=AQUA, ms=4,
            mec="white", mew=1, label="each domain alone (32 thr.)")
    ax.axhline(341.2, color=INK2, lw=1, ls=":")
    ax.text(1.1, 341.2 * 1.04, "theoretical 341 GB/s (16 x DDR4-2666)", fontsize=7, color=INK2)
    ax.axhline(BW_NODE, color=INK2, lw=1, ls="--")
    ax.text(1.1, BW_NODE * 1.04, f"best measured {BW_NODE:.0f} GB/s", fontsize=7, color=INK2)
    ax.set_xscale("log", base=2)
    ax.set_xticks([1, 2, 4, 8, 16, 32, 64, 128])
    ax.set_xticklabels(["1", "2", "4", "8", "16", "32", "64", "128"])
    ax.set_ylim(0, 380)
    ax.set_xlabel("threads")
    ax.set_ylabel("STREAM triad (GB/s)")
    ax.grid(True, which="major", color=GRID, lw=0.6)
    ax.legend(loc="upper left", bbox_to_anchor=(0.0, 0.64), fontsize=7)
    save(fig, "fig_stream")


def fig_placement():
    order = ["A", "B", "C", "E", "D"]
    labels = {"A": "1x128\ndefault", "B": "1x128\ninterleave", "C": "1x120\ndefault",
              "E": "1x128\nTHP off", "D": "4x32\nMPI"}
    cols = [BLUE, ORANGE, AQUA, YELLOW]
    names = ["SCCL 1", "SCCL 3", "SCCL 5", "SCCL 7"]   # memory-controller groups, one per NUMA domain (assumed)
    keys = ["share_s1", "share_s3", "share_s5", "share_s7"]

    fig, ax = plt.subplots(figsize=(3.3, 2.7))
    xs = np.arange(len(order))
    bottom = np.zeros(len(order))
    for k, (key, col, nm) in enumerate(zip(keys, cols, names)):
        vals = np.array([float(PL[v][key]) for v in order])
        ax.bar(xs, vals, 0.62, bottom=bottom, color=col, edgecolor="white", linewidth=1.5, label=nm)
        for x, b, v in zip(xs, bottom, vals):
            ax.text(x, b + v / 2, f"{v:.0f}", ha="center", va="center", fontsize=6.5, color=INK)
        bottom += vals
    for x, v in zip(xs, order):
        ax.text(x, 103, f"{wall(v):.1f} s", ha="center", va="bottom", fontsize=7, color=INK)
    ax.set_xticks(xs)
    ax.set_xticklabels([labels[v] for v in order], fontsize=7)
    ax.set_ylim(0, 118)
    ax.set_yticks([0, 25, 50, 75, 100])
    ax.set_ylabel("share of DRAM traffic (%)")
    ax.legend(ncol=4, loc="upper center", bbox_to_anchor=(0.5, -0.22), fontsize=7,
              handlelength=1, columnspacing=1)
    save(fig, "fig_placement")


ORDER = [n for n, _ in sorted(KP.items(), key=lambda kv: -float(kv[1]["time_1x1"]))]
NUM = {n: i + 1 for i, n in enumerate(ORDER)}          # marker number = row in the kernel table
OFFS_A = {1: (-8, 3), 2: (0, -9), 3: (5, 3), 4: (-2, -9), 5: (7, 2), 6: (-3, -11),
          7: (6, 3), 8: (5, 3), 9: (-9, 2), 12: (5, 3)}
OFFS_B = {1: (0, -9), 2: (-9, 3), 3: (5, -6), 4: (3, -9), 5: (7, 2), 6: (9, -2),
          7: (6, 3), 8: (-3, 7), 9: (-9, 0), 12: (7, 3)}


def roof(ax, bw, peak, extra, x0, x1, title, ymin, ymax):
    ai = np.logspace(math.log10(x0), math.log10(x1), 300)
    ax.plot(ai, np.minimum(peak, ai * bw), color=INK, lw=1.8, zorder=2)
    ax.text(x1, peak * 1.1, f"FMA peak {peak:.4g} GFLOP/s", ha="right", va="bottom", fontsize=7, color=INK2)
    for level, lab, ls in extra:
        ax.plot([level / bw, x1], [level, level], color=INK2, lw=1, ls=ls, zorder=1)
        ax.text(x1, level * 1.1, f"{lab} {level:.3g} GFLOP/s", ha="right", va="bottom", fontsize=7, color=INK2)
    ax.set_xscale("log")
    ax.set_yscale("log")
    ax.set_xlim(x0, x1)
    ax.set_ylim(ymin, ymax)
    ax.set_title(title)
    ax.set_xlabel("arithmetic intensity (flop/byte)")
    ax.grid(True, which="major", color=GRID, lw=0.6)


def slope_label(ax, fig, bw, x):
    fig.canvas.draw()
    p0, p1 = ax.transData.transform([(x, x * bw), (x * 4, x * 4 * bw)])
    ang = math.degrees(math.atan2(p1[1] - p0[1], p1[0] - p0[0]))
    ax.text(x, x * bw * 1.35, f"{bw:.1f} GB/s", rotation=ang, rotation_mode="anchor",
            fontsize=7, color=INK2, ha="left", va="bottom")


def kernel_points(ax, col, offs):
    skip = {"reset_field", "revert", "update_halo"}      # no floating-point work: not on a flop roofline
    for name in KP:
        if name in skip or name not in MODEL:
            continue
        ai, gf, _ = kernel_perf(name, col)
        ax.scatter([ai], [gf], s=30, color=BLUE, edgecolor="white", lw=1, zorder=4)
        dx, dy = offs[NUM[name]]
        ax.annotate(str(NUM[name]), (ai, gf), xytext=(dx, dy), textcoords="offset points",
                    fontsize=7, color=INK, ha="center", va="center", zorder=6)


def fig_roofline():
    fig, (a, b) = plt.subplots(1, 2, figsize=(6.6, 3.2))

    roof(a, BW_CORE, FMA_CORE, [(DIV_CORE, "vector divide", ":")], 0.08, 10, "(a) one core", 0.1, 30)
    kernel_points(a, "time_1x1", OFFS_A)
    a.set_ylabel("performance (GFLOP/s)")

    roof(b, BW_NODE, FMA_NODE, [(DIV_NODE, "vector divide", ":")], 0.08, 10, "(b) full node, 128 cores", 1.5, 4000)
    kernel_points(b, "time_1x128", OFFS_B)
    b.scatter([], [], s=30, color=BLUE, edgecolor="white", lw=1, label="kernels (numbered as in the table)")
    # whole application, measured DRAM bytes: hollow markers so the kernels stay visible
    app = [("A", "o", INK2, 90, "whole app, 1x128, THP on"),
           ("E", "D", ORANGE, 70, "whole app, 1x128, THP off"),
           ("D", "s", AQUA, 40, "whole app, 4x32")]
    for v, mk, col, size, lab in app:
        nbytes = float(PL[v]["dram_GB"]) * 1e9
        b.scatter([APP_FLOPS / nbytes], [APP_FLOPS / wall(v) * 1e-9], s=size, marker=mk,
                  facecolors="none", edgecolors=col, linewidths=1.6, zorder=5, label=lab)
    b.legend(loc="lower right", fontsize=6.5, handletextpad=0.3)

    fig.tight_layout()
    slope_label(a, fig, BW_CORE, 0.1)
    slope_label(b, fig, BW_NODE, 0.1)
    save(fig, "fig_roofline")


# ================================================================== tables
def tab_kernels():
    tot1 = sum(float(r["time_1x1"]) for r in KP.values())
    tot128 = sum(float(r["time_1x128"]) for r in KP.values())
    lines = [r"\begin{tabular}{rlrrrrrr}", r"\toprule",
             r"\# & kernel & \multicolumn{2}{c}{time share (\%)} & IPC & vector & FP scalar & back-end \\",
             r" & & 1 core & 128 cores & 1 core & ins.\ (\%) & ins.\ (\%) & stall (\%) \\", r"\midrule"]
    for name, r in sorted(KP.items(), key=lambda kv: -float(kv[1]["time_1x1"])):
        lines.append(
            f"{NUM[name]} & \\texttt{{{name.replace('_', chr(92) + '_')}}} & {100 * float(r['time_1x1']) / tot1:.1f} & "
            f"{100 * float(r['time_1x128']) / tot128:.1f} & {float(r['ipc_1x1']):.2f} & "
            f"{float(r['vec_pct_1x1']):.0f} & {float(r['fp_pct_1x1']):.0f} & "
            f"{float(r['be_stall_1x1']):.0f} / {float(r['be_stall_1x128']):.0f} \\\\")
    lines += [r"\bottomrule", r"\end{tabular}"]
    tex("tab_kernels.tex", "\n".join(lines) + "\n")


def tab_model():
    lines = [r"\begin{tabular}{lrrrrr}", r"\toprule",
             r"kernel & calls/step & flop/cell & B/cell & B/cell & AI \\",
             r" & & & (no WA) & (with WA) & (flop/B, WA) \\", r"\midrule"]
    tot_f = tot_b0 = tot_b1 = 0.0
    for k in kernel_model.KERNELS:
        f, b0, b1 = k.flops_per_cell(), k.bytes_per_cell(0), k.bytes_per_cell(1)
        tot_f += f * k.calls_per_step
        tot_b0 += b0 * k.calls_per_step
        tot_b1 += b1 * k.calls_per_step
        lines.append(f"\\texttt{{{k.name.replace('_', chr(92) + '_')}}} & {k.calls_per_step:g} & "
                     f"{f:.0f} & {b0:.0f} & {b1:.0f} & {f / b1:.2f} \\\\")
    lines += [r"\midrule",
              f"per cell and step & & {tot_f:.0f} & {tot_b0:.0f} & {tot_b1:.0f} & {tot_f / tot_b1:.2f} \\\\",
              r"\bottomrule", r"\end{tabular}"]
    tex("tab_model.tex", "\n".join(lines) + "\n")


def tab_placement():
    lines = [r"\begin{tabular}{llrrrr}", r"\toprule",
             r"variant & wall (s) & DRAM (TB) & busiest/mean & bandwidth & vs.\ STREAM \\",
             r" & median (min--max) & & controller & (GB/s) & best (\%) \\", r"\midrule"]
    for v in ["A", "B", "C", "E", "D", "F"]:
        r = PL[v]
        ws = [float(r[f"wall_{i}"]) for i in (1, 2, 3)]
        shares = [float(r[k]) for k in ("share_s1", "share_s3", "share_s5", "share_s7")]
        bw = float(r["dram_GB"]) / statistics.median(ws)
        lines.append(f"{r['label']} & {statistics.median(ws):.1f} ({min(ws):.1f}--{max(ws):.1f}) & "
                     f"{float(r['dram_GB']) / 1000:.2f} & {max(shares) / 25:.2f} & {bw:.0f} & "
                     f"{100 * bw / BW_NODE:.0f} \\\\")
    lines += [r"\bottomrule", r"\end{tabular}"]
    tex("tab_placement.tex", "\n".join(lines) + "\n")


def esc(s):
    return s.replace("_", r"\_").replace("%", r"\%")


def tab_correctness():
    lines = [r"\begin{tabular}{llrrl}", r"\toprule",
             r"kernels & layout & runs & deviation (\%) & CloverLeaf verdict \\", r"\midrule"]
    for r in rows("correctness.csv"):
        lines.append(f"{r['kernels']} & {r['layout']} & {r['reps']} & {esc(r['qa_pct'])} & "
                     f"{r['clover_verdict']} ({esc(r['source'])}) \\\\")
    lines += [r"\bottomrule", r"\end{tabular}"]
    tex("tab_correctness.tex", "\n".join(lines) + "\n")


def tab_plan():
    lines = [r"\begin{tabular}{p{7.2cm}rrrr}", r"\toprule",
             r"change & B/cell & DRAM & cumulative & floor \\",
             r" & (WA) & bytes & bytes & (s) \\", r"\midrule"]
    for r in rows("plan.csv"):
        if r["kind"] == "bytes":
            lines.append(f"{esc(r['change'])} & {r['bytes_per_cell_wa']} & ${float(r['delta_pct']):+.1f}\\%$ & "
                         f"${float(r['cumulative_delta_pct']):+.1f}\\%$ & {r['floor_s'] or '--'} \\\\")
        else:
            lines.append(f"{esc(r['change'])} & \\multicolumn{{4}}{{l}}{{time only: {esc(r['rationale'])}}} \\\\")
    lines += [r"\bottomrule", r"\end{tabular}"]
    tex("tab_plan.tex", "\n".join(lines) + "\n")


def m3_rows():
    return [r for r in rows("m3_baseline.csv") if r["median_s"]]


def tab_m3_baseline():
    lines = [r"\begin{tabular}{llllrrrrl}", r"\toprule",
             r"kernels & layout & THP & wall (s) & DRAM & bandwidth & busiest/ & vs.\ hw & source \\",
             r" & & & median (min--max) & (TB) & (GB/s) & mean & roof (\%) & \\", r"\midrule"]
    hw = C.get("dram_node_hw")
    for r in m3_rows():
        med = float(r["median_s"])
        dram = f"{float(r['dram_TB']):.2f}" if r["dram_TB"] else "--"
        bw = f"{float(r['hw_GBs']):.0f}" if r["hw_GBs"] else "--"
        bus = f"{float(r['busiest_over_mean']):.2f}" if r["busiest_over_mean"] else "--"
        roof = f"{100 * float(r['hw_GBs']) / hw:.0f}" if (r["hw_GBs"] and hw) else "--"
        lines.append(f"{r['kernels']} & {r['layout']} & {r['thp']} & {med:.1f} ({float(r['min_s']):.1f}--{float(r['max_s']):.1f}) & "
                     f"{dram} & {bw} & {bus} & {roof} & {esc(r['source'])} \\\\")
    lines += [r"\bottomrule", r"\end{tabular}"]
    tex("tab_m3_baseline.tex", "\n".join(lines) + "\n")


def fig_m3_layouts():
    data = m3_rows()
    layouts = []
    for r in data:
        if r["layout"] not in layouts:
            layouts.append(r["layout"])
    series = [("c", "on", BLUE, "C, THP on"), ("c", "off", AQUA, "C, THP off"), ("fortran", "on", "#b8b6b0", "Fortran, THP on (reference)")]
    fig, ax = plt.subplots(figsize=(4.6, 2.7))
    xs = np.arange(len(layouts))
    width = 0.26
    for i, (k, thp, col, lab) in enumerate(series):
        sel = {r["layout"]: r for r in data if r["kernels"] == k and r["thp"] == thp}
        if not sel:
            continue
        x = [xs[layouts.index(l)] + (i - 1) * width for l in sel]
        y = [float(r["median_s"]) for r in sel.values()]
        lo = [float(r["median_s"]) - float(r["min_s"]) for r in sel.values()]
        hi = [float(r["max_s"]) - float(r["median_s"]) for r in sel.values()]
        ax.bar(x, y, width, color=col, label=lab, yerr=[lo, hi], capsize=2, error_kw=dict(lw=0.8, ecolor=INK2))
        for xi, yi in zip(x, y):
            ax.text(xi, yi + 0.4, f"{yi:.1f}", ha="center", va="bottom", fontsize=6, color=INK)
    hw = C.get("dram_node_hw")
    floor = APP_BYTES_MODEL / ((hw or BW_NODE * 4 / 3) * 1e9)
    ax.axhline(floor, color=INK2, lw=1, ls="--")
    ax.text(len(layouts) - 0.5, floor + 0.4, f"floor {floor:.1f} s", ha="right", fontsize=7, color=INK2)
    ax.set_xticks(xs)
    ax.set_xticklabels(layouts)
    ax.set_xlabel("MPI ranks x OpenMP threads")
    ax.set_ylabel("wall clock, 87 steps (s)")
    ax.grid(True, axis="y", color=GRID, lw=0.6)
    ax.legend(fontsize=7, loc="upper right")
    save(fig, "fig_m3_layouts")


def tab_configs():
    sc = [r for r in rows("scaling.csv") if r["deck"] == "bm3840"]
    t1 = float(sc[0]["median_s"])
    lines = [r"\begin{tabular}{lrrrr}", r"\toprule",
             r"configuration & cores & wall (s) & min--max (s) & speed-up \\", r"\midrule"]
    for r in sc:
        n = int(r["ranks"]) * int(r["threads"])
        lines.append(f"{r['ranks']} rank{'s' if r['ranks'] != '1' else ''} $\\times$ {r['threads']} thr. & "
                     f"{n} & {float(r['median_s']):.1f} & {float(r['min_s']):.1f}--{float(r['max_s']):.1f} & "
                     f"{t1 / float(r['median_s']):.1f} \\\\")
    lines += [r"\midrule",
              f"1 rank $\\times$ 128 thr., THP off & 128 & {wall('E'):.1f} & "
              f"{min(float(PL['E'][f'wall_{i}']) for i in (1, 2, 3)):.1f}--"
              f"{max(float(PL['E'][f'wall_{i}']) for i in (1, 2, 3)):.1f} & {t1 / wall('E'):.1f} \\\\",
              r"\bottomrule", r"\end{tabular}"]
    tex("tab_configs.tex", "\n".join(lines) + "\n")


def numbers():
    """Key numbers quoted in the text, printed so main.tex can be checked against them."""
    e, a, d = wall("E"), wall("A"), wall("D")
    print(f"app flops {APP_FLOPS:.3e}  model bytes (WA) {APP_BYTES_MODEL:.3e}  AI {APP_FLOPS / APP_BYTES_MODEL:.3f}")
    for v in ("A", "E", "D"):
        nb = float(PL[v]["dram_GB"]) * 1e9
        print(f"{v}: wall {wall(v):.2f}s  DRAM {nb:.3e} B  AI {APP_FLOPS / nb:.3f}  "
              f"GFLOP/s {APP_FLOPS / wall(v) * 1e-9:.1f}  BW {nb / wall(v) * 1e-9:.0f} GB/s  "
              f"model/measured {APP_BYTES_MODEL / nb:.2f}")
    print(f"THP speed-up {a / e:.2f}x; floor at best STREAM: model {APP_BYTES_MODEL / (BW_NODE * 1e9):.1f} s, "
          f"measured bytes {float(PL['E']['dram_GB']) * 1e9 / (BW_NODE * 1e9):.1f} s")
    print(f"ridge point (FMA) {FMA_NODE / BW_NODE:.2f} flop/B; 1 core {FMA_CORE / BW_CORE:.2f}")
    if "dram_node_hw" in C:
        print(f"hardware ceiling {C['dram_node_hw']:.0f} GB/s (wa_ratio {C.get('wa_ratio', float('nan')):.2f}, "
              f"DIMM >= {C.get('dimm_mts_min', float('nan')):.0f} MT/s); floor at measured bytes "
              f"{float(PL['E']['dram_GB']) * 1e9 / (C['dram_node_hw'] * 1e9):.1f} s")
    else:
        print("no dram_node_hw row in ceilings.csv yet: run perf/jobs/m3_stream_ddrc.sbatch and paste ceilings_rows.csv")


if __name__ == "__main__":
    FIG.mkdir(exist_ok=True)
    TAB.mkdir(exist_ok=True)
    fig_scaling()
    fig_stream()
    fig_placement()
    fig_roofline()
    tab_kernels()
    tab_model()
    tab_placement()
    tab_configs()
    tab_correctness()
    tab_plan()
    tab_m3_baseline()
    fig_m3_layouts()
    numbers()
