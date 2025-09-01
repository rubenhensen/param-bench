#!/bin/bash

# Create CSV header
echo "filename,param_count,run,compilation_time" > results.csv

# Loop through all SAC files from 0 to 19 parameters
for i in {0..9}; do
    filename="${i}-param.sac"
    echo "Benchmarking $filename..."
    
    # Run compilation 10 times for each file
    for run in {1..10}; do
        echo "  Run $run/10..."
        
        # Clean up any existing binary
        rm -f "${i}-param"
        
        # Time the compilation and capture the result
        start_time=$(date +%s.%N)
        sac2c "$filename" >/dev/null 2>&1
        end_time=$(date +%s.%N)
        
        # Calculate compilation time
        compilation_time=$(echo "$end_time - $start_time" | bc)
        
        # Append results to CSV
        echo "$filename,$i,$run,$compilation_time" >> results.csv
        
        # Clean up the binary after timing
        rm -f "${i}-param"
    done
done

echo "Benchmark complete! Results saved to results.csv"
