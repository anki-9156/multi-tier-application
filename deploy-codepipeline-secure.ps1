# AWS CodePipeline Deployment Script (Secure Version)
Write-Host "🚀 AWS CodePipeline Deployment Script (Secure)" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan

# Check if AWS CLI is configured
Write-Host "Checking AWS CLI configuration..." -ForegroundColor Yellow
try {
    $awsIdentity = aws sts get-caller-identity | ConvertFrom-Json
    Write-Host "✅ AWS CLI configured for account: $($awsIdentity.Account)" -ForegroundColor Green
} catch {
    Write-Host "❌ AWS CLI not configured. Please run 'aws configure'" -ForegroundColor Red
    exit 1
}

# Get GitHub token from environment variable or prompt
$GITHUB_TOKEN = $env:GITHUB_TOKEN
if (-not $GITHUB_TOKEN) {
    Write-Host "⚠️  GitHub token not found in environment variable GITHUB_TOKEN" -ForegroundColor Yellow
    $GITHUB_TOKEN = Read-Host "Please enter your GitHub Personal Access Token" -AsSecureString
    $GITHUB_TOKEN = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($GITHUB_TOKEN))
}

if (-not $GITHUB_TOKEN -or $GITHUB_TOKEN.Length -lt 10) {
    Write-Host "❌ Invalid GitHub token!" -ForegroundColor Red
    Write-Host "Please create a token at: https://github.com/settings/tokens" -ForegroundColor Blue
    Write-Host "Required scope: 'repo' (Full control of private repositories)" -ForegroundColor White
    exit 1
}

# Set environment variables (customize these values)
$env:GITHUB_OWNER = if ($env:GITHUB_OWNER) { $env:GITHUB_OWNER } else { "your-github-username" }
$env:GITHUB_TOKEN = $GITHUB_TOKEN
$env:GITHUB_REPO = if ($env:GITHUB_REPO) { $env:GITHUB_REPO } else { "multi-tier-application" }
$env:GITHUB_BRANCH = if ($env:GITHUB_BRANCH) { $env:GITHUB_BRANCH } else { "aws-code-pipeline" }
$env:DB_PASSWORD = if ($env:DB_PASSWORD) { $env:DB_PASSWORD } else { "ChangeThisSecurePassword123!" }
$env:JWT_SECRET = if ($env:JWT_SECRET) { $env:JWT_SECRET } else { "change-this-jwt-secret-32chars-min!" }

Write-Host "✅ Configuration set:" -ForegroundColor Green
Write-Host "   GitHub Owner: $env:GITHUB_OWNER" -ForegroundColor White
Write-Host "   GitHub Repo: $env:GITHUB_REPO" -ForegroundColor White
Write-Host "   GitHub Branch: $env:GITHUB_BRANCH" -ForegroundColor White
Write-Host "   GitHub Token: $('*' * 8)$($GITHUB_TOKEN.Substring([Math]::Max(0, $GITHUB_TOKEN.Length - 4)))" -ForegroundColor White

# Confirm deployment
Write-Host "`n⚠️  This will create AWS resources that may incur costs (~$7-17/month)" -ForegroundColor Yellow
$confirm = Read-Host "Do you want to continue with deployment? (y/N)"

if ($confirm -ne 'y' -and $confirm -ne 'Y') {
    Write-Host "Deployment cancelled." -ForegroundColor Yellow
    exit 0
}

# Run the setup script
Write-Host "`n🚀 Starting CodePipeline deployment..." -ForegroundColor Cyan

try {
    # Run with Git Bash for better compatibility
    & "C:\Program Files\Git\bin\bash.exe" -c "cd /c/Users/Lenovo/multi-tier-application && chmod +x scripts/setup-codepipeline.sh && ./scripts/setup-codepipeline.sh"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n🎉 CodePipeline deployment completed successfully!" -ForegroundColor Green
        Write-Host "📊 View your pipeline: https://us-east-1.console.aws.amazon.com/codesuite/codepipeline/pipelines" -ForegroundColor Blue
        Write-Host "📊 View builds: https://us-east-1.console.aws.amazon.com/codesuite/codebuild/" -ForegroundColor Blue
        Write-Host "📊 View ECS: https://us-east-1.console.aws.amazon.com/ecs/" -ForegroundColor Blue
        
        Write-Host "`n📝 Next steps:" -ForegroundColor Yellow
        Write-Host "   1. Monitor the first pipeline execution (~15-20 minutes)" -ForegroundColor White
        Write-Host "   2. Push code changes to trigger automatic deployments" -ForegroundColor White
        Write-Host "   3. Check application URL after deployment completes" -ForegroundColor White
    } else {
        Write-Host "❌ Deployment failed. Check the output above for errors." -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Error running deployment script: $($_.Exception.Message)" -ForegroundColor Red
} 