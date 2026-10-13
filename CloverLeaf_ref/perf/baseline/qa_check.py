#!/usr/bin/env python3
"""Correctness gate: compare the kinetic-energy deviation of every run in a results.csv
with the recorded baseline deviation of the same deck and kernel set.

  python3 qa_check.py <results.csv> <correctness_baseline.csv> [--tol 1e-6]

baseline csv columns: deck,kernels,qa_pct[,source]  ('#' lines ignored)
Exit status 0 when every run matches (|qa_pct - baseline| <= tol, in %), 1 otherwise.
A run with no deviation line (crash, no clover.out) fails. The built-in PASSED/FAILED
flag of CloverLeaf (0.001 % threshold) is printed but not used: clover_bm.in fails it on
this system for both kernel sets with the unmodified code, so the gate is reproduction
of the baseline deviation, not the absolute threshold.
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
    a = ap.parse_args()

    base = {}
    with open(a.baseline, newline="") as f:
        for r in csv.DictReader(line for line in f if not line.startswith("#")):
            base[(r["deck"], r["kernels"])] = fl(r["qa_pct"])
    rows = list(csv.DictReader(open(a.results, newline="")))
    if not rows:
        sys.exit("no runs in " + a.results)

    bad = 0
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
    print(f"\n{len(rows) - bad} of {len(rows)} runs reproduce the baseline deviation (tol {a.tol:g} %)")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
