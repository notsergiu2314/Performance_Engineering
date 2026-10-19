/* Self-written STREAM-style memory bandwidth benchmark (copy, scale, add, triad, read).
 *
 * usage: membw [N] [NTIMES]      N doubles per array (default 2^27 = 1 GiB each), NTIMES
 *                                 repetitions; the best time after the first is reported.
 * Arrays are initialised in a parallel loop so first-touch places pages next to the
 * threads that use them. Bytes are counted the STREAM way (no write-allocate traffic):
 * copy/scale 16 B, add/triad 24 B, read 8 B per element. Output is one key=value per line.
 */
#include <stdio.h>
#include <stdlib.h>
#include <omp.h>

#define NK 5
static const char *names[NK] = {"copy", "scale", "add", "triad", "read"};
static const double bytes_per_elem[NK] = {16, 16, 24, 24, 8};

int main(int argc, char **argv)
{
    long n = argc > 1 ? atol(argv[1]) : (1L << 27);
    int ntimes = argc > 2 ? atoi(argv[2]) : 20;
    const double s = 3.0;
    double *a = malloc(n * sizeof *a), *b = malloc(n * sizeof *b), *c = malloc(n * sizeof *c);
    if (!a || !b || !c) { fprintf(stderr, "membw: allocation of 3 x %ld doubles failed\n", n); return 1; }

#pragma omp parallel for schedule(static)
    for (long i = 0; i < n; i++) { a[i] = 1.0; b[i] = 2.0; c[i] = 0.0; }

    double best[NK], sum = 0.0;
    for (int k = 0; k < NK; k++) best[k] = 1e30;

    for (int t = 0; t < ntimes; t++) {
        double t0, dt;
        t0 = omp_get_wtime();
#pragma omp parallel for simd schedule(static)
        for (long i = 0; i < n; i++) c[i] = a[i];
        dt = omp_get_wtime() - t0; if (t && dt < best[0]) best[0] = dt;

        t0 = omp_get_wtime();
#pragma omp parallel for simd schedule(static)
        for (long i = 0; i < n; i++) b[i] = s * c[i];
        dt = omp_get_wtime() - t0; if (t && dt < best[1]) best[1] = dt;

        t0 = omp_get_wtime();
#pragma omp parallel for simd schedule(static)
        for (long i = 0; i < n; i++) c[i] = a[i] + b[i];
        dt = omp_get_wtime() - t0; if (t && dt < best[2]) best[2] = dt;

        t0 = omp_get_wtime();
#pragma omp parallel for simd schedule(static)
        for (long i = 0; i < n; i++) a[i] = b[i] + s * c[i];
        dt = omp_get_wtime() - t0; if (t && dt < best[3]) best[3] = dt;

        double acc = 0.0;
        t0 = omp_get_wtime();
#pragma omp parallel for simd schedule(static) reduction(+:acc)
        for (long i = 0; i < n; i++) acc += a[i];
        dt = omp_get_wtime() - t0; if (t && dt < best[4]) best[4] = dt;
        sum += acc;
    }

    for (int k = 0; k < NK; k++)
        printf("%s_gbs=%.3f\n", names[k], bytes_per_elem[k] * (double)n / best[k] / 1e9);
    printf("n=%ld\nntimes=%d\nthreads=%d\narray_mib=%.0f\nchecksum=%.6e\n",
           n, ntimes, omp_get_max_threads(), n * sizeof(double) / 1048576.0, sum);
    free(a); free(b); free(c);
    return 0;
}
