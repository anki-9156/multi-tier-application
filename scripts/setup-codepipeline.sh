#!/bin/bash
set -e

echo "🚀 Setting up AWS CodePipeline for Multi-Tier Application..."

# Configuration
STACK_NAME="ecommerce-codepipeline"
REGION="us-east-1"
TEMPLATE_FILE="cloudformation/codepipeline.yml"

# Check if required parameters are provided
if [ -z "$GITHUB_OWNER" ]; then
    echo "❌ Error: GITHUB_OWNER environment variable is required"
    echo "Usage: export GITHUB_OWNER=your-github-username && ./setup-codepipeline.sh"
    exit 1
fi

if [ -z "$GITHUB_TOKEN" ]; then
    echo "❌ Error: GITHUB_TOKEN environment variable is required"
    echo "You need a GitHub Personal Access Token with repo permissions"
    echo "Create one at: https://github.com/settings/tokens"
    echo "Usage: export GITHUB_TOKEN=your-token && ./setup-codepipeline.sh"
    exit 1
fi

if [ -z "$DB_PASSWORD" ]; then
    echo "❌ Error: DB_PASSWORD environment variable is required"
    echo "Usage: export DB_PASSWORD=your-db-password && ./setup-codepipeline.sh"
    exit 1
fi

if [ -z "$JWT_SECRET" ]; then
    echo "❌ Error: JWT_SECRET environment variable is required"
    echo "Usage: export JWT_SECRET=your-jwt-secret && ./setup-codepipeline.sh"
    exit 1
fi

# Set defaults
GITHUB_REPO=${GITHUB_REPO:-"multi-tier-application"}
GITHUB_BRANCH=${GITHUB_BRANCH:-"aws-code-pipeline"}

echo "📋 Configuration:"
echo "  Stack Name: $STACK_NAME"
echo "  Region: $REGION"
echo "  GitHub Owner: $GITHUB_OWNER"
echo "  GitHub Repo: $GITHUB_REPO"
echo "  GitHub Branch: $GITHUB_BRANCH"
echo "  Template: $TEMPLATE_FILE"

# Check if CloudFormation template exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "❌ Error: CloudFormation template not found: $TEMPLATE_FILE"
    exit 1
fi

# Check if stack already exists
STACK_EXISTS=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION --query 'Stacks[0].StackName' --output text 2>/dev/null || echo "None")

if [ "$STACK_EXISTS" = "$STACK_NAME" ]; then
    echo "📝 Stack already exists. Updating..."
    
    aws cloudformation update-stack \
        --stack-name $STACK_NAME \
        --template-body file://$TEMPLATE_FILE \
        --parameters \
            ParameterKey=GitHubOwner,ParameterValue=$GITHUB_OWNER \
            ParameterKey=GitHubRepo,ParameterValue=$GITHUB_REPO \
            ParameterKey=GitHubBranch,ParameterValue=$GITHUB_BRANCH \
            ParameterKey=GitHubToken,ParameterValue=$GITHUB_TOKEN \
            ParameterKey=DatabasePassword,ParameterValue=$DB_PASSWORD \
            ParameterKey=JWTSecret,ParameterValue=$JWT_SECRET \
        --capabilities CAPABILITY_NAMED_IAM \
        --region $REGION
    
    echo "⏳ Waiting for stack update to complete..."
    aws cloudformation wait stack-update-complete --stack-name $STACK_NAME --region $REGION
    
else
    echo "🆕 Creating new stack..."
    
    aws cloudformation create-stack \
        --stack-name $STACK_NAME \
        --template-body file://$TEMPLATE_FILE \
        --parameters \
            ParameterKey=GitHubOwner,ParameterValue=$GITHUB_OWNER \
            ParameterKey=GitHubRepo,ParameterValue=$GITHUB_REPO \
            ParameterKey=GitHubBranch,ParameterValue=$GITHUB_BRANCH \
            ParameterKey=GitHubToken,ParameterValue=$GITHUB_TOKEN \
            ParameterKey=DatabasePassword,ParameterValue=$DB_PASSWORD \
            ParameterKey=JWTSecret,ParameterValue=$JWT_SECRET \
        --capabilities CAPABILITY_NAMED_IAM \
        --region $REGION
    
    echo "⏳ Waiting for stack creation to complete..."
    aws cloudformation wait stack-create-complete --stack-name $STACK_NAME --region $REGION
fi

# Get stack outputs
echo "📊 Getting stack outputs..."
PIPELINE_NAME=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION --query 'Stacks[0].Outputs[?OutputKey==`PipelineName`].OutputValue' --output text)
CODEBUILD_PROJECT=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION --query 'Stacks[0].Outputs[?OutputKey==`CodeBuildProjectName`].OutputValue' --output text)
ARTIFACTS_BUCKET=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION --query 'Stacks[0].Outputs[?OutputKey==`ArtifactsBucket`].OutputValue' --output text)

echo "✅ CodePipeline setup completed successfully!"
echo ""
echo "📋 Resources Created:"
echo "  Pipeline Name: $PIPELINE_NAME"
echo "  CodeBuild Project: $CODEBUILD_PROJECT"
echo "  Artifacts Bucket: $ARTIFACTS_BUCKET"
echo ""
echo "🌐 Access URLs:"
echo "  CodePipeline Console: https://$REGION.console.aws.amazon.com/codesuite/codepipeline/pipelines/$PIPELINE_NAME/view"
echo "  CodeBuild Console: https://$REGION.console.aws.amazon.com/codesuite/codebuild/projects/$CODEBUILD_PROJECT"
echo ""
echo "🚀 Next Steps:"
echo "  1. The pipeline will automatically trigger on pushes to the '$GITHUB_BRANCH' branch"
echo "  2. Monitor the pipeline execution in the AWS Console"
echo "  3. After successful deployment, your application will be available at the ALB DNS name"
echo ""
echo "💡 To trigger a deployment now:"
echo "  - Push any change to the '$GITHUB_BRANCH' branch"
echo "  - Or manually start the pipeline in the AWS Console" 