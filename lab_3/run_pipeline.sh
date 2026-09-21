#!/bin/bash

# Complete lab 3 pipeline: compile -> benchmark -> plots -> LaTeX table,
# for every combination of timing tool and optimisation level.
#
# Usage:
#   ./run_pipeline.sh                           # clk + PAPI, O0 + O3
#   TOOLS="PAPI" OPTS="O3" ./run_pipeline.sh    # subset
#   TABLE_ITERS=50 ./run_pipeline.sh            # iterations used for the table

set -euo pipefail
cd "$(dirname "$0")"

TOOLS="${TOOLS:-clk PAPI}"
OPTS="${OPTS:-O0 O3}"
TABLE_ITERS="${TABLE_ITERS:-100}"

# use the project venv when it exists
if [[ -x ../.venv/bin/python ]]; then
    PYTHON="$(cd .. && pwd)/.venv/bin/python"
else
    PYTHON=python3
fi

generated=()

for tool in $TOOLS; do

    case "$tool" in
        clk)
            define="TIMING_TOOL_CLOCK_GETTIME"
            libs=""
            ;;
        PAPI)
            define="TIMING_TOOL_PAPI"
            libs="$(pkg-config --cflags --libs papi 2>/dev/null || echo "-lpapi")"
            ;;
        *)
            echo "Unknown timing tool: $tool (use clk or PAPI)"
            exit 1
            ;;
    esac

    for opt in $OPTS; do
        name="${tool}_${opt}"
        exe="lab3_${name}.out"
        csv="matrix_benchmark_${name}.csv"
        tex="table_${name}.tex"

        echo "=== [$name] Compiling..."
        # shellcheck disable=SC2086
        g++ -std=c++17 "-$opt" "-D$define" lab3.cpp -o "$exe" $libs

        echo "=== [$name] Running benchmark..."
        "./$exe" "$csv" | tee "log_${name}.tmp"

        echo "=== [$name] Creating plots..."
        "$PYTHON" plot_time_matrix.py --csv "$csv" --opt-level "$opt" --timing-tool "$tool"

        echo "=== [$name] Creating table..."
        ./csv2tex.sh "$csv" "$tex" "$TABLE_ITERS" "$tool, $opt"

        rm -f "$exe"
        generated+=("$csv" "$tex" mm_"${name}"_*.png)
    done
done

echo "=== Creating roofline plot..."
# shellcheck disable=SC2086
"$PYTHON" plot_roofline.py --timing-tools $TOOLS --opt-levels $OPTS --iterations "$TABLE_ITERS"
generated+=("mm_roofline.png")

echo
echo "Done! Generated files:"
printf '    %s\n' "${generated[@]}"
