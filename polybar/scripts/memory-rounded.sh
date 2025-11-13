#!/usr/bin/env bash

# Script to display memory usage with rounded values in GB format
# Usage: memory-rounded.sh

# Get memory info from /proc/meminfo
meminfo=$(cat /proc/meminfo)

# Extract values in KB
mem_total=$(echo "$meminfo" | grep "^MemTotal:" | awk '{print $2}')
mem_available=$(echo "$meminfo" | grep "^MemAvailable:" | awk '{print $2}')

# Calculate used memory
mem_used=$((mem_total - mem_available))

# Convert to GB and round
mem_total_gb=$(( (mem_total + 512*1024) / (1024*1024) ))
mem_used_gb=$(( (mem_used + 512*1024) / (1024*1024) ))

# Calculate percentage
mem_percent=$(( mem_used * 100 / mem_total ))

# Display format: "8/15GB" or percentage
echo "${mem_used_gb}/${mem_total_gb}GB"

