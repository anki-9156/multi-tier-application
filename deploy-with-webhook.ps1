# Deploy CodePipeline with Webhook
Write-Host "🚀 Deploying CodePipeline with Webhook Support" -ForegroundColor Cyan

# Environment variables
$GITHUB_OWNER = if ($env:GITHUB_OWNER) { $env:GITHUB_OWNER } else { "anki-9156" }
$GITHUB_REPO = if ($env:GITHUB_REPO) { $env:GITHUB_REPO } else { "multi-tier-application" }
$GITHUB_BRANCH = if ($env:GITHUB_BRANCH) { $env:GITHUB_BRANCH } else { "aws-code-pipeline" }
$GITHUB_TOKEN = $env:GITHUB_TOKEN
$DB_PASSWORD = if ($env:DB_PASSWORD) { $env:DB_PASSWORD } else { "ChangeThisSecurePassword123!" }
$JWT_SECRET = if ($env:JWT_SECRET) { $env:JWT_SECRET } else { "change-this-jwt-secret-32chars-min!" }

if (-not $GITHUB_TOKEN) {
    Write-Host "❌ GITHUB_TOKEN environment variable is required!" -ForegroundColor Red
    Write-Host "   Set it with: `$env:GITHUB_TOKEN = 'your_token_here'" -ForegroundColor Yellow
    exit 1
}

Write-Host "📋 Configuration:" -ForegroundColor Yellow
Write-Host "   GitHub Owner: $GITHUB_OWNER" -ForegroundColor White
Write-Host "   GitHub Repo: $GITHUB_REPO" -ForegroundColor White
Write-Host "   GitHub Branch: $GITHUB_BRANCH" -ForegroundColor White
Write-Host "   GitHub Token: $('*' * 8)$($GITHUB_TOKEN.Substring([Math]::Max(0, $GITHUB_TOKEN.Length - 4)))" -ForegroundColor White

try {
    Write-Host "🚀 Deploying CloudFormation stack..." -ForegroundColor Cyan
    
    aws cloudformation deploy `
        --template-file cloudformation/codepipeline.yml `
        --stack-name ecommerce-codepipeline-stack `
        --parameter-overrides `
            GitHubOwner=$GITHUB_OWNER `
            GitHubRepo=$GITHUB_REPO `
            GitHubBranch=$GITHUB_BRANCH `
            GitHubToken=$GITHUB_TOKEN `
            DatabasePassword=$DB_PASSWORD `
            JWTSecret=$JWT_SECRET `
        --capabilities CAPABILITY_IAM `
        --region us-east-1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ CloudFormation stack deployed successfully!" -ForegroundColor Green
        
        # Get the webhook URL
        Write-Host "🔍 Getting webhook URL..." -ForegroundColor Yellow
        $webhookUrl = aws cloudformation describe-stacks `
            --stack-name ecommerce-codepipeline-stack `
            --query 'Stacks[0].Outputs[?OutputKey==`GitHubWebhookURL`].OutputValue' `
            --output text `
            --region us-east-1
        
        if ($webhookUrl -and $webhookUrl -ne "None") {
            Write-Host "✅ Webhook URL found: $webhookUrl" -ForegroundColor Green
            Write-Host ""
            Write-Host "🔗 GitHub Webhook Configuration:" -ForegroundColor Cyan
            Write-Host "   1. Go to: https://github.com/$GITHUB_OWNER/$GITHUB_REPO/settings/hooks" -ForegroundColor Blue
            Write-Host "   2. Click 'Add webhook'" -ForegroundColor White
            Write-Host "   3. Payload URL: $webhookUrl" -ForegroundColor White
            Write-Host "   4. Content type: application/json" -ForegroundColor White
            Write-Host "   5. Secret: $GITHUB_TOKEN" -ForegroundColor White
            Write-Host "   6. Events: Just the push event" -ForegroundColor White
            Write-Host "   7. Click 'Add webhook'" -ForegroundColor White
        } else {
            Write-Host "❌ Could not retrieve webhook URL" -ForegroundColor Red
        }
        
        Write-Host ""
        Write-Host "📊 Monitor Pipeline: https://us-east-1.console.aws.amazon.com/codesuite/codepipeline/pipelines" -ForegroundColor Blue
        
    } else {
        Write-Host "❌ CloudFormation deployment failed" -ForegroundColor Red
    }
    
} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
} 