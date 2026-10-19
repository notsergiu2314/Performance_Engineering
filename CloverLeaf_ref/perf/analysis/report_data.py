#!/usr/bin/env python3
"""Copy the results of the optimised-kernel jobs into report/data/ (no hand editing).

  python3 -I report_data.py --data ../../report/data [--optimised optimised.csv] [--ladder ladder.csv]
          [--correctness correctness_rows.csv] [--papi perf/results/m3_papi_opt_<id> --variant opt]

--optimised / --ladder   data/optimised.csv, data/ladder.csv: copied verbatim when absent (they carry
                         their '#' provenance header); otherwise the rows of variants not yet present
                         are appended (key: variant, layout, thp), existing rows and the first job's
                         base rerun are kept, and the new file's provenance lines are added
--correctness            rows of qa_check.py --csv appended to data/correctness.csv; the file
                         gets the columns variant,gate (existing rows: base, ok); rows already
                         present are not duplicated
--papi DIR --variant V   data/kernels_papi.csv gets/updates the columns time_64x2_V, ipc_64x2_V,
                         be_stall_64x2_V from DIR/ipc/<64x2 tag>.papi.csv and DIR/stall/<tag>.papi.csv
                         (papi_summary.py --csv, written by jobs/m3_papi.sbatch)
"""
import argparse
import csv
import shutil
import sys
from pathlib import Path


def split(path):
    """-> (comment lines, header, rows) of a csv with '#' comment lines on top."""
    comments, body = [], []
    for line in Path(path).read_text().splitlines():
        (comments if line.startswith("#") else body).append(line)
    rows = list(csv.reader(body))
    return comments, rows[0], rows[1:]


def write(path, comments, header, rows):
    with open(path, "w", newline="") as f:
        for c in comments:
            f.write(c + "\n")
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(rows)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--data", required=True, help="report/data directory")
    ap.add_argument("--optimised")
    ap.add_argument("--ladder")
    ap.add_argument("--correctness")
    ap.add_argument("--papi", help="m3_papi_<variant>_<id> results directory")
    ap.add_argument("--variant", default="opt")
    a = ap.parse_args()
    data = Path(a.data)
    data.is_dir() or sys.exit(f"not a directory: {data}")

    for src, name in ((a.optimised, "optimised.csv"), (a.ladder, "ladder.csv")):
        if not src:
            continue
        if not (data / name).exists():
            shutil.copyfile(src, data / name)
            print(f"{name}: copied from {src}")
            continue
        comments, header, rows = split(data / name)
        ncomments, nh, new = split(src)
        keycols = [c for c in ("variant", "layout", "thp") if c in header]
        key = lambda r, h: tuple(r[h.index(c)] for c in keycols)
        have = {key(r, header) for r in rows}
        idx = [nh.index(c) for c in header]
        added = [[r[i] for i in idx] for r in new if key(r, nh) not in have]
        rows += added
        comments += [c for c in ncomments if c not in comments]
        comments.append(f"# {len(added)} rows appended from {src} (variants not present before; earlier rows kept)")
        write(data / name, comments, header, rows)
        print(f"{name}: {len(added)} rows appended from {src} ({[r[header.index('variant')] for r in added][:1]}...)")

    if a.correctness:
        comments, header, rows = split(data / "correctness.csv")
        for col, default in (("variant", "base"), ("gate", "ok")):
            if col not in header:
                header.append(col)
                rows = [r + [default] for r in rows]
        _, nh, new = split(a.correctness)
        idx = [nh.index(c) for c in header]
        added = 0
        for r in new:
            row = [r[i] for i in idx]
            if row not in rows:
                rows.append(row)
                added += 1
        comments.append(f"# {added} rows appended from {a.correctness} (variant/gate columns: qa_check.py --csv)")
        write(data / "correctness.csv", comments, header, rows)
        print(f"correctness.csv: {added} rows appended")

    if a.papi:
        papi = Path(a.papi)
        v = a.variant
        cols = {}
        for subset, keys in (("ipc", {"time_s": f"time_64x2_{v}", "IPC": f"ipc_64x2_{v}"}),
                             ("stall", {"be_stall%": f"be_stall_64x2_{v}"})):
            files = [f for f in (papi / subset).glob("*_r64_t2.papi.csv")]
            if not files:
                print(f"warning: no {subset}/*_r64_t2.papi.csv under {papi}; columns {list(keys.values())} skipped")
                continue
            for r in csv.DictReader(open(files[0], newline="")):
                for src, dst in keys.items():
                    if src in r:
                        cols.setdefault(dst, {})[r["region"]] = f"{float(r[src]):.3f}"
        comments, header, rows = split(data / "kernels_papi.csv")
        kcol = header.index("kernel")
        for dst, by_region in cols.items():
            if dst not in header:
                header.append(dst)
                rows = [r + [""] for r in rows]
            j = header.index(dst)
            known = set()
            for r in rows:
                known.add(r[kcol])
                r[j] = by_region.get(r[kcol], "")
            extra = set(by_region) - known
            if extra:
                print(f"note: regions {sorted(extra)} of {papi.name} are not rows of kernels_papi.csv (not added)")
        comments.append(f"# {', '.join(cols)}: {papi.name} (perf/jobs/m3_papi.sbatch, variant {v}, 64x2 THP on)")
        write(data / "kernels_papi.csv", comments, header, rows)
        print(f"kernels_papi.csv: columns {list(cols)} from {papi}")


if __name__ == "__main__":
    main()
