#include <stdio.h>
#include <stdlib.h>
#include <time.h>

// timer helper
long long now_ns()
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC_RAW, &ts);
    return ts.tv_sec * 1000000000LL + ts.tv_nsec;
}

// Squared sum, unrolled by a factor U with one accumulator per unroll
template <int U>
__attribute__((noinline)) // ask the compiler not to perform inlining to keep the unroll factor the only change
double sqsum(double *__restrict a, int n)
{
    double s[U] = {};
    int i = 0;

    for (; i + U - 1 < n; i += U) {
        // unroll inner loop fully, because we want all U accumulators written here
        #pragma GCC unroll 16 // max unroll we test
        for (int k = 0; k < U; k++) {
            s[k] += a[i + k] * a[i + k];
        }
    }

    // remainder when n is not a multiple of U
    for (; i < n; i++) {
        s[0] += a[i] * a[i];
    }

    double total = 0.0;
    for (int k = 0; k < U; k++){
        total += s[k];
    }

    return total;
}

struct Kernel {
    int unroll;
    double (*fn)(double *__restrict, int);
};

#define KERNEL(U) {U, sqsum<U>},

// called through this table, so the compiler cannot inline the kernels or
// hoist the calls out of the timing loop
const Kernel kernels[] = {
    KERNEL(1) KERNEL(2) KERNEL(3) KERNEL(4) KERNEL(5) KERNEL(6) KERNEL(7)
    KERNEL(8) KERNEL(9) KERNEL(10) KERNEL(11) KERNEL(12) KERNEL(14) KERNEL(16)
};

double sum;

int main()
{
    int n = 8192;
    int calls = 10000;
    int reps = 30;

    // Multiples of 0.25 so no floating point inaccuracies
    double *a = (double *) calloc(n, sizeof(double));
    double expected = 0.0;
    for (int i = 0; i < n; i++) {
        a[i] = (i % 16) * 0.25;
        expected += a[i] * a[i];
    }

    printf("unroll,min_ns,ns_per_element,cycles_per_element\n");

    for (const Kernel& kernel : kernels) {
        // assume max clock speed for Jort's system
        double core_ghz = 4.50;

        // best case of `reps` batches of `calls` calls
        long long min_ns = 0;
        for (int rep = 0; rep < reps; rep++) {
            long long start = now_ns();
            for (int i = 0; i < calls; i++) {
                sum = kernel.fn(a, n);
            }
            long long elapsed = now_ns() - start;

            if (rep == 0 || elapsed < min_ns) {
                min_ns = elapsed;
            }
        }

        if (sum != expected) {
            fprintf(stderr, "Error: U=%d returned %f, expected %f\n",
                    kernel.unroll, sum, expected);
            return 1;
        }

        double ns_per_element = (double) min_ns / n / calls;
        printf("%d,%lld,%.4f,%.3f\n", kernel.unroll, min_ns, ns_per_element,
               ns_per_element * core_ghz);
    }

    free(a);
    return 0;
}
