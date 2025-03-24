#!/bin/bash

# Check for required commands
command -v jq >/dev/null 2>&1 || { echo "Error: jq is required but not installed. Please install jq."; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "Error: curl is required but not installed. Please install curl."; exit 1; }
command -v git >/dev/null 2>&1 || { echo "Error: git is required but not installed. Please install git."; exit 1; }

# Create required directories
mkdir -p scripts .github/workflows

# Create the main backup script if it doesn't exist
if [ ! -f scripts/backup-repos.sh ]; then
    echo "Creating backup script..."
    # The actual script content will be added manually
    touch scripts/backup-repos.sh
    chmod +x scripts/backup-repos.sh
fi

# Create the GitHub Actions workflow file
if [ ! -f .github/workflows/backup-repos.yml ]; then
    echo "Creating GitHub Actions workflow..."
    # The actual workflow content will be added manually
    touch .github/workflows/backup-repos.yml
fi

# Validate GitLab and GitHub tokens if provided
if [ ! -z "$GITHUB_TOKEN" ] && [ ! -z "$GITHUB_ORG" ]; then
    echo "Testing GitHub token and organization..."
    GITHUB_TEST=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/orgs/$GITHUB_ORG")
    
    if [ "$GITHUB_TEST" -eq 200 ]; then
        echo "✅ GitHub token and organization are valid."
    else
        echo "❌ GitHub token or organization is invalid. Status code: $GITHUB_TEST"
    fi
fi

if [ ! -z "$GITLAB_TOKEN" ] && [ ! -z "$GITLAB_GROUP_ID" ]; then
    echo "Testing GitLab token and group..."
    GITLAB_TEST=$(curl -s -o /dev/null -w "%{http_code}" -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
        "https://gitlab.com/api/v4/groups/$GITLAB_GROUP_ID")
    
    if [ "$GITLAB_TEST" -eq 200 ]; then
        echo "✅ GitLab token and group are valid."
    else
        echo "❌ GitLab token or group is invalid. Status code: $GITLAB_TEST"
    fi
fi

echo "Setup complete. Now you need to:"
echo "1. Add the necessary script content to scripts/backup-repos.sh"
echo "2. Add the workflow content to .github/workflows/backup-repos.yml"
echo "3. Add the following secrets to your GitHub repository:"
echo "   - GITHUB_TOKEN_BACKUP (a GitHub PAT with repo access)"
echo "   - GITHUB_ORG (Your GitHub organization name)"
echo "   - GITLAB_TOKEN (Your GitLab PAT)"
echo "   - GITLAB_GROUP (Your GitLab group name)"
echo "   - GITLAB_GROUP_ID (Your GitLab group ID)"