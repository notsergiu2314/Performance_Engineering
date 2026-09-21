import pandas as pd
import matplotlib.pyplot as plt
import argparse

# ------------------------------------------------------------
# Configuration
# ------------------------------------------------------------

# argparse
parser = argparse.ArgumentParser(
                    prog='plot_time_matrix',
                    description='Plot the matrix multiplication benchmark results')
parser.add_argument('--csv', default="matrix_benchmark.csv")  # benchmark results file
parser.add_argument('--opt-level', default="Ounknown")      # optimisation level string
parser.add_argument('--timing-tool', default="unknown")      # timing tool string

args = parser.parse_args()

# ------------------------------------------------------------
# Load data
# ------------------------------------------------------------

df = pd.read_csv(args.csv)

print("Loaded benchmark data:")
print(df)


# ------------------------------------------------------------
# Variability plot: average ± std, one subplot per iteration count
# ------------------------------------------------------------

if "stddev_ns" not in df.columns:
    print(f"No stddev_ns column in {args.csv}, skipping std plot")
else:
    # std is undefined for a single iteration
    groups = list(df[df["iterations"] > 1].groupby("iterations"))

    ncols = 2
    nrows = (len(groups) + ncols - 1) // ncols
    fig, axes = plt.subplots(nrows, ncols, figsize=(6 * ncols, 5 * nrows),
                             sharex=True, sharey=True, squeeze=False)
    axes = axes.flatten()

    for ax, (iterations, group) in zip(axes, groups):

        group = group.sort_values("matrix_size")

        avg = group["average_ns"]
        std = group["stddev_ns"]

        # y axis is logarithmic and avg - std can drop below zero for noisy
        # runs, the measured minimum is a true lower bound
        lower = (avg - std).clip(lower=group["minimum_ns"])
        upper = avg + std

        ax.plot(group["matrix_size"], avg, color="tab:blue", marker="o", label="Average")
        ax.fill_between(group["matrix_size"], lower, upper, color="tab:blue", alpha=0.2, label="± 1 std")

        ax.set_xscale("log", base=2)
        ax.set_yscale("log")
        ax.set_title(f"{iterations} iterations")
        ax.grid(True, which="both", linestyle="--", alpha=0.5)
        ax.legend()

    # shared axes: only label the outer subplots
    for ax in axes[:len(groups)]:
        ax.set_xlabel("Matrix size (N × N)")
        ax.tick_params(labelbottom=True)
    for ax in axes[::ncols]:
        ax.set_ylabel("Execution time (ns)")

    # hide unused subplots
    for ax in axes[len(groups):]:
        ax.set_visible(False)

    # the ± std band is hard to see on a log axis spanning several decades,
    # so use a free slot for the relative std (std / average) of all groups
    if len(groups) < len(axes):
        ax = fig.add_subplot(nrows, ncols, len(axes))

        for iterations, group in groups:
            group = group.sort_values("matrix_size")
            ax.plot(
                group["matrix_size"],
                100 * group["stddev_ns"] / group["average_ns"],
                marker="o",
                label=f"{iterations} iterations"
            )

        ax.set_xscale("log", base=2)
        ax.set_yscale("log")
        ax.set_title("Relative std")
        ax.set_xlabel("Matrix size (N × N)")
        ax.set_ylabel("std / average (%)")
        ax.grid(True, which="both", linestyle="--", alpha=0.5)
        ax.legend(title="Iterations")

    fig.suptitle(f"({args.opt_level}) Matrix Multiplication - average ± std")

    plt.tight_layout()
    plt.savefig(f"mm_{args.timing_tool}_{args.opt_level}_std.png")
    plt.close()
