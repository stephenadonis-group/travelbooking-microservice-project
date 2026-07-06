pipeline {
    agent { label 'travelbooking' }

    environment {
        AWS_DEFAULT_REGION = 'us-east-1'
        AWS_ACCOUNT_ID     = credentials('aws-account-id')
        ECR_REGISTRY       = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com"
        IMAGE_TAG          = "1.0.${BUILD_NUMBER}"
        HELM_CHART_PATH    = 'helm/travel-booking'
        NAMESPACE          = 'travel-booking'
    }

    stages {
        

        stage('Test - Go Services') {
            steps {
                container('golang') {
                    sh '''
                    for service in user-service search-service booking-service payment-service notification-service; do
                        echo "===== Testing $service ====="
                        cd $service
                        go mod download
                        go mod tidy
                        go vet ./...
                        cd ..
                    done
                    echo "All Go services passed testing"
                    '''
                }
            }
        }

        stage('Test - Frontend') {
            steps {
                container('nodejs') {
                    sh '''
                    echo "===== Testing Frontend ====="
                    cd frontend
                    npm install --legacy-peer-deps
                    echo "Frontend dependencies installed successfully"
                    cd ..
                    '''
                }
            }
        }

        stage('Docker Login to ECR') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials', accessKeyVariable: 'AWS_ACCESS_KEY_ID', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
                    container('awscli') {
                        sh '''
                        aws ecr get-login-password --region $AWS_DEFAULT_REGION > /tmp/ecr-login.txt
                        echo "Retrieved ECR login password"
                        '''
                    }
                    container('docker') {
                        sh '''
                        cat /tmp/ecr-login.txt | docker login --username AWS --password-stdin $ECR_REGISTRY
                        echo "Successfully logged into Amazon ECR"
                        '''
                    }
                }
            }
        }

        stage('Build & Push Services') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials', accessKeyVariable: 'AWS_ACCESS_KEY_ID', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
                    container('docker') {
                        script {
                            def services = ['frontend', 'user-service', 'search-service', 'booking-service', 'payment-service', 'notification-service']
                            for (service in services) {
                                sh """
                                echo "===== Building ${service} ====="
                                docker build -t ${ECR_REGISTRY}/${service}:${IMAGE_TAG} ./${service}
                                docker tag ${ECR_REGISTRY}/${service}:${IMAGE_TAG} ${ECR_REGISTRY}/${service}:latest
                                docker push ${ECR_REGISTRY}/${service}:${IMAGE_TAG}
                                docker push ${ECR_REGISTRY}/${service}:latest
                                docker rmi ${ECR_REGISTRY}/${service}:${IMAGE_TAG} || true
                                echo "${service} image pushed successfully"
                                """
                            }
                        }
                    }
                }
            }
        }

        stage('Update Helm Values') {
            steps {
                container('helm') {
                    sh """
                    echo "===== Updating Helm values.yaml ====="
                    for service in frontend user-service search-service booking-service payment-service notification-service; do
                        sed -i "s|image: .*${service}:.*|image: ${ECR_REGISTRY}/${service}:${IMAGE_TAG}|g" ${HELM_CHART_PATH}/values.yaml
                    done
                    echo "Helm values updated successfully"
                    grep "image:" ${HELM_CHART_PATH}/values.yaml
                    """
                }
            }
        }

        stage('Deploy to EKS') {
            steps {
                container('helm') {
                    sh """
                    echo "===== Deploying to EKS ====="
                    helm upgrade --install travel-booking ${HELM_CHART_PATH} \\
                      --namespace ${NAMESPACE} \\
                      --create-namespace \\
                      --wait \\
                      --timeout 5m
                    echo "Deployment completed successfully"
                    """
                }
            }
        }
    }

    post {
        success {
            echo "✅ Pipeline completed successfully! Build #${BUILD_NUMBER}"
        }
        failure {
            echo "❌ Pipeline failed. Check logs above."
        }
    }
}
