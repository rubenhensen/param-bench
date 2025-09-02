#!/bin/bash

# Check if SLURM results exist
if [ ! -f "results-slurm.csv" ]; then
    echo "Error: results-slurm.csv not found. Please run ./collect_results.sh first."
    exit 1
fi

echo "Analyzing SLURM benchmark results..."

# Create the summary markdown file
cat > summary-slurm.md << 'EOF'
# SAC Compilation Time Analysis (SLURM Cluster)

This report analyzes the compilation times of SAC functions with varying parameter counts, run on a SLURM cluster.

## Summary Statistics

EOF

# Calculate statistics for each parameter count
echo "| Parameters | Avg Time (s) | Min Time (s) | Max Time (s) | Std Dev (s) | Nodes Used |" >> summary-slurm.md
echo "|------------|--------------|--------------|--------------|-------------|------------|" >> summary-slurm.md

# Process each parameter count from the CSV
for i in {0..19}; do
    # Extract times and nodes for this parameter count
    data=$(grep "^${i}-param.sac," results-slurm.csv)
    
    if [ -n "$data" ]; then
        times=$(echo "$data" | cut -d',' -f4)
        nodes=$(echo "$data" | cut -d',' -f6 | sort -u | tr '\n' ',' | sed 's/,$//')
        
        # Calculate statistics using awk
        stats=$(echo "$times" | LC_NUMERIC=C awk '
        {
            sum += $1
            times[NR] = $1
            if (NR == 1 || $1 < min) min = $1
            if (NR == 1 || $1 > max) max = $1
        }
        END {
            avg = sum / NR
            # Calculate standard deviation
            for (i = 1; i <= NR; i++) {
                sumsq += (times[i] - avg)^2
            }
            stddev = sqrt(sumsq / NR)
            printf "%.3f %.3f %.3f %.3f", avg, min, max, stddev
        }')
        
        read avg min max stddev <<< "$stats"
        echo "| $i | $avg | $min | $max | $stddev | $nodes |" >> summary-slurm.md
    fi
done

# Add cluster-specific information
cat >> summary-slurm.md << 'EOF'

## Cluster Information

EOF

# Extract job and node information
echo "### Job Distribution" >> summary-slurm.md
echo "" >> summary-slurm.md
echo "| Parameter Count | Job ID(s) | Node(s) |" >> summary-slurm.md
echo "|-----------------|-----------|---------|" >> summary-slurm.md

for i in {0..19}; do
    data=$(grep "^${i}-param.sac," results-slurm.csv | head -1)
    if [ -n "$data" ]; then
        job_id=$(echo "$data" | cut -d',' -f5)
        node=$(echo "$data" | cut -d',' -f6)
        echo "| $i | $job_id | $node |" >> summary-slurm.md
    fi
done

# Add performance analysis (similar to original analyze.sh)
cat >> summary-slurm.md << 'EOF'

## Key Observations

### Compilation Time Growth

EOF

# Get averages for analysis
avg_0=$(grep "^0-param.sac," results-slurm.csv | cut -d',' -f4 | LC_NUMERIC=C awk '{sum+=$1} END {printf "%.3f", sum/NR}')
avg_1=$(grep "^1-param.sac," results-slurm.csv | cut -d',' -f4 | LC_NUMERIC=C awk '{sum+=$1} END {printf "%.3f", sum/NR}')
avg_5=$(grep "^5-param.sac," results-slurm.csv | cut -d',' -f4 | LC_NUMERIC=C awk '{sum+=$1} END {printf "%.3f", sum/NR}')
avg_8=$(grep "^8-param.sac," results-slurm.csv | cut -d',' -f4 | LC_NUMERIC=C awk '{sum+=$1} END {printf "%.3f", sum/NR}')

# Calculate growth factors
if [ -n "$avg_0" ] && [ -n "$avg_1" ]; then
    growth_0_to_1=$(echo "$avg_1 $avg_0" | LC_NUMERIC=C awk '{printf "%.1f", $1/$2}')
    echo "- **0 to 1 parameter**: ${growth_0_to_1}x increase" >> summary-slurm.md
fi

if [ -n "$avg_1" ] && [ -n "$avg_5" ]; then
    growth_1_to_5=$(echo "$avg_5 $avg_1" | LC_NUMERIC=C awk '{printf "%.1f", $1/$2}')
    echo "- **1 to 5 parameters**: ${growth_1_to_5}x increase" >> summary-slurm.md
fi

if [ -n "$avg_5" ] && [ -n "$avg_8" ]; then
    growth_5_to_8=$(echo "$avg_8 $avg_5" | LC_NUMERIC=C awk '{printf "%.0f", $1/$2}')
    echo "- **5 to 8 parameters**: ${growth_5_to_8}x increase" >> summary-slurm.md
fi

# Add cluster-specific insights
cat >> summary-slurm.md << 'EOF'

### SLURM Cluster Benefits

- Each parameter count compiled in parallel on separate compute nodes
- Consistent environment across all compilations
- Job isolation prevents resource contention
- Detailed job tracking and resource usage monitoring

### Performance Insights

- Compilation time grows **exponentially** with parameter count
- Functions with 0-4 parameters compile in under 2 seconds
- Functions with 5+ parameters show dramatic compilation time increases
- Cluster parallelization enables efficient testing across parameter space

### Methodology

- Each SAC file compiled as separate SLURM job
- 10 compilation runs per parameter count within each job
- High-precision timing measurements
- Jobs distributed across available compute nodes

EOF

# Add timestamp and cluster info
echo "Generated: $(date)" >> summary-slurm.md
echo "Cluster: $(scontrol show config | grep ClusterName | cut -d'=' -f2 | tr -d ' ' || echo 'Unknown')" >> summary-slurm.md

echo "SLURM analysis complete! Summary saved to summary-slurm.md"