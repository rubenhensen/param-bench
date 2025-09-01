#!/bin/bash
#SBATCH --job-name=sac-19-param
#SBATCH --output=slurm-19-param-%j.out
#SBATCH --error=slurm-19-param-%j.err
#SBATCH --time=02:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --account=csmpi
#SBATCH --partition=csmpi_fpga_long
#SBATCH --gres=gpu:0

# Load any required modules (adjust as needed for your cluster)
# module load gcc/9.3.0

# Set up environment
# Use SBATCH_SUBMIT_DIR (newer) or fallback to current directory
if [ -n "$SBATCH_SUBMIT_DIR" ]; then
    cd "$SBATCH_SUBMIT_DIR"
elif [ -n "$SLURM_SUBMIT_DIR" ]; then
    cd "$SLURM_SUBMIT_DIR"
else
    echo "Warning: No submit directory found, staying in current directory: $(pwd)"
fi

# Create results file for this job
echo "filename,param_count,run,compilation_time,job_id,node" > results-19-param.csv

filename="19-param.sac"
echo "Starting benchmark for $filename on node $(hostname)"
echo "Job ID: $SLURM_JOB_ID"

# Run compilation 10 times
for run in {1..10}; do
    echo "Run $run/10 for $filename..."
    
    # Clean up any existing binary
    # rm -f "19-param"
    
    # Time the compilation
    start_time=$(date +%s.%N)
    /home/rhensen/orig/sac2c/build_p/sac2c_p -v4 "$filename" 
    # >/dev/null 2>&1
    compilation_result=$?
    end_time=$(date +%s.%N)
    
    # Calculate compilation time
    compilation_time=$(echo "$end_time - $start_time" | bc)
    
    # Record results with job info
    echo "$filename,19,$run,$compilation_time,$SLURM_JOB_ID,$(hostname)" >> results-19-param.csv
    
    # Clean up binary
    rm -f "19-param"
done

echo "Benchmark complete for $filename"
echo "Results saved to results-19-param.csv"
