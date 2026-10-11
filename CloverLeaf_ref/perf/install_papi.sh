#!/bin/bash
# Private PAPI install into $HOME/opt/papi, only needed if HAICGU has no PAPI
# module. Run it on a compute node so the build matches the target CPU:
#   srun -p cn-ib -N 1 -t 00:30:00 bash perf/install_papi.sh
set -euo pipefail

PREFIX="${PAPI_DIR:-$HOME/opt/papi}"
TAG="${PAPI_TAG:-papi-7-1-0-t}"
SRC="$HOME/src/papi"

module purge
module load GCC/12.1.0

mkdir -p "$(dirname "$SRC")"
[ -d "$SRC" ] || git clone https://github.com/icl-utk-edu/papi.git "$SRC"
cd "$SRC"
git fetch --tags
git checkout "$TAG"
cd src
./configure --prefix="$PREFIX"
make -j 32
make install

"$PREFIX/bin/papi_avail" | head -40
echo "PAPI installed in $PREFIX"
