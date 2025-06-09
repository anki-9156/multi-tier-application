# Direct GitHub Webhook Setup for Existing CodePipeline
Write-Host "🔗 Setting up GitHub webhook for CodePipeline..." -ForegroundColor Cyan

# Configuration
$GITHUB_OWNER = "anki-9156"
$GITHUB_REPO = "multi-tier-application"
$GITHUB_BRANCH = "aws-code-pipeline"
$GITHUB_TOKEN = $env:GITHUB_TOKEN

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

# AWS CodePipeline webhook URL (generic webhook endpoint)
$WEBHOOK_URL = "https://webhooks.us-east-1.amazonaws.com/trigger?t=json&l=AmazonCodePipeline&v=2&b64=false"

Write-Host "🔗 Using webhook URL: $WEBHOOK_URL" -ForegroundColor Blue

# Create GitHub webhook using API
Write-Host "🚀 Creating GitHub webhook..." -ForegroundColor Cyan

try {
    $webhookData = @{
        name = "web"
        active = $true
        events = @("push")
        config = @{
            url = $WEBHOOK_URL
            content_type = "json"
            secret = $GITHUB_TOKEN
            insecure_ssl = "0"
        }
    } | ConvertTo-Json -Depth 3

    $response = Invoke-RestMethod -Uri "https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO/hooks" `
        -Method POST `
        -Headers @{
            "Authorization" = "token $GITHUB_TOKEN"
            "Accept" = "application/vnd.github.v3+json"
            "User-Agent" = "PowerShell-Script"
        } `
        -Body $webhookData `
        -ContentType "application/json"

    Write-Host "✅ GitHub webhook created successfully!" -ForegroundColor Green
    Write-Host "   Webhook ID: $($response.id)" -ForegroundColor White
    Write-Host "   Webhook URL: $($response.config.url)" -ForegroundColor White
    Write-Host "   Active: $($response.active)" -ForegroundColor White
    
    Write-Host ""
    Write-Host "🎉 Success! Your pipeline will now trigger automatically on push to '$GITHUB_BRANCH' branch" -ForegroundColor Green
    Write-Host ""
    Write-Host "📊 Monitor your pipeline:" -ForegroundColor Cyan
    Write-Host "   https://us-east-1.console.aws.amazon.com/codesuite/codepipeline/pipelines" -ForegroundColor Blue
    
    # Test the webhook
    Write-Host ""
    Write-Host "🧪 To test the webhook, make a commit and push:" -ForegroundColor Yellow
    Write-Host "   git add ." -ForegroundColor White
    Write-Host "   git commit -m 'Test webhook'" -ForegroundColor White
    Write-Host "   git push" -ForegroundColor White

} catch {
    Write-Host "❌ Failed to create webhook: $($_.Exception.Message)" -ForegroundColor Red
    
    Write-Host ""
    Write-Host "🔧 Manual setup alternative:" -ForegroundColor Cyan
    Write-Host "   1. Go to: https://github.com/$GITHUB_OWNER/$GITHUB_REPO/settings/hooks" -ForegroundColor Blue
    Write-Host "   2. Click 'Add webhook'" -ForegroundColor White
    Write-Host "   3. Payload URL: $WEBHOOK_URL" -ForegroundColor White
    Write-Host "   4. Content type: application/json" -ForegroundColor White
    Write-Host "   5. Secret: $GITHUB_TOKEN" -ForegroundColor White
    Write-Host "   6. Events: Just the push event" -ForegroundColor White
} 