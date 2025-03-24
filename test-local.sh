#!/bin/bash

# Check if required environment variables are set
if [ -z "$GH_PAT" ] || [ -z "$GH_ORG" ] || [ -z "$GL_TOKEN" ] || \
    [ -z "$GL_GROUP" ] || [ -z "$GL_GROUP_ID" ]; then
    echo "Error: Required environment variables are not set."
    echo "Please set the following variables:"
    echo "  GH_PAT - Your GitHub personal access token"
    echo "  GH_ORG - GitHub organization name"
    echo "  GL_TOKEN - Your GitLab personal access token"
    echo "  GL_GROUP - GitLab group name"
    echo "  GL_GROUP_ID - GitLab group ID (numeric)"
    exit 1
fi

# Test GitHub API access
echo "Testing GitHub API access..."
GITHUB_REPOS=$(curl -s -H "Authorization: token $GH_PAT" \
    "https://api.github.com/orgs/$GH_ORG/repos?per_page=5" | jq -r '.[].name')

if [ -z "$GITHUB_REPOS" ]; then
    echo "❌ Failed to fetch repositories from GitHub."
    echo "Please check your GitHub token and organization name."
    exit 1
else
    echo "✅ Successfully fetched repositories from GitHub:"
    echo "$GITHUB_REPOS" | head -n 5
fi

# Test GitLab API access
echo -e "\nTesting GitLab API access..."
GL_GROUP_INFO=$(curl -s -H "PRIVATE-TOKEN: $GL_TOKEN" \
    "https://gitlab.com/api/v4/groups/$GL_GROUP_ID")

GL_GROUP_NAME=$(echo $GL_GROUP_INFO | jq -r '.name')

if [ "$GL_GROUP_NAME" == "null" ] || [ -z "$GL_GROUP_NAME" ]; then
    echo "❌ Failed to access GitLab group."
    echo "Please check your GitLab token and group ID."
    exit 1
else
    echo "✅ Successfully accessed GitLab group: $GL_GROUP_NAME"
fi

# Test creating a temporary project in GitLab
echo -e "\nTesting project creation in GitLab..."
TEMP_PROJECT_NAME="test-backup-delete-me-$(date +%s)"

CREATE_RESPONSE=$(curl -s -X POST -H "PRIVATE-TOKEN: $GL_TOKEN" \
    -H "Content-Type: application/json" \
    "https://gitlab.com/api/v4/projects" \
    -d "{
        \"name\": \"$TEMP_PROJECT_NAME\",
        \"namespace_id\": $GL_GROUP_ID,
        \"visibility\": \"private\",
        \"description\": \"Temporary test project\"
    }")

TEMP_PROJECT_ID=$(echo $CREATE_RESPONSE | jq -r '.id')

if [ "$TEMP_PROJECT_ID" == "null" ] || [ -z "$TEMP_PROJECT_ID" ]; then
    echo "❌ Failed to create test project in GitLab."
    echo "Response: $CREATE_RESPONSE"
    echo "Please check your GitLab token permissions."
    exit 1
else
    echo "✅ Successfully created test project in GitLab: $TEMP_PROJECT_NAME (ID: $TEMP_PROJECT_ID)"
    
    # Clean up the test project
    echo "Deleting test project..."
    curl -s -X DELETE -H "PRIVATE-TOKEN: $GL_TOKEN" \
        "https://gitlab.com/api/v4/projects/$TEMP_PROJECT_ID"
    echo "✅ Test project deleted."
fi

echo -e "\nAll tests passed! Your configuration appears to be working correctly."
echo "You can now set up the GitHub Actions workflow."