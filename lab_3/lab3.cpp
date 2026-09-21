#include <iostream>
#include <vector>
#include <time.h>
#include <limits>
#include <cmath>
#include <string>
#include <iomanip>
// for output to .csv, plotting in separate python script
#include <fstream> 

// Select exactly one timing tool on the command line:
//   -DTIMING_TOOL_CLOCK_GETTIME or -DTIMING_TOOL_PAPI
// Defaults to PAPI when neither is given.
#if !defined(TIMING_TOOL_CLOCK_GETTIME) && !defined(TIMING_TOOL_PAPI)
#define TIMING_TOOL_PAPI
#endif

#if defined(TIMING_TOOL_CLOCK_GETTIME) && defined(TIMING_TOOL_PAPI)
#error "Only one timing tool can be selected"
#endif

#ifdef TIMING_TOOL_PAPI
#include <papi.h>
#endif

// macros
#define NS_DIV 1000000000LL

// namespaces
using namespace std;

// gettime helper
long long timespec_diff_ns(const struct timespec *t2,
                           const struct timespec *t1)
{
    return ((long long)(t2->tv_sec - t1->tv_sec) * NS_DIV) +
           (t2->tv_nsec - t1->tv_nsec);
}

#ifdef TIMING_TOOL_CLOCK_GETTIME
struct Timer {
    struct timespec start;
    struct timespec end;

    void start_timer()
    {
        clock_gettime(CLOCK_MONOTONIC_RAW, &start);
    }

    void stop_timer()
    {
        clock_gettime(CLOCK_MONOTONIC_RAW, &end);
    }

    long long elapsed_ns() const
    {
        return timespec_diff_ns(&end, &start);
    }
};

const char* timing_tool_name()
{
    return "clock_gettime(CLOCK_MONOTONIC_RAW)";
}

int measure_timing_overhead()
{ 
    struct timespec ts1, ts2;
    long long latency_ns; int num_iterations = 100000;
    long long total_latency = 0; long long min_latency = -1; 
    long long max_latency = 0; 
    printf("\nMeasuring clock_gettime(CLOCK_MONOTONIC_RAW) overhead...\n\n");
    for (int i = 0; i < num_iterations; ++i) {
        clock_gettime(CLOCK_MONOTONIC_RAW, &ts1);
        clock_gettime(CLOCK_MONOTONIC_RAW, &ts2);
        latency_ns = timespec_diff_ns(&ts2, &ts1);
        total_latency += latency_ns;

        if (min_latency == -1 || latency_ns < min_latency) {
            min_latency = latency_ns;
        }
        if (latency_ns > max_latency) {
            max_latency = latency_ns;
        }
    }
    printf("Iterations: %d\n", num_iterations);
    printf("Average latency: %lld ns\n", total_latency / num_iterations);
    printf("Minimum latency: %lld ns\n", min_latency); printf("Maximum latency: %lld ns\n", max_latency);
    return 0;
}
#endif

#ifdef TIMING_TOOL_PAPI
struct Timer {
    long long start;
    long long end;

    void start_timer()
    {
        start = PAPI_get_real_nsec();
    }

    void stop_timer()
    {
        end = PAPI_get_real_nsec();
    }

    long long elapsed_ns() const
    {
        return end - start;
    }
};

const char* timing_tool_name()
{
    return "PAPI_get_real_nsec()";
}

bool initialize_papi()
{
    int retval = PAPI_library_init(PAPI_VER_CURRENT);

    if (retval != PAPI_VER_CURRENT) {
        cerr << "PAPI_library_init failed: "
             << PAPI_strerror(retval) << "\n";
        return false;
    }

    return true;
}

int measure_timing_overhead()
{
    long long t1, t2;
    long long latency_ns;

    int num_iterations = 100000;
    long long total_latency = 0;
    long long min_latency = -1;
    long long max_latency = 0;

    printf("Measuring PAPI_get_real_nsec() overhead...\n");

    for (int i = 0; i < num_iterations; ++i) {

        t1 = PAPI_get_real_nsec();
        t2 = PAPI_get_real_nsec();

        latency_ns = t2 - t1;

        total_latency += latency_ns;

        if (min_latency == -1 || latency_ns < min_latency) {
            min_latency = latency_ns;
        }

        if (latency_ns > max_latency) {
            max_latency = latency_ns;
        }
    }

    printf("Iterations: %d\n", num_iterations);
    printf("Average latency: %lld ns\n",
           total_latency / num_iterations);
    printf("Minimum latency: %lld ns\n",
           min_latency);
    printf("Maximum latency: %lld ns\n",
           max_latency);

    return 0;
}
#endif

// Matrix multiplication 
vector<double> multiply_matrices(const vector<double>& A, const vector<double>& B, int n)
{
    vector<double> C(n * n, 0.0);

    for (int i = 0; i < n; ++i) {
        for (int k = 0; k < n; ++k) {
            double aik = A[i * n + k];
            for (int j = 0; j < n; ++j) {
                C[i * n + j] += aik * B[k * n + j];
            }
        }
    }

    return C;
}
struct TimingStats {
    long long total_ns = 0;
    long long min_ns = numeric_limits<long long>::max();
    long long max_ns = 0;

    // running mean / sum of squared deviations (Welford), a plain sum of
    // squares in long long overflows for the large matrices
    long long count = 0;
    double mean = 0.0;
    double m2 = 0.0;

    void add(long long elapsed_ns)
    {
        total_ns += elapsed_ns;

        count++;
        double delta = static_cast<double>(elapsed_ns) - mean;
        mean += delta / count;
        m2 += delta * (static_cast<double>(elapsed_ns) - mean);

        if (elapsed_ns < min_ns)
            min_ns = elapsed_ns;
        if (elapsed_ns > max_ns)
            max_ns = elapsed_ns;
    }

    double average_ns(int iterations) const
    {
        return static_cast<double>(total_ns) / iterations;
    }

    // sample variance (n - 1), 0 when there are fewer than 2 samples
    double variance_ns2() const
    {
        if (count < 2)
            return 0.0;
        return m2 / (count - 1);
    }

    double stddev_ns() const
    {
        return sqrt(variance_ns2());
    }
};

void benchmark_mm(const size_t n, const size_t iterations, ofstream& csv)
{
    cout << "\nMatrix multiplication benchmark\n";
    cout << "--------------------------------\n";
    cout << "Matrix size: " << n << " x " << n << "\n";
    cout << "Iterations:  " << iterations << "\n";
    cout << "Timer:       " << timing_tool_name() << "\n";
    cout << "\n";

    // Allocate matrices
    vector<double> A(n * n);
    vector<double> B(n * n);
    vector<double> C;

    // Initialize A and B
    for (int i = 0; i < n; ++i) {
        for (int j = 0; j < n; ++j) {
            A[i * n + j] = static_cast<double>(i + j);
            B[i * n + j] = static_cast<double>(i - j);
        }
    }

    // Benchmark
    TimingStats stats;
    double checksum = 0.0;
    for (int iteration = 0; iteration < iterations; ++iteration) {

        Timer timer;
        timer.start_timer();

        C = multiply_matrices(A, B, n);

        timer.stop_timer();
        long long elapsed_ns = timer.elapsed_ns();
        stats.add(elapsed_ns);

        // Calculate checksum (prevent dead code elim) after timing so it 
        // does not affect the measured multiplication time
        checksum = 0.0;

        for (double v : C) {
            checksum += v;
        }

        cout << "Iteration "
             << setw(3) << iteration + 1
             << ": "
             << setw(12) << elapsed_ns
             << " ns ("
             << fixed << setprecision(6)
             << static_cast<double>(elapsed_ns) / NS_DIV
             << " s)\n";
    }

    // Results
    double average_ns = stats.average_ns(iterations);
    long long minimum_ns = stats.min_ns;
    long long maximum_ns = stats.max_ns;
    double variance_ns2 = stats.variance_ns2();
    double stddev_ns = stats.stddev_ns();

    cout << "\n";
    cout << "Results: " << timing_tool_name() << "\n";
    cout << "--------------------------------\n";
    cout << fixed << setprecision(6);

    cout << "Average: "
         << average_ns
         << " ns ("
         << average_ns / NS_DIV
         << " s)\n";

    cout << "Minimum: "
         << minimum_ns
         << " ns ("
         << static_cast<double>(stats.min_ns) / NS_DIV
         << " s)\n";

    cout << "Maximum: "
         << maximum_ns
         << " ns ("
         << static_cast<double>(stats.max_ns) / NS_DIV
         << " s)\n";

    cout << "Variance: "
         << variance_ns2
         << " ns^2\n";

    cout << "Std dev: "
         << stddev_ns
         << " ns ("
         << stddev_ns / NS_DIV
         << " s)\n";

    cout << "\nChecksum: " << checksum << "\n";

    // put results in csv file

    csv << n << ","
        << iterations << ","
        << average_ns << ","
        << minimum_ns << ","
        << maximum_ns << ","
        << variance_ns2 << ","
        << stddev_ns << "\n";

    // Make sure data is written immediately.
    csv.flush();
}

int main(int argc, char** argv)
{
    // optional first argument: output csv file
    const string csv_path = (argc > 1) ? argv[1] : "matrix_benchmark.csv";

#ifdef TIMING_TOOL_PAPI
    if (!initialize_papi()) {
        return 1;
    }
#endif

    // benchmark timing overhead
    measure_timing_overhead();

    // open csv file for results
    ofstream csv_file(csv_path);
    if (!csv_file.is_open()) {
        cerr << "Error: could not open " << csv_path << "\n";

#ifdef TIMING_TOOL_PAPI
        PAPI_shutdown();
#endif
        return 1;
    }

    // CSV header
    csv_file << "matrix_size,"
            << "iterations,"
            << "average_ns,"
            << "minimum_ns,"
            << "maximum_ns,"
            << "variance_ns2,"
            << "stddev_ns\n";

    // fixed notation, default formatting truncates to 6 significant digits
    csv_file << fixed << setprecision(3);

    // values for matrix size and num_iters
    const size_t num_sizes = 9;
    const size_t num_iters = 6;
    const size_t matrix_sizes[num_sizes] = {2, 4, 8, 16, 32, 64, 128, 256, 512};
    // const size_t iters[num_iters] = {1, 10, 25, 50, 100, 150};
    const size_t iters[num_iters] = {100};

    // test all sizes and iters
    for (int i=0; i<num_iters; i++) {
        for(int j=0; j<num_sizes; j++) {
            benchmark_mm(matrix_sizes[j], iters[i], csv_file);
        }
    }

    // cleanup
    csv_file.close();

    cout << "\nBenchmark results written to "
         << csv_path << "\n";

#ifdef TIMING_TOOL_PAPI
    PAPI_shutdown();
#endif

    return 0;
}
