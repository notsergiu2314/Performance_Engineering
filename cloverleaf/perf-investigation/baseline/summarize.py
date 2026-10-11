#!/usr/bin/env python3
"""Summarise results.csv / profiler.csv produced by run_case.sh.
usage: summarize.py OUT_DIR [--md]
Prints best-of-N and median wall time, grind time, QA deviation, the C/Fortran
ratio per layout, and the profiler split of the best repetition."""
import csv, statistics, sys
from collections import defaultdict
from pathlib import Path

out = Path(sys.argv[1] if len(sys.argv) > 1 else "results")
md = "--md" in sys.argv
rows = list(csv.DictReader(open(out / "results.csv")))
prof = list(csv.DictReader(open(out / "profiler.csv"))) if (out / "profiler.csv").exists() else []

def fl(x):
    try: return float(x)
    except ValueError: return float("nan")

cases = defaultdict(list)
for r in rows: cases[r["tag"]].append(r)

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
    lines.append([tag, rs[0]["deck"], rs[0]["kernels"], rs[0]["ranks"], rs[0]["threads"], str(len(rs)),
                  f"{min(walls):.3f}", f"{statistics.median(walls):.3f}",
                  f"{(max(walls)-min(walls))/min(walls)*100:.1f}%",
                  f"{fl(b['grind'])*1e9:.2f}", f"{qa:.2e}", status, "/".join(sorted(kern))])
print(f"Results in {out}  ({len(rows)} runs, {len(cases)} cases)\n")
table(["case", "deck", "kernels", "ranks", "thr", "n", "best_wall_s", "median_s", "spread", "grind_ns/cell", "qa_dev_%", "qa", "reported"], lines)

# C vs Fortran ratio for identical deck/layout
pairs = defaultdict(dict)
for tag, b in best.items():
    pairs[(b["deck"], b["ranks"], b["threads"])][b["kernels"]] = fl(b["wall"])
cmp = [[d, r, t, f"{w['fortran']:.3f}", f"{w['c']:.3f}", f"{w['c']/w['fortran']:.3f}"]
       for (d, r, t), w in sorted(pairs.items()) if "fortran" in w and "c" in w]
if cmp:
    print("C relative to Fortran (best wall, ratio > 1 means C slower)")
    table(["deck", "ranks", "thr", "fortran_s", "c_s", "c/fortran"], cmp)

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
