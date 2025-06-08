# AWS CodePipeline Setup Guide

This guide will help you set up AWS CodePipeline for automated CI/CD deployment of your multi-tier e-commerce application.

## 🏗️ **Architecture Overview**

```
GitHub Repository → CodePipeline → CodeBuild → ECR/ECS/RDS
     ↓                   ↓           ↓         ↓
Source Changes    Pipeline Trigger  Build &   Deploy to AWS
                                   Deploy    Infrastructure
```

## 📋 **Prerequisites**

### **1. AWS CLI Setup**
```bash
# Install AWS CLI (if not already installed)
aws configure
# Enter your AWS credentials and region (us-east-1)
```

### **2. GitHub Personal Access Token**
1. Go to [GitHub Settings → Developer settings → Personal access tokens](https://github.com/settings/tokens)
2. Click "Generate new token (classic)"
3. Select scopes: `repo` (Full control of private repositories)
4. Copy the token (you'll need it for setup)

### **3. Set Environment Variables**
```bash
# Required environment variables
export GITHUB_OWNER="your-github-username"          # Your GitHub username
export GITHUB_TOKEN="your_github_token_here"        # Your GitHub token (get from https://github.com/settings/tokens)
export DB_PASSWORD="your-secure-password"           # Database password (8+ chars)
export JWT_SECRET="your-32-character-jwt-secret"    # JWT secret (32+ chars)

# Optional (defaults provided)
export GITHUB_REPO="multi-tier-application"         # Repository name
export GITHUB_BRANCH="aws-code-pipeline"           # Branch to track
```

## 🚀 **Quick Setup**

### **Step 1: Set Environment Variables**
```bash
# Example setup - REPLACE WITH YOUR ACTUAL VALUES
export GITHUB_OWNER="your-github-username"
export GITHUB_TOKEN="your_github_token_here"
export DB_PASSWORD="your_secure_password_123"
export JWT_SECRET="your-very-long-jwt-secret-key-here-32chars"
```

### **Step 2: Run Setup Script**
```bash
# Make script executable
chmod +x scripts/setup-codepipeline.sh

# Run the setup
./scripts/setup-codepipeline.sh
```

### **Step 3: Monitor Deployment**
- The script will provide AWS Console URLs
- Pipeline automatically triggers on code pushes
- First deployment takes ~15-20 minutes

## 📁 **What Gets Created**

### **AWS Resources:**
- **CodePipeline** - Main orchestration pipeline
- **CodeBuild Project** - Builds Docker images and deploys
- **S3 Bucket** - Stores pipeline artifacts
- **IAM Roles** - Service permissions
- **Parameter Store** - Secure secrets storage

### **Pipeline Stages:**
1. **Source** - Monitors GitHub repository
2. **Build-and-Deploy** - Builds images and deploys infrastructure

## 🔧 **How It Works**

### **Automatic Triggers:**
- ✅ **Push to branch** - Automatically starts pipeline
- ✅ **Pull request merge** - Triggers deployment
- ✅ **Manual trigger** - Start via AWS Console

### **Build Process:**
1. **ECR Setup** - Creates container repositories
2. **Docker Build** - Builds frontend and backend images
3. **ECR Push** - Uploads images to registry
4. **Infrastructure** - Deploys VPC, ALB, security groups
5. **Database** - Creates RDS PostgreSQL instance
6. **ECS Deployment** - Deploys services to Fargate

## 📊 **Monitoring & Management**

### **AWS Console Access:**
- **CodePipeline**: https://us-east-1.console.aws.amazon.com/codesuite/codepipeline/
- **CodeBuild**: https://us-east-1.console.aws.amazon.com/codesuite/codebuild/
- **ECS**: https://us-east-1.console.aws.amazon.com/ecs/
- **RDS**: https://us-east-1.console.aws.amazon.com/rds/

### **Pipeline Status:**
```bash
# Check pipeline status
aws codepipeline get-pipeline-state --name ecommerce-codepipeline-pipeline

# View latest execution
aws codepipeline list-pipeline-executions --pipeline-name ecommerce-codepipeline-pipeline
```

### **Logs Access:**
- **CodeBuild Logs**: Available in CloudWatch
- **ECS Logs**: Available in CloudWatch
- **Pipeline History**: Available in CodePipeline Console

## 🔄 **Making Changes & Deployments**

### **Deploy New Code:**
```bash
# Make your changes
git add .
git commit -m "Your changes"
git push origin aws-code-pipeline
# Pipeline automatically triggers!
```

### **Manual Pipeline Trigger:**
```bash
# Start pipeline manually
aws codepipeline start-pipeline-execution --name ecommerce-codepipeline-pipeline
```

### **Environment Variables:**
Stored securely in AWS Parameter Store:
- `/ecommerce/db/password` - Database password
- `/ecommerce/jwt/secret` - JWT secret

Update via AWS Console or CLI:
```bash
aws ssm put-parameter --name "/ecommerce/db/password" --value "new-password" --type "SecureString" --overwrite
```

## ⚡ **Advanced Configuration**

### **Customizing Build Specs:**
Edit `buildspec.yml` to modify:
- Build commands
- Environment variables
- Deployment steps
- Artifact handling

### **Multi-Environment Setup:**
```bash
# Create staging pipeline
export GITHUB_BRANCH="staging"
./scripts/setup-codepipeline.sh

# Create production pipeline
export GITHUB_BRANCH="main"
./scripts/setup-codepipeline.sh
```

### **Blue/Green Deployments:**
Modify `buildspec.yml` to use ECS blue/green deployment:
```yaml
# Add to post_build phase
- aws ecs update-service --cluster $ECS_CLUSTER --service $SERVICE_NAME --task-definition $TASK_DEF --deployment-configuration maximumPercent=200,minimumHealthyPercent=50
```

## 🛡️ **Security Features**

- **✅ IAM Roles** - Least privilege access
- **✅ Parameter Store** - Encrypted secrets
- **✅ S3 Encryption** - Encrypted artifacts
- **✅ VPC Security** - Private networking
- **✅ No hardcoded secrets** - All externalized

## 💰 **Cost Optimization**

### **CodePipeline Costs:**
- **Pipeline**: $1/month per active pipeline
- **CodeBuild**: $0.005/minute for build time
- **S3 Storage**: Minimal for artifacts

### **Estimated Monthly Costs:**
- **CodePipeline**: ~$1
- **CodeBuild**: ~$5-15 (depending on frequency)
- **S3**: ~$1
- **Total**: ~$7-17/month for CI/CD

### **Cost Saving Tips:**
- Use smaller CodeBuild instance types
- Clean up old artifacts regularly
- Use the cleanup workflow to delete resources when not needed

## ❓ **Troubleshooting**

### **Pipeline Fails at Source:**
- Verify GitHub token has correct permissions
- Check repository name and branch
- Ensure token hasn't expired

### **Build Fails:**
- Check CodeBuild logs in CloudWatch
- Verify Docker builds work locally
- Check IAM permissions for CodeBuild role

### **Deployment Fails:**
- Check if resources already exist
- Verify IAM permissions
- Check Parameter Store values

### **ECS Tasks Not Starting:**
- Check ECS service events
- Verify ECR images exist
- Check security group rules

## 🔄 **Pipeline vs GitHub Actions Comparison**

| Feature | AWS CodePipeline | GitHub Actions |
|---------|------------------|----------------|
| **Cost** | ~$7-17/month | Free tier limited |
| **AWS Integration** | Native | Requires credentials |
| **Scalability** | AWS managed | GitHub managed |
| **Flexibility** | CloudFormation | YAML workflows |
| **Secrets** | Parameter Store | GitHub Secrets |
| **Monitoring** | CloudWatch | GitHub interface |

## 🔗 **Useful Commands**

### **Pipeline Management:**
```bash
# List all pipelines
aws codepipeline list-pipelines

# Get pipeline details
aws codepipeline get-pipeline --name ecommerce-codepipeline-pipeline

# Stop pipeline execution
aws codepipeline stop-pipeline-execution --pipeline-name ecommerce-codepipeline-pipeline --pipeline-execution-id <execution-id>
```

### **Build Management:**
```bash
# List builds
aws codebuild list-builds-for-project --project-name ecommerce-codepipeline-build

# Get build logs
aws logs get-log-events --log-group-name /aws/codebuild/ecommerce-codepipeline-build --log-stream-name <stream-name>
```

### **Cleanup:**
```bash
# Delete the entire stack
aws cloudformation delete-stack --stack-name ecommerce-codepipeline

# Use GitHub Actions cleanup workflow for application resources
# (Keep this for cost savings!)
```

## 🎯 **Next Steps**

1. **✅ Run the setup script**
2. **✅ Push code to trigger first deployment**
3. **✅ Monitor deployment in AWS Console**
4. **✅ Access your deployed application**
5. **✅ Set up monitoring and alerting**
6. **✅ Configure automated testing**

Your AWS CodePipeline is now ready for production-grade CI/CD! 🚀 