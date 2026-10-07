#!/bin/bash

# Fixed matrix size (N=8192 ensures the vector exceeds the 48 KiB L1d cache)
N=8192

# Array of block sizes to test
BLOCK_SIZES=(8 16 32 64 128 256 512 1024)

# Output CSV file
OUTPUT_FILE="cache_misses.csv"

# Initialize the CSV with headers
echo "BlockSize_B,D1_Misses" > "$OUTPUT_FILE"
echo "Starting Cachegrind benchmark for N=$N..."

for B in "${BLOCK_SIZES[@]}"; do
    echo -n "Testing B=$B... "
    
    # --cachegrind-out-file=/dev/null prevents the .out files from being generated
    # awk '{print $4}' grabs the actual number instead of the word "misses:"
    MISSES=$(valgrind --tool=cachegrind --cachegrind-out-file=/dev/null ./blocked_matvec $N $B 2>&1 | grep "D1  misses:" | awk '{print $4}' | tr -d ',')
    
    # Append the result to the CSV
    echo "$B,$MISSES" >> "$OUTPUT_FILE"
    echo "Misses: $MISSES"
done

echo "Done! Results saved to $OUTPUT_FILE."