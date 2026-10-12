/* FP64 peak benchmark: every thread runs NACC independent fused multiply-add chains so the
 * FMA pipes are saturated regardless of latency (NACC = 32 doubles = 16 NEON or 8 AVX2
 * vectors, more than latency x pipes on any current core).
 *
 * usage: peak_fma [ITERS] [FLOP_PER_CYCLE]   ITERS loop trips per thread (default 4e8);
 *        FLOP_PER_CYCLE (default 8) is only used to print the implied clock frequency.
 * FLOPs = 2 * NACC * ITERS per thread. The reported rate uses the slowest thread's time.
 * Output is one key=value per line.
 */
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <omp.h>

#define NACC 32

int main(int argc, char **argv)
{
    long iters = argc > 1 ? atol(argv[1]) : 400000000L;
    double flop_per_cycle = argc > 2 ? atof(argv[2]) : 8.0;
    const double x = 1.0 + 1e-9, y = 1e-9;      /* acc grows by e^(iters*1e-9): no overflow */
    double checksum = 0.0, tmax = 0.0, tsum = 0.0;
    int threads = 0;

#pragma omp parallel reduction(+:checksum,tsum) reduction(max:tmax)
    {
        double acc[NACC];
        for (int i = 0; i < NACC; i++) acc[i] = 1.0 + 1e-3 * i;
#pragma omp barrier
        double t0 = omp_get_wtime();
        for (long it = 0; it < iters; it++) {
#pragma omp simd
            for (int i = 0; i < NACC; i++) acc[i] = fma(acc[i], x, y);
        }
        double dt = omp_get_wtime() - t0;
        double s = 0.0;
        for (int i = 0; i < NACC; i++) s += acc[i];
        checksum += s; tsum += dt; if (dt > tmax) tmax = dt;
#pragma omp single
        threads = omp_get_num_threads();
    }

    double flops_per_thread = 2.0 * NACC * (double)iters;
    double gflops_total = flops_per_thread * threads / tmax / 1e9;
    double gflops_per_thread = flops_per_thread / (tsum / threads) / 1e9;
    printf("gflops_total=%.2f\ngflops_per_thread=%.2f\nimplied_ghz=%.3f\nthreads=%d\n"
           "iters=%ld\nnacc=%d\ntime_s=%.3f\nchecksum=%.6e\n",
           gflops_total, gflops_per_thread, gflops_per_thread / flop_per_cycle, threads,
           iters, NACC, tmax, checksum);
    return 0;
}
