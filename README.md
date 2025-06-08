# Containerized Multi-Tier E-Commerce Application

## Overview
A containerized e-commerce application with React frontend, Node.js backend, and PostgreSQL database, with GitHub Actions CI/CD pipeline for automated deployment to AWS.

## Architecture
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Frontend      │    │    Backend      │    │   Database      │
│   (React)       │───▶│   (Node.js)     │───▶│  (PostgreSQL)   │
│   Port: 3000    │    │   Port: 5000    │    │   Port: 5432    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Local Development

### Prerequisites
- Docker Desktop
- Node.js 18+
- AWS CLI configured (for deployments)

### Quick Start
```bash
# Copy environment variables
cp .env.example .env

# Start all services
docker-compose up --build

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

### Testing Endpoints
- Frontend: http://localhost:3000
- Backend: http://localhost:5000
- Backend Health: http://localhost:5000/health

## CI/CD Pipeline

### AWS CodePipeline Deployment (Recommended)
A native AWS CI/CD pipeline for automated deployment:

**Features:**
- Native AWS integration with IAM roles
- Automated Docker image building and ECR deployment
- Infrastructure deployment (VPC, ALB, Security Groups)
- Database deployment (RDS PostgreSQL)
- ECS service deployment with Fargate
- Secure secrets management with Parameter Store
- CloudWatch integration for monitoring

**Setup:**
- See [AWS-CODEPIPELINE-SETUP.md](AWS-CODEPIPELINE-SETUP.md) for complete guide
- Requires GitHub token and AWS CLI setup
- Uses CloudFormation for infrastructure as code

**Triggers:**
- Push to `aws-code-pipeline` branch: Automatic deployment
- Manual trigger via AWS Console
- Webhook integration with GitHub

### GitHub Actions Cleanup
A GitHub Actions workflow for resource cleanup:

**Features:**
- Manual resource deletion to save costs (~$100-150/month)
- Safe confirmation required (type "DELETE")
- Cleans up ECS, RDS, VPC, and all AWS resources
- Optional ECR cleanup

**Setup:**
- See [CLEANUP-GUIDE.md](CLEANUP-GUIDE.md) for usage instructions
- Available in GitHub Actions tab
- Perfect for development environments

## Deployment
Can be deployed to AWS ECS with ECR for container registry, or other cloud platforms through the CI/CD pipeline.

## Technology Stack
- **Frontend**: React with TypeScript, Nginx
- **Backend**: Node.js, Express, Sequelize
- **Database**: PostgreSQL
- **Containerization**: Docker, Docker Compose
- **Cloud**: AWS ECS, ECR, RDS, ALB 

## 🚀 Quick Start

This application is configured for automated deployment using **AWS CodePipeline**. 

### AWS CodePipeline Deployment

The application automatically deploys to AWS using CodePipeline when changes are pushed to the `aws-code-pipeline` branch.

**Architecture**: GitHub → CodePipeline → CodeBuild → ECR/ECS/RDS

**Setup Guide**: See [AWS-CODEPIPELINE-SETUP.md](AWS-CODEPIPELINE-SETUP.md)

**Deployment Status**: Ready for production deployment ✅ 