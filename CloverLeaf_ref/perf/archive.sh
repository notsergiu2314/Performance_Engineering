#!/bin/bash
# Archive the summaries of finished jobs (never the per-repetition directories) under
# perf/archive/m3/<job dir name>/ and, with --report, copy the aggregated rows into
# report/data/ (analysis/report_data.py).
#   bash perf/archive.sh perf/results/m3_opt_<id> [perf/results/m3_correctness_<id> ...] [--report]
# Files kept per job: environment.txt system.txt results.csv profiler.csv summary.txt summary.md
# qa_check.txt correctness_rows.csv optimised.csv ladder.csv compare.md papi_avail.txt and, from
# the sub-directories (variants, PAPI event sets), the same files flattened as
# <sub>_<file> plus every *.papi.csv (as perf/archive/m3/m3_papi_34798 is laid out).
# Knobs: ARCHIVE (perf/archive/m3), REPORT_DATA (../../report/data), VARIANT (opt: the
# variant whose PAPI columns go into kernels_papi.csv).
set -euo pipefail
PERF_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCHIVE="${ARCHIVE:-$PERF_ROOT/archive/m3}"
REPORT_DATA="${REPORT_DATA:-$PERF_ROOT/../../report/data}"
VARIANT="${VARIANT:-opt}"
keep="environment.txt system.txt results.csv profiler.csv summary.txt summary.md qa_check.txt correctness_rows.csv optimised.csv ladder.csv compare.md papi_avail.txt"
report=0; dirs=()
for arg in "$@"; do [ "$arg" = --report ] && report=1 || dirs+=("$arg"); done
[ ${#dirs[@]} -gt 0 ] || { sed -n 2,5p "$0"; exit 1; }

opt_csv= ladder_csv= corr_csv= papi_dir=
for d in "${dirs[@]}"; do
  d="${d%/}"; [ -d "$d" ] || { echo "not a directory: $d" >&2; exit 1; }
  dst="$ARCHIVE/$(basename "$d")"; mkdir -p "$dst"
  n=0
  for f in $keep; do [ -f "$d/$f" ] && { cp "$d/$f" "$dst/"; n=$((n + 1)); }; done
  # one or two levels of sub-directories: m3_opt (layouts/<v>, ladder/<v>), m3_correctness (<v>),
  # m3_papi (<set>/, <set>/<tag>.papi.csv)
  while IFS= read -r f; do
    rel="${f#"$d/"}"; cp "$f" "$dst/${rel//\//_}"; n=$((n + 1))
  done < <(find "$d" -mindepth 2 -maxdepth 3 -type f \( $(printf -- '-name %s -o ' $keep) -name '*.papi.csv' \) \
           -not -path '*/clover_*' -not -name 'rep*')
  echo "$dst: $n files"
  [ -f "$d/optimised.csv" ] && opt_csv="$d/optimised.csv"
  [ -f "$d/ladder.csv" ] && ladder_csv="$d/ladder.csv"
  [ -f "$d/correctness_rows.csv" ] && corr_csv="$d/correctness_rows.csv"
  case $(basename "$d") in m3_papi_${VARIANT}_*) papi_dir="$d" ;; esac
done

if [ "$report" = 1 ]; then
  args=()
  [ -n "$opt_csv" ] && args+=(--optimised "$opt_csv")
  [ -n "$ladder_csv" ] && args+=(--ladder "$ladder_csv")
  [ -n "$corr_csv" ] && args+=(--correctness "$corr_csv")
  [ -n "$papi_dir" ] && args+=(--papi "$papi_dir" --variant "$VARIANT")
  [ ${#args[@]} -gt 0 ] || { echo "--report: nothing to copy (no optimised.csv, ladder.csv, correctness_rows.csv or m3_papi_${VARIANT}_* among the jobs)" >&2; exit 1; }
  python3 -I "$PERF_ROOT/analysis/report_data.py" --data "$REPORT_DATA" "${args[@]}"
  echo "now: /usr/bin/python3 $(cd "$REPORT_DATA/.." && pwd)/make_assets.py"
fi
