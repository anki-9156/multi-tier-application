#!/bin/bash
set -e

echo "🧹 Cleaning up ECR repositories..."

# ECR repositories to clean up
REPOSITORIES=(
    "$FRONTEND_REPO"
    "$BACKEND_REPO"
)

for REPO in "${REPOSITORIES[@]}"; do
    echo "Checking ECR repository: $REPO"
    
    REPO_EXISTS=$(aws ecr describe-repositories --repository-names $REPO --query 'repositories[0].repositoryName' --output text 2>/dev/null || echo "None")
    
    if [ "$REPO_EXISTS" != "None" ]; then
        echo "🗑️ Deleting all images in repository: $REPO"
        
        # Get all image tags
        IMAGE_TAGS=$(aws ecr list-images --repository-name $REPO --query 'imageIds[].imageTag' --output text 2>/dev/null || echo "")
        
        if [ ! -z "$IMAGE_TAGS" ]; then
            echo "Found images with tags: $IMAGE_TAGS"
            
            # Delete all images
            aws ecr batch-delete-image \
                --repository-name $REPO \
                --image-ids imageTag=latest || echo "No 'latest' tag found"
            
            # Delete any other tagged images
            for TAG in $IMAGE_TAGS; do
                if [ "$TAG" != "latest" ] && [ ! -z "$TAG" ]; then
                    aws ecr batch-delete-image \
                        --repository-name $REPO \
                        --image-ids imageTag=$TAG || echo "Failed to delete tag: $TAG"
                fi
            done
            
            # Delete untagged images
            UNTAGGED_IMAGES=$(aws ecr list-images --repository-name $REPO --filter tagStatus=UNTAGGED --query 'imageIds[].imageDigest' --output text 2>/dev/null || echo "")
            
            if [ ! -z "$UNTAGGED_IMAGES" ]; then
                for DIGEST in $UNTAGGED_IMAGES; do
                    if [ ! -z "$DIGEST" ]; then
                        aws ecr batch-delete-image \
                            --repository-name $REPO \
                            --image-ids imageDigest=$DIGEST || echo "Failed to delete untagged image"
                    fi
                done
            fi
        fi
        
        echo "🗑️ Deleting ECR repository: $REPO"
        aws ecr delete-repository --repository-name $REPO --force
        echo "✅ ECR repository deleted: $REPO"
    else
        echo "ℹ️ ECR repository not found: $REPO"
    fi
done

echo "✅ ECR cleanup completed!"
echo "💰 ECR storage charges have been stopped." 