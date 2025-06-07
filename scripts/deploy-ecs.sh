#!/bin/bash
set -e

echo "🚢 Deploying ECS Services..."

# Source infrastructure variables
source /tmp/aws-env.sh

# Create ECS cluster
echo "Creating ECS cluster..."
aws ecs describe-clusters --clusters $ECS_CLUSTER >/dev/null 2>&1 || {
    aws ecs create-cluster --cluster-name $ECS_CLUSTER
}

# Create task execution role if it doesn't exist
ROLE_NAME="ecsTaskExecutionRole"
aws iam get-role --role-name $ROLE_NAME >/dev/null 2>&1 || {
    echo "Creating ECS task execution role..."
    aws iam create-role \
        --role-name $ROLE_NAME \
        --assume-role-policy-document '{
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Principal": {
                        "Service": "ecs-tasks.amazonaws.com"
                    },
                    "Action": "sts:AssumeRole"
                }
            ]
        }'
    
    aws iam attach-role-policy \
        --role-name $ROLE_NAME \
        --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
}

EXECUTION_ROLE_ARN="arn:aws:iam::$AWS_ACCOUNT_ID:role/$ROLE_NAME"

# Create backend task definition
echo "Creating backend task definition..."
cat > /tmp/backend-task-def.json << EOF
{
  "family": "ecommerce-backend",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "$EXECUTION_ROLE_ARN",
  "runtimePlatform": {
    "cpuArchitecture": "X86_64",
    "operatingSystemFamily": "LINUX"
  },
  "containerDefinitions": [
    {
      "name": "backend",
      "image": "$ECR_REGISTRY/$BACKEND_REPO:latest",
      "cpu": 0,
      "portMappings": [
        {
          "containerPort": 5000,
          "hostPort": 5000,
          "protocol": "tcp",
          "name": "backend-5000-tcp",
          "appProtocol": "http"
        }
      ],
      "essential": true,
      "environment": [
        {
          "name": "PORT",
          "value": "5000"
        },
        {
          "name": "NODE_ENV",
          "value": "production"
        },
        {
          "name": "DB_HOST",
          "value": "$DB_ENDPOINT"
        },
        {
          "name": "DB_PORT",
          "value": "5432"
        },
        {
          "name": "DB_NAME",
          "value": "$DB_NAME"
        },
        {
          "name": "DB_USER",
          "value": "$DB_USERNAME"
        },
        {
          "name": "DB_PASSWORD",
          "value": "$DB_PASSWORD"
        },
        {
          "name": "JWT_SECRET",
          "value": "$JWT_SECRET"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/ecommerce-backend",
          "awslogs-region": "$AWS_DEFAULT_REGION",
          "awslogs-stream-prefix": "ecs",
          "awslogs-create-group": "true"
        }
      },
      "healthCheck": {
        "command": [
          "CMD-SHELL",
          "curl -f http://localhost:5000/health || exit 1"
        ],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
EOF

aws ecs register-task-definition --cli-input-json file:///tmp/backend-task-def.json

# Create frontend task definition
echo "Creating frontend task definition..."
cat > /tmp/frontend-task-def.json << EOF
{
  "family": "ecommerce-frontend",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "$EXECUTION_ROLE_ARN",
  "runtimePlatform": {
    "cpuArchitecture": "X86_64",
    "operatingSystemFamily": "LINUX"
  },
  "containerDefinitions": [
    {
      "name": "frontend",
      "image": "$ECR_REGISTRY/$FRONTEND_REPO:latest",
      "cpu": 0,
      "portMappings": [
        {
          "containerPort": 80,
          "hostPort": 80,
          "protocol": "tcp",
          "name": "frontend-80-tcp",
          "appProtocol": "http"
        }
      ],
      "essential": true,
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/ecommerce-frontend",
          "awslogs-region": "$AWS_DEFAULT_REGION",
          "awslogs-stream-prefix": "ecs",
          "awslogs-create-group": "true"
        }
      },
      "healthCheck": {
        "command": [
          "CMD-SHELL",
          "curl -f http://localhost:80/health || exit 1"
        ],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 10
      }
    }
  ]
}
EOF

aws ecs register-task-definition --cli-input-json file:///tmp/frontend-task-def.json

# Convert subnet IDs to array format for ECS
SUBNET_ARRAY=($SUBNET_IDS)
SUBNETS_JSON=$(printf '"%s",' "${SUBNET_ARRAY[@]}" | sed 's/,$//')

# Create backend service
echo "Creating backend service..."
BACKEND_SERVICE=$(aws ecs describe-services --cluster $ECS_CLUSTER --services ecommerce-backend-service --query 'services[0].serviceName' --output text 2>/dev/null || echo "None")
if [ "$BACKEND_SERVICE" = "None" ]; then
    aws ecs create-service \
        --cluster $ECS_CLUSTER \
        --service-name ecommerce-backend-service \
        --task-definition ecommerce-backend \
        --desired-count 2 \
        --capacity-provider-strategy capacityProvider=FARGATE,weight=1,base=0 \
        --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS_JSON],securityGroups=[$SG_ID],assignPublicIp=ENABLED}" \
        --load-balancers "targetGroupArn=$BACKEND_TG_ARN,containerName=backend,containerPort=5000" \
        --enable-execute-command \
        --deployment-configuration "deploymentCircuitBreaker={enable=true,rollback=true},maximumPercent=200,minimumHealthyPercent=100"
else
    echo "Updating backend service..."
    aws ecs update-service \
        --cluster $ECS_CLUSTER \
        --service ecommerce-backend-service \
        --task-definition ecommerce-backend \
        --force-new-deployment
fi

# Create frontend service
echo "Creating frontend service..."
FRONTEND_SERVICE=$(aws ecs describe-services --cluster $ECS_CLUSTER --services ecommerce-frontend-service --query 'services[0].serviceName' --output text 2>/dev/null || echo "None")
if [ "$FRONTEND_SERVICE" = "None" ]; then
    aws ecs create-service \
        --cluster $ECS_CLUSTER \
        --service-name ecommerce-frontend-service \
        --task-definition ecommerce-frontend \
        --desired-count 2 \
        --capacity-provider-strategy capacityProvider=FARGATE,weight=1,base=0 \
        --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS_JSON],securityGroups=[$SG_ID],assignPublicIp=ENABLED}" \
        --load-balancers "targetGroupArn=$FRONTEND_TG_ARN,containerName=frontend,containerPort=80" \
        --enable-execute-command \
        --deployment-configuration "deploymentCircuitBreaker={enable=true,rollback=true},maximumPercent=200,minimumHealthyPercent=100"
else
    echo "Updating frontend service..."
    aws ecs update-service \
        --cluster $ECS_CLUSTER \
        --service ecommerce-frontend-service \
        --task-definition ecommerce-frontend \
        --force-new-deployment
fi

echo "✅ ECS deployment completed!"
echo "Services created/updated in cluster: $ECS_CLUSTER" 