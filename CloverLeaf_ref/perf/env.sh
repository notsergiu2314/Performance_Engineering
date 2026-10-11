# Environment for building and running on HAICGU (source it: `. perf/env.sh`).
# Module names follow https://haicgu.github.io/usage.html; check `module avail`
# if a load fails and adjust the versions here (and only here).

PERF_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PERF_ROOT
export CLOVER_ROOT="$(dirname "$PERF_ROOT")"

# lmod's init scripts read variables that may be unset (e.g. LD_PRELOAD), which
# kills them under `set -u`. Relax it while the module system is used.
case $- in *u*) _perf_restore_u=1; set +u ;; *) _perf_restore_u=0 ;; esac

# Non-interactive shells (srun, sbatch) may not have the `module` function yet.
if ! type module > /dev/null 2>&1; then
  for _f in /etc/profile.d/lmod.sh /opt/ohpc/admin/lmod/lmod/init/bash; do
    [ -f "$_f" ] && . "$_f" && break
  done
fi

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

[ "$_perf_restore_u" = 1 ] && set -u

# Fail here, with the module state, instead of deep inside make.
for _tool in mpicc mpif90 gcc; do
  if ! command -v "$_tool" > /dev/null 2>&1; then
    echo "env.sh: '$_tool' not found after module load. Loaded modules:" >&2
    module -t list >&2
    echo "Check names with: module avail GCC OpenMPI   (then edit perf/env.sh)" >&2
    return 1 2> /dev/null || exit 1
  fi
done
