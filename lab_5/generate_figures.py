import csv
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt


def read_csv(path):
    with open(path) as f:
        rows = list(csv.DictReader(f))
    return {k: [float(r[k]) for r in rows] for k in rows[0]}


# --- Figure 1: Cache Misses vs Block Size ---
try:
    d = read_csv("cache_misses.csv")
    plt.figure(figsize=(8, 5))
    plt.plot(d["BlockSize_B"], d["D1_Misses"], marker="o", linestyle="-", color="#0052cc")
    plt.title("L1D Cache Misses vs. Block Size (N=8192)")
    plt.xlabel("Block Size (B)")
    plt.ylabel("D1 Cache Misses")
    plt.xscale("log", base=2)
    plt.grid(True, which="both", linestyle="--", alpha=0.7)
    plt.tight_layout()
    plt.savefig("report/figure_1_cache_misses.png", dpi=300)
    print("Created report/figure_1_cache_misses.png")
except FileNotFoundError:
    print("Could not find cache_misses.csv")

# --- Figure 2: Malloc Overhead vs Allocation Size ---
try:
    d = read_csv("benchmark_malloc.csv")
    plt.figure(figsize=(8, 5))
    plt.plot(d["size_bytes"], d["batch_ns"], marker="s", linestyle="-",
             color="#d93025", label="batch (amortized timer)")
    plt.plot(d["size_bytes"], d["perpair_mean_ns"], marker="o", linestyle="--",
             color="#0052cc", label="per-pair mean (timer overhead subtracted)")
    plt.plot(d["size_bytes"], d["perpair_median_ns"], marker="^", linestyle=":",
             color="#188038", label="per-pair median (timer overhead subtracted)")
    plt.title("Memory Allocation Overhead vs. Allocation Size")
    plt.xlabel("Allocation Size (bytes)")
    plt.ylabel("Time per malloc/free pair (ns)")
    plt.xscale("log", base=2)
    plt.ylim(bottom=0)
    plt.grid(True, which="both", linestyle="--", alpha=0.7)
    plt.legend()
    plt.tight_layout()
    plt.savefig("report/figure_2_malloc_overhead.png", dpi=300)
    print("Created report/figure_2_malloc_overhead.png")
except FileNotFoundError:
    print("Could not find benchmark_malloc.csv")
