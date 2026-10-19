#!/usr/bin/env python3
"""Compare build variants (perf/variants.conf) measured with the matrix harness, as run by
jobs/m3_opt.sbatch, and write the rows the report reads.

  python3 -I variants.py --run perf/results/m3_opt_<id> [--qa correctness_rows.csv]
          [--baseline-archive perf/archive/m3/m3_baseline_34797/results.csv]
          [--stream-hw-gbs 266.5] [--plan report/data/plan.csv] [--out DIR]
  python3 -I variants.py --layouts opt=DIR [--layouts base=DIR] [--ladder flags=DIR ...]

--run DIR discovers DIR/layouts/<variant>/results.csv (layout sweep, matrix.opt) and
DIR/ladder/<variant>/results.csv (64x2 per commit, matrix.ladder). Output, in --out
(default: the run directory), each file with a '#' provenance header:
  optimised.csv  one row per (variant, layout, thp) of the layout runs. Columns (a superset of
                 what report/make_assets.py reads): layout,ranks,threads,thp,variant,n,
                 median_s,min_s,max_s,dram_TB,hw_GBs,busiest_over_mean,qa_ok,source
  ladder.csv     one row per ladder variant: variant,description,n,median_s,min_s,max_s,
                 dram_TB,hw_GBs,time_vs_base_pct,bytes_vs_base_pct,source
  compare.md     archive baseline vs the same-job base rerun vs every variant per layout
                 (speed-up, bytes saved, drift of the rerun), the ladder, the plan prediction
Aggregation as baseline/summarize.py: median/min/max wall over the repetitions, median DRAM
bytes of the DDR-controller counters (hardware bytes), hw_GBs = median bytes / median wall.
qa_ok: the gate verdict of that variant in the --qa rows (qa_check.py --csv: ok|MISMATCH,
every row of the variant must be ok); without --qa, CloverLeaf's own PASSED/FAILED flag of
the timed runs, prefixed 'clover:' because it is not the project's gate.
"""
import argparse
import csv
import datetime
import re
import statistics
import sys
from collections import defaultdict
from pathlib import Path


def fl(x):
    try:
        return float(x)
    except (TypeError, ValueError):
        return float("nan")


def isnum(x):
    return x == x


def fmt(x, nd=3):
    return "" if not isnum(x) else f"{x:.{nd}f}"


def read_rows(path):
    with open(path, newline="") as f:
        return [r for r in csv.DictReader(l for l in f if not l.startswith("#"))]


def environment(d):
    """binary md5, job, node, variant, build description from baseline.sh's environment.txt."""
    info = {"job": "", "node": "", "md5": "", "description": "", "variant": ""}
    p = Path(d) / "environment.txt"
    if not p.exists():
        return info
    for line in p.read_text().splitlines():
        if line.startswith("slurm:"):
            m = re.search(r"job (\S+) on (\S+)", line)
            if m:
                info["job"], info["node"] = m.group(1), m.group(2)
        elif line.startswith("host:") and not info["node"]:
            info["node"] = line.split()[1]
        elif line.startswith("binary:"):
            m = re.search(r"\(([0-9a-f]+)\)", line)
            info["md5"] = m.group(1) if m else ""
        elif line.startswith("variant:"):
            info["variant"] = line.split(None, 1)[1].strip()
        elif line.strip().startswith("build: description:"):
            info["description"] = line.split("description:", 1)[1].strip()
    return info


def aggregate(rows):
    """{(ranks, threads, thp, kernels): case dict} from results.csv rows."""
    cases = defaultdict(list)
    for r in rows:
        cases[(r["ranks"], r["threads"], r.get("thp", "on"), r["kernels"])].append(r)
    out = {}
    for key, rs in cases.items():
        walls = [fl(r["wall"]) for r in rs if isnum(fl(r["wall"]))]
        if not walls:
            continue
        drams = [fl(r.get("dram_GB")) for r in rs if isnum(fl(r.get("dram_GB")))]
        bus = [fl(r.get("busiest_over_mean")) for r in rs if isnum(fl(r.get("busiest_over_mean")))]
        med = statistics.median(walls)
        dram_tb = statistics.median(drams) / 1000 if drams else float("nan")
        out[key] = {
            "ranks": key[0], "threads": key[1], "thp": key[2], "kernels": key[3],
            "layout": f"{key[0]}x{key[1]}", "n": len(walls),
            "median_s": med, "min_s": min(walls), "max_s": max(walls),
            "dram_TB": dram_tb, "hw_GBs": dram_tb * 1000 / med if drams else float("nan"),
            "busiest_over_mean": statistics.median(bus) if bus else float("nan"),
            "clover": "PASSED" if all(r["qa"] == "PASSED" for r in rs) else "FAILED",
            "variant": rs[0].get("variant", ""),
        }
    return out


def load_variant_dirs(spec_list, run_dir, sub):
    """[(variant, dir)] from --layouts/--ladder NAME=DIR specs and/or run_dir/sub/*/."""
    found = []
    for spec in spec_list or []:
        name, _, d = spec.partition("=")
        if not d:
            sys.exit(f"expected NAME=DIR, got '{spec}'")
        found.append((name, Path(d)))
    if run_dir:
        for d in sorted((Path(run_dir) / sub).glob("*/")):
            if (d / "results.csv").exists():
                found.append((d.name, d))
    return found


def ordered(names, conf):
    """Variants in perf/variants.conf order (unknown names last, alphabetically)."""
    order = []
    if conf and Path(conf).exists():
        for line in Path(conf).read_text().splitlines():
            parts = line.split()
            if parts and not parts[0].startswith("#"):
                order.append(parts[0])
    rank = {n: i for i, n in enumerate(order)}
    return sorted(set(names), key=lambda n: (rank.get(n, len(order)), n))


def pct(new, ref):
    return (new / ref - 1) * 100 if isnum(new) and isnum(ref) and ref else float("nan")


def spct(x):
    """signed percentage for the markdown tables, '--' when not measured (e.g. no DDRC counters)."""
    return f"{x:+.1f} %" if isnum(x) else "--"


def main():
    here = Path(__file__).resolve().parent
    perf_root = here.parent
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--run", help="m3_opt output directory (layouts/<v>/, ladder/<v>/)")
    ap.add_argument("--layouts", action="append", metavar="NAME=DIR", help="layout-sweep results of one variant")
    ap.add_argument("--ladder", action="append", metavar="NAME=DIR", help="64x2 results of one ladder variant")
    ap.add_argument("--qa", help="correctness_rows.csv from m3_correctness (qa_check.py --csv)")
    ap.add_argument("--baseline-archive", default=str(perf_root / "archive/m3/m3_baseline_34797/results.csv"),
                    help="results.csv of the archived baseline job (C rows are the reference)")
    ap.add_argument("--stream-hw-gbs", type=float, default=None, help="hardware STREAM ceiling for %%-of-roof")
    ap.add_argument("--plan", default=str(perf_root.parent.parent / "report/data/plan.csv"),
                    help="plan.csv with the byte-model prediction (row 'all byte changes together')")
    ap.add_argument("--conf", default=str(perf_root / "variants.conf"), help="variant order")
    ap.add_argument("--ref", default="base", help="reference variant for speed-ups (default base)")
    ap.add_argument("--opt", default="opt", help="the optimised variant for the archive speed-ups and the plan comparison (default opt)")
    ap.add_argument("--out", help="output directory (default: --run or the first layouts dir)")
    a = ap.parse_args()

    layouts = load_variant_dirs(a.layouts, a.run, "layouts")
    ladder = load_variant_dirs(a.ladder, a.run, "ladder")
    if not layouts and not ladder:
        sys.exit("nothing to compare: give --run DIR or --layouts/--ladder NAME=DIR")
    out = Path(a.out or a.run or (layouts[0][1] if layouts else ladder[0][1]))
    out.mkdir(parents=True, exist_ok=True)

    # per variant: aggregated cases and provenance
    lay = {v: (aggregate(read_rows(d / "results.csv")), environment(d)) for v, d in layouts}
    lad = {v: (aggregate(read_rows(d / "results.csv")), environment(d)) for v, d in ladder}
    archive = {}
    if a.baseline_archive and Path(a.baseline_archive).exists():
        archive = {k: c for k, c in aggregate(read_rows(a.baseline_archive)).items() if k[3] == "c"}
    archive_name = Path(a.baseline_archive).parent.name if archive else "none"

    # correctness gate per variant
    gate = {}
    if a.qa:
        for r in read_rows(a.qa):
            v = r.get("variant", "")
            gate[v] = "ok" if gate.get(v, "ok") == "ok" and r["gate"] == "ok" else "MISMATCH"

    def source(info, v):
        return f"job {info['job']} (m3_opt, {v})" if info["job"] else f"{info['node']} ({v})"

    def qa_ok(v, case):
        if a.qa:
            return gate.get(v, "n/a")
        return "clover:" + case["clover"]

    stamp = datetime.datetime.now().isoformat(timespec="seconds")
    prov = [f"# generated {stamp} by perf/analysis/variants.py" + (f" from {a.run}" if a.run else ""),
            f"# baseline archive: {archive_name}; qa_ok: " +
            ("gate verdict of " + a.qa if a.qa else "CloverLeaf's own PASSED/FAILED flag (not the project gate; pass --qa)")]
    for v in ordered(list(lay) + list(lad), a.conf):
        info = (lay.get(v) or lad.get(v))[1]
        prov.append(f"# variant {v}: binary md5 {info['md5'] or '?'}, node {info['node'] or '?'}, job {info['job'] or '?'}"
                    + (f": {info['description']}" if info["description"] else ""))

    # ---- optimised.csv
    if lay:
        cols = ["layout", "ranks", "threads", "thp", "variant", "n", "median_s", "min_s", "max_s",
                "dram_TB", "hw_GBs", "busiest_over_mean", "qa_ok", "source"]
        with open(out / "optimised.csv", "w", newline="") as f:
            f.write("\n".join(prov) + "\n")
            w = csv.writer(f)
            w.writerow(cols)
            for v in ordered(list(lay), a.conf):
                cases, info = lay[v]
                for key in sorted(cases, key=lambda k: (int(k[0]), k[2])):
                    c = cases[key]
                    if c["kernels"] != "c":
                        continue
                    w.writerow([c["layout"], c["ranks"], c["threads"], c["thp"], v, c["n"],
                                fmt(c["median_s"]), fmt(c["min_s"]), fmt(c["max_s"]), fmt(c["dram_TB"]),
                                fmt(c["hw_GBs"], 1), fmt(c["busiest_over_mean"]), qa_ok(v, c), source(info, v)])

    # ---- ladder.csv
    ref_key = None
    if lad:
        cols = ["variant", "description", "n", "median_s", "min_s", "max_s", "dram_TB", "hw_GBs",
                "time_vs_base_pct", "bytes_vs_base_pct", "source"]
        ref = lad.get(a.ref)
        ref_case = None
        if ref:
            ref_cases = [c for c in ref[0].values() if c["kernels"] == "c"]
            ref_case = ref_cases[0] if ref_cases else None
        with open(out / "ladder.csv", "w", newline="") as f:
            f.write("\n".join(prov) + "\n")
            w = csv.writer(f)
            w.writerow(cols)
            for v in ordered(list(lad), a.conf):
                cases, info = lad[v]
                for c in cases.values():
                    if c["kernels"] != "c":
                        continue
                    tv = pct(c["median_s"], ref_case["median_s"]) if ref_case else float("nan")
                    bv = pct(c["dram_TB"], ref_case["dram_TB"]) if ref_case else float("nan")
                    w.writerow([v, info["description"], c["n"], fmt(c["median_s"]), fmt(c["min_s"]), fmt(c["max_s"]),
                                fmt(c["dram_TB"]), fmt(c["hw_GBs"], 1), fmt(tv, 1), fmt(bv, 1),
                                source(info, v).replace("m3_opt", "m3_opt ladder")])

    # ---- compare.md
    md = [f"# Variants compared ({stamp})", ""]
    md += [p.lstrip("# ") for p in prov[1:]] + [""]

    def wall_tb(c):
        return f"{c['median_s']:.2f} s ({c['min_s']:.2f}-{c['max_s']:.2f})" + \
               (f", {c['dram_TB']:.3f} TB, {c['hw_GBs']:.0f} GB/s" if isnum(c["dram_TB"]) else "")

    if lay:
        vs = ordered(list(lay), a.conf)
        ref_v = a.ref if a.ref in lay else vs[0]
        md += [f"## Layouts (C kernels; reference variant: {ref_v}; archive: {archive_name})", ""]
        hdr = ["layout", "thp", f"archive {archive_name}"] + vs
        for v in vs:
            if v != ref_v:
                hdr += [f"{v}/{ref_v} speed-up", f"{v} bytes vs {ref_v}"]
        if ref_v in lay and archive:
            hdr += [f"{ref_v} rerun drift vs archive"]
        md += ["| " + " | ".join(hdr) + " |", "|" + "---|" * len(hdr)]
        keys = sorted({k[:3] for cs, _ in lay.values() for k in cs if k[3] == "c"}, key=lambda k: (int(k[0]), k[2]))
        for rk, th, thp in keys:
            key = (rk, th, thp, "c")
            cells = [f"{rk}x{th}", thp, wall_tb(archive[key]) if key in archive else "--"]
            refc = lay[ref_v][0].get(key) if ref_v in lay else None
            for v in vs:
                c = lay[v][0].get(key)
                cells.append(wall_tb(c) if c else "--")
            for v in vs:
                if v == ref_v:
                    continue
                c = lay[v][0].get(key)
                if c and refc:
                    cells += [f"{refc['median_s'] / c['median_s']:.3f}x", spct(pct(c['dram_TB'], refc['dram_TB']))]
                else:
                    cells += ["--", "--"]
            if ref_v in lay and archive:
                ac = archive.get(key)
                cells.append(f"{spct(pct(refc['median_s'], ac['median_s']))} time, {spct(pct(refc['dram_TB'], ac['dram_TB']))} bytes"
                             if refc and ac else "--")
            md.append("| " + " | ".join(cells) + " |")
        md.append("")
        if archive and a.opt in lay:
            md += [f"Speed-up of {a.opt} against the archived baseline (the report's reference):", ""]
            for rk, th, thp in keys:
                key = (rk, th, thp, "c")
                c, ac = lay[a.opt][0].get(key), archive.get(key)
                if c and ac:
                    md.append(f"- {rk}x{th} thp={thp}: {ac['median_s'] / c['median_s']:.3f}x, bytes {spct(pct(c['dram_TB'], ac['dram_TB']))}")
            md.append("")

    if lad:
        ref = lad.get(a.ref)
        rc = next((c for c in ref[0].values() if c["kernels"] == "c"), None) if ref else None
        lad_layout = rc["layout"] if rc else next(c["layout"] for cs, _ in lad.values() for c in cs.values())
        md += [f"## Ladder at {lad_layout} (reference: {a.ref})", "",
               "| variant | description | wall (s) | DRAM (TB) | GB/s | time vs ref | bytes vs ref |", "|---|---|---|---|---|---|---|"]
        for v in ordered(list(lad), a.conf):
            cases, info = lad[v]
            for c in cases.values():
                if c["kernels"] != "c":
                    continue
                md.append(f"| {v} | {info['description']} | {c['median_s']:.3f} ({c['min_s']:.3f}-{c['max_s']:.3f}) | "
                          f"{fmt(c['dram_TB'])} | {fmt(c['hw_GBs'], 0)} | "
                          f"{spct(pct(c['median_s'], rc['median_s']))} | {spct(pct(c['dram_TB'], rc['dram_TB']))} |"
                          if rc else f"| {v} | {info['description']} | {c['median_s']:.3f} | {fmt(c['dram_TB'])} | {fmt(c['hw_GBs'], 0)} | -- | -- |")
        md.append("")

    # plan prediction next to the measured opt 64x2 row
    plan = None
    if a.plan and Path(a.plan).exists():
        for r in read_rows(a.plan):
            if r["change"].startswith("all byte changes"):
                plan = r
    if plan:
        md += ["## Byte-model prediction (report/data/plan.csv, all byte changes together)", ""]
        base64 = None
        for src in (lad, lay):
            if a.ref in src:
                base64 = src[a.ref][0].get(("64", "2", "on", "c"))
                if base64:
                    break
        if not base64 and archive:
            base64 = archive.get(("64", "2", "on", "c"))
        opt64 = None
        for src in (lad, lay):
            if a.opt in src:
                opt64 = src[a.opt][0].get(("64", "2", "on", "c"))
                if opt64:
                    break
        md.append(f"- predicted: {plan['pred_TB']} TB ({plan['cumulative_delta_pct']} % bytes), floor {plan['floor_s']} s")
        if opt64 and base64:
            md.append(f"- measured {a.opt} at 64x2: {fmt(opt64['dram_TB']) or '--'} TB ({spct(pct(opt64['dram_TB'], base64['dram_TB']))} vs {a.ref}), "
                      f"{opt64['median_s']:.2f} s ({spct(pct(opt64['median_s'], base64['median_s']))})")
        if a.stream_hw_gbs and opt64 and isnum(opt64["dram_TB"]):
            md.append(f"- {a.opt} at 64x2 runs at {100 * opt64['hw_GBs'] / a.stream_hw_gbs:.0f} % of the {a.stream_hw_gbs:.0f} GB/s hardware ceiling; "
                      f"memory floor for its bytes {opt64['dram_TB'] * 1000 / a.stream_hw_gbs:.2f} s")
        md.append("")

    (out / "compare.md").write_text("\n".join(md) + "\n")
    print("\n".join(md))
    print(f"written: {out / 'compare.md'}" + (f", {out / 'optimised.csv'}" if lay else "") + (f", {out / 'ladder.csv'}" if lad else ""))


if __name__ == "__main__":
    main()
