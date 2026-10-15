#!/bin/bash
# Copy CloverLeaf_ref (sources, perf/ tooling, perf/src variants) to the cluster with rsync.
#   CLUSTER=haicgu bash perf/sync.sh
# Knobs: CLUSTER (ssh host or user@host, required), REMOTE (target directory on the cluster,
# default CloverLeaf_ref), RSYNC_ARGS (extra flags, e.g. -n for a dry run).
# Build products, job results and the laptop binaries are not copied; nothing is deleted.
set -euo pipefail
CLOVER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${CLUSTER:?set CLUSTER to the ssh host (e.g. CLUSTER=haicgu or user@host)}"
REMOTE="${REMOTE:-CloverLeaf_ref}"
# shellcheck disable=SC2086
rsync -a --info=stats1,progress0 ${RSYNC_ARGS:-} \
  --exclude 'perf/results/' --exclude 'perf/bin/' --exclude '*.o' --exclude '*.mod' \
  --exclude 'clover_leaf' --exclude 'clover.out' --exclude '__pycache__/' \
  "$CLOVER_ROOT/" "$CLUSTER:$REMOTE/"
echo "synced $CLOVER_ROOT -> $CLUSTER:$REMOTE (perf/src variants included)"
