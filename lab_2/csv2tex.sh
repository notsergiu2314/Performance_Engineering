#!/bin/bash

input="$1"
output="$2"

if [[ -z "$input" || -z "$output" ]]; then
    echo "Usage: $0 input.csv output.tex"
    exit 1
fi

awk -F',' '
BEGIN {
    print "\\begin{table}[ht]"
    print "    \\centering"
    print "    \\caption{STREAM benchmark results. Values are reported as average $\\pm$ half the observed min--max range.}"
    print "    \\label{tab:stream-results}"
    print "    \\begin{tabular}{rcccc}"
    print "        \\hline"
    print "        Array size & Copy & Scale & Add & Triad \\\\"
    print "        \\hline"
}
NR > 1 {
    # Remove accidental Markdown formatting
    for (i = 1; i <= NF; i++) {
        gsub(/\*\*/, "", $i)
    }

    array_size = $1

    copy_var  = ($4  - $3)  / 2
    scale_var = ($7  - $6)  / 2
    add_var   = ($10 - $9)  / 2
    triad_var = ($13 - $12) / 2

    printf "        %s & $%.1f \\pm %.1f$ & $%.1f \\pm %.1f$ & $%.1f \\pm %.1f$ & $%.1f \\pm %.1f$ \\\\\n", \
        array_size, \
        $2, copy_var, \
        $5, scale_var, \
        $8, add_var, \
        $11, triad_var
}
END {
    print "        \\hline"
    print "    \\end{tabular}"
    print "\\end{table}"
}
' "$input" > "$output"

echo "Wrote LaTeX table to $output"
