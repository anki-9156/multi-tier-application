#!/bin/bash
set -e

echo "🚀 Deploying Infrastructure..."

# Get default VPC
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query 'Vpcs[0].VpcId' --output text)
echo "Using VPC: $VPC_ID"

# Get subnets
SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[].SubnetId' --output text | tr '\t' ' ')
SUBNET_ARRAY=($SUBNET_IDS)
echo "Using subnets: ${SUBNET_ARRAY[@]}"

# Check if security group exists
SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=ecommerce-sg" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo "None")

if [ "$SG_ID" = "None" ]; then
    echo "Creating security group..."
    SG_ID=$(aws ec2 create-security-group \
        --group-name ecommerce-sg \
        --description "Security group for ecommerce application" \
        --vpc-id $VPC_ID \
        --query 'GroupId' --output text)
    
    # Add security group rules
    echo "Adding security group rules..."
    
    # HTTP access for frontend (port 80)
    aws ec2 authorize-security-group-ingress \
        --group-id $SG_ID \
        --protocol tcp \
        --port 80 \
        --cidr 0.0.0.0/0
    
    # Backend API access (port 5000)
    aws ec2 authorize-security-group-ingress \
        --group-id $SG_ID \
        --protocol tcp \
        --port 5000 \
        --cidr 0.0.0.0/0
    
    # PostgreSQL access within VPC
    aws ec2 authorize-security-group-ingress \
        --group-id $SG_ID \
        --protocol tcp \
        --port 5432 \
        --source-group $SG_ID
    
    # All traffic within security group
    aws ec2 authorize-security-group-ingress \
        --group-id $SG_ID \
        --protocol -1 \
        --source-group $SG_ID
else
    echo "Security group exists: $SG_ID"
fi

# Check if load balancer exists
ALB_ARN=$(aws elbv2 describe-load-balancers --names ecommerce-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null || echo "None")

if [ "$ALB_ARN" = "None" ]; then
    echo "Creating Application Load Balancer..."
    ALB_ARN=$(aws elbv2 create-load-balancer \
        --name ecommerce-alb \
        --subnets ${SUBNET_ARRAY[@]} \
        --security-groups $SG_ID \
        --scheme internet-facing \
        --type application \
        --ip-address-type ipv4 \
        --query 'LoadBalancers[0].LoadBalancerArn' --output text)
    
    echo "Waiting for load balancer to be active..."
    aws elbv2 wait load-balancer-available --load-balancer-arns $ALB_ARN
else
    echo "Load balancer exists: $ALB_ARN"
fi

# Create target groups
echo "Creating target groups..."

# Frontend target group
FRONTEND_TG_ARN=$(aws elbv2 describe-target-groups --names ecommerce-frontend-tg --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null || echo "None")
if [ "$FRONTEND_TG_ARN" = "None" ]; then
    FRONTEND_TG_ARN=$(aws elbv2 create-target-group \
        --name ecommerce-frontend-tg \
        --protocol HTTP \
        --port 80 \
        --vpc-id $VPC_ID \
        --target-type ip \
        --health-check-path /health \
        --health-check-interval-seconds 30 \
        --health-check-timeout-seconds 5 \
        --healthy-threshold-count 2 \
        --unhealthy-threshold-count 3 \
        --query 'TargetGroups[0].TargetGroupArn' --output text)
fi

# Backend target group
BACKEND_TG_ARN=$(aws elbv2 describe-target-groups --names ecommerce-backend-tg --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null || echo "None")
if [ "$BACKEND_TG_ARN" = "None" ]; then
    BACKEND_TG_ARN=$(aws elbv2 create-target-group \
        --name ecommerce-backend-tg \
        --protocol HTTP \
        --port 5000 \
        --vpc-id $VPC_ID \
        --target-type ip \
        --health-check-path /health \
        --health-check-interval-seconds 30 \
        --health-check-timeout-seconds 5 \
        --healthy-threshold-count 2 \
        --unhealthy-threshold-count 3 \
        --query 'TargetGroups[0].TargetGroupArn' --output text)
fi

# Create listeners
echo "Creating listeners..."

# Frontend listener (port 80)
FRONTEND_LISTENER=$(aws elbv2 describe-listeners --load-balancer-arn $ALB_ARN --query 'Listeners[?Port==`80`].ListenerArn' --output text 2>/dev/null || echo "")
if [ -z "$FRONTEND_LISTENER" ]; then
    aws elbv2 create-listener \
        --load-balancer-arn $ALB_ARN \
        --protocol HTTP \
        --port 80 \
        --default-actions Type=forward,TargetGroupArn=$FRONTEND_TG_ARN
fi

# Backend listener (port 5000)
BACKEND_LISTENER=$(aws elbv2 describe-listeners --load-balancer-arn $ALB_ARN --query 'Listeners[?Port==`5000`].ListenerArn' --output text 2>/dev/null || echo "")
if [ -z "$BACKEND_LISTENER" ]; then
    aws elbv2 create-listener \
        --load-balancer-arn $ALB_ARN \
        --protocol HTTP \
        --port 5000 \
        --default-actions Type=forward,TargetGroupArn=$BACKEND_TG_ARN
fi

# Export variables for other scripts
echo "export VPC_ID=$VPC_ID" > /tmp/aws-env.sh
echo "export SG_ID=$SG_ID" >> /tmp/aws-env.sh
echo "export ALB_ARN=$ALB_ARN" >> /tmp/aws-env.sh
echo "export FRONTEND_TG_ARN=$FRONTEND_TG_ARN" >> /tmp/aws-env.sh
echo "export BACKEND_TG_ARN=$BACKEND_TG_ARN" >> /tmp/aws-env.sh
echo "export SUBNET_IDS='${SUBNET_IDS}'" >> /tmp/aws-env.sh

echo "✅ Infrastructure deployment completed!"
echo "VPC ID: $VPC_ID"
echo "Security Group: $SG_ID"
echo "Load Balancer: $ALB_ARN" 