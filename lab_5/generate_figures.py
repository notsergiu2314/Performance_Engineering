import pandas as pd
import matplotlib.pyplot as plt

# --- Figure 1: Cache Misses vs Block Size ---
try:
    df_cache = pd.read_csv('cache_misses.csv')
    
    plt.figure(figsize=(8, 5))
    plt.plot(df_cache['BlockSize_B'], df_cache['D1_Misses'], marker='o', linestyle='-', color='#0052cc')
    plt.title('L1D Cache Misses vs. Block Size (N=8192)')
    plt.xlabel('Block Size (B)')
    plt.ylabel('D1 Cache Misses')
    plt.xscale('log', base=2) # Log scale makes the block sizes evenly spaced
    plt.grid(True, which="both", linestyle='--', alpha=0.7)
    plt.tight_layout()
    plt.savefig('figure_1_cache_misses.png', dpi=300)
    print("Created figure_1_cache_misses.png")
except FileNotFoundError:
    print("Could not find cache_misses.csv")

# --- Figure 2: Malloc Overhead vs Allocation Size ---
# Using the exact data from your benchmark run
sizes = [8, 64, 256, 1024, 4096, 65536, 1048576]
times = [10.18, 6.48, 6.66, 6.63, 16.92, 20.74, 16.49]

plt.figure(figsize=(8, 5))
plt.plot(sizes, times, marker='s', linestyle='-', color='#d93025')
plt.title('Memory Allocation Overhead vs. Allocation Size')
plt.xlabel('Allocation Size (bytes)')
plt.ylabel('Average Time (ns / pair)')
plt.xscale('log', base=2)
plt.ylim(0, 25) # Start Y-axis at 0 for honest representation
plt.grid(True, which="both", linestyle='--', alpha=0.7)
plt.tight_layout()
plt.savefig('figure_2_malloc_overhead.png', dpi=300)
print("Created figure_2_malloc_overhead.png")