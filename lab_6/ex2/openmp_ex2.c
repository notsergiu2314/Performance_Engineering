#include <omp.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#define NS_DIV 1000000000LL

void mxv(double *restrict y,
         double *restrict a,
         double *restrict x,
         int m, int n)
{
    for (int i=0; i<m; i++) {
        y[i] = 0.0;
        for (int j=0; j<n; j++) {
            y[i] += a[i*n+j] * x[j];
        }
    }
}

/* Three separate functions for the parallel implementation, because of simplicity. 
 * We did not want to complicate the code and the running script with compile-time
 * if-statements for each schedule directive, and have to recompile the binary each time.
 */
void mxv_par_static(double *restrict y,
         double *restrict a,
         double *restrict x,
         int m, int n)
{
    #pragma omp parallel for default(none) shared(y,a,x,m,n) schedule(static)
    for (int i=0; i<m; i++) {
        
        double sum = 0.0; // local variable to avoid unnecessary memory writes
        int col = i*n; // don't recompute column each time
        #pragma omp simd reduction(+:sum)
        for (int j=0; j<n; j++) {
            sum += a[col+j] * x[j];
        }
        y[i] = sum;
    }
}

void mxv_par_dynamic(double *restrict y,
         double *restrict a,
         double *restrict x,
         int m, int n)
{
    #pragma omp parallel for default(none) shared(y,a,x,m,n) schedule(dynamic)
    for (int i=0; i<m; i++) {
        
        double sum = 0.0; // local variable to avoid unnecessary memory writes
        int col = i*n; // don't recompute column each time
        #pragma omp simd reduction(+:sum)
        for (int j=0; j<n; j++) {
            sum += a[col+j] * x[j];
        }
        y[i] = sum;
    }
}

void mxv_par_guided(double *restrict y,
         double *restrict a,
         double *restrict x,
         int m, int n)
{
    #pragma omp parallel for default(none) shared(y,a,x,m,n) schedule(guided)
    for (int i=0; i<m; i++) {
        
        double sum = 0.0; // local variable to avoid unnecessary memory writes
        int col = i*n; // don't recompute column each time
        #pragma omp simd reduction(+:sum)
        for (int j=0; j<n; j++) {
            sum += a[col+j] * x[j];
        }
        y[i] = sum;
    }
}

int main(int argc, char *argv[]) {
    if (argc != 4) {
        printf("Usage: %s <N> <B> <iterations>\n", argv[0]);
        return 1;
    }

    int N = atoi(argv[1]);
    int B = atoi(argv[2]);

    if (N % B != 0) {
        printf("Error: N must be divisible by B.\n");
        return 1;
    }

    int max_it = atoi(argv[3]);
    if (max_it < 0) {
        printf("iterations must be greater than 0.\n");
        return 1;
    }

    /* open csv file for results */
    FILE *results_csv = fopen("results.csv", "w");
    fprintf(results_csv, "iteration,paralellization_type,time_ns,result\n");

    // Allocate memory
    double *A = (double *)malloc(N * N * sizeof(double));
    double *x = (double *)malloc(N * sizeof(double));
    double *y = (double *)malloc(N * sizeof(double));

    if (!A || !x || !y) {
        printf("Memory allocation failed.\n");

        free(A);
        free(x);
        free(y);
        fclose(results_csv);

        return 1;
    }

    /* Parallel first-touch initialization. */
    #pragma omp parallel default(none) shared(A, x, y, N)
    {
        #pragma omp for schedule(static) // only static, not the other scheduling policies,
        // because we cannot predict which pages are processed by which threads later
        for (int i = 0; i < N; i++) {
            size_t row = (size_t)i * (size_t)N;

            for (int j = 0; j < N; j++) {
                A[row + j] = 1.0;
            }
        }

        #pragma omp for schedule(static)
        for (int i = 0; i < N; i++) {
            x[i] = 2.0;
            y[i] = 0.0;
        }
    }

    /* =========================== Baseline benchmark =========================== */

    for (int i=0; i<max_it; i++) {
        // start timer
        struct timespec start, end;
        clock_gettime(CLOCK_MONOTONIC, &start);
        // Run the blocked matrix-vector multiplication
        mxv(y, A, x, B, N);
        clock_gettime(CLOCK_MONOTONIC, &end);
        long long time_taken_ns = (end.tv_sec - start.tv_sec) * NS_DIV + (end.tv_nsec - start.tv_nsec);
        
        fprintf(results_csv, "%d,baseline,%d,%lf\n", i, time_taken_ns,y[0]);
        printf("Execution time: %lld ns\n", time_taken_ns);
    
        // Print a single value to prevent dead-code elimination
        printf("Result y[0]: %f\n", y[0]);
    }

    /*=========================== Paralellization using Static ===========================*/

    for (int i=0; i<max_it; i++) {
        // start timer
        struct timespec start, end;
        clock_gettime(CLOCK_MONOTONIC, &start);
        // Run the blocked matrix-vector multiplication
        mxv_par_static(y, A, x, B, N);
        clock_gettime(CLOCK_MONOTONIC, &end);
        long long time_taken_ns = (end.tv_sec - start.tv_sec) * NS_DIV + (end.tv_nsec - start.tv_nsec);
        
        fprintf(results_csv, "%d,parallel_static,%d,%lf\n", i, time_taken_ns,y[0]);
        printf("Execution time: %lld ns\n", time_taken_ns);
    
        // Print a single value to prevent dead-code elimination
        printf("Result y[0]: %f\n", y[0]);
    }

    /*=========================== Paralellization using Dynamic ===========================*/

    for (int i=0; i<max_it; i++) {
        // start timer
        struct timespec start, end;
        clock_gettime(CLOCK_MONOTONIC, &start);
        // Run the blocked matrix-vector multiplication
        mxv_par_dynamic(y, A, x, B, N);
        clock_gettime(CLOCK_MONOTONIC, &end);
        long long time_taken_ns = (end.tv_sec - start.tv_sec) * NS_DIV + (end.tv_nsec - start.tv_nsec);
        
        fprintf(results_csv, "%d,parallel_dynamic,%d,%lf\n", i, time_taken_ns,y[0]);
        printf("Execution time: %lld ns\n", time_taken_ns);
    
        // Print a single value to prevent dead-code elimination
        printf("Result y[0]: %f\n", y[0]);
    }

    /*=========================== Paralellization using Guided ===========================*/
    
    for (int i=0; i<max_it; i++) {
        // start timer
        struct timespec start, end;
        clock_gettime(CLOCK_MONOTONIC, &start);
        // Run the blocked matrix-vector multiplication
        mxv_par_guided(y, A, x, B, N);
        clock_gettime(CLOCK_MONOTONIC, &end);
        long long time_taken_ns = (end.tv_sec - start.tv_sec) * NS_DIV + (end.tv_nsec - start.tv_nsec);
        
        fprintf(results_csv, "%d,parallel_guided,%d,%lf\n", i, time_taken_ns,y[0]);
        printf("Execution time: %lld ns\n", time_taken_ns);
    
        // Print a single value to prevent dead-code elimination
        printf("Result y[0]: %f\n", y[0]);
    }

    // Cleanup
    fclose(results_csv);

    free(A);
    free(x);
    free(y);

    return 0;
}