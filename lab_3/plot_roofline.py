import os
import argparse
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

# ------------------------------------------------------------
# Configuration
# ------------------------------------------------------------

# Model of the matrix multiplication C <- A * B with N x N doubles:
#   I_fp  = 2 N^3 FLOPs            (N^3 multiplications + N^3 additions)
#   I_mem = 3 * 8 * N^2 bytes      (A, B and C are each moved once)
#   AI    = I_fp / I_mem = N / 12  FLOPs/byte

# Default roofs: AMD Ryzen 7 5825U (Zen 3), 8 cores, 2 x DDR4-3200
#   compute:   2 FMA units * 4 doubles (AVX2) * 2 FLOPs = 16 FLOPs/cycle/core
#   bandwidth: 2 channels * 3200 MT/s * 8 bytes = 51.2 GB/s
# (check the memory configuration with: sudo dmidecode -t memory)

parser = argparse.ArgumentParser(
                    prog='plot_roofline',
                    description='Roofline model with the attained matrix multiplication performance')
parser.add_argument('--timing-tools', nargs='+', default=["clk", "PAPI"])
parser.add_argument('--opt-levels', nargs='+', default=["O0", "O3"])
parser.add_argument('--iterations', type=int, default=100)      # fixed iterations, only N varies
parser.add_argument('--bandwidth-gbs', type=float, default=51.2)  # peak memory bandwidth (GB/s)
parser.add_argument('--freq-ghz', type=float, default=4.55)       # max core frequency (GHz)
parser.add_argument('--flops-per-cycle', type=float, default=16)  # peak FLOPs per cycle per core
parser.add_argument('--cores', type=int, default=8)
parser.add_argument('--output', default="mm_roofline.png")

args = parser.parse_args()

bandwidth = args.bandwidth_gbs * 1e9                            # bytes/s
peak_core = args.freq_ghz * 1e9 * args.flops_per_cycle          # FLOPs/s, one core
peak_system = peak_core * args.cores                            # FLOPs/s, all cores

# ------------------------------------------------------------
# Load data
# ------------------------------------------------------------

results = {}

for opt_level in args.opt_levels:
    for timing_tool in args.timing_tools:

        csv_file = f"matrix_benchmark_{timing_tool}_{opt_level}.csv"

        if not os.path.exists(csv_file):
            print(f"{csv_file} not found, skipping")
            continue

        df = pd.read_csv(csv_file)
        df = df[df["iterations"] == args.iterations].sort_values("matrix_size")

        if df.empty:
            print(f"No rows with iterations={args.iterations} in {csv_file}, skipping")
            continue

        n = df["matrix_size"].astype(float)
        flops = 2 * n**3
        avg_s = df["average_ns"] * 1e-9
        std_s = df["stddev_ns"] * 1e-9

        df = df.assign(
            ai=n / 12,
            flops_per_s=flops / avg_s,
            # avg ± std in time -> asymmetric range in FLOPs/s, the measured
            # minimum time bounds the fastest run
            flops_per_s_low=flops / (avg_s + std_s),
            flops_per_s_high=flops / (avg_s - std_s).clip(lower=df["minimum_ns"] * 1e-9),
        )

        results[(timing_tool, opt_level)] = df

        print(f"\n{timing_tool}, {opt_level}:")
        print(df[["matrix_size", "ai", "flops_per_s"]].to_string(index=False))

if not results:
    raise SystemExit("No benchmark results found")

# ------------------------------------------------------------
# Plot
# ------------------------------------------------------------

fig, ax = plt.subplots(figsize=(10, 7))

# --- Roofs: attainable performance = min(peak FLOPs/s, AI * bandwidth) ---
ai_min = min(df["ai"].min() for df in results.values()) / 2
ai_max = max(df["ai"].max() for df in results.values()) * 4
ai = np.logspace(np.log10(ai_min), np.log10(ai_max), 500)

ax.plot(ai, np.minimum(peak_system, ai * bandwidth) / 1e9, color="black", linewidth=2,
        label=f"Roofline, {args.cores} cores ({peak_system / 1e9:.0f} GFLOPs/s, {args.bandwidth_gbs:g} GB/s)")
ax.plot(ai, np.minimum(peak_core, ai * bandwidth) / 1e9, color="black", linewidth=1.5, linestyle="--",
        label=f"Compute ceiling, 1 core ({peak_core / 1e9:.1f} GFLOPs/s)")

# --- Attained performance: color = optimisation level, marker = timing tool ---
colors = {opt: c for opt, c in zip(args.opt_levels, ["tab:blue", "tab:orange", "tab:green", "tab:red"])}
markers = [
    dict(marker="o", markersize=5),
    # hollow and larger, so it stays visible around the first tool's marker
    dict(marker="s", markersize=10, markerfacecolor="none", linestyle=":"),
    dict(marker="^", markersize=10, markerfacecolor="none", linestyle="-."),
]
styles = {tool: m for tool, m in zip(args.timing_tools, markers)}

for (timing_tool, opt_level), df in results.items():

    perf = df["flops_per_s"]
    yerr = [(perf - df["flops_per_s_low"]) / 1e9, (df["flops_per_s_high"] - perf) / 1e9]

    ax.errorbar(df["ai"], perf / 1e9, yerr=yerr, color=colors[opt_level], capsize=3,
                label=f"{timing_tool}, {opt_level}", **styles[timing_tool])

ax.set_xscale("log", base=2)
ax.set_yscale("log")
ax.set_xlim(ai_min, ai_max)

ax.set_xlabel("Arithmetic intensity N / 12 (FLOPs/byte)")
ax.set_ylabel("Performance (GFLOPs/s)")
ax.set_title(f"Roofline model - matrix multiplication ($2N^3$ FLOPs, {args.iterations} iterations, ± 1 std)")

# second x axis with the matrix size, AI = N / 12
top = ax.secondary_xaxis("top", functions=(lambda x: x * 12, lambda x: x / 12))
top.set_xscale("log", base=2)
top.set_xlabel("Matrix size N")

ax.grid(True, which="both", linestyle="--", alpha=0.5)
ax.legend(loc="lower right")

plt.tight_layout()
plt.savefig(args.output, dpi=300)
plt.close()

print(f"\nWrote {args.output}")
