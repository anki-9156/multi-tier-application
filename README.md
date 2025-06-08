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

### GitHub Actions Deployment
A complete GitHub Actions CI/CD pipeline automatically deploys your application to AWS:

**Features:**
- Automated testing for frontend and backend
- Docker image building and ECR deployment
- Infrastructure deployment (VPC, ALB, Security Groups)
- Database deployment (RDS PostgreSQL)
- ECS service deployment with Fargate
- Integration testing and health checks
- Deployment notifications and summaries

**Setup:**
- See [GITHUB-ACTIONS-QUICK-START.md](GITHUB-ACTIONS-QUICK-START.md) for quick setup
- See [GITHUB-ACTIONS-SETUP.md](GITHUB-ACTIONS-SETUP.md) for detailed instructions

**Triggers:**
- Push to `main` branch: Full deployment to production
- Push to `develop` branch: Build and push images only
- Pull requests: Run tests only
- Manual deployment: Use GitHub Actions workflow dispatch

## Deployment
Can be deployed to AWS ECS with ECR for container registry, or other cloud platforms through the CI/CD pipeline.

## Technology Stack
- **Frontend**: React with TypeScript, Nginx
- **Backend**: Node.js, Express, Sequelize
- **Database**: PostgreSQL
- **Containerization**: Docker, Docker Compose
- **Cloud**: AWS ECS, ECR, RDS, ALB 