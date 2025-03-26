#!/bin/bash

set -e
echo "Starting GitHub organization backup to GitLab and Amazon S3..."
echo "GitHub Organization: $GH_ORG"
echo "GitLab Group: $GL_GROUP"
echo "S3 Bucket: $S3_BUCKET"

# Create backup report file
mkdir -p backup-report
touch backup-report.txt

# Configure git
git config --global user.name "GitHub Backup Bot"
git config --global user.email "backup-bot@example.com"

# Install AWS CLI if not already present
if ! command -v aws &> /dev/null; then
    echo "Installing AWS CLI..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    rm -rf aws awscliv2.zip
fi

# Configure AWS credentials
aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID"
aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"
aws configure set default.region "$AWS_REGION"

# Get list of all repositories from GitHub organization
echo "Fetching repository list from GitHub..."
REPOS=$(curl -s -H "Authorization: token $GH_PAT" \
    "https://api.github.com/orgs/$GH_ORG/repos?per_page=100" | \
    jq -r '.[].name')

# For each repository, create or update backup in GitLab and S3
for REPO in $REPOS; do
    echo "-----------------------------------------"
    echo "Processing repository: $REPO"
    echo "Processing repository: $REPO" >> backup-report.txt
    
    # Check if the repo already exists in GitLab
    REPO_EXISTS=$(curl -s -H "PRIVATE-TOKEN: $GL_TOKEN" \
        "https://gitlab.com/api/v4/groups/$GL_GROUP_ID/projects?search=$REPO" | \
        jq --arg REPO "$REPO" '.[] | select(.name==$REPO) | .id')
    
    # If repo doesn't exist, create it
    if [ -z "$REPO_EXISTS" ]; then
        echo "Creating new repository in GitLab: $REPO"
        curl -s -X POST -H "PRIVATE-TOKEN: $GL_TOKEN" \
        -H "Content-Type: application/json" \
        "https://gitlab.com/api/v4/projects" \
        -d "{
            \"name\": \"$REPO\",
            \"namespace_id\": $GL_GROUP_ID,
            \"visibility\": \"private\",
            \"description\": \"Backup of GitHub repository $GH_ORG/$REPO\"
        }" > /dev/null
        
        echo "Repository created in GitLab" >> backup-report.txt
        # Wait a moment for GitLab to set up the repository
        sleep 5
    else
        echo "Repository already exists in GitLab: $REPO"
        echo "Repository already exists in GitLab" >> backup-report.txt
    fi
    
    # Perform the backup
    echo "Cloning repository from GitHub..."
    
    # Create temp directory for repo
    TEMP_DIR=$(mktemp -d)
    cd $TEMP_DIR
    
    # First, get the default branch for this repository
    DEFAULT_BRANCH=$(curl -s -H "Authorization: token $GH_PAT" \
        "https://api.github.com/repos/$GH_ORG/$REPO" | \
        jq -r '.default_branch')
        
    echo "Default branch for $REPO is: $DEFAULT_BRANCH"
    
    # Clone using the default branch (full clone, not shallow)
    if [ -n "$DEFAULT_BRANCH" ]; then
        git clone --branch $DEFAULT_BRANCH https://${GH_PAT}@github.com/${GH_ORG}/${REPO}.git
        
        if [ $? -ne 0 ]; then
            # Try without specifying a branch if that fails
            echo "Default branch clone failed, trying without branch specification..."
            git clone https://${GH_PAT}@github.com/${GH_ORG}/${REPO}.git
            
            if [ $? -ne 0 ]; then
                echo "ERROR: Could not clone repository $REPO" >> backup-report.txt
                cd ..
                rm -rf $TEMP_DIR
                continue
            fi
        fi
    else
        # If we couldn't determine the default branch, try without specifying one
        git clone https://${GH_PAT}@github.com/${GH_ORG}/${REPO}.git
        
        if [ $? -ne 0 ]; then
            echo "ERROR: Could not clone repository $REPO" >> backup-report.txt
            cd ..
            rm -rf $TEMP_DIR
            continue
        fi
    fi
    
    cd $REPO
    
    # Get the primary branch name (the one we actually cloned)
    PRIMARY_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    
    # Set the GitLab repository as a remote and push
    echo "Pushing to GitLab..."
    git remote add gitlab https://oauth2:${GL_TOKEN}@gitlab.com/${GL_GROUP}/${REPO}.git
    git push -f gitlab $PRIMARY_BRANCH:main
    
    if [ $? -eq 0 ]; then
        echo "Successfully backed up $REPO to GitLab" >> backup-report.txt
    else
        echo "ERROR: Failed to push $REPO to GitLab" >> backup-report.txt
    fi
    
    # Backup to Amazon S3
    echo "Backing up to Amazon S3..."
    BACKUP_FILENAME="${REPO}-$(date +"%Y%m%d").tar.gz"
    tar -czvf "$BACKUP_FILENAME" .
    
    # Upload to S3 with date-based versioning
    aws s3 cp "$BACKUP_FILENAME" "s3://$S3_BUCKET/$GH_ORG/$REPO/$BACKUP_FILENAME"
    
    if [ $? -eq 0 ]; then
        echo "Successfully backed up $REPO to S3" >> backup-report.txt
    else
        echo "ERROR: Failed to backup $REPO to S3" >> backup-report.txt
    fi
    
    # Clean up local backup file
    rm "$BACKUP_FILENAME"
    
    # Clean up
    cd ../..
    rm -rf $TEMP_DIR
done

echo "-----------------------------------------"
echo "Backup process completed."
echo "See backup-report.txt for details."