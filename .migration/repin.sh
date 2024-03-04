#!/bin/bash
set -euo pipefail

# set repo_name

# Check if no arguments are provided
if [ $# -eq 0 ]; then
    # Get the current Git branch name
    current_branch=$(git rev-parse --abbrev-ref HEAD)
    # Extract the substring after the first slash
    repo_name=$(echo $current_branch | cut -d'/' -f3)
else
    repo_name=$1
fi

# Extract the subfolder names
folders=$(grep "$repo_name" libs/*/cpanfile.pinned | cut -d'/' -f2)

# Iterate over each folder and execute the command
for folder in $folders; do
    echo "Executing: tools/pin.sh libs/$folder"
    tools/pin.sh "libs/$folder" 2>&1
    if [ $? -ne 0 ]; then
        echo "Error occurred with libs/$folder"
        exit 1
    fi
done

echo "All commands executed successfully."
