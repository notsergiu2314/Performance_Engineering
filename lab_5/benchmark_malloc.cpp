/*
 * Benchmark: overhead of a single malloc()/free() pair.
 *
 * Two independent measurements are taken for every allocation size:
 *
 *  1. per-pair timing: every malloc/free pair is wrapped in two
 *     clock_gettime() calls.  This gives the full distribution
 *     (mean, median, stddev, min, max) but every sample also contains the
 *     cost of the timer itself, which is measured separately and subtracted.
 *
 *  2. batch timing: the timer is started once, ITERATIONS pairs are executed
 *     and the timer is stopped; the elapsed time is divided by ITERATIONS.
 *     The timer overhead is amortized to ~0 and the result is used as a
 *     cross-check for (1).
 *
 * Results are written to benchmark_malloc.csv (plotted by generate_figures.py).
 */
#include <time.h>
#include <stdio.h>
#include <stdlib.h>

#include <algorithm>
#include <cmath>
#include <limits>
#include <vector>

using namespace std;

static const clockid_t CLOCK_ID = CLOCK_MONOTONIC;
#define NS_DIV 1000000000LL

static inline long long timespec_diff_ns(const struct timespec *t2,
                                         const struct timespec *t1)
{
    return ((long long)(t2->tv_sec - t1->tv_sec) * NS_DIV) +
           (t2->tv_nsec - t1->tv_nsec);
}

struct TimingStats {
    long long min_ns = numeric_limits<long long>::max();
    long long max_ns = 0;

    // running mean / sum of squared deviations (Welford); a plain sum of
    // squares in long long overflows for a large number of samples
    long long count = 0;
    double mean = 0.0;
    double m2 = 0.0;

    vector<long long> samples; // kept for the median

    void add(long long elapsed_ns)
    {
        count++;
        double delta = static_cast<double>(elapsed_ns) - mean;
        mean += delta / count;
        m2 += delta * (static_cast<double>(elapsed_ns) - mean);

        if (elapsed_ns < min_ns) min_ns = elapsed_ns;
        if (elapsed_ns > max_ns) max_ns = elapsed_ns;
        samples.push_back(elapsed_ns);
    }

    // sample variance (n - 1), 0 when there are fewer than 2 samples
    double variance_ns2() const
    {
        if (count < 2) return 0.0;
        return m2 / (count - 1);
    }

    double stddev_ns() const { return sqrt(variance_ns2()); }

    double median_ns()
    {
        if (samples.empty()) return 0.0;
        size_t mid = samples.size() / 2;
        nth_element(samples.begin(), samples.begin() + mid, samples.end());
        return static_cast<double>(samples[mid]);
    }
};

/* Cost of two back-to-back clock_gettime() calls, i.e. what an "empty"
 * per-pair measurement reports. */
static TimingStats measure_timer_overhead(int iterations)
{
    TimingStats stats;
    stats.samples.reserve(iterations);
    struct timespec t1, t2;
    for (int i = 0; i < iterations; ++i) {
        clock_gettime(CLOCK_ID, &t1);
        clock_gettime(CLOCK_ID, &t2);
        stats.add(timespec_diff_ns(&t2, &t1));
    }
    return stats;
}

/* Per-pair timing: each malloc/free pair is timed individually. */
static TimingStats measure_alloc_per_pair(size_t alloc_size, int iterations)
{
    TimingStats stats;
    stats.samples.reserve(iterations);
    struct timespec start, end;

    for (int i = 0; i < iterations; i++) {
        clock_gettime(CLOCK_ID, &start);
        void *ptr = malloc(alloc_size);
        // touch the memory so the allocation cannot be optimised away
        if (ptr != NULL) {
            ((volatile char *)ptr)[0] = 'a';
            free(ptr);
        }
        clock_gettime(CLOCK_ID, &end);
        stats.add(timespec_diff_ns(&end, &start));
    }
    return stats;
}

/* Batch timing: one timer read around all iterations, timer cost amortized. */
static double measure_alloc_batch(size_t alloc_size, int iterations)
{
    struct timespec start, end;
    clock_gettime(CLOCK_ID, &start);
    for (int i = 0; i < iterations; i++) {
        void *ptr = malloc(alloc_size);
        if (ptr != NULL) {
            ((volatile char *)ptr)[0] = 'a';
            free(ptr);
        }
    }
    clock_gettime(CLOCK_ID, &end);
    return static_cast<double>(timespec_diff_ns(&end, &start)) / iterations;
}

int main()
{
    const int iterations = 1000000;
    const size_t sizes[] = {8, 64, 256, 1024, 4096, 65536, 1048576};
    const int num_sizes = sizeof(sizes) / sizeof(sizes[0]);

    /* 1. timer overhead */
    TimingStats timer = measure_timer_overhead(iterations);
    const double timer_overhead_ns = timer.median_ns();
    printf("clock_gettime(CLOCK_MONOTONIC) back-to-back overhead (%d samples):\n",
           iterations);
    printf("  mean %.2f ns, median %.0f ns, min %lld ns, max %lld ns\n\n",
           timer.mean, timer.median_ns(), timer.min_ns, timer.max_ns);

    /* 2. malloc/free pairs */
    FILE *csv_file = fopen("benchmark_malloc.csv", "w");
    if (!csv_file) { perror("fopen"); return 1; }
    fprintf(csv_file,
            "size_bytes,batch_ns,perpair_mean_raw_ns,perpair_mean_ns,"
            "perpair_median_ns,perpair_stddev_ns,perpair_min_ns,perpair_max_ns\n");

    printf("Iterations per size: %d (timer overhead %.0f ns subtracted)\n\n",
           iterations, timer_overhead_ns);
    printf("%-10s %10s %10s %10s %10s %10s %8s\n", "size", "batch", "raw mean",
           "mean", "median", "stddev", "min");

    for (int i = 0; i < num_sizes; i++) {
        measure_alloc_batch(sizes[i], iterations / 10); // warm-up, not recorded

        double batch_ns = measure_alloc_batch(sizes[i], iterations);
        TimingStats pp = measure_alloc_per_pair(sizes[i], iterations);

        double mean_ns = pp.mean - timer_overhead_ns;
        double median_ns = pp.median_ns() - timer_overhead_ns;
        double min_ns = static_cast<double>(pp.min_ns) - timer_overhead_ns;

        printf("%-10zu %10.2f %10.2f %10.2f %10.2f %10.2f %8.0f\n", sizes[i],
               batch_ns, pp.mean, mean_ns, median_ns, pp.stddev_ns(), min_ns);
        fprintf(csv_file, "%zu,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%lld\n", sizes[i],
                batch_ns, pp.mean, mean_ns, median_ns, pp.stddev_ns(), min_ns,
                pp.max_ns);
    }

    fclose(csv_file);
    return 0;
}
