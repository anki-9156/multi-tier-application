#!/bin/bash

# GitHub Webhook Setup Script for CodePipeline
echo "🔗 Setting up GitHub webhook for automatic CodePipeline triggering..."

# Check if required environment variables are set
if [ -z "$GITHUB_TOKEN" ] || [ -z "$GITHUB_OWNER" ] || [ -z "$GITHUB_REPO" ]; then
    echo "❌ Missing required environment variables:"
    echo "   GITHUB_TOKEN - Your GitHub personal access token"
    echo "   GITHUB_OWNER - Your GitHub username"
    echo "   GITHUB_REPO - Your repository name"
    exit 1
fi

# Get the pipeline webhook URL from CloudFormation
WEBHOOK_URL=$(aws cloudformation describe-stacks \
    --stack-name ecommerce-codepipeline-stack \
    --query 'Stacks[0].Outputs[?OutputKey==`GitHubWebhookURL`].OutputValue' \
    --output text 2>/dev/null)

if [ -z "$WEBHOOK_URL" ] || [ "$WEBHOOK_URL" == "None" ]; then
    echo "❌ Could not find webhook URL from CloudFormation stack"
    echo "ℹ️  Make sure your CloudFormation stack is deployed with the webhook resource"
    exit 1
fi

echo "✅ Found webhook URL: $WEBHOOK_URL"

# Create webhook manually using GitHub API
WEBHOOK_RESPONSE=$(curl -s -X POST \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO/hooks \
    -d '{
        "name": "web",
        "active": true,
        "events": ["push"],
        "config": {
            "url": "'$WEBHOOK_URL'",
            "content_type": "json",
            "secret": "'$GITHUB_TOKEN'"
        }
    }')

# Check if webhook was created successfully
if echo "$WEBHOOK_RESPONSE" | grep -q '"id"'; then
    WEBHOOK_ID=$(echo "$WEBHOOK_RESPONSE" | grep '"id"' | head -1 | sed 's/.*"id": *\([0-9]*\).*/\1/')
    echo "✅ GitHub webhook created successfully with ID: $WEBHOOK_ID"
    echo "🚀 Your pipeline will now trigger automatically on push to $GITHUB_BRANCH branch"
else
    echo "❌ Failed to create webhook. Response:"
    echo "$WEBHOOK_RESPONSE"
    echo ""
    echo "🔧 Manual setup instructions:"
    echo "1. Go to: https://github.com/$GITHUB_OWNER/$GITHUB_REPO/settings/hooks"
    echo "2. Click 'Add webhook'"
    echo "3. Payload URL: $WEBHOOK_URL"
    echo "4. Content type: application/json"
    echo "5. Secret: Your GitHub token"
    echo "6. Events: Just the push event"
fi

echo ""
echo "📊 Monitor your pipeline: https://us-east-1.console.aws.amazon.com/codesuite/codepipeline/pipelines" 