#!/bin/bash
set -euo pipefail

# Check if a branch name is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <branch_name>"
    exit 1
fi

branch_name=$1

# Function to check if the current directory is a Git repository root
is_git_repo_root() {
    # Check if .git directory or file exists in the current directory
    if [ -d ".git" ] || git rev-parse --git-dir > /dev/null 2>&1; then
        # Check if the current directory is the root of the Git repository
        if [ "$(git rev-parse --show-toplevel)" = "$(pwd)" ]; then
            return 0 # True, it is the root
        fi
    fi
    return 1 # False, it is not the root
}

# Function to check if the current Git repository is 'sf-perl'
is_sf_perl_repo() {
    # Get the URL of the remote repository named 'origin'
    repo_url=$(git remote get-url origin 2>/dev/null || echo "")
    if [[ "$repo_url" =~ sf-perl ]]; then
        return 0 # True, it matches 'sf-perl'
    fi
    return 1 # False, it does not match
}

# Check if the current directory is a Git repository root and if it is 'sf-perl'
if is_git_repo_root && is_sf_perl_repo; then
    echo "The current directory is the root of the 'sf-perl' Git project."
else
    echo "The current directory is NOT the root of the 'sf-perl' Git project."
    exit 1
fi

# Clear workspace
git checkout main # Attempt to checkout main, if it fails, try master
git fetch origin
git reset --hard origin/main # Reset to remote main/master
git clean -d -f # Clean all untracked files in your git workdir

# Check if project already exists
if [ -d "./libs/$branch_name" ]; then
    echo "The path './libs/$branch_name' exists in the Git repository."
    exit 1
fi

# Add project
git subtree add --prefix=libs/$branch_name git@github.com:SocialFlowDev/$branch_name.git master || {
    echo "Failed to add the subtree for $branch_name."
    exit 1
}
git switch -c sf-perl-migration/$branch_name || git checkout -b sf-perl-migration/$branch_name
