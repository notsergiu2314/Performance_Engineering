#!/usr/bin/env python3
"""Roofline model of CloverLeaf from a baseline results directory and a machine.csv.

  roofline.py --machine results/roofline-<id>/machine.csv --results ../baseline/results/baseline-cluster
              [--deck clover_bm16_short.in] [--kernels fortran,c] [--tag TAG ...]
              [--write-allocate] [--scope node] [--out results/roofline_bm16_short.png]

Points: one per profiler section (time of the best repetition / steps) for the fastest
layout of each kernel set, with FLOPs and bytes per step from kernel_model.py; plus a
whole-step point (modelled FLOPs/bytes over the Total time) and a kernels-only point
(over the sum of the modelled sections). Ceilings: measured peak_fma and STREAM triad/copy,
theoretical peak_flops and dram_bw, and the site-quoted STREAM, all read from machine.csv.
Needs numpy/pandas/matplotlib (the repo .venv); kernel_model.py is stdlib.
"""
import argparse
import csv
import math
import re
import sys
from collections import defaultdict
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import kernel_model as km  # noqa: E402

SECTION_ORDER = list(km.SECTIONS)
COLORS = {s: c for s, c in zip(SECTION_ORDER, plt.cm.tab10.colors)}
MARKER = {"fortran": dict(marker="o", ms=8), "c": dict(marker="s", ms=9, mfc="none", mew=1.8)}


def fl(x):
    try:
        return float(x)
    except (TypeError, ValueError):
        return math.nan


def read_csv(path):
    with open(path, newline="") as f:
        return list(csv.DictReader(f))


def parse_deck(path):
    d = {}
    for line in Path(path).read_text().splitlines():
        m = re.match(r"\s*(x_cells|y_cells|end_step)\s*=\s*(\d+)", line)
        if m:
            d[m.group(1)] = int(m.group(2))
    return d


def steps_run(out_file, fallback):
    last = None
    try:
        for line in Path(out_file).read_text(errors="replace").splitlines():
            m = re.match(r"\s*Step\s+(\d+)\s+time", line)
            if m:
                last = int(m.group(1))
    except OSError:
        pass
    return last or fallback


def pick_cases(results_dir, deck, kernels, tags):
    rows = [r for r in read_csv(results_dir / "results.csv") if r["deck"] == deck]
    if not rows:
        sys.exit(f"no rows for deck {deck} in {results_dir}/results.csv")
    best = {}
    for r in rows:
        if r["tag"] not in best or fl(r["wall"]) < fl(best[r["tag"]]["wall"]):
            best[r["tag"]] = r
    chosen = []
    if tags:
        for t in tags:
            if t not in best:
                sys.exit(f"tag {t} not in results.csv")
            chosen.append(best[t])
    else:
        for k in kernels:
            cand = [r for r in best.values() if r["kernels"] == k]
            if cand:
                chosen.append(min(cand, key=lambda r: fl(r["wall"])))
    return chosen


def load_hw_model():
    """The per-kernel byte model of perf/analysis/kernel_model.py (write-allocate, validated
    against the DDR-controller counters to 1-5 %), keyed by profiler category."""
    import importlib.util
    p = Path(__file__).resolve().parent.parent / "analysis" / "kernel_model.py"
    spec = importlib.util.spec_from_file_location("kernel_model_hw", p)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def ceilings(machine_csvs, scope, write_allocate, hw_roof=None, hw_copy=None):
    """Return {name: GB/s or GFLOP/s} for the chosen scope. Later files override earlier
    rows with the same (quantity, source), so a partial rerun (matrix.peak) can be layered
    on a full machine.csv. hw_roof/hw_copy (GB/s) replace the STREAM-counted triad/copy
    ceilings by hardware-byte ones (--hw mode)."""
    c = {}
    for machine_csv in machine_csvs:
        for r in read_csv(machine_csv):
            if r["scope"] != scope:
                continue
            key = (r["quantity"], r["source"])
            c[key] = fl(r["value"])
    machine_csv = machine_csvs[-1]
    out = {}
    if ("peak_fma", "measured") in c:
        out["peak_measured"] = c[("peak_fma", "measured")]
    if ("peak_flops", "theoretical") in c:
        out["peak_theoretical"] = c[("peak_flops", "theoretical")]
    # With write-allocate the model counts 16 B per stored element; STREAM reports
    # 8 B per stored element, so rescale the measured ceilings to hardware bytes.
    wa_copy, wa_triad = (1.5, 4 / 3) if write_allocate else (1, 1)
    if ("stream_triad", "measured") in c:
        out["bw_triad"] = c[("stream_triad", "measured")] * wa_triad
    if ("stream_copy", "measured") in c:
        out["bw_copy"] = c[("stream_copy", "measured")] * wa_copy
    if ("dram_bw", "theoretical") in c:
        out["bw_theoretical"] = c[("dram_bw", "theoretical")]
    if ("stream_triad", "site") in c:
        out["bw_site"] = c[("stream_triad", "site")] * wa_triad
    if hw_roof:
        out["bw_triad"] = hw_roof
        out.pop("bw_copy", None)
        out.pop("bw_site", None)
        if hw_copy:
            out["bw_copy"] = hw_copy
    if "peak_measured" not in out and "peak_theoretical" not in out:
        sys.exit(f"no peak_fma/peak_flops rows with scope={scope} in {machine_csv}")
    if "bw_triad" not in out and "bw_theoretical" not in out:
        sys.exit(f"no stream_triad/dram_bw rows with scope={scope} in {machine_csv}")
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0],
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--machine", required=True, action="append",
                    help="machine.csv from machine.sh; may be repeated, later files override earlier rows")
    ap.add_argument("--results", required=True, help="baseline OUT_DIR (results.csv, profiler.csv, <tag>/)")
    ap.add_argument("--deck", default="clover_bm16_short.in")
    ap.add_argument("--kernels", default="fortran,c", help="comma list; fastest layout per kernel set")
    ap.add_argument("--tag", action="append", help="explicit case tag(s) instead of the fastest")
    ap.add_argument("--write-allocate", action="store_true", help="count read-for-ownership on stores")
    ap.add_argument("--hw", action="store_true",
                    help="hardware-byte mode: whole-step bytes = DDR-controller bytes of the chosen repetition "
                         "(results.csv dram_GB), split over the sections with the write-allocate model of "
                         "perf/analysis/kernel_model.py; needs --hw-roof")
    ap.add_argument("--hw-roof", type=float, help="hardware STREAM triad ceiling, GB/s (dram_node_hw from m3_stream_ddrc)")
    ap.add_argument("--hw-copy", type=float, help="hardware STREAM copy ceiling, GB/s (optional)")
    ap.add_argument("--scope", default="node", help="machine.csv scope for the ceilings (core|numa|socket|node)")
    ap.add_argument("--out", help="PNG path (default results/roofline_<deck>[_wa].png next to this script)")
    ap.add_argument("--title", default=None)
    a = ap.parse_args()

    here = Path(__file__).resolve().parent
    results_dir = Path(a.results)
    if a.hw and not a.hw_roof:
        sys.exit("--hw needs --hw-roof <GB/s> (hardware STREAM triad from jobs/m3_stream_ddrc.sbatch)")
    if a.hw and a.write_allocate:
        sys.exit("--hw already uses the write-allocate model of perf/analysis; drop --write-allocate")
    hw_model = load_hw_model() if a.hw else None
    stem = a.deck.replace(".in", "").replace("clover_", "") + ("_wa" if a.write_allocate else "") + ("_hw" if a.hw else "")
    out_png = Path(a.out) if a.out else here / "results" / f"roofline_{stem}.png"
    out_png.parent.mkdir(parents=True, exist_ok=True)
    out_csv = out_png.with_suffix(".csv")
    out_bw = out_png.with_name(out_png.stem + "_bw.png")

    cases = pick_cases(results_dir, a.deck, a.kernels.split(","), a.tag)
    prof = defaultdict(dict)
    for r in read_csv(results_dir / "profiler.csv"):
        prof[(r["tag"], r["rep"])][r["section"]] = fl(r["time"])
    ceil = ceilings([Path(m) for m in a.machine], a.scope, a.write_allocate, a.hw_roof if a.hw else None,
                    a.hw_copy if a.hw else None)

    points = []   # dicts, one per (case, section)
    for case in cases:
        tag, rep = case["tag"], case["rep"]
        deck = parse_deck(results_dir / tag / "clover.in")
        x, y = deck["x_cells"], deck["y_cells"]
        steps = steps_run(results_dir / tag / f"rep{rep}.out", deck.get("end_step", 0))
        times = prof[(tag, rep)]
        model = km.section_totals(x, y, a.write_allocate)
        step = km.step_totals(x, y, a.write_allocate)
        if a.hw:
            # Section bytes from the write-allocate model, rescaled so that their sum equals the
            # DDR-controller bytes per step of this repetition (the split stays the model's).
            hw = {cat: b for cat, (_, b) in hw_model.per_category(x * y, 1, 1).items()}
            model_total = sum(hw.get(sec, 0.0) for sec in SECTION_ORDER)
            dram = fl(case.get("dram_GB")) * 1e9 / steps
            if math.isnan(dram) or dram <= 0:
                print(f"warning: {tag} rep {rep} has no dram_GB in results.csv; using the model total")
                dram = model_total
            for sec in SECTION_ORDER:
                model[sec]["bytes"] = hw.get(sec, model[sec]["bytes"]) * dram / model_total
            step["bytes"] = dram
            print(f"{tag}: hardware bytes {dram/1e9:.2f} GB/step, write-allocate model {model_total/1e9:.2f} "
                  f"GB/step (measured/model {dram/model_total:.2f})")
        bw_ref = ceil.get("bw_triad") or ceil.get("bw_theoretical")
        peak_ref = ceil.get("peak_measured") or ceil.get("peak_theoretical")

        def point(section, t, flops, byts, calls):
            # Pure copy sections (Revert, Reset) have no FLOPs: AI = 0, no point on the
            # log-log roofline, but they still get an achieved-bandwidth entry.
            ai = flops / byts
            gf, gb = flops / t / 1e9, byts / t / 1e9
            roof = min(peak_ref, ai * bw_ref) if flops else math.nan
            return dict(tag=tag, kernels=case["kernels"], ranks=case["ranks"], threads=case["threads"],
                        x_cells=x, y_cells=y, steps=steps, section=section, calls_per_step=calls,
                        time_per_step_s=t, flops_per_step=flops, bytes_per_step=byts, ai=ai,
                        gflops=gf, gbs=gb, frac_bw_roof=gb / bw_ref, roof_gflops=roof,
                        frac_roof=gf / roof if flops else math.nan,
                        write_allocate=2 if a.hw else int(a.write_allocate), scope=a.scope)

        modelled_time = 0.0
        for sec in SECTION_ORDER:
            if sec not in times:
                print(f"warning: section '{sec}' missing in profiler rows of {tag} rep {rep}")
                continue
            t = times[sec] / steps
            modelled_time += t
            points.append(point(sec, t, model[sec]["flops"], model[sec]["bytes"], model[sec]["calls"]))
        total_time = times.get("Total", modelled_time) / steps
        points.append(point("Whole step", total_time, step["flops"], step["bytes"], 1))
        points.append(point("Kernels only", modelled_time, step["flops"], step["bytes"], 1))
        other = {s: times[s] / steps for s in km.UNMODELLED if s in times}
        print(f"{tag}: rep {rep}, {x}x{y} cells, {steps} steps, {total_time*1e3:.1f} ms/step, "
              f"modelled sections {modelled_time/total_time*100:.1f}% of Total; unmodelled: "
              + ", ".join(f"{s} {t*1e3:.1f} ms" for s, t in other.items()))

    # ---- CSV ----
    with open(out_csv, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(points[0]))
        w.writeheader()
        w.writerows(points)

    # ---- console table ----
    print(f"\n{'section':20} {'kernels':8} {'ms/step':>8} {'AI':>6} {'GFLOP/s':>8} {'GB/s':>7} {'%bw roof':>8} {'%roof':>6}")
    for p in points:
        print(f"{p['section']:20} {p['kernels']:8} {p['time_per_step_s']*1e3:8.2f} {p['ai']:6.3f} "
              f"{p['gflops']:8.1f} {p['gbs']:7.1f} {p['frac_bw_roof']*100:8.1f} {p['frac_roof']*100:6.1f}"
              .replace("   nan", "     -"))
    print("\nceilings (" + a.scope + "): " + ", ".join(f"{k}={v:.1f}" for k, v in ceil.items()))

    # ---- roofline figure ----
    fig, ax = plt.subplots(figsize=(10, 7))
    ai_all = [p["ai"] for p in points if p["ai"] > 0]
    ai_min, ai_max = min(ai_all) / 4, max(ai_all) * 64
    ai = np.logspace(np.log10(ai_min), np.log10(ai_max), 400)
    wa_note = " (hardware bytes incl. write-allocate)" if a.write_allocate else (" (hardware bytes, DDRC)" if a.hw else "")
    if "peak_measured" in ceil and "bw_triad" in ceil:
        ax.plot(ai, np.minimum(ceil["peak_measured"], ai * ceil["bw_triad"]), "k-", lw=2,
                label=f"measured: FMA peak {ceil['peak_measured']:.0f} GFLOP/s, STREAM triad {ceil['bw_triad']:.0f} GB/s{wa_note}")
    if "bw_copy" in ceil:
        ax.plot(ai, np.minimum(ceil.get("peak_measured", ceil.get("peak_theoretical")), ai * ceil["bw_copy"]),
                color="0.45", ls="-.", lw=1.2, label=f"measured: STREAM copy {ceil['bw_copy']:.0f} GB/s{wa_note}")
    if "peak_theoretical" in ceil and "bw_theoretical" in ceil:
        ax.plot(ai, np.minimum(ceil["peak_theoretical"], ai * ceil["bw_theoretical"]), color="0.3", ls="--", lw=1.5,
                label=f"theoretical: {ceil['peak_theoretical']:.0f} GFLOP/s, {ceil['bw_theoretical']:.0f} GB/s DRAM")
    if "bw_site" in ceil:
        ax.plot(ai, np.minimum(ceil.get("peak_measured", ceil.get("peak_theoretical")), ai * ceil["bw_site"]),
                color="0.6", ls=":", lw=1.2, label=f"site STREAM triad {ceil['bw_site']:.0f} GB/s{wa_note}")

    labelled = set()
    for p in points:
        sec = p["section"]
        if p["ai"] == 0:
            continue
        if sec in ("Whole step", "Kernels only"):
            style = dict(marker="*" if sec == "Whole step" else "P", ms=14 if sec == "Whole step" else 10,
                         color="black", mfc="black" if p["kernels"] == "fortran" else "none", mew=1.5)
            ax.plot(p["ai"], p["gflops"], ls="none", **style)
            if sec == "Whole step" and (sec, p["kernels"]) not in labelled:
                # one label per kernel set; the kernels-only marker sits on the same spot
                ax.annotate(f"whole step ({p['kernels']})", (p["ai"], p["gflops"]), textcoords="offset points",
                            xytext=(10, -2 if p["kernels"] == "fortran" else -12), fontsize=8)
                labelled.add((sec, p["kernels"]))
            continue
        ax.plot(p["ai"], p["gflops"], ls="none", color=COLORS[sec], **MARKER[p["kernels"]])
        if sec not in labelled and p["kernels"] == cases[0]["kernels"]:
            ax.annotate(sec, (p["ai"], p["gflops"]), textcoords="offset points", xytext=(7, 4),
                        fontsize=8, color=COLORS[sec])
            labelled.add(sec)
    for k in dict.fromkeys(p["kernels"] for p in points):
        ax.plot([], [], ls="none", color="0.2", label=f"{k} kernels, per profiler section", **MARKER[k])
    ax.plot([], [], ls="none", marker="*", ms=12, color="black", label="whole step (Total time)")
    ax.plot([], [], ls="none", marker="P", ms=9, color="black", mfc="none", label="kernels only (sum of modelled sections)")
    zero = [p["section"] for p in points if p["ai"] == 0 and p["kernels"] == cases[0]["kernels"]]
    if zero:
        ax.plot([], [], ls="none", label="no FLOPs (copy only), see bandwidth figure: " + ", ".join(zero))

    ax.set_xscale("log", base=2)
    ax.set_yscale("log")
    ax.set_xlim(ai_min, ai_max)
    ymax = max(ceil.get("peak_theoretical", 0), ceil.get("peak_measured", 0)) * 2
    ymin = min(p["gflops"] for p in points if p["gflops"] > 0) / 4
    ax.set_ylim(ymin, ymax)
    ax.set_xlabel("Arithmetic intensity (FLOP / DRAM byte, analytical model" + (", write-allocate" if a.write_allocate else "") + ")")
    ax.set_ylabel("Performance (GFLOP/s)")
    c0 = cases[0]
    layout = ", ".join(f"{c['kernels']} {c['ranks']}x{c['threads']}" for c in cases)
    ax.set_title(a.title or f"CloverLeaf roofline, {a.deck} ({c0.get('x_cells', '')}{layout}), {a.scope} scope")
    ax.grid(True, which="both", linestyle="--", alpha=0.4)
    ax.legend(loc="lower right", fontsize=8)
    plt.tight_layout()
    plt.savefig(out_png, dpi=300)
    plt.close()

    # ---- achieved-bandwidth figure ----
    secs = [s for s in SECTION_ORDER + ["Kernels only", "Whole step"] if any(p["section"] == s for p in points)]
    ks = list(dict.fromkeys(p["kernels"] for p in points))
    fig, ax = plt.subplots(figsize=(10, 0.45 * len(secs) + 2))
    h = 0.8 / len(ks)
    for i, k in enumerate(ks):
        vals = [next((p["gbs"] for p in points if p["section"] == s and p["kernels"] == k), 0) for s in secs]
        ax.barh(np.arange(len(secs)) + (i - (len(ks) - 1) / 2) * h, vals, height=h, label=f"{k} kernels",
                color="tab:blue" if k == "fortran" else "tab:orange")
    for key, lbl, st in [("bw_triad", "STREAM triad", "-"), ("bw_copy", "STREAM copy", "-."),
                         ("bw_theoretical", "DRAM theoretical", "--"), ("bw_site", "site STREAM", ":")]:
        if key in ceil:
            ax.axvline(ceil[key], color="k", ls=st, lw=1.2, label=f"{lbl} {ceil[key]:.0f} GB/s")
    ax.set_yticks(range(len(secs)))
    ax.set_yticklabels(secs)
    ax.invert_yaxis()
    ax.set_xlabel("Achieved DRAM bandwidth (GB/s, modelled bytes / measured time)" + wa_note)
    ax.set_title(f"CloverLeaf achieved bandwidth per section, {a.deck}, {a.scope} scope")
    ax.grid(True, axis="x", linestyle="--", alpha=0.4)
    ax.legend(fontsize=8, loc="lower right")
    plt.tight_layout()
    plt.savefig(out_bw, dpi=300)
    plt.close()
    print(f"\nwrote {out_csv}\n      {out_png}\n      {out_bw}")


if __name__ == "__main__":
    main()
