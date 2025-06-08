#!/bin/bash
set -e

echo "🧹 Cleaning up RDS Database..."

DB_IDENTIFIER="database-2"

# Check if RDS instance exists
echo "Checking RDS instance: $DB_IDENTIFIER"
DB_EXISTS=$(aws rds describe-db-instances --db-instance-identifier $DB_IDENTIFIER --query 'DBInstances[0].DBInstanceIdentifier' --output text 2>/dev/null || echo "None")

if [ "$DB_EXISTS" != "None" ]; then
    echo "🗑️ Deleting RDS instance: $DB_IDENTIFIER"
    
    # Delete the RDS instance without final snapshot (faster cleanup)
    aws rds delete-db-instance \
        --db-instance-identifier $DB_IDENTIFIER \
        --skip-final-snapshot \
        --delete-automated-backups
    
    echo "⏳ Waiting for RDS instance to be deleted (this may take 5-10 minutes)..."
    
    # Wait for the instance to be deleted (with timeout)
    echo "ℹ️ You can monitor deletion progress in AWS Console"
    echo "ℹ️ This script will wait up to 15 minutes for deletion to complete"
    
    # Check deletion status every 30 seconds for up to 15 minutes
    TIMEOUT=900  # 15 minutes
    ELAPSED=0
    INTERVAL=30
    
    while [ $ELAPSED -lt $TIMEOUT ]; do
        DB_STATUS=$(aws rds describe-db-instances --db-instance-identifier $DB_IDENTIFIER --query 'DBInstances[0].DBInstanceStatus' --output text 2>/dev/null || echo "deleted")
        
        if [ "$DB_STATUS" = "deleted" ]; then
            echo "✅ RDS instance successfully deleted: $DB_IDENTIFIER"
            break
        else
            echo "⏳ Current status: $DB_STATUS (waiting...)"
            sleep $INTERVAL
            ELAPSED=$((ELAPSED + INTERVAL))
        fi
    done
    
    if [ $ELAPSED -ge $TIMEOUT ]; then
        echo "⚠️ Timeout reached. RDS deletion may still be in progress."
        echo "ℹ️ Check AWS Console for final status."
    fi
else
    echo "ℹ️ RDS instance not found: $DB_IDENTIFIER"
fi

# Delete DB subnet group
echo "🗑️ Deleting DB subnet group..."
DB_SUBNET_GROUP="ecommerce-db-subnet-group"

SUBNET_GROUP_EXISTS=$(aws rds describe-db-subnet-groups --db-subnet-group-name $DB_SUBNET_GROUP --query 'DBSubnetGroups[0].DBSubnetGroupName' --output text 2>/dev/null || echo "None")

if [ "$SUBNET_GROUP_EXISTS" != "None" ]; then
    # Wait a bit more to ensure RDS is fully deleted before deleting subnet group
    echo "⏳ Waiting for RDS to be fully deleted before removing subnet group..."
    sleep 60
    
    aws rds delete-db-subnet-group --db-subnet-group-name $DB_SUBNET_GROUP
    echo "✅ DB subnet group deleted: $DB_SUBNET_GROUP"
else
    echo "ℹ️ DB subnet group not found: $DB_SUBNET_GROUP"
fi

echo "✅ Database cleanup completed!"
echo "💰 RDS charges have been stopped." 