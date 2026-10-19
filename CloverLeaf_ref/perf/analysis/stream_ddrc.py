#!/usr/bin/env python3
"""Hardware bytes of STREAM / membw runs from the DDR-controller counters.

Reads a jobs/m3_stream_ddrc.sbatch output directory:
  raw_stream_<variant>_rep<i>.txt   STREAM stdout (Copy/Scale/Add/Triad lines, best MB/s)
  stream_<variant>_rep<i>.ddrc.csv  perf stat -x, -a output of hisi_sccl*_ddrc*/flux_{rd,wr}
  raw_membw_<variant>_rep<i>.txt    membw stdout (key=value lines, GB/s counted the STREAM way)
  membw_<variant>_rep<i>.ddrc.csv   idem

  python3 stream_ddrc.py <dir> --n 100000000 --ntimes 20 [--unit 32]

For every repetition it prints the STREAM-counted triad bandwidth, the DDRC bytes and
the ratio of those bytes to two byte models of the whole process:
  no write-allocate:   init 3 arrays + NTIMES x 10 arrays + validation 3 arrays
  with write-allocate: every store also reads its line first: init 6, timed 14 per NTIMES
A ratio near 1.0 for the write-allocate model (and ~1.4 for the other) means the cores
do read-for-ownership on streaming stores, and the hardware memory ceiling is
4/3 x the STREAM-counted triad (3 arrays counted, 4 moved). Writes ceilings_rows.csv
with the rows for report/data/ceilings.csv.
"""
import argparse
import csv
import re
import statistics
import sys
from pathlib import Path

EVENT = re.compile(r"hisi_sccl(\d+)_ddrc(\d+)/flux_(rd|wr)/")


def ddrc_bytes(path, unit):
    """-> (total bytes, seconds, {sccl: bytes}) from a perf stat -x, csv."""
    per = {}
    seconds = 0.0
    with open(path, newline="") as f:
        for row in csv.reader(f):
            if len(row) < 4 or row[0].startswith("#"):
                continue
            m = EVENT.search(row[2])
            if not m:
                continue
            try:
                per[int(m.group(1))] = per.get(int(m.group(1)), 0.0) + float(row[0]) * unit
                seconds = max(seconds, float(row[3]) * 1e-9)
            except ValueError:
                pass
    return sum(per.values()), seconds, per


def stream_rates(path):
    """-> {'copy': GB/s, ...} from STREAM stdout (its MB/s is decimal 1e6 B/s)."""
    out = {}
    for line in open(path, errors="replace"):
        m = re.match(r"^(Copy|Scale|Add|Triad):\s+([0-9.]+)", line)
        if m:
            out[m.group(1).lower()] = float(m.group(2)) / 1000.0
    return out


def membw_rates(path):
    out = {}
    for line in open(path, errors="replace"):
        m = re.match(r"^(copy|scale|add|triad|read)_gbs=([0-9.]+)", line)
        if m:
            out[m.group(1)] = float(m.group(2))
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("dir")
    ap.add_argument("--n", type=float, required=True, help="doubles per array")
    ap.add_argument("--ntimes", type=int, required=True)
    ap.add_argument("--unit", type=float, default=32.0, help="bytes per DDRC count")
    ap.add_argument("--channels", type=int, default=16, help="DDR channels per node (bus-width bound)")
    a = ap.parse_args()
    d = Path(a.dir)
    n8 = a.n * 8
    # STREAM: init (3 stores), NTIMES x (copy 1r1w, scale 1r1w, add 2r1w, triad 2r1w), validation 3 reads
    model_nowa = (3 + 10 * a.ntimes + 3) * n8
    model_wa = (6 + 14 * a.ntimes + 3) * n8
    # membw: init 3 stores, NTIMES x (copy, scale, add, triad, read): 1r1w,1r1w,2r1w,2r1w,1r
    membw_nowa = (3 + 11 * a.ntimes) * n8
    membw_wa = (6 + 15 * a.ntimes) * n8

    rows = []
    print(f"{'run':24s} {'triad_cnt':>9s} {'ddrc_GB':>8s} {'secs':>6s} {'avg_hw':>7s} {'/noWA':>6s} {'/WA':>6s} {'busiest':>7s}")
    for variant in ("nothp", "default"):
        for i in range(1, 100):
            raw = d / f"raw_stream_{variant}_rep{i}.txt"
            ddrc = d / f"stream_{variant}_rep{i}.ddrc.csv"
            if not raw.exists():
                break
            rates = stream_rates(raw)
            if not rates or not ddrc.exists():
                continue
            tot, secs, per = ddrc_bytes(ddrc, a.unit)
            busiest = max(per.values()) / tot * len(per) if tot else float("nan")
            r = dict(kind="stream", variant=variant, rep=i, triad=rates.get("triad", float("nan")),
                     copy=rates.get("copy", float("nan")), ddrc=tot, secs=secs,
                     r_nowa=tot / model_nowa, r_wa=tot / model_wa, busiest=busiest)
            rows.append(r)
            print(f"stream_{variant}_rep{i:<13d} {r['triad']:9.1f} {tot/1e9:8.1f} {secs:6.1f} {tot/secs/1e9:7.1f} "
                  f"{r['r_nowa']:6.2f} {r['r_wa']:6.2f} {busiest:7.2f}")
    for i in range(1, 100):
        raw = d / f"raw_membw_nothp_rep{i}.txt"
        ddrc = d / f"membw_nothp_rep{i}.ddrc.csv"
        if not raw.exists():
            break
        rates = membw_rates(raw)
        if not rates or not ddrc.exists():
            continue
        tot, secs, per = ddrc_bytes(ddrc, a.unit)
        busiest = max(per.values()) / tot * len(per) if tot else float("nan")
        r = dict(kind="membw", variant="nothp", rep=i, triad=rates.get("triad", float("nan")),
                 copy=rates.get("copy", float("nan")), ddrc=tot, secs=secs,
                 r_nowa=tot / membw_nowa, r_wa=tot / membw_wa, busiest=busiest)
        rows.append(r)
        print(f"membw_nothp_rep{i:<13d} {r['triad']:9.1f} {tot/1e9:8.1f} {secs:6.1f} {tot/secs/1e9:7.1f} "
              f"{r['r_nowa']:6.2f} {r['r_wa']:6.2f} {busiest:7.2f}")
    if not rows:
        sys.exit("no complete repetitions found")
    print("triad_cnt = STREAM-counted triad GB/s (24 B/element); avg_hw = DDRC bytes / perf elapsed (whole process,\n"
          "incl. init and validation); /noWA, /WA = DDRC bytes over the two byte models of the whole process")

    nothp = [r for r in rows if r["kind"] == "stream" and r["variant"] == "nothp"]
    default = [r for r in rows if r["kind"] == "stream" and r["variant"] == "default"]
    pool = nothp or default
    best = max(pool, key=lambda r: r["triad"])
    wa_ratio = statistics.median(r["r_wa"] for r in pool)
    nowa_ratio = statistics.median(r["r_nowa"] for r in pool)
    wa = abs(wa_ratio - 1.0) < abs(nowa_ratio - 1.0)
    factor = 4.0 / 3.0 if wa else 1.0
    hw_triad = best["triad"] * factor
    mts_min = hw_triad * 1e9 / (a.channels * 8) / 1e6
    print()
    print(f"write-allocate: DDRC bytes / model = {wa_ratio:.2f} (with WA) vs {nowa_ratio:.2f} (without) "
          f"-> {'WITH write-allocate: stores cost a read too' if wa else 'NO write-allocate: plain STREAM counting holds'}")
    print(f"best STREAM-counted triad (nothp): {best['triad']:.1f} GB/s rep {best['rep']}; "
          f"hardware triad ceiling = x{factor:.3f} = {hw_triad:.1f} GB/s")
    if nothp and default:
        print(f"THP effect on STREAM triad: nothp median {statistics.median(r['triad'] for r in nothp):.1f} GB/s "
              f"(min {min(r['triad'] for r in nothp):.1f}), default median "
              f"{statistics.median(r['triad'] for r in default):.1f} GB/s (min {min(r['triad'] for r in default):.1f})")
    print(f"bus-width check: {hw_triad:.1f} GB/s over {a.channels} channels x 8 B needs DIMMs of at least "
          f"{mts_min:.0f} MT/s (DDR4-2666 = {a.channels*8*2666e6/1e9:.1f} GB/s, DDR4-2933 = "
          f"{a.channels*8*2933e6/1e9:.1f}, DDR4-3200 = {a.channels*8*3200e6/1e9:.1f}); see dimm.txt for the DMI answer")

    with open(d / "ceilings_rows.csv", "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["name", "value", "unit", "note"])
        w.writerow(["dram_node_counted_best", f"{best['triad']:.1f}", "GB/s",
                    f"STREAM triad 128 threads THP off best of {len(pool)} (STREAM-counted bytes), job {d.name}"])
        w.writerow(["dram_node_hw", f"{hw_triad:.1f}", "GB/s",
                    f"hardware bytes: counted triad x {factor:.3f} ({'with' if wa else 'without'} write-allocate, DDRC calibrated)"])
        w.writerow(["wa_ratio", f"{wa_ratio:.3f}", "ratio",
                    f"DDRC bytes / write-allocate byte model of the STREAM process (no-WA model: {nowa_ratio:.3f})"])
        w.writerow(["dimm_mts_min", f"{mts_min:.0f}", "MT/s",
                    f"lower bound from {hw_triad:.1f} GB/s over {a.channels} channels; DMI reading in dimm.txt"])
    print(f"ceilings rows written to {d / 'ceilings_rows.csv'}")


if __name__ == "__main__":
    main()
