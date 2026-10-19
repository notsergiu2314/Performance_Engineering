#include <omp.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#define NS_DIV 1000000000LL

void mxv(double *restrict y,
         double *restrict a,
         double *restrict x,
         size_t m, size_t n)
{
    for (size_t i=0; i<m; i++) {
        y[i] = 0.0;
        for (size_t j=0; j<n; j++) {
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
         size_t m, size_t n)
{
    #pragma omp parallel for default(none) shared(y,a,x,m,n) schedule(static)
    for (size_t i=0; i<m; i++) {
        
        double sum = 0.0; // local variable to avoid unnecessary memory writes
        size_t col = i * n; // don't recompute column each time
        #pragma omp simd reduction(+:sum)
        for (size_t j=0; j<n; j++) {
            sum += a[col+j] * x[j];
        }
        y[i] = sum;
    }
}

void mxv_par_dynamic(double *restrict y,
         double *restrict a,
         double *restrict x,
         size_t m, size_t n)
{
    #pragma omp parallel for default(none) shared(y,a,x,m,n) schedule(dynamic)
    for (size_t i=0; i<m; i++) {
        
        double sum = 0.0; // local variable to avoid unnecessary memory writes
        size_t col = i * n; // don't recompute column each time
        #pragma omp simd reduction(+:sum)
        for (size_t j=0; j<n; j++) {
            sum += a[col+j] * x[j];
        }
        y[i] = sum;
    }
}

void mxv_par_guided(double *restrict y,
         double *restrict a,
         double *restrict x,
         size_t m, size_t n)
{
    #pragma omp parallel for default(none) shared(y,a,x,m,n) schedule(guided)
    for (size_t i=0; i<m; i++) {
        
        double sum = 0.0; // local variable to avoid unnecessary memory writes
        size_t col = i * n; // don't recompute column each time
        #pragma omp simd reduction(+:sum)
        for (size_t j=0; j<n; j++) {
            sum += a[col+j] * x[j];
        }
        y[i] = sum;
    }
}

int main(int argc, char *argv[]) {
    if (argc != 4) {
        printf("Usage: %s <MAT_COLS> <MAT_ROWS> <iterations (unsigned int)>\n", argv[0]);
        return 1;
    }

    /* Trust the user that they will not input a stupid number, since he is me. */
    size_t N = strtoull(argv[1], NULL, 10);
    size_t M = strtoull(argv[2], NULL, 10);
    size_t max_it = strtoull(argv[3], NULL, 10);

    /* open csv file for results */
    FILE *results_csv = fopen("results.csv", "w");

    if (!results_csv) {
        perror("Could not open results.csv");
        return 1;
    }

    fprintf(results_csv, "iteration,paralellization_type,time_ns,result\n");

    // Allocate memory
    double *A = (double *)malloc(M * N * sizeof(double));
    double *x = (double *)malloc(N * sizeof(double));
    double *y = (double *)malloc(M * sizeof(double));

    if (!A || !x || !y) {
        printf("Memory allocation failed.\n");

        free(A);
        free(x);
        free(y);
        fclose(results_csv);

        return 1;
    }

    /* Parallel first-touch initialization. Possible limitation that pages might migrate
    * because of large serial access right after parallel static schedule allocate.
    */
    #pragma omp parallel default(none) shared(A, x, y, M, N)
    {
        #pragma omp for schedule(static) // only static, not the other scheduling policies,
        // because we cannot predict which pages are processed by which threads later
        for (size_t i=0; i < M; i++) {
            size_t row = i * N;

            for (size_t j=0; j < N; j++) {
                A[row + j] = 1.0;
            }
        }

        #pragma omp for schedule(static)
        for (size_t i=0; i < N; i++) {
            x[i] = 2.0;
        }

        #pragma omp for schedule(static)
        for (size_t i=0; i < M; i++) {
            y[i] = 0.0;
        }
    }

    /* =========================== Baseline benchmark =========================== */

    for (size_t i=0; i<max_it; i++) {
        // start timer
        struct timespec start, end;
        clock_gettime(CLOCK_MONOTONIC, &start);
        // Run the blocked matrix-vector multiplication
        mxv(y, A, x, M, N);
        clock_gettime(CLOCK_MONOTONIC, &end);
        long long time_taken_ns = (end.tv_sec - start.tv_sec) * NS_DIV + (end.tv_nsec - start.tv_nsec);
        
        fprintf(results_csv, "%zu,baseline,%lld,%lf\n", i, time_taken_ns,y[0]);
        printf("Execution time: %lld ns\n", time_taken_ns);
    
        // Print a single value to prevent dead-code elimination
        printf("Result y[0]: %f\n", y[0]);
    }

    /*=========================== Paralellization using Static ===========================*/

    for (size_t i=0; i<max_it; i++) {
        // start timer
        struct timespec start, end;
        clock_gettime(CLOCK_MONOTONIC, &start);
        // Run the blocked matrix-vector multiplication
        mxv_par_static(y, A, x, M, N);
        clock_gettime(CLOCK_MONOTONIC, &end);
        long long time_taken_ns = (end.tv_sec - start.tv_sec) * NS_DIV + (end.tv_nsec - start.tv_nsec);
        
        fprintf(results_csv, "%zu,parallel_static,%lld,%lf\n", i, time_taken_ns,y[0]);
        printf("Execution time: %lld ns\n", time_taken_ns);
    
        // Print a single value to prevent dead-code elimination
        printf("Result y[0]: %f\n", y[0]);
    }

    /*=========================== Paralellization using Dynamic ===========================*/

    for (size_t i=0; i<max_it; i++) {
        // start timer
        struct timespec start, end;
        clock_gettime(CLOCK_MONOTONIC, &start);
        // Run the blocked matrix-vector multiplication
        mxv_par_dynamic(y, A, x, M, N);
        clock_gettime(CLOCK_MONOTONIC, &end);
        long long time_taken_ns = (end.tv_sec - start.tv_sec) * NS_DIV + (end.tv_nsec - start.tv_nsec);
        
        fprintf(results_csv, "%zu,parallel_dynamic,%lld,%lf\n", i, time_taken_ns,y[0]);
        printf("Execution time: %lld ns\n", time_taken_ns);
    
        // Print a single value to prevent dead-code elimination
        printf("Result y[0]: %f\n", y[0]);
    }

    /*=========================== Paralellization using Guided ===========================*/
    
    for (size_t i=0; i<max_it; i++) {
        // start timer
        struct timespec start, end;
        clock_gettime(CLOCK_MONOTONIC, &start);
        // Run the blocked matrix-vector multiplication
        mxv_par_guided(y, A, x, M, N);
        clock_gettime(CLOCK_MONOTONIC, &end);
        long long time_taken_ns = (end.tv_sec - start.tv_sec) * NS_DIV + (end.tv_nsec - start.tv_nsec);
        
        fprintf(results_csv, "%zu,parallel_guided,%lld,%lf\n", i, time_taken_ns,y[0]);
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