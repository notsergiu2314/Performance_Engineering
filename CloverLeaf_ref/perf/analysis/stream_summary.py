#!/usr/bin/env python3
"""Summarise perf/jobs/m2_stream.sbatch output (stream.csv).

For each configuration and thread count: median, min and max over the
repetitions (GB/s, as STREAM counts bytes, i.e. without write-allocate) and
the triad value corrected for write-allocate (x 4/3), to show which one the
DDR controller counters agree with.

  python3 stream_summary.py stream.csv
"""

import csv
import statistics
import sys
from collections import defaultdict

PEAK_SOCKET = 170.6  # GB/s, 8 x DDR4-2666 channels (lab 2 hint)


def main():
    rows = defaultdict(list)
    with open(sys.argv[1], newline="") as f:
        for r in csv.DictReader(f):
            if r["triad_MBs"]:
                rows[(r["config"], int(r["threads"]))].append(r)

    print(f"{'config':>8s} {'thr':>4s} {'reps':>4s} | {'copy':>7s} {'scale':>7s} {'add':>7s} "
          f"{'triad':>7s} {'min':>7s} {'max':>7s} | {'triad+WA':>8s}   (GB/s, median)")
    best = 0.0
    for (cfg, t), rs in sorted(rows.items(), key=lambda kv: (kv[0][0] != "node", kv[0])):
        med = {k: statistics.median(float(r[f"{k}_MBs"]) for r in rs) / 1000
               for k in ("copy", "scale", "add", "triad")}
        triads = [float(r["triad_MBs"]) / 1000 for r in rs]
        best = max(best, med["triad"])
        print(f"{cfg:>8s} {t:4d} {len(rs):4d} | {med['copy']:7.1f} {med['scale']:7.1f} "
              f"{med['add']:7.1f} {med['triad']:7.1f} {min(triads):7.1f} {max(triads):7.1f} | "
              f"{med['triad'] * 4 / 3:8.1f}")
    print(f"\nhighest median triad: {best:.1f} GB/s = {100 * best / (2 * PEAK_SOCKET):.0f}% "
          f"of the node's theoretical {2 * PEAK_SOCKET:.1f} GB/s "
          f"(use it as the roofline memory ceiling: roofline.py --bw {best:.0f})")


if __name__ == "__main__":
    main()
