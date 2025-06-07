# 🚀 Jenkins CI/CD Pipeline for Multi-Tier Application

This repository contains a complete Jenkins CI/CD pipeline that automatically deploys your full-stack ecommerce application to AWS ECS with RDS database whenever code is pushed to the main branch.

## 📁 Files Overview

- **`Jenkinsfile`** - Main pipeline configuration
- **`scripts/deploy-infrastructure.sh`** - Creates AWS infrastructure (VPC, ALB, Security Groups)
- **`scripts/deploy-database.sh`** - Deploys RDS PostgreSQL database
- **`scripts/deploy-ecs.sh`** - Creates ECS cluster and services
- **`jenkins-setup.md`** - Detailed setup instructions

## 🎯 What This Pipeline Does

1. **Builds Docker Images**: Creates optimized images for backend and frontend
2. **Pushes to ECR**: Stores images in AWS Elastic Container Registry
3. **Creates Infrastructure**: Sets up VPC, ALB, security groups automatically
4. **Deploys Database**: Creates RDS PostgreSQL instance with proper configuration
5. **Deploys Services**: Runs containers on ECS Fargate with auto-scaling
6. **Health Checks**: Verifies all services are running correctly

## ⚡ Quick Start

### 1. Prerequisites
- Jenkins server with Docker and AWS CLI
- AWS account with appropriate permissions
- ECR repositories already created (backend and frontend)

### 2. Setup Jenkins
```bash
# Install required plugins in Jenkins:
# - AWS CLI Plugin
# - Docker Pipeline Plugin  
# - GitHub Plugin
# - CloudBees AWS Credentials Plugin
```

### 3. Configure Credentials
In Jenkins, add these credentials:
- `aws-credentials` (AWS Access Key/Secret)
- `db-password` (Database password)
- `jwt-secret` (JWT secret for authentication)

### 4. Create Pipeline Job
1. New Item → Pipeline
2. Configure GitHub repository
3. Set script path to `Jenkinsfile`
4. Enable GitHub webhook trigger

### 5. Test Deployment
Push to main branch or trigger build manually in Jenkins.

## 🏗️ Infrastructure Created

The pipeline automatically creates:

- **ECS Cluster**: `multi-tier`
- **RDS Database**: PostgreSQL with SSL
- **Application Load Balancer**: Routes traffic to services
- **Security Groups**: Proper network access controls
- **Target Groups**: Health checks for services
- **IAM Roles**: ECS task execution permissions

## 🌐 Access Your Application

After successful deployment:

- **Frontend**: `http://[alb-dns]/`
- **Backend API**: `http://[alb-dns]:5000/api`
- **Health Checks**: `/health` endpoints for both services

## 🔧 Configuration

### Environment Variables (Jenkinsfile)
```groovy
AWS_DEFAULT_REGION = 'us-east-1'
AWS_ACCOUNT_ID = '358112240377'
ECS_CLUSTER = 'multi-tier'
DB_NAME = 'postgres'
DB_USERNAME = 'postgres'
```

### Database Configuration
- **Engine**: PostgreSQL 13.13
- **Instance**: db.t3.micro
- **Storage**: 20GB GP2
- **SSL**: Enabled for production

### ECS Configuration
- **Platform**: Fargate
- **CPU**: 512 units per service
- **Memory**: 1024 MB per service
- **Desired Count**: 2 tasks per service

## 📊 Pipeline Stages

1. **Checkout** - Get latest code
2. **Setup AWS CLI** - Configure credentials
3. **Build and Push Images** - Docker build & ECR push (parallel)
4. **Deploy Infrastructure** - VPC, ALB, Security Groups
5. **Deploy Database** - RDS PostgreSQL
6. **Deploy ECS Services** - Containers and services
7. **Update Frontend** - Rebuild with actual ALB URL
8. **Health Check** - Verify deployment

## 🔍 Monitoring

### Jenkins
- Build history and status
- Console output for troubleshooting
- Blue Ocean for visual pipeline view

### AWS CloudWatch
- ECS service metrics
- Application logs
- Database performance

### Health Endpoints
```bash
# Frontend health
curl http://[alb-dns]/health

# Backend health  
curl http://[alb-dns]:5000/health

# API test
curl http://[alb-dns]:5000/api/products
```

## 🚨 Troubleshooting

### Common Issues

1. **Build Fails**: Check AWS credentials and permissions
2. **Docker Issues**: Ensure Jenkins can access Docker daemon
3. **ECR Push Fails**: Verify ECR repositories exist
4. **Database Connection**: Check security group rules
5. **Health Checks Fail**: Review CloudWatch logs

### Debug Commands
```bash
# Check ECS services
aws ecs list-services --cluster multi-tier

# View logs
aws logs tail /ecs/ecommerce-backend --follow

# Check target health
aws elbv2 describe-target-health --target-group-arn [arn]
```

## 📈 Scaling

The pipeline creates auto-scaling ECS services. To modify:

1. Update desired count in `scripts/deploy-ecs.sh`
2. Modify CPU/memory resources as needed
3. Configure auto-scaling policies for production

## 🔒 Security Features

- **SSL/TLS**: Database connections encrypted
- **VPC Security**: Private subnets for database
- **IAM Roles**: Least privilege access
- **Security Groups**: Restricted network access
- **Secrets Management**: Jenkins credentials store

## 📝 Next Steps

1. **Production Setup**: 
   - Use AWS Secrets Manager for production secrets
   - Enable SSL/HTTPS with certificate manager
   - Set up monitoring and alerting

2. **Advanced Features**:
   - Blue/Green deployments
   - Rollback capabilities
   - Multi-environment support (dev/staging/prod)

3. **Optimization**:
   - Image caching strategies
   - Resource optimization
   - Cost monitoring

---

For detailed setup instructions, see [`jenkins-setup.md`](jenkins-setup.md) 