#!/usr/bin/env python3
"""Summarise results.csv / profiler.csv produced by run_case.sh.
usage: summarize.py OUT_DIR [--md] [--stream-hw-gbs GBS]
Prints best-of-N and median wall time, grind time, QA deviation, DRAM traffic from the
DDR-controller counters (hardware bytes, when recorded), the C/Fortran ratio per
layout, and the profiler split of the best repetition.
--stream-hw-gbs  hardware STREAM ceiling (GB/s, DDRC bytes over time, from
                 jobs/m3_stream_ddrc.sbatch); adds a %-of-roof column."""
import csv, statistics, sys
from collections import defaultdict
from pathlib import Path

args = sys.argv[1:]
md = "--md" in args
hw_roof = None
if "--stream-hw-gbs" in args:
    hw_roof = float(args[args.index("--stream-hw-gbs") + 1])
    del args[args.index("--stream-hw-gbs"):args.index("--stream-hw-gbs") + 2]
args = [a for a in args if not a.startswith("--")]
out = Path(args[0] if args else "results")
rows = list(csv.DictReader(open(out / "results.csv")))
prof = list(csv.DictReader(open(out / "profiler.csv"))) if (out / "profiler.csv").exists() else []

def fl(x):
    try: return float(x)
    except (TypeError, ValueError): return float("nan")

def isnum(x): return x == x   # not NaN

cases = defaultdict(list)
for r in rows: cases[r["tag"]].append(r)
have_dram = any(isnum(fl(r.get("dram_GB"))) for r in rows)

def table(hdr, lines):
    if md:
        print("| " + " | ".join(hdr) + " |"); print("|" + "---|" * len(hdr))
        for l in lines: print("| " + " | ".join(l) + " |")
    else:
        w = [max(len(h), *(len(l[i]) for l in lines)) for i, h in enumerate(hdr)]
        print("  ".join(h.ljust(w[i]) for i, h in enumerate(hdr)))
        for l in lines: print("  ".join(c.ljust(w[i]) for i, c in enumerate(l)))
    print()

best = {}
lines = []
for tag, rs in cases.items():
    walls = [fl(r["wall"]) for r in rs]
    b = min(rs, key=lambda r: fl(r["wall"]))
    best[tag] = b
    qa = max(fl(r["qa_pct"]) for r in rs)
    status = "PASSED" if all(r["qa"] == "PASSED" for r in rs) else "FAILED"
    kern = {r["kernels_reported"] for r in rs}
    line = [tag, rs[0]["deck"], rs[0]["kernels"], rs[0]["ranks"], rs[0]["threads"], rs[0].get("thp", "on"),
            str(len(rs)), f"{min(walls):.3f}", f"{statistics.median(walls):.3f}",
            f"{(max(walls)-min(walls))/min(walls)*100:.1f}%",
            f"{fl(b['grind'])*1e9:.2f}", f"{qa:.2e}", status, "/".join(sorted(kern))]
    if have_dram:
        drams = [fl(r.get("dram_GB")) for r in rs if isnum(fl(r.get("dram_GB")))]
        bus = [fl(r.get("busiest_over_mean")) for r in rs if isnum(fl(r.get("busiest_over_mean")))]
        if drams:
            d = statistics.median(drams)
            # hardware bandwidth of the median-traffic rep over the median wall: both are
            # medians of the same reps, so this is the typical sustained DRAM bandwidth
            gbs = d / statistics.median(walls)
            line += [f"{d/1000:.3f}", f"{gbs:.0f}", f"{statistics.median(bus):.2f}" if bus else "NA"]
            line += [f"{100*gbs/hw_roof:.0f}%"] if hw_roof else []
        else:
            line += ["NA", "NA", "NA"] + (["NA"] if hw_roof else [])
    lines.append(line)
print(f"Results in {out}  ({len(rows)} runs, {len(cases)} cases)\n")
hdr = ["case", "deck", "kernels", "ranks", "thr", "thp", "n", "best_wall_s", "median_s", "spread",
       "grind_ns/cell", "qa_dev_%", "qa", "reported"]
if have_dram:
    hdr += ["dram_TB", "hw_GB/s", "busiest/mean"] + (["%hw_roof"] if hw_roof else [])
table(hdr, lines)
if have_dram:
    print("dram_TB: DDR-controller bytes (32 B/count, everything the controllers moved incl. read-for-ownership), median over reps; "
          "hw_GB/s = dram / median wall; busiest/mean = load of the busiest NUMA controller group (1.00 = balanced)"
          + (f"; %hw_roof vs {hw_roof:.0f} GB/s hardware STREAM" if hw_roof else "") + "\n")

# C vs Fortran ratio for identical deck/layout/thp (Fortran is the reference, C the subject)
pairs = defaultdict(dict)
for tag, b in best.items():
    pairs[(b["deck"], b["ranks"], b["threads"], b.get("thp", "on"))][b["kernels"]] = fl(b["wall"])
cmp = [[d, r, t, thp, f"{w['fortran']:.3f}", f"{w['c']:.3f}", f"{w['c']/w['fortran']:.3f}"]
       for (d, r, t, thp), w in sorted(pairs.items()) if "fortran" in w and "c" in w]
if cmp:
    print("C relative to Fortran (best wall, ratio > 1 means C slower; Fortran for reference only)")
    table(["deck", "ranks", "thr", "thp", "fortran_s", "c_s", "c/fortran"], cmp)

if prof:
    sect = defaultdict(dict)
    order = []
    for p in prof:
        b = best.get(p["tag"])
        if b and p["rep"] == b["rep"]:
            sect[p["section"]][p["tag"]] = (fl(p["time"]), fl(p["pct"]))
            if p["section"] not in order: order.append(p["section"])
    tags = list(best)
    lines = []
    for s in order:
        vals = [sect[s].get(t, (float("nan"), float("nan"))) for t in tags]
        if max(v[1] for v in vals) < 1.0: continue
        lines.append([s] + [f"{v[0]:.2f} ({v[1]:.0f}%)" for v in vals])
    print("Profiler split of best repetition (seconds, % of wall); sections under 1% omitted")
    table(["section"] + tags, lines)
