#!/bin/bash

echo "SAC Benchmark Job Status"
echo "======================="

if [ -f "job_ids.txt" ]; then
    job_ids=($(cat job_ids.txt))
    echo "Monitoring ${#job_ids[@]} jobs: ${job_ids[@]}"
    echo ""
    
    # Check status of each job
    for i in {0..19}; do
        job_id=${job_ids[$i]}
        if [ -n "$job_id" ]; then
            status=$(squeue -h -j $job_id -o "%T" 2>/dev/null || echo "COMPLETED/NOT_FOUND")
            echo "${i}-param job ($job_id): $status"
        fi
    done
    
    echo ""
    echo "Overall queue status:"
    squeue -u $USER --format="%.8i %.12j %.8T %.10M %.9l %.6D %R" | grep sac- || echo "No SAC jobs found in queue"
    
else
    echo "No job_ids.txt found. Run ./submit_all.sh first."
fi