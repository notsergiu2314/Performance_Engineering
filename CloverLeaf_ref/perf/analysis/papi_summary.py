#!/usr/bin/env python3
"""Summarise papi_prof_<pid>.csv files of one run (kernels/papi_prof.c).

Per kernel region:
  time      = max over threads of the time spent in the region (wall time;
              includes the closing OpenMP barrier)
  events    = summed over all threads (and over all MPI ranks)
  cyc_imbal = max / mean of per-thread PAPI_TOT_CYC. Only meaningful with
              OMP_WAIT_POLICY=passive: threads then sleep in the barrier
              (not counted in user mode) instead of spinning
plus derived metrics when the needed events were counted:
  IPC, GHz (cycles / thread time), L1/L2 miss ratio, instruction mix and
  backend/frontend stall share.

  python3 papi_summary.py <run dir> [--csv out.csv]
"""

import argparse
import csv
import sys
from collections import defaultdict
from pathlib import Path

DERIVED = [
    # name, numerator, denominator, scale
    ("IPC", "PAPI_TOT_INS", "PAPI_TOT_CYC", 1),
    ("L1_miss%", "PAPI_L1_DCM", "PAPI_L1_DCA", 100),
    ("L2_miss%", "PAPI_L2_DCM", "PAPI_L2_DCA", 100),
    ("vec_ins%", "PAPI_VEC_INS", "PAPI_TOT_INS", 100),
    ("fp_ins%", "PAPI_FP_INS", "PAPI_TOT_INS", 100),
    ("ld_ins%", "PAPI_LD_INS", "PAPI_TOT_INS", 100),
    ("be_stall%", "STALL_BACKEND", "PAPI_TOT_CYC", 100),
    ("fe_stall%", "STALL_FRONTEND", "PAPI_TOT_CYC", 100),
]


def load(run_dir):
    rows = []
    for f in sorted(Path(run_dir).glob("papi_prof_*.csv")):
        with open(f, newline="") as fh:
            for r in csv.DictReader(fh):
                r["_file"] = f.name
                rows.append(r)
    return rows


def summarise(rows):
    events = [c for c in rows[0] if c not in ("region", "thread", "calls", "time_s", "_file")]
    per_region = defaultdict(list)
    for r in rows:
        per_region[r["region"]].append(r)

    total_time = sum(max(float(r["time_s"]) for r in rs) for rs in per_region.values())
    out = []
    for region, rs in per_region.items():
        times = [float(r["time_s"]) for r in rs]
        rec = {
            "region": region,
            "threads": len(rs),
            "calls": int(rs[0]["calls"]),
            "time_s": max(times),
            "share%": 100 * max(times) / total_time if total_time else 0,
        }
        sums = {e: sum(float(r[e]) for r in rs) for e in events}
        rec.update(sums)
        if "PAPI_TOT_CYC" in sums and sums["PAPI_TOT_CYC"]:
            cyc = [float(r["PAPI_TOT_CYC"]) for r in rs]
            rec["GHz"] = sums["PAPI_TOT_CYC"] / sum(times) * 1e-9
            rec["cyc_imbal"] = max(cyc) / (sum(cyc) / len(cyc))
        for name, num, den, scale in DERIVED:
            if num in sums and den in sums and sums[den]:
                rec[name] = scale * sums[num] / sums[den]
        out.append(rec)
    out.sort(key=lambda r: -r["time_s"])
    return out, events


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("run_dir")
    ap.add_argument("--csv")
    args = ap.parse_args()

    rows = load(args.run_dir)
    if not rows:
        sys.exit(f"no papi_prof_*.csv in {args.run_dir}")
    recs, events = summarise(rows)

    derived = [d[0] for d in DERIVED if any(d[0] in r for r in recs)]
    extra = [c for c in ("GHz", "cyc_imbal") if any(c in r for r in recs)] + derived
    cols = ["region", "calls", "threads", "time_s", "share%"] + extra
    print(f"{cols[0]:14s}" + "".join(f"{c:>11s}" for c in cols[1:]))
    for r in recs:
        line = f"{r['region']:14s}"
        for c in cols[1:]:
            v = r.get(c, float("nan"))
            line += f"{v:11d}" if isinstance(v, int) else f"{v:11.3f}"
        print(line)
    if events:
        print("raw event totals (all threads):")
        for r in recs:
            print(f"  {r['region']:14s} " + "  ".join(f"{e}={r[e]:.4g}" for e in events))

    if args.csv:
        with open(args.csv, "w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=cols + events, extrasaction="ignore")
            w.writeheader()
            w.writerows(recs)


if __name__ == "__main__":
    main()
