#!/usr/bin/env python3
"""Correctness gate: compare the kinetic-energy deviation of every run in a results.csv
with the recorded baseline deviation of the same deck and kernel set.

  python3 qa_check.py <results.csv> <correctness_baseline.csv> [--tol 1e-6]
                      [--csv rows.csv --source "job 123"]

baseline csv columns: deck,kernels,qa_pct[,source]  ('#' lines ignored)
Exit status 0 when every run matches (|qa_pct - baseline| <= tol, in %), 1 otherwise.
A run with no deviation line (crash, no clover.out) fails. The built-in PASSED/FAILED
flag of CloverLeaf (0.001 % threshold) is printed but not used: clover_bm.in fails it on
this system for both kernel sets with the unmodified code, so the gate is reproduction
of the baseline deviation, not the absolute threshold.
--csv appends one row per run in the report/data/correctness.csv format plus the build
variant (results.csv column, if present) and the gate verdict:
  deck,kernels,layout,reps,qa_pct,clover_verdict,source,variant,gate
"""
import argparse
import csv
import sys


def fl(x):
    try:
        return float(x)
    except (TypeError, ValueError):
        return float("nan")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("results")
    ap.add_argument("baseline")
    ap.add_argument("--tol", type=float, default=1e-6, help="allowed |difference| in percent")
    ap.add_argument("--csv", help="append report-format rows to this file (header written if new)")
    ap.add_argument("--source", default="", help="source column of the --csv rows, e.g. 'job 34796'")
    a = ap.parse_args()

    base = {}
    with open(a.baseline, newline="") as f:
        for r in csv.DictReader(line for line in f if not line.startswith("#")):
            base[(r["deck"], r["kernels"])] = fl(r["qa_pct"])
    rows = list(csv.DictReader(open(a.results, newline="")))
    if not rows:
        sys.exit("no runs in " + a.results)

    bad = 0
    out = []
    print(f"{'case':44s} {'rep':>3s} {'qa_pct':>14s} {'baseline':>14s} {'diff':>10s} clover  gate")
    for r in rows:
        key = (r["deck"], r["kernels"])
        q, b = fl(r["qa_pct"]), base.get(key, float("nan"))
        if key not in base:
            verdict = "NO-BASELINE"
        elif q != q:
            verdict = "NO-RESULT"
        elif abs(q - b) <= a.tol:
            verdict = "ok"
        else:
            verdict = "MISMATCH"
        bad += verdict != "ok"
        print(f"{r['tag']:44s} {r['rep']:>3s} {q:14.7e} {b:14.7e} {q - b:10.1e} {r['qa']:6s}  {verdict}")
        layout = f"{r['ranks']}x{r['threads']}" + (" THP off" if r.get("thp", "on") == "off" else "")
        out.append([r["deck"], r["kernels"], layout, 1, r["qa_pct"], r["qa"], a.source,
                    r.get("variant", ""), verdict])
    print(f"\n{len(rows) - bad} of {len(rows)} runs reproduce the baseline deviation (tol {a.tol:g} %)")
    if a.csv:
        import os
        new = not os.path.exists(a.csv) or os.path.getsize(a.csv) == 0
        with open(a.csv, "a", newline="") as f:
            w = csv.writer(f)
            if new:
                w.writerow(["deck", "kernels", "layout", "reps", "qa_pct", "clover_verdict", "source", "variant", "gate"])
            w.writerows(out)
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
