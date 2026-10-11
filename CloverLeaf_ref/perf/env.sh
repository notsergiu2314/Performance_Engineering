# Environment for building and running on HAICGU (source it: `. perf/env.sh`).
# Module names follow https://haicgu.github.io/usage.html; check `module avail`
# if a load fails and adjust the versions here (and only here).

PERF_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PERF_ROOT
export CLOVER_ROOT="$(dirname "$PERF_ROOT")"

module purge
module load GCC/12.1.0
module load OpenMPI

# PAPI: prefer a site module, fall back to a private install made with
# perf/install_papi.sh.
if module -t avail PAPI 2>&1 | grep -q '^PAPI'; then
  module load PAPI
  export PAPI_DIR="${EBROOTPAPI:-$(dirname "$(dirname "$(command -v papi_avail)")")}"
else
  export PAPI_DIR="${PAPI_DIR:-$HOME/opt/papi}"
  export PATH="$PAPI_DIR/bin:$PATH"
  export LD_LIBRARY_PATH="$PAPI_DIR/lib:${LD_LIBRARY_PATH:-}"
fi

# Kunpeng 920 node: 2 sockets x 64 cores, 4 NUMA domains of 32 cores.
export OMP_PLACES=cores
export OMP_PROC_BIND=close
