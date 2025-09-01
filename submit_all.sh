#!/bin/bash

echo "Submitting SAC compilation benchmark jobs to SLURM cluster..."
echo "=========================================================="

# Array to store job IDs
job_ids=()

# Submit each job and collect job IDs
for i in {0..19}; do
    echo "Submitting ${i}-param job..."
    job_id=$(sbatch jobs/job-${i}-param.sh | awk '{print $4}')
    job_ids+=($job_id)
    echo "  Job ID: $job_id"
done

echo ""
echo "All jobs submitted successfully!"
echo "Job IDs: ${job_ids[@]}"

# Save job IDs to file for monitoring
echo "${job_ids[@]}" > job_ids.txt

echo ""
echo "Monitor jobs with:"
echo "  squeue -u \$USER"
echo "  ./check_jobs.sh"
echo ""
echo "Collect results when complete with:"
echo "  ./collect_results.sh"