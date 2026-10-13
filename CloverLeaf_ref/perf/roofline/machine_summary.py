#!/usr/bin/env python3
"""Reduce machine_raw.csv to machine.csv: best of the repetitions per (quantity, threads,
scope), plus theoretical rows from a machine.<profile>.env file.
usage: machine_summary.py OUT_DIR PROFILE_ENV
Stdlib only."""
import csv
import sys
from collections import defaultdict
from pathlib import Path

out = Path(sys.argv[1])
env = {}
for line in Path(sys.argv[2]).read_text().splitlines():
    line = line.split("#", 1)[0].strip()
    if "=" in line:
        k, v = line.split("=", 1)
        env[k.strip()] = v.strip()

best = {}
n = defaultdict(int)
spread = defaultdict(list)
with open(out / "machine_raw.csv") as f:
    for r in csv.DictReader(f):
        key = (r["quantity"], int(r["threads"]), r["scope"])
        v = float(r["value"])
        spread[key].append(v)
        if key not in best or v > best[key][0]:
            best[key] = (v, r["unit"])

rows = []
for (q, t, scope), (v, unit) in sorted(best.items(), key=lambda kv: (kv[0][0], kv[0][1])):
    vals = spread[(q, t, scope)]
    note = f"best of {len(vals)}, spread {(max(vals)-min(vals))/max(vals)*100:.1f}%"
    rows.append([q, t, scope, f"{v:.3f}", unit, "measured", note])

ghz = float(env.get("GHZ", 0)); fpc = float(env.get("FLOP_PER_CYCLE", 0))
cps = int(env.get("CORES_PER_SOCKET", 0)); sockets = int(env.get("SOCKETS", 1))
nps = int(env.get("NUMA_PER_SOCKET", 1))
if ghz and fpc and cps:
    core = ghz * fpc
    for scope, cores in [("core", 1), ("numa", cps // nps), ("socket", cps), ("node", cps * sockets)]:
        rows.append(["peak_flops", cores, scope, f"{core*cores:.1f}", "GFLOP/s", "theoretical",
                     f"{cores} x {ghz} GHz x {fpc:g} FLOP/cycle"])
ch = int(env.get("MEM_CHANNELS_PER_SOCKET", 0)); mts = float(env.get("MEM_MTS", 0))
bus = float(env.get("MEM_BUS_BYTES", 8))
if ch and mts:
    sock = ch * mts * 1e6 * bus / 1e9
    for scope, cores, f in [("numa", cps // nps, 1 / nps), ("socket", cps, 1), ("node", cps * sockets, sockets)]:
        rows.append(["dram_bw", cores, scope, f"{sock*f:.1f}", "GB/s", "theoretical",
                     f"{ch*f:g} ch x {mts:g} MT/s x {bus:g} B"])
if env.get("STREAM_SITE_TRIAD_GBS"):
    rows.append(["stream_triad", cps * sockets, "node", env["STREAM_SITE_TRIAD_GBS"], "GB/s", "site",
                 "value quoted by the site"])

with open(out / "machine.csv", "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["quantity", "threads", "scope", "value", "unit", "source", "note"])
    w.writerows(rows)

hdr = ["quantity", "threads", "scope", "value", "unit", "source", "note"]
width = [max(len(str(c)) for c in col) for col in zip(hdr, *rows)]
for r in [hdr] + rows:
    print("  ".join(str(c).ljust(n) for c, n in zip(r, width)))
