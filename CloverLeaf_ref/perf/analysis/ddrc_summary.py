#!/usr/bin/env python3
"""Summarise HiSilicon DDR-controller counters from `perf stat -x, -a`.

Input: the perf_stat.csv written by m1_perf/m2_stream/m3_numa, with events
hisi_sccl<N>_ddrc<M>/flux_rd/ and /flux_wr/ (one SCCL = one NUMA domain).

  python3 ddrc_summary.py perf_stat.csv [--unit 32] [--model-bytes 2.8e12]

Prints per-SCCL read/write counts, their share of the node's traffic (a
perfectly NUMA-balanced run gives 25 % each), the DRAM bytes and the average
bandwidth over perf's measurement time.

--unit  bytes per counter increment. 32 is the value consistent with STREAM
        (counted bytes + write-allocate) and with the analytic CloverLeaf model;
        check it on your own STREAM run: unit = expected bytes / total counts.
"""

import argparse
import csv
import re
import sys
from collections import defaultdict

EVENT = re.compile(r"hisi_sccl(\d+)_ddrc(\d+)/flux_(rd|wr)/")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("csv")
    ap.add_argument("--unit", type=float, default=32.0)
    ap.add_argument("--model-bytes", type=float,
                    help="analytic-model bytes of the same run, for a measured/model ratio")
    ap.add_argument("--csv-row", action="store_true",
                    help="print one line 'rd_GB,wr_GB,total_GB,busiest_over_mean,seconds' and nothing else "
                         "(used by perf/baseline/run_case.sh to fill results.csv)")
    args = ap.parse_args()

    counts = defaultdict(lambda: {"rd": 0.0, "wr": 0.0})
    seconds = 0.0
    with open(args.csv, newline="") as f:
        for row in csv.reader(f):
            if len(row) < 4 or row[0].startswith("#"):
                continue
            m = EVENT.search(row[2])
            if not m:
                continue
            try:
                counts[int(m.group(1))][m.group(3)] += float(row[0])
                seconds = max(seconds, float(row[3]) * 1e-9)   # runtime column, ns
            except ValueError:
                print(f"warning: no value for {row[2]} ({row[0]})", file=sys.stderr)
    if not counts:
        sys.exit("no hisi_sccl*_ddrc*/flux_* rows found")

    total = sum(c["rd"] + c["wr"] for c in counts.values())
    tot_rd = sum(c["rd"] for c in counts.values())
    tot_wr = sum(c["wr"] for c in counts.values())
    u = args.unit
    if args.csv_row:
        n = len(counts)
        busiest = max(c["rd"] + c["wr"] for c in counts.values()) / total * n
        print(f"{tot_rd * u * 1e-9:.3f},{tot_wr * u * 1e-9:.3f},{total * u * 1e-9:.3f},{busiest:.3f},{seconds:.3f}")
        return
    print(f"unit = {u:g} B/count, measured for {seconds:.2f} s")
    print(f"{'SCCL':>5s} {'read GB':>9s} {'write GB':>9s} {'share%':>7s} {'GB/s':>7s}")
    shares = []
    for sccl in sorted(counts):
        c = counts[sccl]
        t = c["rd"] + c["wr"]
        shares.append(t / total)
        print(f"{sccl:5d} {c['rd'] * u * 1e-9:9.1f} {c['wr'] * u * 1e-9:9.1f} "
              f"{100 * t / total:7.1f} {t * u * 1e-9 / seconds:7.1f}")
    print(f"{'total':>5s} {tot_rd * u * 1e-9:9.1f} {tot_wr * u * 1e-9:9.1f} {100:7.1f} "
          f"{total * u * 1e-9 / seconds:7.1f}")
    n = len(shares)
    print(f"read:write = {tot_rd / tot_wr:.2f}:1    busiest/mean controller = "
          f"{max(shares) * n:.2f}  (1.00 = balanced)")
    if max(shares) > 0:
        print(f"if the busiest controller saturated at 67 GB/s (STREAM per domain), the node "
              f"could not exceed {67 / max(shares):.0f} GB/s with this placement")
    if args.model_bytes:
        print(f"measured DRAM bytes / analytic model = {total * u / args.model_bytes:.2f}")


if __name__ == "__main__":
    main()
