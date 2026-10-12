/*
 * Attainable double-precision throughput (compute ceilings for the roofline).
 *
 * Every thread runs NACC independent dependency chains of one operation on
 * 2-lane double vectors (NEON on aarch64) or on scalars:
 *   vfma : acc = acc*m + a   (2 flop/lane)  -> peak FMA ceiling
 *   sfma : scalar fma        (2 flop)       -> "no SIMD" ceiling
 *   vmul : acc = acc*m       (1 flop/lane)  -> peak without FMA
 *   vdiv : acc = b / acc     (1 flop/lane)  -> division ceiling
 * With few chains the result is latency bound; the plateau reached when
 * NACC >= latency x pipelines is the throughput ceiling.
 *
 * Build: gcc -O3 -mcpu=native -fno-tree-vectorize -fopenmp peak_flops.c -o peak_flops -lm
 *        (-fno-tree-vectorize keeps sfma scalar; the vector ops use intrinsics)
 * Run:   OMP_NUM_THREADS=64 OMP_PLACES=cores OMP_PROC_BIND=close ./peak_flops
 * Output is CSV: op,nacc,threads,seconds,gflops,flop_per_cycle_per_core
 */

#include <math.h>
#include <omp.h>
#include <stdio.h>
#include <stdlib.h>

#if defined(__aarch64__)
#include <arm_neon.h>
typedef float64x2_t vd;
static inline vd v_set(double x)            { return vdupq_n_f64(x); }
static inline vd v_fma(vd x, vd m, vd a)    { return vfmaq_f64(a, x, m); }
static inline vd v_acc(vd acc, vd m, vd a)  { return vfmaq_f64(acc, m, a); }
static inline vd v_mul(vd x, vd m)          { return vmulq_f64(x, m); }
static inline vd v_div(vd b, vd x)          { return vdivq_f64(b, x); }
static inline double v_sum(vd v)            { return vgetq_lane_f64(v, 0) + vgetq_lane_f64(v, 1); }
#else
/* Portable fallback (e.g. for testing on x86 with -march=native). */
typedef double vd __attribute__((vector_size(16)));
static inline vd v_set(double x)            { vd v = {x, x}; return v; }
static inline vd v_fma(vd x, vd m, vd a)    { return x * m + a; }
static inline vd v_acc(vd acc, vd m, vd a)  { return acc + m * a; }
static inline vd v_mul(vd x, vd m)          { return x * m; }
static inline vd v_div(vd b, vd x)          { return b / x; }
static inline double v_sum(vd v)            { return v[0] + v[1]; }
#endif

#define DEF_KERNELS(N)                                                        \
static __attribute__((unused)) double vfma_##N(long it, double mv, double av) {                       \
  vd acc[N], m = v_set(mv), a = v_set(av);                                    \
  for (int k = 0; k < N; k++) acc[k] = v_set(1.0 + k);                        \
  for (long i = 0; i < it; i++) {                                             \
    _Pragma("GCC unroll 16")                                                  \
    for (int k = 0; k < N; k++) acc[k] = v_fma(acc[k], m, a);                 \
  }                                                                           \
  double s = 0; for (int k = 0; k < N; k++) s += v_sum(acc[k]); return s;     \
}                                                                             \
static __attribute__((unused)) double vacc_##N(long it, double mv, double av) {                       \
  vd acc[N], m = v_set(mv), a = v_set(av);                                    \
  for (int k = 0; k < N; k++) acc[k] = v_set(1.0 + k);                        \
  for (long i = 0; i < it; i++) {                                             \
    _Pragma("GCC unroll 16")                                                  \
    for (int k = 0; k < N; k++) acc[k] = v_acc(acc[k], m, a);                 \
  }                                                                           \
  double s = 0; for (int k = 0; k < N; k++) s += v_sum(acc[k]); return s;     \
}                                                                             \
static __attribute__((unused)) double sfma_##N(long it, double m, double a) {                         \
  double acc[N];                                                              \
  for (int k = 0; k < N; k++) acc[k] = 1.0 + k;                               \
  for (long i = 0; i < it; i++) {                                             \
    _Pragma("GCC unroll 16")                                                  \
    for (int k = 0; k < N; k++) acc[k] = fma(acc[k], m, a);                   \
  }                                                                           \
  double s = 0; for (int k = 0; k < N; k++) s += acc[k]; return s;           \
}                                                                             \
static __attribute__((unused)) double vmul_##N(long it, double mv, double av) {                       \
  vd acc[N], m = v_set(mv);                                                   \
  (void) av;                                                                  \
  for (int k = 0; k < N; k++) acc[k] = v_set(1.0 + k);                        \
  for (long i = 0; i < it; i++) {                                             \
    _Pragma("GCC unroll 16")                                                  \
    for (int k = 0; k < N; k++) acc[k] = v_mul(acc[k], m);                    \
  }                                                                           \
  double s = 0; for (int k = 0; k < N; k++) s += v_sum(acc[k]); return s;     \
}                                                                             \
static __attribute__((unused)) double vdiv_##N(long it, double bv, double av) {                       \
  vd acc[N], b = v_set(bv);                                                   \
  (void) av;                                                                  \
  for (int k = 0; k < N; k++) acc[k] = v_set(1.0 + k);                        \
  for (long i = 0; i < it; i++) {                                             \
    _Pragma("GCC unroll 16")                                                  \
    for (int k = 0; k < N; k++) acc[k] = v_div(b, acc[k]);                    \
  }                                                                           \
  double s = 0; for (int k = 0; k < N; k++) s += v_sum(acc[k]); return s;     \
}

DEF_KERNELS(1)
DEF_KERNELS(2)
DEF_KERNELS(4)
DEF_KERNELS(8)
DEF_KERNELS(12)
DEF_KERNELS(16)

typedef double (*kernel_fn)(long, double, double);

typedef struct {
  const char *op;
  int         nacc;
  int         lanes;
  int         flop_per_lane;
  long        iter_divisor;      /* divisions are much slower: fewer iterations */
  kernel_fn   fn;
} bench;

#define ROW(op, N, lanes, fpl, div) { #op, N, lanes, fpl, div, op##_##N }
static const bench benches[] = {
  ROW(vfma, 1, 2, 2, 1), ROW(vfma, 2, 2, 2, 1), ROW(vfma, 4, 2, 2, 1),
  ROW(vfma, 8, 2, 2, 1), ROW(vfma, 12, 2, 2, 1), ROW(vfma, 16, 2, 2, 1),
  /* vacc: the accumulator is the FMLA destination (no register copies), the
     real peak-FMA kernel. vfma keeps the chain on the multiplicand, which
     forces a copy of the addend per FMA; it is kept to show that effect. */
  ROW(vacc, 1, 2, 2, 1), ROW(vacc, 2, 2, 2, 1), ROW(vacc, 4, 2, 2, 1),
  ROW(vacc, 8, 2, 2, 1), ROW(vacc, 12, 2, 2, 1), ROW(vacc, 16, 2, 2, 1),
  ROW(sfma, 1, 1, 2, 1), ROW(sfma, 4, 1, 2, 1), ROW(sfma, 8, 1, 2, 1),
  ROW(sfma, 16, 1, 2, 1),
  ROW(vmul, 1, 2, 1, 1), ROW(vmul, 8, 2, 1, 1), ROW(vmul, 16, 2, 1, 1),
  ROW(vdiv, 1, 2, 1, 16), ROW(vdiv, 4, 2, 1, 16), ROW(vdiv, 8, 2, 1, 16),
  ROW(vdiv, 16, 2, 1, 16),
};

int main(int argc, char **argv)
{
  long iters = argc > 1 ? atol(argv[1]) : 100000000L;
  double ghz = getenv("CPU_GHZ") ? atof(getenv("CPU_GHZ")) : 2.6;
  int nthreads = omp_get_max_threads();
  double sink = 0.0;

  printf("op,nacc,threads,seconds,gflops,flop_per_cycle_per_core\n");
  for (size_t b = 0; b < sizeof(benches) / sizeof(benches[0]); b++) {
    const bench *bm = &benches[b];
    long it = iters / bm->iter_divisor;
    double t0 = 0.0, t1 = 0.0;

#pragma omp parallel reduction(+:sink)
    {
      sink += bm->fn(it / 20, 0.999999, 1e-7);   /* warm-up, clocks up */
#pragma omp barrier
#pragma omp master
      t0 = omp_get_wtime();
#pragma omp barrier
      sink += bm->fn(it, 0.999999, 1e-7);
#pragma omp barrier
#pragma omp master
      t1 = omp_get_wtime();
    }

    double flop = (double) it * bm->nacc * bm->lanes * bm->flop_per_lane * nthreads;
    double gflops = flop / (t1 - t0) * 1e-9;
    printf("%s,%d,%d,%.4f,%.2f,%.3f\n", bm->op, bm->nacc, nthreads, t1 - t0,
           gflops, gflops / nthreads / ghz);
    fflush(stdout);
  }
  fprintf(stderr, "checksum %g\n", sink);
  return 0;
}
