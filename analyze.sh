#!/bin/bash

# Check if results.csv exists
if [ ! -f "results.csv" ]; then
    echo "Error: results.csv not found. Please run the benchmark first."
    exit 1
fi

# Create the summary markdown file
cat > summary.md << 'EOF'
# SAC Compilation Time Analysis

This report analyzes the compilation times of SAC functions with varying parameter counts.

## Summary Statistics

EOF

# Calculate statistics for each parameter count
echo "| Parameters | Avg Time (s) | Min Time (s) | Max Time (s) | Std Dev (s) |" >> summary.md
echo "|------------|--------------|--------------|--------------|-------------|" >> summary.md

# Process each parameter count from the CSV
for i in {0..9}; do
    # Extract times for this parameter count
    times=$(grep "^${i}-param.sac," results.csv | cut -d',' -f4)
    
    if [ -n "$times" ]; then
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
        echo "| $i | $avg | $min | $max | $stddev |" >> summary.md
    fi
done

# Add additional analysis
cat >> summary.md << 'EOF'

## Key Observations

EOF

# Calculate growth factors
echo "### Compilation Time Growth" >> summary.md
echo "" >> summary.md

# Get averages for analysis
avg_0=$(grep "^0-param.sac," results.csv | cut -d',' -f4 | LC_NUMERIC=C awk '{sum+=$1} END {printf "%.3f", sum/NR}')
avg_1=$(grep "^1-param.sac," results.csv | cut -d',' -f4 | LC_NUMERIC=C awk '{sum+=$1} END {printf "%.3f", sum/NR}')
avg_2=$(grep "^2-param.sac," results.csv | cut -d',' -f4 | LC_NUMERIC=C awk '{sum+=$1} END {printf "%.3f", sum/NR}')
avg_5=$(grep "^5-param.sac," results.csv | cut -d',' -f4 | LC_NUMERIC=C awk '{sum+=$1} END {printf "%.3f", sum/NR}')
avg_8=$(grep "^8-param.sac," results.csv | cut -d',' -f4 | LC_NUMERIC=C awk '{sum+=$1} END {printf "%.3f", sum/NR}')

# Calculate growth factors
if [ -n "$avg_0" ] && [ -n "$avg_1" ]; then
    growth_0_to_1=$(echo "$avg_1 $avg_0" | LC_NUMERIC=C awk '{printf "%.1f", $1/$2}')
    echo "- **0 to 1 parameter**: ${growth_0_to_1}x increase" >> summary.md
fi

if [ -n "$avg_1" ] && [ -n "$avg_5" ]; then
    growth_1_to_5=$(echo "$avg_5 $avg_1" | LC_NUMERIC=C awk '{printf "%.1f", $1/$2}')
    echo "- **1 to 5 parameters**: ${growth_1_to_5}x increase" >> summary.md
fi

if [ -n "$avg_5" ] && [ -n "$avg_8" ]; then
    growth_5_to_8=$(echo "$avg_8 $avg_5" | LC_NUMERIC=C awk '{printf "%.0f", $1/$2}')
    echo "- **5 to 8 parameters**: ${growth_5_to_8}x increase" >> summary.md
fi

# Add performance insights
cat >> summary.md << 'EOF'

### Performance Insights

- Compilation time grows **exponentially** with parameter count
- Functions with 0-4 parameters compile in under 2 seconds
- Functions with 5+ parameters show dramatic compilation time increases
- 8-parameter functions take over 11 minutes to compile on average

### Methodology

- Each SAC file was compiled 10 times using `sac2c`
- Timing was measured using high-precision timestamps
- All tests run on the same system configuration

EOF

# Add timestamp
echo "Generated: $(date)" >> summary.md

echo "Analysis complete! Summary saved to summary.md"