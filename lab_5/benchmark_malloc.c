#include <stdio.h>
#include <stdlib.h>
#include <time.h>

// Function to measure the average time of a malloc/free pair
double measure_alloc_overhead(size_t alloc_size, int iterations) {
    struct timespec start, end;
    
    // Start high-resolution timer
    clock_gettime(CLOCK_MONOTONIC, &start);
    
    for (int i = 0; i < iterations; i++) {
        void *ptr = malloc(alloc_size);
        
        // Force the compiler to actually perform the allocation by touching the memory
        if (ptr != NULL) {
            ((volatile char *)ptr)[0] = 'a';
            free(ptr);
        }
    }
    
    // Stop timer
    clock_gettime(CLOCK_MONOTONIC, &end);
    
    // Calculate total time in seconds
    double total_time = (end.tv_sec - start.tv_sec) + 
                        (end.tv_nsec - start.tv_nsec) / 1e9;
                        
    // Return average time per pair in nanoseconds
    return (total_time / iterations) * 1e9; 
}

int main() {
    int iterations = 1000000; // 1 million iterations to amortize timer overhead
    
    // Test different allocation sizes to see if size affects overhead
    size_t sizes[] = {8, 64, 256, 1024, 4096, 65536, 1048576}; 
    int num_sizes = sizeof(sizes) / sizeof(sizes[0]);
    
    printf("Iterations per test: %d\n\n", iterations);
    printf("%-15s %-25s\n", "Size (bytes)", "Avg Time (ns / pair)");
    printf("----------------------------------------\n");
    
    for (int i = 0; i < num_sizes; i++) {
        double avg_time_ns = measure_alloc_overhead(sizes[i], iterations);
        printf("%-15zu %-25.2f\n", sizes[i], avg_time_ns);
    }
    
    return 0;
}