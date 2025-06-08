#!/bin/bash
set -e

echo "🚢 Deploying ECS Services..."

# Source infrastructure variables
source /tmp/aws-env.sh

# Debug: Show loaded variables
echo "🔍 Variables loaded from aws-env.sh:"
echo "ECS_CLUSTER: $ECS_CLUSTER"
echo "AWS_ACCOUNT_ID: $AWS_ACCOUNT_ID"
echo "ECR_REGISTRY: $ECR_REGISTRY"
echo "AWS_DEFAULT_REGION: $AWS_DEFAULT_REGION"

# Create ECS cluster
echo "Creating ECS cluster..."
CLUSTER_EXISTS=$(aws ecs describe-clusters --clusters $ECS_CLUSTER --query 'clusters[0].clusterName' --output text 2>/dev/null || echo "None")
if [ "$CLUSTER_EXISTS" = "None" ]; then
    echo "Creating new ECS cluster: $ECS_CLUSTER"
    aws ecs create-cluster --cluster-name $ECS_CLUSTER
    echo "✅ ECS cluster created successfully"
else
    echo "✅ ECS cluster already exists: $CLUSTER_EXISTS"
fi

# Verify cluster exists before proceeding
echo "Verifying cluster exists..."
CLUSTER_STATUS=$(aws ecs describe-clusters --clusters $ECS_CLUSTER --query 'clusters[0].status' --output text 2>/dev/null || echo "None")
if [ "$CLUSTER_STATUS" != "ACTIVE" ]; then
    echo "❌ ERROR: Cluster $ECS_CLUSTER is not in ACTIVE state. Current status: $CLUSTER_STATUS"
    exit 1
fi
echo "✅ Cluster verification passed: $ECS_CLUSTER is ACTIVE"

# Create task execution role if it doesn't exist
EXECUTION_ROLE_NAME="ecsTaskExecutionRole"
aws iam get-role --role-name $EXECUTION_ROLE_NAME >/dev/null 2>&1 || {
    echo "Creating ECS task execution role..."
    aws iam create-role \
        --role-name $EXECUTION_ROLE_NAME \
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
        --role-name $EXECUTION_ROLE_NAME \
        --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
}

# Create task role if it doesn't exist
TASK_ROLE_NAME="ecsTaskRole"
aws iam get-role --role-name $TASK_ROLE_NAME >/dev/null 2>&1 || {
    echo "Creating ECS task role..."
    aws iam create-role \
        --role-name $TASK_ROLE_NAME \
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
    
    # Attach basic ECS task permissions
    aws iam attach-role-policy \
        --role-name $TASK_ROLE_NAME \
        --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskRolePolicy
}

EXECUTION_ROLE_ARN="arn:aws:iam::$AWS_ACCOUNT_ID:role/$EXECUTION_ROLE_NAME"
TASK_ROLE_ARN="arn:aws:iam::$AWS_ACCOUNT_ID:role/$TASK_ROLE_NAME"

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
  "taskRoleArn": "$TASK_ROLE_ARN",
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
  "taskRoleArn": "$TASK_ROLE_ARN",
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

# Debug: Check all required variables before service creation
echo "🔍 Debugging variables before service creation:"
echo "ECS_CLUSTER: $ECS_CLUSTER"
echo "SG_ID: $SG_ID"
echo "SUBNET_IDS: $SUBNET_IDS"
echo "SUBNETS_JSON: $SUBNETS_JSON"
echo "BACKEND_TG_ARN: $BACKEND_TG_ARN"
echo "FRONTEND_TG_ARN: $FRONTEND_TG_ARN"

# Final cluster verification
echo "🔍 Final cluster verification:"
aws ecs describe-clusters --clusters $ECS_CLUSTER --query 'clusters[0].{Name:clusterName,Status:status,RunningTasks:runningTasksCount,ActiveServices:activeServicesCount}' --output table

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