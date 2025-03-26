#!/bin/bash

# Load environment variables from .env file
ENV_FILE=".env"

# Check if .env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo "Error: .env file not found at $ENV_FILE"
    exit 1
fi

# Read .env file and export variables
set -a
source "$ENV_FILE"
set +a

# Check if required environment variables are set
REQUIRED_VARS=("GH_PAT" "GH_ORG" "GL_TOKEN" "GL_GROUP" "GL_GROUP_ID" 
               "AWS_ACCESS_KEY_ID" "AWS_SECRET_ACCESS_KEY" "AWS_REGION" "S3_BUCKET")
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        echo "Error: $var is not set in the .env file."
        exit 1
    fi
done

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

# Test AWS S3 configuration
echo -e "\nTesting AWS S3 configuration..."

# Verify AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is not installed. Please install it first."
    exit 1
fi

# Configure AWS credentials
aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID"
aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"
aws configure set default.region "$AWS_REGION"

# Test S3 bucket listing
echo "Checking S3 bucket access..."
S3_LIST_TEST=$(aws s3 ls "s3://$S3_BUCKET" 2>&1)
if [ $? -ne 0 ]; then
    echo "❌ Failed to list S3 bucket contents."
    echo "Error: $S3_LIST_TEST"
    exit 1
fi

# Test S3 write and delete permissions
echo "Testing S3 write and delete permissions..."
TEMP_TEST_FILE="test-backup-$(date +%s).txt"
echo "Backup test file" > "$TEMP_TEST_FILE"

# Try to upload the file
aws s3 cp "$TEMP_TEST_FILE" "s3://$S3_BUCKET/$TEMP_TEST_FILE"
if [ $? -ne 0 ]; then
    echo "❌ Failed to upload test file to S3 bucket."
    rm "$TEMP_TEST_FILE"
    exit 1
fi

# Try to delete the uploaded file
aws s3 rm "s3://$S3_BUCKET/$TEMP_TEST_FILE"
if [ $? -ne 0 ]; then
    echo "❌ Failed to delete test file from S3 bucket."
    rm "$TEMP_TEST_FILE"
    exit 1
fi

# Clean up local test file
rm "$TEMP_TEST_FILE"

echo -e "\n✅ All tests passed successfully!"
echo "Your GitHub, GitLab, and AWS configurations are working correctly."
echo "You can now proceed with setting up the backup workflow."