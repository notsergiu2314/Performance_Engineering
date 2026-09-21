#!/bin/bash

input="$1"
output="$2"
iters="${3:-100}"       # fixed number of iterations, only N varies in the table
suffix="${4:-}"         # optional text for caption/label, e.g. "PAPI, O3"

if [[ -z "$input" || -z "$output" ]]; then
    echo "Usage: $0 input.csv output.tex [iterations] [caption-suffix]"
    exit 1
fi

caption_suffix=""
label="tab:mm-results"
if [[ -n "$suffix" ]]; then
    caption_suffix=" ($suffix)"
    # label: lowercase, anything that is not alphanumeric becomes a dash
    label="tab:mm-$(echo "$suffix" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-|-$//g')"
fi

awk -F',' -v iters="$iters" -v caption_suffix="$caption_suffix" -v label="$label" '
BEGIN {
    print "\\begin{table}[ht]"
    print "    \\centering"
    print "    \\caption{Matrix multiplication execution time" caption_suffix ". Values are reported as average $\\pm$ standard deviation over " iters " iterations.}"
    print "    \\label{" label "}"
    print "    \\begin{tabular}{rcc}"
    print "        \\hline"
    print "        $N$ & Time (ns) & Rel. std (\\%) \\\\"
    print "        \\hline"
}
# columns: matrix_size,iterations,average_ns,minimum_ns,maximum_ns,variance_ns2,stddev_ns
NR == 1 && $7 != "stddev_ns" {
    # csv from before the std was added to the benchmark
    exit 2
}
NR > 1 && $2 == iters {
    n   = $1
    avg = $3
    std = $7

    # shared exponent so the average and std are directly comparable
    exponent = int(log(avg) / log(10))
    if (10 ^ exponent > avg) exponent--
    scale = 10 ^ exponent

    printf "        %d & $(%.3f \\pm %.3f) \\times 10^{%d}$ & %.2f \\\\\n", \
        n, avg / scale, std / scale, exponent, 100 * std / avg

    rows++
}
END {
    print "        \\hline"
    print "    \\end{tabular}"
    print "\\end{table}"

    if (rows == 0) exit 2
}
' "$input" > "$output"

if [[ $? -ne 0 ]]; then
    echo "Error: no rows with iterations=$iters (or no stddev_ns column) in $input"
    rm -f "$output"
    exit 1
fi

echo "Wrote LaTeX table to $output"
