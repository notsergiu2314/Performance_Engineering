#!/usr/bin/env python3
"""Summarise a run.sh output directory into per-sort counter values.

For every (variant, count) the median over trials of each counter is taken for the reps=R run
and for the reps=0 run (allocate + initialise only); the difference divided by R is the value
per sort. Times come from the benchmark's own timers (sort_s, perm_s in the .out files).
  python3 summarize.py results/<id> [--tex tables_dir]
Writes <dir>/summary.csv and, with --tex, tab_small_<count>.tex / tab_big_<count>.tex.
"""
import csv, glob, os, re, statistics, sys
from collections import defaultdict

EVENT_ROWS = [  # (perf event, row label, scale)  -- order of the table rows
    ("cycles", "cycles"),
    ("instructions", "instructions"),
    ("L1-dcache-loads", "L1d loads"),
    ("L1-dcache-load-misses", "L1d load misses"),
    ("l2d_cache", "L2 accesses"),
    ("l2d_cache_refill", "L2 refills"),
    ("ll_cache_rd", "L3 reads"),
    ("ll_cache_miss_rd", "L3 read misses"),
    ("dTLB-load-misses", "dTLB load misses"),
    ("stall_backend", "backend stall cycles"),
    ("branch-misses", "branch misses"),
]
VARIANT_LABEL = {"small_base": "base", "small_opt": "optimized", "small_reorder": "reorder",
                 "small_align": "reorder+align", "small_split": "split",
                 "big_base": "base", "big_opt": "optimized", "big_pad": "pad", "big_split": "split"}
TABLE_VARIANTS = {"small": ["small_base", "small_opt"], "big": ["big_base", "big_opt"]}  # tex columns
VARIANT_ORDER = ["small_base", "small_opt", "small_reorder", "small_align", "small_split",
                 "big_base", "big_opt", "big_pad", "big_split"]

def parse_dir(d):
    counters = defaultdict(lambda: defaultdict(list))   # (variant,count,reps) -> event -> [values]
    times = defaultdict(lambda: defaultdict(list))      # (variant,count,reps) -> field -> [values]
    warnings = []
    for f in sorted(glob.glob(os.path.join(d, "*.csv"))):
        m = re.match(r"(.+)\.(\d+)\.(\d+)\.t(\d+)\.g(\d+)\.csv$", os.path.basename(f))
        if not m:
            continue
        v, c, r = m.group(1), int(m.group(2)), int(m.group(3))
        with open(f) as fh:
            for row in csv.reader(l for l in fh if l.strip() and not l.startswith("#")):
                if len(row) < 5:
                    continue
                val, ev, pct = row[0], row[2], row[4]
                try:
                    val = float(val)
                except ValueError:
                    warnings.append(f"{os.path.basename(f)}: {ev} = {val}")
                    continue
                if pct and float(pct) < 99.5:
                    warnings.append(f"{os.path.basename(f)}: {ev} ran {pct}% (multiplexed)")
                counters[(v, c, r)][ev].append(val)
        out = f[:-4] + ".out"
        if os.path.exists(out):
            kv = dict(re.findall(r"(\w+)=(\S+)", open(out).read()))
            if kv.get("check") != "ok":
                warnings.append(f"{os.path.basename(out)}: check={kv.get('check')}")
            for k in ("sort_s", "perm_s", "per_rep_s", "init_s"):
                times[(v, c, r)][k].append(float(kv[k]))
            times[(v, c, r)]["sizeof"] = [float(kv["sizeof"])]
    return counters, times, warnings

def med(xs):
    return statistics.median(xs) if xs else float("nan")

def per_sort(counters, times):
    """(variant,count) -> dict of per-sort values."""
    res = {}
    for (v, c, r), evs in counters.items():
        if r == 0:
            continue
        base = counters.get((v, c, 0), {})
        d = {"reps": r, "sizeof": times[(v, c, r)]["sizeof"][0]}
        for ev, vals in evs.items():
            d[ev] = (med(vals) - med(base.get(ev, [0.0]))) / r
        t = times[(v, c, r)]
        d["sort_s"] = med(t["sort_s"]) / r
        d["perm_s"] = med(t["perm_s"]) / r
        d["total_s"] = d["sort_s"] + d["perm_s"]
        res[(v, c)] = d
    return res

def fmt(x):
    if x != x:
        return "--"
    if x < 0:  # difference of two noisy near-zero counts
        return "$\\approx 0$"
    ax = abs(x)
    for s, u in ((1e9, "G"), (1e6, "M"), (1e3, "k")):
        if ax >= s:
            return f"{x / s:.3g}\\,{u}" if ax / s < 100 else f"{x / s:.0f}\\,{u}"
    return f"{x:.3g}"

def write_tex(res, path, variants, count, caption, label):
    cols = [v for v in variants if (v, count) in res]
    rows = []
    rows.append(("record size [B]", [f"{res[(v, count)]['sizeof']:.0f}" for v in cols]))
    rows.append(("time per sort [ms]", [f"{1e3 * res[(v, count)]['total_s']:.3g}" for v in cols]))
    if any(res[(v, count)]["perm_s"] > 0 for v in cols):
        rows.append(("\\quad of which key sort [ms]",
                     [f"{1e3 * res[(v, count)]['sort_s']:.3g}" if res[(v, count)]["perm_s"] > 0 else "--"
                      for v in cols]))
        rows.append(("\\quad of which permutation [ms]",
                     [f"{1e3 * res[(v, count)]['perm_s']:.3g}" if res[(v, count)]["perm_s"] > 0 else "--"
                      for v in cols]))
    rows.append(("speed-up vs.\\ base", [f"{res[(cols[0], count)]['total_s'] / res[(v, count)]['total_s']:.2f}"
                                        for v in cols]))
    for ev, lab in EVENT_ROWS:
        if all(ev in res[(v, count)] for v in cols):
            rows.append((lab, [fmt(res[(v, count)][ev]) for v in cols]))
    def ratio(a, b, v):
        d = res[(v, count)]
        return d[a] / d[b] if a in d and b in d and d[b] else float("nan")
    rows.append(("IPC", [f"{ratio('instructions', 'cycles', v):.2f}" for v in cols]))
    rows.append(("L1d miss rate [\\%]", [f"{100 * ratio('L1-dcache-load-misses', 'L1-dcache-loads', v):.1f}" for v in cols]))
    rows.append(("backend stall [\\% cycles]", [f"{100 * ratio('stall_backend', 'cycles', v):.0f}" for v in cols]))
    with open(path, "w") as fh:
        fh.write("\\begin{table}[htbp]\\centering\\small\n")
        fh.write("\\begin{tabular}{l" + "r" * len(cols) + "}\n\\toprule\n")
        fh.write("per sort & " + " & ".join(VARIANT_LABEL.get(v, v) for v in cols) + " \\\\\n\\midrule\n")
        for lab, vals in rows:
            fh.write(lab + " & " + " & ".join(vals) + " \\\\\n")
        fh.write("\\bottomrule\n\\end{tabular}\n")
        fh.write(f"\\caption{{{caption}}}\\label{{{label}}}\n\\end{{table}}\n")

def main():
    d = sys.argv[1]
    tex = sys.argv[sys.argv.index("--tex") + 1] if "--tex" in sys.argv else None
    counters, times, warnings = parse_dir(d)
    res = per_sort(counters, times)
    for w in warnings:
        print("WARNING:", w)
    with open(os.path.join(d, "summary.csv"), "w", newline="") as fh:
        w = csv.writer(fh)
        keys = ["sizeof", "reps", "total_s", "sort_s", "perm_s"] + [e for e, _ in EVENT_ROWS]
        w.writerow(["variant", "count"] + keys)
        for (v, c) in sorted(res, key=lambda k: (VARIANT_ORDER.index(k[0]), k[1])):
            w.writerow([v, c] + [res[(v, c)].get(k, "") for k in keys])
    for (v, c) in sorted(res, key=lambda k: (VARIANT_ORDER.index(k[0]), k[1])):
        r = res[(v, c)]
        print(f"{v:14s} n={c:8d} {1e3 * r['total_s']:9.3f} ms/sort  "
              + "  ".join(f"{e}={fmt(r[e]).replace(chr(92) + ',', '')}" for e, _ in EVENT_ROWS if e in r))
    if tex:
        os.makedirs(tex, exist_ok=True)
        for c in sorted({c for v, c in res if v.startswith("small")}):
            write_tex(res, os.path.join(tex, f"tab_small_{c}.tex"), TABLE_VARIANTS["small"], c,
                      f"\\texttt{{Small}}: counters per sort of {c:,} records (median of 3 trials; "
                      "reps=0 run subtracted).".replace(",", "\\,"), f"tab:small{c}")
        for c in sorted({c for v, c in res if v.startswith("big")}):
            write_tex(res, os.path.join(tex, f"tab_big_{c}.tex"), TABLE_VARIANTS["big"], c,
                      f"\\texttt{{Big}}: counters per sort of {c:,} records (median of 3 trials; "
                      "reps=0 run subtracted).".replace(",", "\\,"), f"tab:big{c}")

if __name__ == "__main__":
    main()
