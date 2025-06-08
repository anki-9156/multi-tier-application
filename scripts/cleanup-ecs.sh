#!/bin/bash
set -e

echo "🧹 Cleaning up ECS resources..."

ECS_CLUSTER="ecommerce-cluster"

# Stop and delete ECS services
echo "Stopping ECS services..."
SERVICES=(
    "ecommerce-frontend-service"
    "ecommerce-backend-service"
)

for SERVICE in "${SERVICES[@]}"; do
    echo "Checking service: $SERVICE"
    SERVICE_EXISTS=$(aws ecs describe-services --cluster $ECS_CLUSTER --services $SERVICE --query 'services[0].serviceName' --output text 2>/dev/null || echo "None")
    
    if [ "$SERVICE_EXISTS" != "None" ]; then
        echo "⏳ Scaling down service: $SERVICE"
        aws ecs update-service --cluster $ECS_CLUSTER --service $SERVICE --desired-count 0
        
        echo "⏳ Waiting for tasks to stop..."
        aws ecs wait services-stable --cluster $ECS_CLUSTER --services $SERVICE
        
        echo "🗑️ Deleting service: $SERVICE"
        aws ecs delete-service --cluster $ECS_CLUSTER --service $SERVICE
        echo "✅ Service $SERVICE deleted"
    else
        echo "ℹ️ Service $SERVICE not found, skipping..."
    fi
done

# Wait a bit for services to be fully deleted
echo "⏳ Waiting for services to be completely removed..."
sleep 30

# Delete task definitions (mark as INACTIVE)
echo "🗑️ Deregistering task definitions..."
TASK_FAMILIES=("ecommerce-frontend" "ecommerce-backend")

for FAMILY in "${TASK_FAMILIES[@]}"; do
    echo "Deregistering task definition family: $FAMILY"
    
    # Get all revisions for this family
    REVISIONS=$(aws ecs list-task-definitions --family-prefix $FAMILY --status ACTIVE --query 'taskDefinitionArns[]' --output text)
    
    for REVISION in $REVISIONS; do
        if [ ! -z "$REVISION" ]; then
            echo "  Deregistering: $REVISION"
            aws ecs deregister-task-definition --task-definition $REVISION >/dev/null || echo "    Failed to deregister $REVISION"
        fi
    done
    echo "✅ Task definition family $FAMILY deregistered"
done

# Delete ECS cluster
echo "🗑️ Deleting ECS cluster..."
CLUSTER_EXISTS=$(aws ecs describe-clusters --clusters $ECS_CLUSTER --query 'clusters[0].clusterName' --output text 2>/dev/null || echo "None")

if [ "$CLUSTER_EXISTS" != "None" ]; then
    aws ecs delete-cluster --cluster $ECS_CLUSTER
    echo "✅ ECS cluster deleted: $ECS_CLUSTER"
else
    echo "ℹ️ ECS cluster not found: $ECS_CLUSTER"
fi

# Delete CloudWatch log groups
echo "🗑️ Deleting CloudWatch log groups..."
LOG_GROUPS=(
    "/ecs/ecommerce-frontend"
    "/ecs/ecommerce-backend"
)

for LOG_GROUP in "${LOG_GROUPS[@]}"; do
    echo "Checking log group: $LOG_GROUP"
    if aws logs describe-log-groups --log-group-name-prefix $LOG_GROUP --query 'logGroups[0].logGroupName' --output text 2>/dev/null | grep -q "$LOG_GROUP"; then
        aws logs delete-log-group --log-group-name $LOG_GROUP
        echo "✅ Log group deleted: $LOG_GROUP"
    else
        echo "ℹ️ Log group not found: $LOG_GROUP"
    fi
done

echo "✅ ECS cleanup completed!" 