#include <stdio.h>
#include <stdlib.h>
#include <stddef.h>
#include <time.h>

void matvec(const double * restrict A,
            const double * restrict x,
            double * restrict y,
            int N)
{
    for (int i = 0; i < N; i++) {
        double sum = 0.0;

        for (int j = 0; j < N; j++) {
            sum += A[(size_t)i * N + j] * x[j];
        }

        y[i] = sum;
    }
}

int main() {
    int N = 2048; // matrix size large enough to benefit from vectorization
    
    // Allocate memory for the N x N matrix and the two vectors
    double *A = (double *)malloc((size_t)N * N * sizeof(double));
    double *x = (double *)malloc((size_t)N * sizeof(double));
    double *y = (double *)malloc((size_t)N * sizeof(double));

    if (A == NULL || x == NULL || y == NULL) {
        fprintf(stderr, "Memory allocation failed.\n");
        return 1;
    }

    // prevent dead-code elimination
    for (size_t i = 0; i < (size_t)N * N; i++) {
        A[i] = 1.0;
    }
    for (int i = 0; i < N; i++) {
        x[i] = 2.0;
        y[i] = 0.0;
    }

    //  multiplication
    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);
    
    // Execute the multiplication
    matvec(A, x, y, N);
    
    clock_gettime(CLOCK_MONOTONIC, &end);
    double time_taken = (end.tv_sec - start.tv_sec) + (end.tv_nsec - start.tv_nsec) * 1e-9;
    
    printf("Execution time: %f seconds\n", time_taken);

    printf("Result y[0] = %f\n", y[0]);

    // Clean up memory
    free(A);
    free(x);
    free(y);

    return 0;
}