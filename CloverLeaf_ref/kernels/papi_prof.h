/**
 *  @brief Per-kernel hardware counter instrumentation (PAPI).
 *  @details PROF_BEGIN/PROF_END are placed as the first and last statement
 *  inside the "omp parallel" region of each C kernel, so every OpenMP thread
 *  counts its own share of the kernel. Without -DUSE_PAPI they expand to
 *  nothing and the kernels are identical to the reference code.
 *
 *  Runtime configuration (environment):
 *    PROF_EVENTS  comma separated PAPI preset or native event names
 *                 (default "PAPI_TOT_CYC,PAPI_TOT_INS"; "" = wall time only)
 *    PROF_DIR     output directory (default "."), one CSV per process:
 *                 papi_prof_<pid>.csv with one row per (region, thread)
 */

#ifndef PAPI_PROF_H
#define PAPI_PROF_H

enum prof_region {
  PROF_IDEAL_GAS,
  PROF_VISCOSITY,
  PROF_CALC_DT,
  PROF_PDV_PREDICT,
  PROF_PDV_CORRECT,
  PROF_REVERT,
  PROF_ACCELERATE,
  PROF_FLUX_CALC,
  PROF_ADVEC_CELL,
  PROF_ADVEC_MOM,
  PROF_RESET_FIELD,
  PROF_FIELD_SUMMARY,
  PROF_UPDATE_HALO,
  PROF_NREGIONS
};

#define PROF_REGION_NAMES                                               \
  "ideal_gas", "viscosity", "calc_dt", "pdv_predict", "pdv_correct",    \
  "revert", "accelerate", "flux_calc", "advec_cell", "advec_mom",       \
  "reset_field", "field_summary", "update_halo"

#ifdef USE_PAPI
void prof_begin(int region);
void prof_end(int region);
#define PROF_BEGIN(r) prof_begin(r)
#define PROF_END(r)   prof_end(r)
#else
#define PROF_BEGIN(r) ((void)0)
#define PROF_END(r)   ((void)0)
#endif

#endif
