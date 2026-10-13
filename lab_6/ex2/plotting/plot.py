import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
from matplotlib.patches import Patch

# ============================================================
# Configuration
# ============================================================

INPUT_FILE = "../results.csv"
SUMMARY_FILE = "summary.csv"
PLOT_FILE = "timing_results.png"

# Convert nanoseconds to milliseconds for readability
NS_TO_MS = 1e6

# Desired order in the plot
TYPE_ORDER = [
    "baseline",
    "parallel_static",
    "parallel_dynamic",
    "parallel_guided",
]

TYPE_LABELS = {
    "baseline": "Baseline",
    "parallel_static": "Static",
    "parallel_dynamic": "Dynamic",
    "parallel_guided": "Guided",
}


# ============================================================
# Load benchmark results
# ============================================================

df = pd.read_csv(INPUT_FILE)

required_columns = {
    "iteration",
    "paralellization_type",
    "time_ns",
    "result",
}

missing_columns = required_columns - set(df.columns)

if missing_columns:
    raise ValueError(
        f"Missing required columns in {INPUT_FILE}: {missing_columns}"
    )


# ============================================================
# Compute statistics
# ============================================================

summary = (
    df.groupby("paralellization_type")["time_ns"]
    .agg(
        mean="mean",
        min="min",
        max="max",
        std="std",
    )
    .reindex(TYPE_ORDER)
)

# Remove types which do not occur in the CSV
summary = summary.dropna(how="all")

# Convert ns -> ms
summary_ms = summary / NS_TO_MS

summary_ms.index = [
    TYPE_LABELS.get(name, name)
    for name in summary_ms.index
]

print("\nTiming statistics [ms]:")
print(summary_ms.to_string(float_format=lambda x: f"{x:.3f}"))

summary_ms.to_csv(SUMMARY_FILE)


# ============================================================
# Plot
# ============================================================

labels = summary_ms.index.tolist()

means = summary_ms["mean"].to_numpy()
mins = summary_ms["min"].to_numpy()
maxs = summary_ms["max"].to_numpy()
stds = summary_ms["std"].to_numpy()

x = np.arange(len(labels))

fig, ax = plt.subplots(figsize=(9, 6))

# Mean values as bars.
# No explicit colors are specified, so matplotlib uses its
# default color cycle.
bars = ax.bar(
    x,
    means,
    width=0.6,
    zorder=2,
)

# Standard deviation as error bars
ax.errorbar(
    x,
    means,
    yerr=stds,
    fmt="none",
    ecolor='r',
    capsize=6,
    linewidth=1.5,
    zorder=4,
)

# Draw min and max as dotted horizontal lines over each bar
line_half_width = 0.38

for xpos, minimum, maximum in zip(x, mins, maxs):
    ax.hlines(
        minimum,
        xpos - line_half_width,
        xpos + line_half_width,
        colors='r',
        linestyles="dotted",
        linewidth=2,
        zorder=5,
    )

    ax.hlines(
        maximum,
        xpos - line_half_width,
        xpos + line_half_width,
        colors='r',
        linestyles="dotted",
        linewidth=2,
        zorder=5,
    )


# ============================================================
# Labels / formatting
# ============================================================

ax.set_title("Matrix-Vector Multiplication Runtime")
ax.set_xlabel("Parallelization / Scheduling Policy")
ax.set_ylabel("Execution Time [ms]")

ax.set_xticks(x)
ax.set_xticklabels(labels)

ax.grid(
    axis="y",
    linestyle="--",
    alpha=0.4,
    zorder=0,
)

# Add mean values above bars
offset = 0.02 * max(maxs)

for bar, mean, minimum in zip(bars, means, mins):
    ax.text(
        bar.get_x() + bar.get_width() / 2,
        minimum - offset,
        f"{mean:.2f}",
        ha="center",
        va="top",
        zorder=6,
    )


# ============================================================
# Legend
# ============================================================

legend_elements = [
    Patch(
        label="Mean"
    ),
    Line2D(
        [0],
        [0],
        linestyle="-",
        marker="_",
        markersize=12,
        label="±1 std",
    ),
    Line2D(
        [0],
        [0],
        linestyle=":",
        linewidth=2,
        label="Minimum / Maximum",
    ),
]

ax.legend(
    handles=legend_elements,
    loc="best",
)

fig.tight_layout()

plt.savefig(
    PLOT_FILE,
    dpi=300,
    bbox_inches="tight",
)

plt.show()

print(f"\nStatistics written to: {SUMMARY_FILE}")
print(f"Plot written to:       {PLOT_FILE}")