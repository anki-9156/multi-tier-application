#!/bin/bash
set -e

echo "🗄️ Deploying Database..."

# Source infrastructure variables
source /tmp/aws-env.sh

# Create DB subnet group
echo "Creating DB subnet group..."
SUBNET_ARRAY=($SUBNET_IDS)
DB_SUBNET_GROUP_NAME="ecommerce-db-subnet-group"

# Check if subnet group exists
aws rds describe-db-subnet-groups --db-subnet-group-name $DB_SUBNET_GROUP_NAME >/dev/null 2>&1 || {
    echo "Creating new DB subnet group..."
    aws rds create-db-subnet-group \
        --db-subnet-group-name $DB_SUBNET_GROUP_NAME \
        --db-subnet-group-description "Subnet group for ecommerce database" \
        --subnet-ids ${SUBNET_ARRAY[@]}
}

# Check if database exists
DB_IDENTIFIER="database-2"
DB_STATUS=$(aws rds describe-db-instances --db-instance-identifier $DB_IDENTIFIER --query 'DBInstances[0].DBInstanceStatus' --output text 2>/dev/null || echo "not-found")

if [ "$DB_STATUS" = "not-found" ]; then
    echo "Creating RDS PostgreSQL database..."
    # Get the latest available PostgreSQL version
    POSTGRES_VERSION=$(aws rds describe-db-engine-versions --engine postgres --default-only --query 'DBEngineVersions[0].EngineVersion' --output text)
    echo "Using PostgreSQL version: $POSTGRES_VERSION"
    
    aws rds create-db-instance \
        --db-instance-identifier $DB_IDENTIFIER \
        --db-instance-class db.t3.micro \
        --engine postgres \
        --engine-version $POSTGRES_VERSION \
        --master-username $DB_USERNAME \
        --master-user-password $DB_PASSWORD \
        --allocated-storage 20 \
        --storage-type gp2 \
        --vpc-security-group-ids $SG_ID \
        --db-subnet-group-name $DB_SUBNET_GROUP_NAME \
        --backup-retention-period 0 \
        --no-multi-az \
        --no-publicly-accessible \
        --no-storage-encrypted \
        --no-deletion-protection \
        --db-name $DB_NAME
    
    echo "Waiting for database to be available..."
    aws rds wait db-instance-available --db-instance-identifier $DB_IDENTIFIER
    echo "Database is now available!"
else
    echo "Database already exists with status: $DB_STATUS"
    if [ "$DB_STATUS" != "available" ]; then
        echo "Waiting for database to be available..."
        aws rds wait db-instance-available --db-instance-identifier $DB_IDENTIFIER
    fi
fi

# Get database endpoint
DB_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier $DB_IDENTIFIER --query 'DBInstances[0].Endpoint.Address' --output text)
echo "Database endpoint: $DB_ENDPOINT"

# Export database info
echo "export DB_ENDPOINT=$DB_ENDPOINT" >> /tmp/aws-env.sh
echo "export DB_IDENTIFIER=$DB_IDENTIFIER" >> /tmp/aws-env.sh

echo "✅ Database deployment completed!" 