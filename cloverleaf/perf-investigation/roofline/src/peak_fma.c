/* FP64 peak benchmark: every thread runs NV independent fused multiply-add chains on
 * native-width vectors, held in named variables so the compiler keeps them in registers
 * (an acc[] array may be kept in memory, which turns the chain into a store-forwarding
 * loop and under-reports the peak). NV = 12 vectors is above latency x pipes on any
 * current core (e.g. 4-5 cycles x 2 pipes) and leaves room for x and y in the 16 AVX
 * registers. The vector width follows the target: 512-bit AVX-512, 256-bit AVX, else
 * 128-bit (NEON, SSE2). The chain is written as `v = v + v * x`, the accumulate form
 * that maps directly onto the AArch64 `fmla d, n, m` (d += n*m) with d = v: the form
 * `v * x + y` makes GCC load y into the destination and copy the result back, two
 * extra SIMD register moves per FMA that compete with the FMA for the same pipes
 * (measured 2.4 instead of 8 FLOP/cycle on Kunpeng 920). build.sh records the hot loop
 * in build.log so this can be checked.
 *
 * usage: peak_fma [ITERS] [FLOP_PER_CYCLE]   ITERS loop trips per thread (default 4e8);
 *        FLOP_PER_CYCLE (default 8) is only used to print the implied clock frequency.
 * FLOPs = 2 * NV * LANES * ITERS per thread. The reported total uses the slowest thread.
 * Output is one key=value per line.
 */
#include <stdio.h>
#include <stdlib.h>
#include <omp.h>

#if defined(__AVX512F__)
#define VW 64
#elif defined(__AVX__)
#define VW 32
#else
#define VW 16
#endif
#define LANES (VW / 8)
#define NV 12
typedef double vd __attribute__((vector_size(VW)));

int main(int argc, char **argv)
{
    long iters = argc > 1 ? atol(argv[1]) : 400000000L;
    double flop_per_cycle = argc > 2 ? atof(argv[2]) : 8.0;
    double checksum = 0.0, tmax = 0.0, tsum = 0.0;
    int threads = 0;

#pragma omp parallel reduction(+:checksum,tsum) reduction(max:tmax)
    {
        vd x, v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11;
        for (int l = 0; l < LANES; l++) {
            x[l] = 1e-9;                          /* v grows by e^(iters*1e-9): no overflow */
            v0[l] = 1.00 + 1e-3 * l; v1[l] = 1.01 + 1e-3 * l; v2[l] = 1.02 + 1e-3 * l;
            v3[l] = 1.03 + 1e-3 * l; v4[l] = 1.04 + 1e-3 * l; v5[l] = 1.05 + 1e-3 * l;
            v6[l] = 1.06 + 1e-3 * l; v7[l] = 1.07 + 1e-3 * l; v8[l] = 1.08 + 1e-3 * l;
            v9[l] = 1.09 + 1e-3 * l; v10[l] = 1.10 + 1e-3 * l; v11[l] = 1.11 + 1e-3 * l;
        }
#pragma omp barrier
        double t0 = omp_get_wtime();
        for (long it = 0; it < iters; it++) {
            v0 = v0 + v0 * x; v1 = v1 + v1 * x; v2 = v2 + v2 * x; v3 = v3 + v3 * x;
            v4 = v4 + v4 * x; v5 = v5 + v5 * x; v6 = v6 + v6 * x; v7 = v7 + v7 * x;
            v8 = v8 + v8 * x; v9 = v9 + v9 * x; v10 = v10 + v10 * x; v11 = v11 + v11 * x;
        }
        double dt = omp_get_wtime() - t0;
        vd s = v0 + v1 + v2 + v3 + v4 + v5 + v6 + v7 + v8 + v9 + v10 + v11;
        double ss = 0.0;
        for (int l = 0; l < LANES; l++) ss += s[l];
        checksum += ss; tsum += dt; if (dt > tmax) tmax = dt;
#pragma omp single
        threads = omp_get_num_threads();
    }

    double flops_per_thread = 2.0 * NV * LANES * (double)iters;
    double gflops_total = flops_per_thread * threads / tmax / 1e9;
    double gflops_per_thread = flops_per_thread / (tsum / threads) / 1e9;
    printf("gflops_total=%.2f\ngflops_per_thread=%.2f\nimplied_ghz=%.3f\nthreads=%d\n"
           "iters=%ld\nvectors=%d\nlanes=%d\ntime_s=%.3f\nchecksum=%.6e\n",
           gflops_total, gflops_per_thread, gflops_per_thread / flop_per_cycle, threads,
           iters, NV, LANES, tmax, checksum);
    return 0;
}
