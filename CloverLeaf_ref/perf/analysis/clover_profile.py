#!/usr/bin/env python3
"""Collect CloverLeaf's internal profiler output (profiler_on) from runs.

Walks a results directory for run directories (meta.txt + clover.out, as
written by perf/jobs/common.sh) and prints, per deck and configuration, the
median over repetitions of each profiler category plus the spread.

  python3 clover_profile.py <results dir> [--csv out.csv]

The CSV (one row per run and category) is the input of roofline.py.
"""

import argparse
import csv
import re
import statistics
import sys
from pathlib import Path

ROW = re.compile(r"^\s*([A-Za-z][A-Za-z ]+?)\s*:\s+([-0-9.]+)\s+([-0-9.]+)\s*$")
STEP = re.compile(r"^\s*Step\s+(\d+)")
CELLS = re.compile(r"^\s*([xy])_cells\s*=\s*(\d+)", re.M)


def read_meta(path):
    meta = {}
    for line in path.read_text().splitlines():
        if "=" in line:
            k, v = line.split("=", 1)
            meta[k.strip()] = v.strip()
    return meta


def parse_run(run_dir):
    """Profiler table, step count, cell count and QA result of one run."""
    out = (run_dir / "clover.out").read_text(errors="replace")
    lines = out.splitlines()
    try:
        start = max(i for i, l in enumerate(lines) if l.strip().startswith("Profiler Output"))
    except ValueError:
        return None  # crashed or profiler_on missing
    prof = {}
    for line in lines[start + 1:]:
        m = ROW.match(line)
        if m:
            prof[m.group(1).strip()] = float(m.group(2))
    wall = [float(l.split()[-1]) for l in lines if l.strip().startswith("Wall clock")]
    steps = max([int(m.group(1)) for m in map(STEP.match, lines) if m] or [0])
    deck = (run_dir / "clover.in").read_text()
    dims = {k: int(v) for k, v in CELLS.findall(deck)}
    return {
        "profile": prof,
        "wall": wall[-1] if wall else float("nan"),
        "steps": steps,
        "cells": dims.get("x", 0) * dims.get("y", 0),
        "passed": "considered PASSED" in out,
        "qa_reported": "Test problem" in out,
    }


def collect(root):
    runs = []
    for meta_file in sorted(Path(root).rglob("meta.txt")):
        d = meta_file.parent
        if not (d / "clover.out").exists():
            continue
        r = parse_run(d)
        if r is None:
            print(f"warning: no profiler table in {d}", file=sys.stderr)
            continue
        meta = read_meta(meta_file)
        r.update(meta=meta, dir=str(d),
                 config=f"{meta.get('ranks', '1')}x{meta.get('threads', '?')}")
        runs.append(r)
    return runs


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("results")
    ap.add_argument("--csv", help="write per-run, per-category rows here")
    args = ap.parse_args()

    runs = collect(args.results)
    if not runs:
        sys.exit(f"no runs found under {args.results}")

    if args.csv:
        with open(args.csv, "w", newline="") as f:
            w = csv.writer(f)
            w.writerow(["deck", "config", "ranks", "threads", "dir", "cells", "steps",
                        "wall_s", "passed", "category", "time_s"])
            for r in runs:
                m = r["meta"]
                for cat, t in r["profile"].items():
                    w.writerow([m.get("deck"), r["config"], m.get("ranks"), m.get("threads"),
                                r["dir"], r["cells"], r["steps"], r["wall"], r["passed"], cat, t])

    groups = {}
    for r in runs:
        groups.setdefault((r["meta"].get("deck"), r["config"]), []).append(r)

    def sort_key(key):
        deck, cfg = key
        ranks, threads = cfg.split("x")
        return (deck, int(ranks) * int(threads), int(ranks))

    for deck in sorted({k[0] for k in groups}):
        keys = sorted((k for k in groups if k[0] == deck), key=sort_key)
        base = statistics.median(r["wall"] for r in groups[keys[0]])
        print(f"\n=== {deck}: wall clock (median over reps), speed-up vs {keys[0][1]}")
        print(f"{'config':>7s} {'reps':>4s} {'wall_s':>9s} {'min':>9s} {'max':>9s} "
              f"{'speedup':>8s} {'QA':>5s}")
        for key in keys:
            walls = [r["wall"] for r in groups[key]]
            med = statistics.median(walls)
            qa = all(r["passed"] for r in groups[key]) if groups[key][0]["qa_reported"] else None
            print(f"{key[1]:>7s} {len(walls):4d} {med:9.3f} {min(walls):9.3f} {max(walls):9.3f} "
                  f"{base / med:8.2f} {'ok' if qa else ('FAIL' if qa is False else '-'):>5s}")

        print(f"\n=== {deck}: share of wall clock per profiler category (median, %)")
        cats = [c for c in groups[keys[0]][0]["profile"] if c not in ("Total",)]
        print(f"{'category':22s}" + "".join(f"{k[1]:>8s}" for k in keys))
        for cat in cats:
            row = f"{cat:22s}"
            for key in keys:
                vals = [100 * r["profile"].get(cat, 0) / r["wall"] for r in groups[key]]
                row += f"{statistics.median(vals):8.1f}"
            print(row)


if __name__ == "__main__":
    main()
