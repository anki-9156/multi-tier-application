pipeline {
    agent any
    
    environment {
        AWS_DEFAULT_REGION = 'us-east-1'
        AWS_ACCOUNT_ID = '358112240377'
        ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com"
        BACKEND_REPO = 'ecommerce/backend'
        FRONTEND_REPO = 'ecommerce/frontend'
        ECS_CLUSTER = 'multi-tier'
        DB_NAME = 'postgres'
        DB_USERNAME = 'postgres'
        VPC_CIDR = '172.31.0.0/16'
        
        // These should be set as Jenkins credentials
        AWS_CREDENTIALS = credentials('aws-credentials')
        DB_PASSWORD = credentials('db-password')
        JWT_SECRET = credentials('jwt-secret')
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.GIT_COMMIT_SHORT = sh(
                        script: 'git rev-parse --short HEAD',
                        returnStdout: true
                    ).trim()
                    env.BUILD_TAG = "${env.BUILD_NUMBER}-${env.GIT_COMMIT_SHORT}"
                }
            }
        }
        
        stage('Setup AWS CLI') {
            steps {
                script {
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                        sh '''
                            aws configure set region $AWS_DEFAULT_REGION
                            aws sts get-caller-identity
                        '''
                    }
                }
            }
        }
        
        stage('Build and Push Images') {
            parallel {
                stage('Backend') {
                    steps {
                        script {
                            withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                                sh '''
                                    # Login to ECR
                                    aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY
                                    
                                    # Build backend image
                                    cd backend
                                    docker build --platform linux/amd64 -t $BACKEND_REPO:$BUILD_TAG .
                                    docker tag $BACKEND_REPO:$BUILD_TAG $ECR_REGISTRY/$BACKEND_REPO:$BUILD_TAG
                                    docker tag $BACKEND_REPO:$BUILD_TAG $ECR_REGISTRY/$BACKEND_REPO:latest
                                    
                                    # Push backend image
                                    docker push $ECR_REGISTRY/$BACKEND_REPO:$BUILD_TAG
                                    docker push $ECR_REGISTRY/$BACKEND_REPO:latest
                                '''
                            }
                        }
                    }
                }
                
                stage('Frontend') {
                    steps {
                        script {
                            withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                                sh '''
                                    # Login to ECR
                                    aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY
                                    
                                    # Build frontend image with API URL
                                    cd frontend
                                    ALB_DNS=$(aws elbv2 describe-load-balancers --names ecommerce-alb --query 'LoadBalancers[0].DNSName' 2>/dev/null || echo "")
                                    if [ -z "$ALB_DNS" ]; then
                                        REACT_APP_API_URL="http://placeholder-alb:5000/api"
                                    else
                                        REACT_APP_API_URL="http://$ALB_DNS:5000/api"
                                    fi
                                    
                                    docker build --platform linux/amd64 --build-arg REACT_APP_API_URL=$REACT_APP_API_URL -t $FRONTEND_REPO:$BUILD_TAG .
                                    docker tag $FRONTEND_REPO:$BUILD_TAG $ECR_REGISTRY/$FRONTEND_REPO:$BUILD_TAG
                                    docker tag $FRONTEND_REPO:$BUILD_TAG $ECR_REGISTRY/$FRONTEND_REPO:latest
                                    
                                    # Push frontend image
                                    docker push $ECR_REGISTRY/$FRONTEND_REPO:$BUILD_TAG
                                    docker push $ECR_REGISTRY/$FRONTEND_REPO:latest
                                '''
                            }
                        }
                    }
                }
            }
        }
        
        stage('Deploy Infrastructure') {
            steps {
                script {
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                        sh '''
                            chmod +x scripts/deploy-infrastructure.sh
                            ./scripts/deploy-infrastructure.sh
                        '''
                    }
                }
            }
        }
        
        stage('Deploy Database') {
            steps {
                script {
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                        sh '''
                            chmod +x scripts/deploy-database.sh
                            ./scripts/deploy-database.sh
                        '''
                    }
                }
            }
        }
        
        stage('Deploy ECS Services') {
            steps {
                script {
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                        sh '''
                            chmod +x scripts/deploy-ecs.sh
                            ./scripts/deploy-ecs.sh
                        '''
                    }
                }
            }
        }
        
        stage('Update Frontend with ALB URL') {
            steps {
                script {
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                        sh '''
                            # Get ALB DNS and rebuild frontend if needed
                            ALB_DNS=$(aws elbv2 describe-load-balancers --names ecommerce-alb --query 'LoadBalancers[0].DNSName' --output text)
                            echo "ALB DNS: $ALB_DNS"
                            
                            # Check if frontend was built with placeholder
                            if docker run --rm $ECR_REGISTRY/$FRONTEND_REPO:latest cat /usr/share/nginx/html/static/js/*.js | grep -q "placeholder-alb"; then
                                echo "Rebuilding frontend with actual ALB URL..."
                                
                                # Login to ECR
                                aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY
                                
                                # Rebuild and push frontend
                                cd frontend
                                REACT_APP_API_URL="http://$ALB_DNS:5000/api"
                                docker build --platform linux/amd64 --build-arg REACT_APP_API_URL=$REACT_APP_API_URL -t $FRONTEND_REPO:$BUILD_TAG-final .
                                docker tag $FRONTEND_REPO:$BUILD_TAG-final $ECR_REGISTRY/$FRONTEND_REPO:latest
                                docker push $ECR_REGISTRY/$FRONTEND_REPO:latest
                                
                                # Force ECS service update
                                aws ecs update-service --cluster $ECS_CLUSTER --service ecommerce-frontend-service --force-new-deployment
                            fi
                        '''
                    }
                }
            }
        }
        
        stage('Health Check') {
            steps {
                script {
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                        sh '''
                            # Wait for services to be stable
                            echo "Waiting for ECS services to stabilize..."
                            aws ecs wait services-stable --cluster $ECS_CLUSTER --services ecommerce-backend-service
                            aws ecs wait services-stable --cluster $ECS_CLUSTER --services ecommerce-frontend-service
                            
                            # Get ALB URL and test endpoints
                            ALB_DNS=$(aws elbv2 describe-load-balancers --names ecommerce-alb --query 'LoadBalancers[0].DNSName' --output text)
                            
                            echo "Testing backend health..."
                            curl -f "http://$ALB_DNS:5000/health" || exit 1
                            
                            echo "Testing frontend health..."
                            curl -f "http://$ALB_DNS/health" || exit 1
                            
                            echo "Testing API endpoint..."
                            curl -f "http://$ALB_DNS:5000/api/products" || exit 1
                            
                            echo "Deployment successful!"
                            echo "Frontend URL: http://$ALB_DNS/"
                            echo "Backend API: http://$ALB_DNS:5000/api"
                        '''
                    }
                }
            }
        }
    }
    
    post {
        always {
            sh 'docker system prune -f'
        }
        success {
            script {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                    def albDns = sh(
                        script: 'aws elbv2 describe-load-balancers --names ecommerce-alb --query "LoadBalancers[0].DNSName" --output text',
                        returnStdout: true
                    ).trim()
                    
                    echo "✅ Deployment Successful!"
                    echo "🌐 Frontend: http://${albDns}/"
                    echo "🔌 Backend API: http://${albDns}:5000/api"
                    echo "🏷️ Images tagged: ${env.BUILD_TAG}"
                }
            }
        }
        failure {
            echo "❌ Deployment failed. Check logs for details."
        }
    }
} 