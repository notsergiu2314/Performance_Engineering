import pandas as pd
import matplotlib.pyplot as plt
import argparse

# ------------------------------------------------------------
# Configuration
# ------------------------------------------------------------

CSV_FILE = "matrix_benchmark.csv"

# argparse
parser = argparse.ArgumentParser(
                    prog='ProgramName',
                    description='What the program does',
                    epilog='Text at the bottom of help')
parser.add_argument('--opt-level', default="Ounknown")      # optimisation level string
parser.add_argument('--timing-tool', default="unknown")      # timing tool string

args = parser.parse_args()

# ------------------------------------------------------------
# Load data
# ------------------------------------------------------------

df = pd.read_csv(CSV_FILE)

print("Loaded benchmark data:")
print(df)


# ------------------------------------------------------------
# Plot
# ------------------------------------------------------------

for timing_type in ["average_ns", "minimum_ns", "maximum_ns"]:

    plt.figure(figsize=(10, 6))

    for iterations, group in df.groupby("iterations"):

        group = group.sort_values("matrix_size")

        plt.plot(
            group["matrix_size"],
            group[timing_type],
            marker="o",
            label=f"{iterations} iterations"
        )

    plt.xlabel("Matrix size (N × N)")
    plt.ylabel("Execution time (ns)")
    plt.title(f"({args.opt_level}) Matrix Multiplication - {timing_type}")

    plt.xscale("log", base=2)
    plt.yscale("log")

    plt.grid(True, which="both", linestyle="--", alpha=0.5)
    plt.legend(title="Iterations")

    plt.tight_layout()
    plt.savefig(f"mm_{args.timing_tool}_{args.opt_level}_{timing_type}.png")