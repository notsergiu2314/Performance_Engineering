#include <iostream>
#include <chrono>
#include <vector>
#include <time.h>
using namespace std;

#define NS_DIV 1000000000LL


// source: https://code-examples.net/en/q/4bf1f79/benchmarking-system-calls-understanding-clock-gettime-latency-in-linux
// Function to calculate time difference in nanoseconds
long long timespec_diff_ns(struct timespec *t2, struct timespec *t1)
{
    return ((long long)(t2->tv_sec - t1->tv_sec) * NS_DIV) +
           (t2->tv_nsec - t1->tv_nsec);
}

int measure_timing_overhead()
{
    struct timespec ts1, ts2;
    long long latency_ns;
    int num_iterations = 100000;
    long long total_latency = 0;
    long long min_latency = -1;
    long long max_latency = 0;

    printf("Measuring clock_gettime(CLOCK_MONOTONIC_RAW) overhead...\n");

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
    printf("Minimum latency: %lld ns\n", min_latency);
    printf("Maximum latency: %lld ns\n", max_latency);

    return 0;
}

vector<double> multiply_matrices(const vector<double>& A, const vector<double>& B, int n) {
    vector<double> C(n*n, 0.0);
    for (int i = 0; i < n; ++i) {
        for (int k = 0; k < n; ++k) {
            double aik = A[i*n + k];
            for (int j = 0; j < n; ++j) {
                C[i*n + j] += aik * B[k*n + j];
            }
        }
    }
    return C;
}

int main() {

    // measure_timing_overhead();

    struct timespec t0,t1,t0_boot,t1_boot;
    clock_gettime(CLOCK_BOOTTIME, &t0_boot);
    clock_gettime(CLOCK_MONOTONIC_RAW, &t0);

    
    int n = 512; // matrix size (change as needed)

    // allocate matrices in row-major 1D vectors
    vector<double> A(n*n), B(n*n), C(n*n, 0.0);

    // initialize A and B with some values
    for (int i = 0; i < n; ++i) {
        for (int j = 0; j < n; ++j) {
            A[i*n + j] = (double)(i + j);
            B[i*n + j] = (double)(i - j);
        }
    }

    C = multiply_matrices(A, B, n);

    clock_gettime(CLOCK_MONOTONIC, &t1);
    clock_gettime(CLOCK_BOOTTIME, &t1_boot);

    // resolution for clocks different??
    cout << "Elapsed time boot: " << (double)timespec_diff_ns(&t1_boot, &t0_boot) / NS_DIV << " seconds\n";
    cout << "Elapsed time: " << (double)timespec_diff_ns(&t1, &t0)  / NS_DIV << " seconds\n";

    // print a checksum to avoid optimizing away the computation
    double checksum = 0.0;
    for (double v : C) checksum += v;
    cout << "Checksum: " << checksum << "\n";
    
   
    return 0;
}
