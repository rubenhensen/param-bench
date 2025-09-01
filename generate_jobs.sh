#!/bin/bash

# Create jobs directory if it doesn't exist
mkdir -p jobs

# Generate individual job scripts for each parameter count
for i in {0..19}; do
    # Copy template and replace PARAM_COUNT with actual value
    sed "s/PARAM_COUNT/$i/g" job_template.sh > "jobs/job-${i}-param.sh"
    chmod +x "jobs/job-${i}-param.sh"
    echo "Generated jobs/job-${i}-param.sh"
done

echo "Job scripts generated in jobs/ directory"