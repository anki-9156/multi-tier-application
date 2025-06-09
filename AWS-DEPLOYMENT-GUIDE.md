# AWS Deployment Guide - Containerized Multi-Tier Application

This guide provides step-by-step instructions for deploying the containerized e-commerce application to AWS using ECS, ECR, and RDS.

## Prerequisites

Before starting the AWS deployment, ensure you have:

1. **AWS CLI configured** with appropriate permissions
2. **Docker Desktop** installed and running
3. **Node.js 18+** installed (for local development/testing)
4. **AWS Account** with the following permissions:
   - ECS (Elastic Container Service)
   - ECR (Elastic Container Registry)
   - RDS (Relational Database Service)
   - VPC (Virtual Private Cloud)
   - ELB (Elastic Load Balancer)
   - IAM (Identity and Access Management)
   - CloudWatch (for logging and monitoring)

## Phase 1: Local Testing (Optional but Recommended)

First, test the application locally to ensure everything works:

```bash
# 1. Install dependencies (if you have Node.js installed)
cd backend && npm install
cd ../frontend && npm install
cd ..

# 2. Start with Docker Compose
docker-compose up --build

# 3. Test endpoints
# Frontend: http://localhost:3000
# Backend: http://localhost:5000/health
# API: http://localhost:5000/api
```

## Phase 2: AWS Infrastructure Setup

### Step 1: Create ECR Repositories

Run the provided script to create ECR repositories:

```bash
# Make the script executable (if not already done)
chmod +x infrastructure/aws/ecr-setup.sh

# Run the ECR setup script
./infrastructure/aws/ecr-setup.sh
```

This script will:
- Create ECR repositories for frontend and backend
- Enable image scanning
- Provide docker commands for building and pushing images

### Step 2: Build and Push Docker Images

```bash
# Set your AWS account ID and region
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=us-east-1

# Build the images
docker build -t ecommerce/frontend ./frontend
docker build -t ecommerce/backend ./backend

# Tag the images for ECR
docker tag ecommerce/frontend:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/ecommerce/frontend:latest
docker tag ecommerce/backend:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/ecommerce/backend:latest

# Login to ECR (if not already done by the script)
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Push the images
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/ecommerce/frontend:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/ecommerce/backend:latest
```

## Phase 3: AWS Database Setup (RDS)

### Step 3: Create RDS PostgreSQL Instance

1. **Go to AWS RDS Console**
2. **Click "Create database"**
3. **Configuration:**
   - Engine: PostgreSQL
   - Version: PostgreSQL 15.x (latest)
   - Template: Free tier (for testing) or Production (for production)
   - DB instance identifier: `ecommerce-db`
   - Master username: `admin`
   - Master password: `your-secure-password`
   - DB instance class: `db.t3.micro` (free tier) or larger
   - Storage: 20 GB (minimum)
   - VPC: Default VPC
   - Subnet group: Default
   - Public access: No (for security)
   - VPC security groups: Create new (allow PostgreSQL port 5432)
   - Database name: `ecommerce`


### Step 4: Configure Security Groups

1. **Find the RDS security group** created in the previous step
2. **Edit inbound rules:**
   - Type: PostgreSQL
   - Port: 5432
   - Source: Custom (select the security group that will be used by ECS tasks)

## Phase 4: AWS ECS Setup

### Step 5: Create ECS Cluster

1. **Go to AWS ECS Console**
2. **Click "Create Cluster"**
3. **Configuration:**
   - Cluster name: `ecommerce-cluster`
   - Infrastructure: AWS Fargate (serverless)
   - Click "Create"

### Step 6: Create Task Definitions

#### Backend Task Definition

1. **Go to Task Definitions**
2. **Click "Create new Task Definition"**
3. **Configuration:**
   - Task definition family: `ecommerce-backend`
   - Launch type: Fargate
   - Operating system: Linux/X86_64
   - CPU: 0.5 vCPU
   - Memory: 1 GB
   - Task role: Create new role or use existing ECS task role

4. **Container Definition:**
   - Container name: `backend`
   - Image URI: `$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/ecommerce/backend:latest`
   - Port: 5000
   - Environment variables:
     ```
     NODE_ENV=production
     DB_HOST=<RDS_ENDPOINT>
     DB_PORT=5432
     DB_NAME=ecommerce
     DB_USER=admin
     DB_PASSWORD=<YOUR_DB_PASSWORD>
     JWT_SECRET=<YOUR_JWT_SECRET>
     ```
   - Health check: 
     - Command: `CMD-SHELL,curl -f http://localhost:5000/health || exit 1`
     - Interval: 30
     - Timeout: 5
     - Retries: 3

#### Frontend Task Definition

1. **Create another Task Definition:**
   - Task definition family: `ecommerce-frontend`
   - Launch type: Fargate
   - CPU: 0.25 vCPU
   - Memory: 0.5 GB

2. **Container Definition:**
   - Container name: `frontend`
   - Image URI: `$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/ecommerce/frontend:latest`
   - Port: 80
   - Environment variables:
     ```
     REACT_APP_API_URL=https://<ALB_DNS_NAME>/api
     ```

### Step 7: Create Application Load Balancer (ALB)

1. **Go to EC2 Console → Load Balancers**
2. **Click "Create Load Balancer"**
3. **Choose Application Load Balancer**
4. **Configuration:**
   - Name: `ecommerce-alb`
   - Scheme: Internet-facing
   - IP address type: IPv4
   - VPC: Default VPC
   - Subnets: Select at least 2 subnets in different AZs
   - Security groups: Create new or use existing (allow HTTP/HTTPS)

5. **Target Groups:**
   
   **Frontend Target Group:**
   - Name: `ecommerce-frontend-tg`
   - Target type: IP
   - Protocol: HTTP
   - Port: 80
   - Health check path: `/health`

   **Backend Target Group:**
   - Name: `ecommerce-backend-tg`
   - Target type: IP
   - Protocol: HTTP
   - Port: 5000
   - Health check path: `/health`

6. **Listeners:**
   - HTTP:80 → Forward to frontend target group
   - Add rule: Path `/api/*` → Forward to backend target group

### Step 8: Create ECS Services

#### Backend Service

1. **Go to ECS Cluster → Services**
2. **Click "Create"**
3. **Configuration:**
   - Launch type: Fargate
   - Task Definition: `ecommerce-backend`
   - Service name: `ecommerce-backend-service`
   - Number of tasks: 2
   - VPC: Default VPC
   - Subnets: Private subnets (if available)
   - Security groups: Allow inbound traffic on port 5000 from ALB
   - Load balancer: Application Load Balancer
   - Target group: `ecommerce-backend-tg`

#### Frontend Service

1. **Create another service:**
   - Task Definition: `ecommerce-frontend`
   - Service name: `ecommerce-frontend-service`
   - Number of tasks: 2
   - Target group: `ecommerce-frontend-tg`

## Phase 5: Database Initialization

### Step 9: Initialize Database Schema

Since we can't directly access the RDS instance, we need to run the database initialization through the backend service:

1. **Option A: Modify backend to run migrations on startup** (Recommended)
   - The current backend code already handles this with Sequelize sync
   - The sample data will need to be inserted manually through the API

2. **Option B: Use a bastion host or ECS task** to run the SQL script:
   ```bash
   # Create a temporary ECS task with PostgreSQL client
   # Connect to RDS and run the init script
   ```

## Phase 6: Configure Environment Variables

### Step 10: Update Frontend Environment

Update the frontend task definition with the correct API URL:

```bash
# Get the ALB DNS name
ALB_DNS_NAME=$(aws elbv2 describe-load-balancers --names ecommerce-alb --query 'LoadBalancers[0].DNSName' --output text)

# Update frontend task definition environment variable
REACT_APP_API_URL=http://$ALB_DNS_NAME/api
```

## Phase 7: Testing and Monitoring

### Step 11: Test the Deployment

1. **Get the Application Load Balancer DNS name:**
   ```bash
   aws elbv2 describe-load-balancers --names ecommerce-alb --query 'LoadBalancers[0].DNSName' --output text
   ```

2. **Test endpoints:**
   - Frontend: `http://<ALB_DNS_NAME>`
   - Backend health: `http://<ALB_DNS_NAME>/api/health`
   - Backend API: `http://<ALB_DNS_NAME>/api/products`

### Step 12: Set Up CloudWatch Monitoring

1. **Go to CloudWatch Console**
2. **Create dashboards for:**
   - ECS service metrics (CPU, Memory, Task count)
   - ALB metrics (Request count, Response time, Error rate)
   - RDS metrics (Connections, CPU, Storage)

### Step 13: Configure Auto Scaling

1. **Go to ECS Services**
2. **Update services to enable auto scaling:**
   - Target CPU utilization: 70%
   - Min tasks: 2
   - Max tasks: 10

## Phase 8: Security and Best Practices

### Step 14: Security Enhancements

1. **Use AWS Secrets Manager** for sensitive environment variables:
   - Database password
   - JWT secret
   - API keys

2. **Configure HTTPS:**
   - Request SSL certificate from AWS Certificate Manager
   - Update ALB listener to use HTTPS

3. **Network Security:**
   - Use private subnets for ECS tasks
   - Configure NAT Gateway for outbound internet access
   - Implement VPC Flow Logs

### Step 15: Backup and Disaster Recovery

1. **Enable RDS automated backups**
2. **Configure RDS snapshots**
3. **Set up cross-region replication** (for production)

## Troubleshooting Common Issues

### Issue 1: Tasks Failing to Start
- Check CloudWatch logs for container errors
- Verify security group configurations
- Ensure ECR image exists and is accessible

### Issue 2: Load Balancer Health Checks Failing
- Verify health check endpoints are responding
- Check security group rules
- Ensure tasks are running on correct ports

### Issue 3: Database Connection Issues
- Verify RDS endpoint and credentials
- Check security group rules for port 5432
- Ensure tasks are in the same VPC as RDS

### Issue 4: CORS Issues
- Update backend CORS configuration
- Verify frontend API URL configuration

## Cost Optimization

1. **Use Fargate Spot** for non-critical workloads
2. **Configure ALB idle timeout**
3. **Use RDS reserved instances** for production
4. **Set up CloudWatch billing alarms**

## Cleanup

To avoid charges, delete resources in this order:

1. ECS Services
2. ECS Cluster
3. Load Balancer and Target Groups
4. RDS Instance
5. ECR Repositories
6. CloudWatch Log Groups

```bash
# Example cleanup commands
aws ecs update-service --cluster ecommerce-cluster --service ecommerce-frontend-service --desired-count 0
aws ecs update-service --cluster ecommerce-cluster --service ecommerce-backend-service --desired-count 0
aws ecs delete-service --cluster ecommerce-cluster --service ecommerce-frontend-service
aws ecs delete-service --cluster ecommerce-cluster --service ecommerce-backend-service
aws ecs delete-cluster --cluster ecommerce-cluster
```

This completes the AWS deployment guide. The application should now be running on AWS with proper container orchestration, load balancing, and database management. 