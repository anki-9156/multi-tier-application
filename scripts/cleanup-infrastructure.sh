#!/bin/bash
set -e

echo "🧹 Cleaning up Infrastructure..."

# Delete Load Balancer
echo "🗑️ Deleting Application Load Balancer..."
ALB_NAME="ecommerce-alb"

ALB_EXISTS=$(aws elbv2 describe-load-balancers --names $ALB_NAME --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null || echo "None")

if [ "$ALB_EXISTS" != "None" ]; then
    echo "Deleting ALB: $ALB_NAME"
    aws elbv2 delete-load-balancer --load-balancer-arn $ALB_EXISTS
    
    echo "⏳ Waiting for ALB to be deleted..."
    aws elbv2 wait load-balancers-deleted --load-balancer-arns $ALB_EXISTS
    echo "✅ ALB deleted: $ALB_NAME"
else
    echo "ℹ️ ALB not found: $ALB_NAME"
fi

# Delete Target Groups
echo "🗑️ Deleting Target Groups..."
TARGET_GROUPS=(
    "ecommerce-frontend-tg"
    "ecommerce-backend-tg"
)

for TG in "${TARGET_GROUPS[@]}"; do
    echo "Checking target group: $TG"
    TG_ARN=$(aws elbv2 describe-target-groups --names $TG --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null || echo "None")
    
    if [ "$TG_ARN" != "None" ]; then
        aws elbv2 delete-target-group --target-group-arn $TG_ARN
        echo "✅ Target group deleted: $TG"
    else
        echo "ℹ️ Target group not found: $TG"
    fi
done

# Delete Security Groups
echo "🗑️ Deleting Security Groups..."

# Get the VPC ID first
VPC_NAME="ecommerce-vpc"
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=$VPC_NAME" --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "None")

if [ "$VPC_ID" != "None" ]; then
    echo "Found VPC: $VPC_ID"
    
    # Get security groups in this VPC (excluding default)
    SECURITY_GROUPS=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=ecommerce-*" --query 'SecurityGroups[].GroupId' --output text)
    
    for SG in $SECURITY_GROUPS; do
        if [ ! -z "$SG" ]; then
            echo "Deleting security group: $SG"
            aws ec2 delete-security-group --group-id $SG || echo "Failed to delete security group $SG (may have dependencies)"
        fi
    done
fi

# Delete NAT Gateway
echo "🗑️ Deleting NAT Gateway..."
if [ "$VPC_ID" != "None" ]; then
    NAT_GATEWAYS=$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC_ID" --query 'NatGateways[?State==`available`].NatGatewayId' --output text)
    
    for NAT_GW in $NAT_GATEWAYS; do
        if [ ! -z "$NAT_GW" ]; then
            echo "Deleting NAT Gateway: $NAT_GW"
            aws ec2 delete-nat-gateway --nat-gateway-id $NAT_GW
            echo "✅ NAT Gateway deletion initiated: $NAT_GW"
        fi
    done
    
    # Wait for NAT Gateways to be deleted
    if [ ! -z "$NAT_GATEWAYS" ]; then
        echo "⏳ Waiting for NAT Gateways to be deleted..."
        for NAT_GW in $NAT_GATEWAYS; do
            if [ ! -z "$NAT_GW" ]; then
                aws ec2 wait nat-gateway-deleted --nat-gateway-ids $NAT_GW
            fi
        done
        echo "✅ NAT Gateways deleted"
    fi
fi

# Release Elastic IPs
echo "🗑️ Releasing Elastic IPs..."
ELASTIC_IPS=$(aws ec2 describe-addresses --filters "Name=domain,Values=vpc" --query 'Addresses[?AssociationId==null].AllocationId' --output text)

for EIP in $ELASTIC_IPS; do
    if [ ! -z "$EIP" ]; then
        echo "Releasing Elastic IP: $EIP"
        aws ec2 release-address --allocation-id $EIP || echo "Failed to release EIP $EIP"
    fi
done

# Delete Internet Gateway
echo "🗑️ Deleting Internet Gateway..."
if [ "$VPC_ID" != "None" ]; then
    IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query 'InternetGateways[0].InternetGatewayId' --output text 2>/dev/null || echo "None")
    
    if [ "$IGW_ID" != "None" ]; then
        echo "Detaching Internet Gateway: $IGW_ID"
        aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID
        
        echo "Deleting Internet Gateway: $IGW_ID"
        aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID
        echo "✅ Internet Gateway deleted: $IGW_ID"
    else
        echo "ℹ️ Internet Gateway not found"
    fi
fi

# Delete Route Tables (custom ones)
echo "🗑️ Deleting Route Tables..."
if [ "$VPC_ID" != "None" ]; then
    ROUTE_TABLES=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=ecommerce-*" --query 'RouteTables[].RouteTableId' --output text)
    
    for RT in $ROUTE_TABLES; do
        if [ ! -z "$RT" ]; then
            echo "Deleting route table: $RT"
            aws ec2 delete-route-table --route-table-id $RT || echo "Failed to delete route table $RT (may be main route table)"
        fi
    done
fi

# Delete Subnets
echo "🗑️ Deleting Subnets..."
if [ "$VPC_ID" != "None" ]; then
    SUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[].SubnetId' --output text)
    
    for SUBNET in $SUBNETS; do
        if [ ! -z "$SUBNET" ]; then
            echo "Deleting subnet: $SUBNET"
            aws ec2 delete-subnet --subnet-id $SUBNET || echo "Failed to delete subnet $SUBNET"
        fi
    done
fi

# Delete VPC
echo "🗑️ Deleting VPC..."
if [ "$VPC_ID" != "None" ]; then
    echo "Deleting VPC: $VPC_ID"
    aws ec2 delete-vpc --vpc-id $VPC_ID
    echo "✅ VPC deleted: $VPC_ID"
else
    echo "ℹ️ VPC not found: $VPC_NAME"
fi

# Delete IAM Roles
echo "🗑️ Deleting IAM Roles..."
IAM_ROLES=(
    "ecsTaskExecutionRole"
    "ecsTaskRole"
)

for ROLE in "${IAM_ROLES[@]}"; do
    echo "Checking IAM role: $ROLE"
    ROLE_EXISTS=$(aws iam get-role --role-name $ROLE --query 'Role.RoleName' --output text 2>/dev/null || echo "None")
    
    if [ "$ROLE_EXISTS" != "None" ]; then
        echo "Detaching policies from role: $ROLE"
        
        # List and detach all attached policies
        ATTACHED_POLICIES=$(aws iam list-attached-role-policies --role-name $ROLE --query 'AttachedPolicies[].PolicyArn' --output text)
        
        for POLICY in $ATTACHED_POLICIES; do
            if [ ! -z "$POLICY" ]; then
                echo "  Detaching policy: $POLICY"
                aws iam detach-role-policy --role-name $ROLE --policy-arn $POLICY
            fi
        done
        
        echo "Deleting IAM role: $ROLE"
        aws iam delete-role --role-name $ROLE
        echo "✅ IAM role deleted: $ROLE"
    else
        echo "ℹ️ IAM role not found: $ROLE"
    fi
done

echo "✅ Infrastructure cleanup completed!"
echo "💰 Load balancer, NAT Gateway, and other infrastructure charges have been stopped." 