# GitHub Actions CI/CD Setup Guide

This guide explains how to set up the GitHub Actions CI/CD pipeline for your multi-tier e-commerce application to deploy to AWS.

## Overview

The GitHub Actions pipeline includes:
- **Automated Testing**: Runs unit tests for both frontend and backend
- **Docker Image Building**: Builds and pushes Docker images to ECR
- **Infrastructure Deployment**: Deploys VPC, ALB, security groups using your existing scripts
- **Database Deployment**: Creates RDS PostgreSQL instance
- **ECS Deployment**: Deploys containerized applications to ECS Fargate
- **Integration Testing**: Validates the deployed application
- **Notifications**: Provides deployment summaries and status updates

## Prerequisites

### 1. AWS Account Setup
Ensure you have an AWS account with the following permissions:
- ECS (Elastic Container Service)
- ECR (Elastic Container Registry) 
- RDS (Relational Database Service)
- VPC (Virtual Private Cloud)
- ELB (Elastic Load Balancer)
- IAM (Identity and Access Management)
- CloudWatch (for logging)

### 2. AWS CLI Configuration
Install and configure AWS CLI locally for initial setup:
```bash
aws configure
```

### 3. ECR Repository Setup
Before running the pipeline, create ECR repositories:
```bash
# Make the script executable
chmod +x scripts/setup-ecr.sh

# Run the ECR setup script
./scripts/setup-ecr.sh
```

## GitHub Repository Setup

### Step 1: GitHub Secrets Configuration

Add the following secrets to your GitHub repository:

1. Go to your repository on GitHub
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Add the following **Repository Secrets**:

| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `AWS_ACCESS_KEY_ID` | AWS Access Key ID | `AKIA...` |
| `AWS_SECRET_ACCESS_KEY` | AWS Secret Access Key | `wJalrXUtnFEMI/K7MDENG...` |
| `DB_PASSWORD` | Database password for RDS | `SecurePassword123!` |
| `JWT_SECRET` | JWT secret for backend authentication | `your-super-secret-jwt-key` |

#### Creating AWS Access Keys

1. Go to **AWS Console** → **IAM** → **Users**
2. Create a new user or select existing user
3. Attach the following policies:
   - `AmazonECS_FullAccess`
   - `AmazonEC2ContainerRegistryFullAccess`  
   - `AmazonRDSFullAccess`
   - `AmazonVPCFullAccess`
   - `ElasticLoadBalancingFullAccess`
   - `IAMFullAccess` (for creating ECS roles)
   - `CloudWatchFullAccess`
4. Create access keys and copy them to GitHub secrets

### Step 2: Environment Variables Configuration

The pipeline uses these environment variables (configured in the workflow):

```yaml
env:
  AWS_REGION: us-east-1              # Change if needed
  ECS_CLUSTER: ecommerce-cluster
  FRONTEND_REPO: ecommerce/frontend
  BACKEND_REPO: ecommerce/backend
  DB_NAME: ecommerce
  DB_USERNAME: admin
```

You can modify these in `.github/workflows/deploy-to-aws.yml` if needed.

## Pipeline Workflow

### Triggers

The pipeline runs on:
- **Push to `main` branch**: Full deployment to production
- **Push to `develop` branch**: Build and push images only (no deployment)
- **Pull requests to `main`**: Run tests only
- **Manual trigger**: Use workflow_dispatch for manual deployments

### Pipeline Stages

1. **Test** 🧪
   - Install dependencies
   - Run backend tests
   - Run frontend tests
   - Build frontend

2. **Build and Push** 🐳
   - Build Docker images
   - Tag with commit SHA and 'latest'
   - Push to ECR repositories

3. **Deploy Infrastructure** 🏗️
   - Create VPC resources
   - Set up Application Load Balancer
   - Configure security groups
   - Create target groups

4. **Deploy Database** 🗄️
   - Create RDS PostgreSQL instance
   - Configure database security
   - Set up subnet groups

5. **Deploy ECS Services** 🚢
   - Create ECS cluster
   - Register task definitions
   - Deploy frontend and backend services
   - Wait for services to stabilize

6. **Integration Tests** ✅
   - Test backend health endpoint
   - Validate frontend accessibility
   - Verify application functionality

7. **Notify** 📢
   - Create deployment summary
   - Provide application URLs
   - Report deployment status

## Usage

### Automatic Deployment
Push to the `main` branch to trigger automatic deployment:
```bash
git add .
git commit -m "Deploy latest changes"
git push origin main
```

### Manual Deployment
1. Go to **Actions** tab in GitHub
2. Select **Deploy to AWS** workflow
3. Click **Run workflow**
4. Choose environment and click **Run workflow**

### Development Workflow
Push to `develop` branch to build and push images without deployment:
```bash
git checkout develop
git add .
git commit -m "Update application"
git push origin develop
```

## Monitoring and Debugging

### GitHub Actions Logs
- View detailed logs in the **Actions** tab
- Each job shows real-time progress
- Download logs for debugging

### AWS CloudWatch
- ECS service logs: `/ecs/ecommerce-frontend` and `/ecs/ecommerce-backend`
- View container logs and health checks

### Application URLs
After successful deployment, access:
- **Frontend**: `http://[ALB-DNS-NAME]`
- **Backend API**: `http://[ALB-DNS-NAME]:5000`
- **Health Check**: `http://[ALB-DNS-NAME]:5000/health`

## Troubleshooting

### Common Issues

#### 1. ECR Repository Not Found
```
Error: The repository with name 'ecommerce/frontend' does not exist
```
**Solution**: Run the ECR setup script:
```bash
./scripts/setup-ecr.sh
```

#### 2. AWS Permissions Error
```
Error: User is not authorized to perform: ecs:CreateCluster
```
**Solution**: Ensure your AWS user has the required IAM policies attached.

#### 3. Database Connection Issues
```
Error: Could not connect to database
```
**Solution**: 
- Check `DB_PASSWORD` secret is set correctly
- Verify RDS security group allows connections from ECS
- Wait for RDS instance to be fully available

#### 4. Service Deployment Timeout
```
Error: Services failed to reach steady state
```
**Solution**:
- Check ECS service logs in CloudWatch
- Verify Docker images are built correctly
- Check environment variables in task definitions

### Debugging Steps

1. **Check GitHub Actions logs** for specific error messages
2. **Verify AWS resources** in the console:
   - ECR repositories exist
   - ECS cluster is created
   - RDS instance is available
   - ALB is configured correctly
3. **Test locally** with Docker Compose before deploying
4. **Check application logs** in CloudWatch

## Security Best Practices

1. **Secrets Management**
   - Never commit secrets to repository
   - Use GitHub Secrets for sensitive data
   - Rotate AWS access keys regularly

2. **Network Security**
   - RDS is not publicly accessible
   - Security groups restrict access appropriately
   - Use HTTPS in production (add SSL certificate to ALB)

3. **Container Security**
   - ECR image scanning is enabled
   - Use specific image tags instead of 'latest' in production
   - Regularly update base images

## Customization

### Changing AWS Region
Update the `AWS_REGION` environment variable in the workflow file:
```yaml
env:
  AWS_REGION: eu-west-1  # Change to your preferred region
```

### Adding Staging Environment
Create a separate workflow file for staging or modify the existing one to support multiple environments.

### Custom Domain
To use a custom domain:
1. Register domain in Route 53
2. Create SSL certificate in ACM
3. Add HTTPS listener to ALB
4. Update DNS records

## Cost Optimization

- **ECS Fargate**: Consider using Spot instances for non-production
- **RDS**: Use `db.t3.micro` for development/testing
- **ALB**: Share ALB across multiple applications if possible
- **ECR**: Lifecycle policies automatically clean up old images

## Support

For issues with the pipeline:
1. Check this documentation
2. Review GitHub Actions logs  
3. Verify AWS resource status
4. Check application-specific logs in CloudWatch

Remember to test the pipeline in a development environment before deploying to production! 

check