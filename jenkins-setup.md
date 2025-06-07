# Jenkins CI/CD Pipeline Setup Guide

This guide will help you set up a Jenkins pipeline that automatically deploys your full-stack ecommerce application to AWS whenever code is pushed to the main branch.

## 📋 Prerequisites

1. **Jenkins Server** with the following plugins installed:
   - AWS CLI Plugin
   - Docker Pipeline Plugin
   - GitHub Plugin
   - Pipeline Plugin
   - CloudBees AWS Credentials Plugin

2. **AWS CLI** installed on Jenkins server
3. **Docker** installed on Jenkins server
4. **Git** configured on Jenkins server

## 🔧 Jenkins Configuration

### 1. Install Required Plugins

In Jenkins, go to **Manage Jenkins** > **Manage Plugins** and install:
- `Amazon Web Services SDK :: All`
- `CloudBees AWS Credentials`
- `Docker Pipeline`
- `GitHub`
- `Pipeline`

### 2. Configure AWS Credentials

1. Go to **Manage Jenkins** > **Manage Credentials**
2. Click **Add Credentials** and create the following:

#### AWS Credentials
- **Kind**: AWS Credentials
- **ID**: `aws-credentials`
- **Access Key ID**: Your AWS Access Key
- **Secret Access Key**: Your AWS Secret Key
- **Description**: AWS Credentials for ECS deployment

#### Database Password
- **Kind**: Secret text
- **Secret**: Your database password (e.g., `mypassword123`)
- **ID**: `db-password`
- **Description**: Database password

#### JWT Secret
- **Kind**: Secret text
- **Secret**: Your JWT secret (e.g., `your-super-secret-jwt-key`)
- **ID**: `jwt-secret`
- **Description**: JWT Secret for authentication

### 3. Configure Docker

Ensure Jenkins can run Docker commands:
```bash
# Add jenkins user to docker group
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

## 🚀 Pipeline Setup

### 1. Create New Pipeline Job

1. In Jenkins, click **New Item**
2. Enter name: `ecommerce-deployment`
3. Select **Pipeline**
4. Click **OK**

### 2. Configure Pipeline

#### General Tab
- ✅ GitHub project: `https://github.com/yourusername/multi-tier-application-1`

#### Build Triggers
- ✅ GitHub hook trigger for GITScm polling

#### Pipeline Tab
- **Definition**: Pipeline script from SCM
- **SCM**: Git
- **Repository URL**: `https://github.com/yourusername/multi-tier-application-1.git`
- **Branch Specifier**: `*/main`
- **Script Path**: `Jenkinsfile`

### 3. Configure GitHub Webhook

1. Go to your GitHub repository
2. Settings > Webhooks > Add webhook
3. **Payload URL**: `http://your-jenkins-url/github-webhook/`
4. **Content type**: application/json
5. **Which events**: Just the push event
6. ✅ Active

## 🔧 Pipeline Environment Variables

Update the `Jenkinsfile` if needed to match your AWS account:

```groovy
environment {
    AWS_DEFAULT_REGION = 'us-east-1'           // Your AWS region
    AWS_ACCOUNT_ID = '358112240377'            // Your AWS account ID
    ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com"
    BACKEND_REPO = 'ecommerce/backend'         // Your ECR backend repo
    FRONTEND_REPO = 'ecommerce/frontend'       // Your ECR frontend repo
    ECS_CLUSTER = 'multi-tier'                 // Your ECS cluster name
}
```

## 🧪 Testing the Pipeline

### 1. Manual Trigger
1. Go to your pipeline job
2. Click **Build Now**
3. Monitor the build in **Console Output**

### 2. Automatic Trigger
1. Make a change to your code
2. Commit and push to main branch:
   ```bash
   git add .
   git commit -m "Test Jenkins deployment"
   git push origin main
   ```
3. Jenkins should automatically trigger the build

## 📊 Pipeline Stages Overview

The pipeline consists of these stages:

1. **Checkout**: Gets latest code from GitHub
2. **Setup AWS CLI**: Configures AWS credentials
3. **Build and Push Images**: 
   - Builds Docker images for backend and frontend
   - Pushes to ECR repositories
4. **Deploy Infrastructure**: 
   - Creates VPC resources, security groups
   - Sets up Application Load Balancer
5. **Deploy Database**: 
   - Creates RDS PostgreSQL instance
   - Configures database connectivity
6. **Deploy ECS Services**: 
   - Creates ECS cluster and task definitions
   - Deploys backend and frontend services
7. **Update Frontend**: 
   - Updates frontend with actual ALB URL
   - Rebuilds if necessary
8. **Health Check**: 
   - Verifies all services are running
   - Tests API endpoints

## 🔍 Monitoring and Troubleshooting

### Check Build Status
- **Blue Ocean**: Install Blue Ocean plugin for better visualization
- **Console Output**: Click on build number > Console Output
- **Build History**: See all previous builds

### Common Issues

#### 1. AWS Permissions
Ensure your AWS credentials have permissions for:
- ECR (push/pull images)
- ECS (create clusters, services, tasks)
- RDS (create databases)
- EC2 (create security groups, VPC resources)
- IAM (create roles)
- ELB (create load balancers)

#### 2. Docker Issues
```bash
# Check Docker daemon is running
sudo systemctl status docker

# Check Jenkins can access Docker
sudo -u jenkins docker ps
```

#### 3. ECR Authentication
The pipeline handles ECR login automatically, but ensure:
- ECR repositories exist
- Proper permissions for ECR access

### Useful Commands for Debugging

```bash
# Check ECS services
aws ecs list-services --cluster multi-tier

# Check task status
aws ecs list-tasks --cluster multi-tier --service-name ecommerce-backend-service

# Check logs
aws logs get-log-events --log-group-name /ecs/ecommerce-backend --log-stream-name [stream-name]

# Check ALB status
aws elbv2 describe-load-balancers --names ecommerce-alb

# Check target health
aws elbv2 describe-target-health --target-group-arn [target-group-arn]
```

## 🎯 Expected Results

After a successful deployment:

1. **Frontend**: Accessible at `http://[alb-dns]/`
2. **Backend API**: Accessible at `http://[alb-dns]:5000/api`
3. **Health Checks**: Both services respond to `/health`
4. **Database**: Connected and accessible to backend
5. **Auto-scaling**: Services can scale based on demand

## 🔄 Continuous Deployment

Once set up, every push to the main branch will:
1. Trigger the Jenkins pipeline automatically
2. Build and deploy the latest code
3. Update running services with zero downtime
4. Run health checks to ensure successful deployment

The pipeline is designed to be idempotent - it can run multiple times safely and will create resources only if they don't exist.

## 📞 Support

If you encounter issues:
1. Check Jenkins console output for detailed error messages
2. Verify AWS credentials and permissions
3. Ensure ECR repositories exist
4. Check that Docker is properly configured
5. Review CloudWatch logs for application-specific issues 