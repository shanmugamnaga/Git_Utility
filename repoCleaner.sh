#!/bin/bash

CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

# User-defined time window (default: 1 year = 365 days)
TIME_WINDOW=${1:-365}

# Read repositories from the file
repos=$(cat masterRepoList.txt)

# Loop through each repo
for repo_url in $repos; do
    # Extract repo name
    repo_name=$(basename "$repo_url" .git)


    # echo "*************************************************************************************************************"
    echo "								"
    echo -e "            ------------------- Processing repository: ${CYAN}$repo_name${NC} ------------------- "
    echo "  "

    # Clone repo if not already cloned
    if [ ! -d "$repo_name" ]; then
        git clone "$repo_url"
    fi

    # Go into the repo folder
    cd "$repo_name" || exit

    # Fetch all branches
    git fetch --all

    # List branches
    branches=$(git branch -r | grep -v '\->' | sed 's/origin\///')

    # Track branch stats
    total_branches=0
    stale_branches=()

    # Analyze branches
    for branch in $branches; do
        total_branches=$((total_branches + 1))

        # Get last commit date
        last_commit_date=$(git log -1 --format="%ci" origin/"$branch")
        commit_date_epoch=$(date -d "$last_commit_date" +%s)
        current_date_epoch=$(date +%s)
        age_days=$(( (current_date_epoch - commit_date_epoch) / 86400 ))

        # Check if branch is stale
        if [ $age_days -gt $TIME_WINDOW ]; then
            stale_branches+=("$branch")
        fi
    done

    # Print branch stats
    echo "Total branches in $repo_name: $total_branches"
    echo "Total stale branches (older than $TIME_WINDOW days): ${#stale_branches[@]}"

    # If all branches are stale
    if [ ${#stale_branches[@]} -eq "$total_branches" ]; then
        echo -e "All branches are stale in $repo_name. ${RED}Consider deleting the entire repository!${NC}"
        echo "								"

        echo "*************************************************************************************************************"
    else
        # Proceed with stale branch deletion
        if [ ${#stale_branches[@]} -eq 0 ]; then
            echo "No stale branches found in $repo_name."
        else
            echo "Stale branches detected in $repo_name: ${stale_branches[*]}"
            echo "								"
            echo "--- Action ---"
            echo "								"
            echo "Select branches to delete (comma-separated, or type 'all' to delete all stale branches):"
            read -p "> " selected_branches

            if [[ "$selected_branches" == "all" ]]; then
                selected_branches="${stale_branches[*]}"
            fi

            IFS=',' read -ra branches_to_delete <<< "$selected_branches"
            deleted_count=0

            for branch in "${branches_to_delete[@]}"; do
                branch=$(echo $branch | xargs)
                if [[ " ${stale_branches[@]} " =~ " $branch " ]]; then
                    git push origin --delete "$branch"
                    echo "Deleted branch: $branch"
                    deleted_count=$((deleted_count + 1))
                else
                    echo "Branch $branch is not stale or doesn’t exist!"
                    echo "                                                 "
                fi
            done

            # Executive summary
            echo "--- Executive Summary ---"
            echo "								"
            echo "Repository: $repo_name"
            echo "Total branches: $total_branches"
            echo "Stale branches detected: ${#stale_branches[@]}"
            echo "Branches deleted: $deleted_count"
            echo "  " 
            echo "*************************************************************************************************************"
        fi
    fi

    # Go back to the parent directory
    cd ..
done
