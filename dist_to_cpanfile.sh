#!/bin/bash
set -euo pipefail

# Check if no arguments are provided
if [ $# -eq 0 ]; then
    # Get the current Git branch name
    current_branch=$(git rev-parse --abbrev-ref HEAD)
    # Extract the substring after the first slash
    repo_name=${current_branch#*/}
else
    repo_name=$1
fi

dist_path="./libs/$repo_name/dist.ini"
cpanfile_path="./libs/$repo_name/cpanfile"
# Check if dist.ini exists
if [ ! -f "$dist_path" ]; then
    echo "$dist_path does not exist."
    exit 1
fi

# Use awk to process the dist.ini file and avoid empty values
awk '
BEGIN {print_mode=0;}
/^\[Prereqs/ {print_mode=1; next}
print_mode && /^\[/ {print_mode=0}
print_mode && !/^;/ && !/^skip/ {
    split($0, parts, " = ");
    key=parts[1];
    value=parts[2];
    if (key != "" && value != "") {
        print "requires \047"key"\047, \047"value"\047;";
    }
}
' "$dist_path" > "$cpanfile_path"

# add test reqs
echo "requires 'Test::Compile::Internal';" >> "$cpanfile_path"

# check SocialFlow::Deploy
if grep -q "SocialFlow::Deploy" "$dist_path"; then
    echo "Check repo sf-deploy-application,"
    echo "If the dependency exists, "
    echo "SocialFlow::Deploy must also be added to the cpanfile."
fi
