#!/bin/bash
set -euo pipefail


# Check if no arguments are provided
if [ $# -eq 0 ]; then
    # Get the current Git branch name
    current_branch=$(git rev-parse --abbrev-ref HEAD)
    # Extract the substring after the first slash
    repo_name=${current_branch#*/}
    input_file="./libs/$repo_name/dist.ini"
    temp_file="./libs/$repo_name/temp_dist.ini"
else
    repo_name=$1
    input_file=$1
    temp_file="temp_dist.ini"
fi

# Get current year and month
year=$(date +%Y)
month=$(date +%m)
version="version = ${year}.${month}_0"

# Initialize variables
declare -A sections
no_tag_items=()
section=""

# Process the input file
while IFS= read -r line
do
    if [[ $line == \[*\] ]]; then
        section=$line
        sections[$section]=""
    elif [[ $line == \;*\]]]; then
        continue
    elif [[ -n $section ]]; then
        sections[$section]+="$line\n"
    elif [[ -n $line ]]; then
        no_tag_items+=("$line")
    fi
done < "$input_file"

# Add version to no-tag items
no_tag_items+=("$version")

# Add new sections
sections["[Prereqs::FromCPANfile]"]=""
sections["[MetaProvides::Package]"]=""

# Remove unwanted sections
for tag in "${!sections[@]}"; do
    if [[ $tag == \[Git:* || $tag == \[SocialFlow::Release] || $tag == \[Prereqs] || $tag == \[AutoPrereqs] ]]; then
        unset sections["$tag"]
    fi
done

# Remove 'first_version' line from [PkgVersion] section
if [[ ${sections["[PkgVersion]"]+_} ]]; then
    sections["[PkgVersion]"]=$(echo -e "${sections["[PkgVersion]"]}" | grep -v 'first_version')
fi

# Sort sections
IFS=$'\n' sorted=($(sort <<<"${!sections[*]}"))
unset IFS

# init temp_file
echo -n > $temp_file

# Write no-tag items to output file
for item in "${no_tag_items[@]}"; do
    echo "$item" >> $temp_file
done

echo '' >> $temp_file

# Write sorted sections and their items to output file
for section in "${sorted[@]}"; do
    if [[ ${sections[$section]+_} ]]; then
        printf "%s\n" "$section" >> $temp_file
        if [[ -n ${sections[$section]} ]]; then
            printf "%b" "${sections[$section]}" >> $temp_file
        fi
    fi
done

# Clear the input file and write the updated content into it
cat $temp_file > $input_file

# Remove the temporary output file
rm $temp_file