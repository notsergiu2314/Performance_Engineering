#!/bin/bash

# Array sizes to test
# SIZES=(126000 630000 1260000 6300000 12600000 63000000 126000000 630000000)
  SIZES=(787500 1575000 3150000 6300000 12600000 25200000 50400000 100800000)

# Updated CSV header to capture Avg (Central Value), Min, and Max (Variability) for all operations
echo "ArraySize,Copy_Avg,Copy_Min,Copy_Max,Scale_Avg,Scale_Min,Scale_Max,Add_Avg,Add_Min,Add_Max,Triad_Avg,Triad_Min,Triad_Max" > stream_results_1.csv

for size in "${SIZES[@]}"; do
    echo "Compiling for array size: $size..."
    
    # Clean previous build
    make clean > /dev/null
    
    # Compile using the existing Makefile with NTIMES=10
    make stream_c.exe CFLAGS="-O3 -fopenmp -mcmodel=medium -DSTREAM_ARRAY_SIZE=$size -DNTIMES=10 -march=native" > /dev/null
    
    echo "Running 50 iterations for size $size..."
    
    # Create/clear a temporary file to store the results of the 50 runs
    > runs_temp.txt
    
    # Run the benchmark 50 times
    for i in {1..50}; do
        ./stream_c.exe > temp_output.txt
        
        # Parse the bandwidth results for this specific run
        copy=$(grep "Copy:" temp_output.txt | awk '{print $2}')
        scale=$(grep "Scale:" temp_output.txt | awk '{print $2}')
        add=$(grep "Add:" temp_output.txt | awk '{print $2}')
        triad=$(grep "Triad:" temp_output.txt | awk '{print $2}')
        
        # Save to temp file
        echo "$copy $scale $add $triad" >> runs_temp.txt

        # print the results of this run to the console for monitoring
        echo "$copy $scale $add $triad" 
    done
    
    # Process the 50 runs to find the Average, Min, and Max
    awk -v size="$size" '
        BEGIN {
            c_min=999999999; c_max=0; c_sum=0;
            s_min=999999999; s_max=0; s_sum=0;
            a_min=999999999; a_max=0; a_sum=0;
            t_min=999999999; t_max=0; t_sum=0;
            count=0;
        }
        {
            # Copy stats
            if ($1 < c_min) c_min = $1; 
            if ($1 > c_max) c_max = $1; 
            c_sum += $1;
            
            # Scale stats
            if ($2 < s_min) s_min = $2; 
            if ($2 > s_max) s_max = $2; 
            s_sum += $2;
            
            # Add stats
            if ($3 < a_min) a_min = $3; 
            if ($3 > a_max) a_max = $3; 
            a_sum += $3;
            
            # Triad stats
            if ($4 < t_min) t_min = $4; 
            if ($4 > t_max) t_max = $4; 
            t_sum += $4;
            
            count++;
        }
        END {
            # Print calculated stats as a CSV row
            printf "%s,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f\n", \
            size, c_sum/count, c_min, c_max, s_sum/count, s_min, s_max, a_sum/count, a_min, a_max, t_sum/count, t_min, t_max;
        }
    ' runs_temp.txt >> stream_results_1.csv

done

# Final cleanup
make clean > /dev/null
rm temp_output.txt runs_temp.txt
echo "Done! Results saved to stream_results_1.csv."