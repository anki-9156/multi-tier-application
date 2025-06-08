#!/bin/bash
set -e

echo "🏗️ Setting up ECR repositories..."

# Get AWS region and account ID
AWS_REGION=${AWS_REGION:-us-east-1}
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Repository names
FRONTEND_REPO="ecommerce/frontend"
BACKEND_REPO="ecommerce/backend"

echo "AWS Account ID: $AWS_ACCOUNT_ID"
echo "AWS Region: $AWS_REGION"

# Function to create ECR repository
create_repo() {
    local repo_name=$1
    echo "Creating ECR repository: $repo_name"
    
    # Check if repository exists
    if aws ecr describe-repositories --repository-names $repo_name --region $AWS_REGION >/dev/null 2>&1; then
        echo "✅ Repository $repo_name already exists"
    else
        echo "Creating repository $repo_name..."
        aws ecr create-repository \
            --repository-name $repo_name \
            --region $AWS_REGION \
            --image-scanning-configuration scanOnPush=true
        echo "✅ Repository $repo_name created successfully"
    fi
}

# Create repositories
create_repo $FRONTEND_REPO
create_repo $BACKEND_REPO

# Set lifecycle policies to manage image retention
echo "Setting up lifecycle policies..."

# Frontend lifecycle policy
cat > /tmp/frontend-lifecycle.json << 'EOF'
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Keep last 10 images",
            "selection": {
                "tagStatus": "any",
                "countType": "imageCountMoreThan",
                "countNumber": 10
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF

# Backend lifecycle policy
cat > /tmp/backend-lifecycle.json << 'EOF'
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Keep last 10 images",
            "selection": {
                "tagStatus": "any",
                "countType": "imageCountMoreThan",
                "countNumber": 10
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF

# Apply lifecycle policies
aws ecr put-lifecycle-policy \
    --repository-name $FRONTEND_REPO \
    --lifecycle-policy-text file:///tmp/frontend-lifecycle.json \
    --region $AWS_REGION

aws ecr put-lifecycle-policy \
    --repository-name $BACKEND_REPO \
    --lifecycle-policy-text file:///tmp/backend-lifecycle.json \
    --region $AWS_REGION

echo "✅ Lifecycle policies applied"

# Display repository information
echo ""
echo "📊 ECR Repository Information:"
echo "Frontend Repository URI: $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$FRONTEND_REPO"
echo "Backend Repository URI: $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$BACKEND_REPO"
echo ""
echo "🔐 To login to ECR from your local machine:"
echo "aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
echo ""
echo "✅ ECR setup completed successfully!" 