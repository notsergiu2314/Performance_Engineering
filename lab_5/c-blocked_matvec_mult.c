#include <stdio.h>
#include <stdlib.h>
#include <time.h>

/* 
 * Computes y = A * x using cache blocking
 * N: Matrix dimension (N x N)
 * B: Block size (N % B must be 0)
 * A: Flattened N x N matrix stored in row-major order
 * x: Input vector of size N
 * y: Output vector of size N
 */
void blocked_mat_vec(int N, int B, const double *A, const double *x, double *y) {
    // 1. Initialize output vector
    for (int i = 0; i < N; i++) {
        y[i] = 0.0;
    }

    // 2. Iterate over blocks
    for (int i = 0; i < N; i += B) {          // Row blocks
        for (int j = 0; j < N; j += B) {      // Column blocks
            
            // 3. Compute multiplication for the current B x B block
            for (int ii = i; ii < i + B; ii++) {
                for (int jj = j; jj < j + B; jj++) {
                    y[ii] += A[ii * N + jj] * x[jj];
                }
            }
            
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
    blocked_mat_vec(N, B, A, x, y);

    // Print a single value to prevent dead-code elimination
    printf("Result y[0]: %f\n", y[0]);

    // Free memory
    free(A);
    free(x);
    free(y);

    return 0;
}