#!/bin/bash
# Export the source of every variant in perf/variants.conf into perf/src/<name>/ so the
# cluster (an rsync copy without git) can build them side by side with perf/build.sh.
#   bash perf/export_variants.sh [NAME...]        (default: every row of variants.conf)
# Only the build inputs are exported (Makefile, *.f90, timer_c.c, kernels/, InputDecks/);
# perf/ itself is not. Each export gets a SOURCE.txt with the ref, commit and description.
# Knobs: CONF (perf/variants.conf), SRC_ROOT (perf/src).
set -euo pipefail
PERF_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="${CONF:-$PERF_ROOT/variants.conf}"
SRC_ROOT="${SRC_ROOT:-$PERF_ROOT/src}"
REPO="$(git -C "$PERF_ROOT" rev-parse --show-toplevel)"
# path of CloverLeaf_ref inside the repository (git archive paths are repo-relative)
PREFIX="$(git -C "$PERF_ROOT" rev-parse --show-prefix | sed 's|perf/$||')"
want=("$@")

mkdir -p "$SRC_ROOT"
while read -r name ref desc; do
  if [ ${#want[@]} -gt 0 ]; then
    case " ${want[*]} " in *" $name "*) ;; *) continue ;; esac
  fi
  hash=$(git -C "$REPO" rev-parse --verify "$ref^{commit}")
  dirty=0
  if [ "$(git -C "$REPO" rev-parse HEAD)" = "$hash" ]; then
    # grep -v exits 1 when every line is filtered out; that is "clean", not an error
    dirty=$(git -C "$REPO" status --porcelain -- "$PREFIX" | { grep -v -E "$PREFIX(perf/|.*\.o$|.*\.mod$|clover_leaf$)" || true; } | wc -l)
    [ "$dirty" -eq 0 ] || echo "warning: $name = HEAD but $dirty tracked files are modified and NOT exported (commit or stash them)" >&2
  fi
  dst="$SRC_ROOT/$name"
  rm -rf "$dst"; mkdir -p "$dst"
  git -C "$REPO" archive --format=tar "$hash" \
      "${PREFIX}Makefile" "${PREFIX}timer_c.c" "${PREFIX}kernels" "${PREFIX}InputDecks" \
      $(git -C "$REPO" ls-tree --name-only "$hash" "$PREFIX" | grep '\.f90$') \
    | tar -x -C "$dst" --strip-components="$(printf '%s' "$PREFIX" | tr -cd / | wc -c)"
  {
    echo "variant:     $name"
    echo "ref:         $ref"
    echo "commit:      $hash"
    echo "date:        $(git -C "$REPO" show -s --format=%ci "$hash")"
    echo "subject:     $(git -C "$REPO" show -s --format=%s "$hash")"
    echo "description: $desc"
    echo "exported:    $(date -Is) from $(hostname), dirty tracked files: $dirty"
  } > "$dst/SOURCE.txt"
  printf '%-6s %s  %s\n' "$name" "${hash:0:7}" "$desc"
done < <(grep -v -E '^\s*(#|$)' "$CONF")
echo "sources in $SRC_ROOT (gitignored); rsync them with the tree, then build with perf/build.sh"
