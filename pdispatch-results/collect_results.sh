#!/bin/bash

echo "Collecting SLURM job results..."
echo "==============================="

# Create combined results file
echo "filename,param_count,run,compilation_time,job_id,node" > results-slurm.csv

# Check if individual result files exist and combine them
results_found=0
missing_results=()

for i in {0..19}; do
    result_file="results-${i}-param.csv"
    if [ -f "$result_file" ]; then
        echo "Found results for ${i}-param"
        # Skip header and append to combined file
        tail -n +2 "$result_file" >> results-slurm.csv
        results_found=$((results_found + 1))
    else
        echo "Missing results for ${i}-param"
        missing_results+=($i)
    fi
done

echo ""
echo "Results Summary:"
echo "Found: $results_found/20 result files"

if [ ${#missing_results[@]} -gt 0 ]; then
    echo "Missing: ${missing_results[@]}"
    echo ""
    echo "Check job status with:"
    echo "  ./check_jobs.sh"
    echo ""
    echo "Check SLURM output files:"
    for missing in "${missing_results[@]}"; do
        echo "  ls slurm-${missing}-param-*.out"
    done
else
    echo "All results collected successfully!"
    echo ""
    echo "Combined results saved to: results-slurm.csv"
    echo "Total data points: $(tail -n +2 results-slurm.csv | wc -l)"
    echo ""
    echo "Generate analysis with:"
    echo "  ./analyze-slurm.sh"
fi