#include <omp.h>
#include <stdio.h>
#include <stdlib.h>

void mxv(double *restrict y,
         double *restrict a,
         double *restrict x,
         int m, int n)
{
    #pragma omp parallel
    for (int i=0; i<m; i++) {
        y[i] = 0.0;

        for (int j=0; j<n; j++) {
            y[i] += a[i*n+j] * x[j];
        }
    }
}

int main(int argc, char *argv[]) {
    if (argc != 3) {
        printf("Usage: %s <N> <B>\n", argv[0]);
        return 1;
    }

    int N = atoi(argv[1]);
    int B = atoi(argv[2]);

    if (N % B != 0) {
        printf("Error: N must be divisible by B.\n");
        return 1;
    }

    // Allocate memory
    double *A = (double *)malloc(N * N * sizeof(double));
    double *x = (double *)malloc(N * sizeof(double));
    double *y = (double *)malloc(N * sizeof(double));

    if (!A || !x || !y) {
        printf("Memory allocation failed.\n");
        return 1;
    }

    // Initialize arrays with dummy data to prevent compiler optimizations
    for (int i = 0; i < N * N; i++) A[i] = 1.0;
    for (int i = 0; i < N; i++) x[i] = 2.0;

    // Run the blocked matrix-vector multiplication
    mxv(y, A, x, B, N);

    // Print a single value to prevent dead-code elimination
    printf("Result y[0]: %f\n", y[0]);

    // Free memory
    free(A);
    free(x);
    free(y);

    return 0;
}