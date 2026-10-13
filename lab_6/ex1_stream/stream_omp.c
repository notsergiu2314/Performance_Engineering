/*
 * stream_omp.c -- the four STREAM kernels (McCalpin) with run-time array
 * length and a timer that also resolves arrays that fit in L1D.
 *
 *   copy  c = a            scale b = s*c
 *   add   c = a + b        triad a = b + s*c
 *
 * Why not the stock stream.c: it times every kernel call once with a 1 us
 * clock. A kernel over N = 1024 doubles takes a fraction of a microsecond (and
 * with many threads a few microseconds of fork/join), so the stock benchmark
 * reports 0 or garbage there. Here one timed sample consists of `reps`
 * back-to-back kernel calls, `reps` being calibrated so a sample lasts >= 1 ms
 * (reps = 1 for large N, i.e. the same measurement as stock STREAM). Bytes are
 * counted as in STREAM (16 N for copy/scale, 24 N for add/triad, no
 * write-allocate), so the large-N numbers are comparable with it.
 *
 * Every kernel is measured in two ways:
 *   <k>     one `omp parallel for` per call (fork + join inside the timing,
 *           this is what stock STREAM does)
 *   <k>_pr  `reps` calls inside ONE parallel region, `omp for` + implicit
 *           barrier per call (only the barrier is left, no fork/join);
 *           only run when reps > 1
 * plus the cost of an empty parallel region ("parregion") and of one barrier
 * ("barrier"), in seconds per operation, to explain the small-N behaviour.
 *
 * Build: gcc -O3 -fopenmp -mcpu=native stream_omp.c -o stream_omp
 * Run:   OMP_NUM_THREADS=t ./stream_omp [N=100000000] [NTIMES=20] [BUDGET_S=60]
 *
 * stdout: comment lines '#...' and one CSV row per measured operation
 *   name,n,threads,reps,ntimes,bytes,tmin_s,tavg_s,tmax_s
 * (times are per single call; iteration 0 is a warm-up and excluded, as in
 * STREAM). bandwidth = bytes/tmin_s ("best") or bytes/tavg_s ("avg").
 * Exit status 1 if the STREAM-style result check fails.
 */
#define _GNU_SOURCE
#include <math.h>
#include <omp.h>
#include <stdio.h>
#include <stdlib.h>
#ifdef _WIN32
#include <malloc.h>
#include <windows.h>
#else
#include <sched.h>
#include <time.h>
#endif

#define SCALAR   3.0
#define MAXNT    100        /* check needs 15^(2*NTIMES+2) < DBL_MAX */
#define TARGET_S 1.0e-3     /* a timed sample lasts at least this long */
#define MAXREPS  (1 << 22)
#define EPSILON  1.0e-12    /* STREAM uses 1e-13; a bit of slack for FMA contraction */

enum { OP_FJ = 0, OP_PR = 4, OP_PARREGION = 8, OP_BARRIER = 9, NOPS = 10 };
static const char *opname[NOPS] = {"copy",    "scale",    "add",       "triad",   "copy_pr",
                                   "scale_pr", "add_pr",  "triad_pr", "parregion", "barrier"};
static const int opwords[NOPS] = {2, 2, 3, 3, 2, 2, 3, 3, 0, 0};

static double *A, *B, *C;
static long N;

/* ns-resolution monotonic clock (omp_get_wtime is ~1 ms on MinGW) */
static double wtime(void)
{
#ifdef _WIN32
    LARGE_INTEGER f, t;
    QueryPerformanceFrequency(&f);
    QueryPerformanceCounter(&t);
    return (double)t.QuadPart / (double)f.QuadPart;
#else
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + 1e-9 * (double)ts.tv_nsec;
#endif
}

static void *alloc64(size_t bytes)
{
#ifdef _WIN32
    return _aligned_malloc(bytes, 64);
#else
    void *p = NULL;
    return posix_memalign(&p, 64, bytes) ? NULL : p;
#endif
}

/* ---- kernels: fork/join per call ---------------------------------------- */
static void kernel_fj(int k, double *restrict a, double *restrict b, double *restrict c, long n)
{
    switch (k) {
    case 0:
#pragma omp parallel for schedule(static)
        for (long i = 0; i < n; i++) c[i] = a[i];
        break;
    case 1:
#pragma omp parallel for schedule(static)
        for (long i = 0; i < n; i++) b[i] = SCALAR * c[i];
        break;
    case 2:
#pragma omp parallel for schedule(static)
        for (long i = 0; i < n; i++) c[i] = a[i] + b[i];
        break;
    default:
#pragma omp parallel for schedule(static)
        for (long i = 0; i < n; i++) a[i] = b[i] + SCALAR * c[i];
        break;
    }
}

/* ---- kernels: `reps` calls inside one parallel region -------------------- */
static void kernel_pr(int k, double *restrict a, double *restrict b, double *restrict c, long n,
                      int reps)
{
#pragma omp parallel
    for (int r = 0; r < reps; r++) {
        switch (k) {
        case 0:
#pragma omp for schedule(static)
            for (long i = 0; i < n; i++) c[i] = a[i];
            break;
        case 1:
#pragma omp for schedule(static)
            for (long i = 0; i < n; i++) b[i] = SCALAR * c[i];
            break;
        case 2:
#pragma omp for schedule(static)
            for (long i = 0; i < n; i++) c[i] = a[i] + b[i];
            break;
        default:
#pragma omp for schedule(static)
            for (long i = 0; i < n; i++) a[i] = b[i] + SCALAR * c[i];
            break;
        }
    }
}

/* All four kernels are idempotent when repeated (inputs are not written by
 * the same kernel), so `reps` repetitions leave the arrays as one call would. */
static void run_op(int op, int reps)
{
    if (op < OP_PR) {
        for (int r = 0; r < reps; r++) kernel_fj(op, A, B, C, N);
    } else if (op < OP_PARREGION) {
        kernel_pr(op - OP_PR, A, B, C, N, reps);
    } else if (op == OP_PARREGION) {
        for (int r = 0; r < reps; r++) {
#pragma omp parallel
            { __asm__ __volatile__("" ::: "memory"); }
        }
    } else {
#pragma omp parallel
        for (int r = 0; r < reps; r++) {
#pragma omp barrier
        }
    }
}

static double timed(int op, int reps)
{
    double t0 = wtime();
    run_op(op, reps);
    return wtime() - t0;
}

/* smallest power-of-two-ish repetition count that makes a sample >= TARGET_S */
static int calibrate(int op)
{
    int reps = 1;
    for (;;) {
        double t = timed(op, reps);
        if (t >= TARGET_S || reps >= MAXREPS) return reps;
        double f = TARGET_S / (t > 1e-9 ? t : 1e-9) * 1.1;
        long next = (long)(reps * (f < 64.0 ? f : 64.0)) + 1;
        reps = next > MAXREPS ? MAXREPS : (int)next;
    }
}

static int this_cpu(void)
{
#ifdef _WIN32
    return -1;
#else
    return sched_getcpu();
#endif
}

static void report_cpus(const char *tag)
{
    int nt = omp_get_max_threads();
    int *cpu = calloc((size_t)nt, sizeof(int));
#pragma omp parallel
    {
        int t = omp_get_thread_num();
        if (t < nt) cpu[t] = this_cpu();
    }
    printf("# cpus_%s:", tag);
    for (int t = 0; t < nt; t++) printf(" %d", cpu[t]);
    printf("\n");
    free(cpu);
}

int main(int argc, char **argv)
{
    N = argc > 1 ? (long)strtod(argv[1], NULL) : 100000000L;
    int ntimes = argc > 2 ? atoi(argv[2]) : 20;
    double budget = argc > 3 ? atof(argv[3]) : 60.0;
    if (N < 1 || ntimes < 2 || ntimes > MAXNT) {
        fprintf(stderr, "usage: %s [N>=1] [2<=NTIMES<=%d] [BUDGET_S]\n", argv[0], MAXNT);
        return 2;
    }
    const char *bind = getenv("OMP_PROC_BIND"), *places = getenv("OMP_PLACES");
    int nt = omp_get_max_threads();

    size_t bytes = (size_t)N * sizeof(double);
    A = alloc64(bytes);
    B = alloc64(bytes);
    C = alloc64(bytes);
    if (!A || !B || !C) {
        fprintf(stderr, "allocation of 3 x %.1f MB failed\n", bytes / 1e6);
        return 2;
    }

    /* first touch with the same static schedule the kernels use */
#pragma omp parallel for schedule(static)
    for (long i = 0; i < N; i++) {
        A[i] = 1.0;
        B[i] = 2.0;
        C[i] = 0.0;
    }
#pragma omp parallel for schedule(static)
    for (long i = 0; i < N; i++) A[i] = 2.0 * A[i];

    printf("# stream_omp n=%ld threads=%d ntimes=%d OMP_PROC_BIND=%s OMP_PLACES=%s\n", N, nt,
           ntimes, bind ? bind : "(unset)", places ? places : "(unset)");
    report_cpus("start");

    /* one "cycle" = copy, scale, add, triad once, in that order */
    int ncyc = 0, reps[NOPS] = {0}, do_pr = 0;
    for (int k = 0; k < 4; k++) {
        reps[OP_FJ + k] = calibrate(OP_FJ + k);
        if (reps[OP_FJ + k] > 1) do_pr = 1;
    }
    ncyc++;
    if (do_pr) {
        for (int k = 0; k < 4; k++) reps[OP_PR + k] = calibrate(OP_PR + k);
        ncyc++;
    }
    reps[OP_PARREGION] = calibrate(OP_PARREGION);
    reps[OP_BARRIER] = calibrate(OP_BARRIER);

    double tmin[NOPS], tsum[NOPS], tmax[NOPS];
    for (int o = 0; o < NOPS; o++) {
        tmin[o] = 1e300;
        tsum[o] = tmax[o] = 0.0;
    }
    int done = 0;
    double tstart = wtime();
    for (int it = 0; it < ntimes; it++) {
        for (int pass = 0; pass < (do_pr ? 2 : 1); pass++) {
            for (int k = 0; k < 4; k++) {
                int op = (pass ? OP_PR : OP_FJ) + k;
                double t = timed(op, reps[op]) / reps[op];
                if (it > 0) {
                    if (t < tmin[op]) tmin[op] = t;
                    if (t > tmax[op]) tmax[op] = t;
                    tsum[op] += t;
                }
            }
            ncyc++;
        }
        for (int op = OP_PARREGION; op <= OP_BARRIER; op++) {
            double t = timed(op, reps[op]) / reps[op];
            if (it > 0) {
                if (t < tmin[op]) tmin[op] = t;
                if (t > tmax[op]) tmax[op] = t;
                tsum[op] += t;
            }
        }
        done = it + 1;
        if (it >= 2 && wtime() - tstart > budget) break;
    }
    report_cpus("end");

    /* STREAM-style result check: replay the recurrence on scalars */
    double aj = 2.0, bj = 2.0, cj = 0.0;
    for (int i = 0; i < ncyc; i++) {
        cj = aj;
        bj = SCALAR * cj;
        cj = aj + bj;
        aj = bj + SCALAR * cj;
    }
    double ea = 0.0, eb = 0.0, ec = 0.0;
#pragma omp parallel for reduction(+ : ea, eb, ec)
    for (long i = 0; i < N; i++) {
        ea += fabs(A[i] - aj);
        eb += fabs(B[i] - bj);
        ec += fabs(C[i] - cj);
    }
    int ok = fabs(ea / N / aj) <= EPSILON && fabs(eb / N / bj) <= EPSILON &&
             fabs(ec / N / cj) <= EPSILON;
    printf("# validation: %s (cycles=%d, rel.err a=%.1e b=%.1e c=%.1e)\n", ok ? "OK" : "FAILED",
           ncyc, fabs(ea / N / aj), fabs(eb / N / bj), fabs(ec / N / cj));

    int samples = done > 1 ? done - 1 : 1;
    for (int op = 0; op < NOPS; op++) {
        if (op >= OP_PR && op < OP_PARREGION && !do_pr) continue;
        printf("%s,%ld,%d,%d,%d,%.0f,%.6e,%.6e,%.6e\n", opname[op], N, nt, reps[op], samples,
               (double)opwords[op] * sizeof(double) * (double)N, tmin[op], tsum[op] / samples,
               tmax[op]);
    }
    return ok ? 0 : 1;
}
