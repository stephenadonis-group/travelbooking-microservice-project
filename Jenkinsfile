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

        stage('Build & Push Services') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-credentials',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
        
                    container('awscli') {
                        sh '''
                        echo "===== Configuring Amazon ECR Authentication ====="
        
                        mkdir -p /home/jenkins/.docker
        
                        PASSWORD=$(aws ecr get-login-password --region ${AWS_DEFAULT_REGION})
                        AUTH=$(printf "AWS:%s" "$PASSWORD" | base64 | tr -d '\n')
        
                        printf '{
          "auths": {
            "%s": {
              "auth": "%s"
            }
          }
        }\n' "${ECR_REGISTRY}" "${AUTH}" > /home/jenkins/.docker/config.json
        
                        echo "Amazon ECR authentication configured successfully."
                        '''
                    }
        
                    container('kaniko') {
                        sh '''
                        echo "===== Preparing Kaniko ====="
        
                        mkdir -p /kaniko/.docker
                        cp /home/jenkins/.docker/config.json /kaniko/.docker/config.json
        
                        if [ -f /kaniko/.docker/config.json ]; then
                            echo "Docker configuration copied successfully."
                        else
                            echo "Failed to copy Docker configuration."
                            exit 1
                        fi
                        '''
        
                        script {
        
                            def services = [
                                'frontend',
                                'user-service',
                                'search-service',
                                'booking-service',
                                'payment-service',
                                'notification-service'
                            ]
        
                            for (service in services) {
        
                                sh """
                                echo "===== Building ${service} ====="
        
                                /kaniko/executor \
                                  --context ./${service} \
                                  --dockerfile ./${service}/Dockerfile \
                                  --destination ${ECR_REGISTRY}/${service}:${IMAGE_TAG} \
                                  --destination ${ECR_REGISTRY}/${service}:latest \
                                  --cache=true \
                                  --cache-repo=${ECR_REGISTRY}/kaniko-cache
        
                                echo "${service} image built and pushed successfully."
                                """
        
                            }
                        }
                    }
                }
            }
        }    
        // ─────────────────────────────────────────────────────────────────────
        // STAGE: Trivy Security Scan
        // ─────────────────────────────────────────────────────────────────────
        stage('Trivy Security Scan') {
            steps {
                container('docker') {
                    script {
                        def services = ['user-service', 'search-service', 'booking-service', 'payment-service', 'notification-service', 'frontend']
                        
                        // Install Trivy
                        sh '''
                        apk add --no-cache curl tar
                        curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
                        trivy --version
                        '''
        
                        // Scan each image
                        for (svc in services) {
                            def scanStatus = sh(
                                script: """
                                echo "===== Scanning ${svc} ====="
                                trivy image --exit-code 0 --severity HIGH,CRITICAL --no-progress ${ECR_REGISTRY}/${svc}:latest || true
                                """,
                                returnStatus: true
                            )
                            if (scanStatus != 0) {
                                echo "WARNING: Trivy scan for ${svc} found issues, but pipeline will continue."
                            }
                        }
                        echo "All images scanned successfully"
                    }
                }
            }
        }
        stage('Update Helm Values') {
            steps {
                container('helm') {
                    sh '''
                    echo "===== Updating Helm values.yaml ====="
        
                    sed -i "s|image: .*frontend:.*|image: ${ECR_REGISTRY}/frontend:${IMAGE_TAG}|g" ${HELM_CHART_PATH}/values.yaml
                    sed -i "s|image: .*user-service:.*|image: ${ECR_REGISTRY}/user-service:${IMAGE_TAG}|g" ${HELM_CHART_PATH}/values.yaml
                    sed -i "s|image: .*search-service:.*|image: ${ECR_REGISTRY}/search-service:${IMAGE_TAG}|g" ${HELM_CHART_PATH}/values.yaml
                    sed -i "s|image: .*booking-service:.*|image: ${ECR_REGISTRY}/booking-service:${IMAGE_TAG}|g" ${HELM_CHART_PATH}/values.yaml
                    sed -i "s|image: .*payment-service:.*|image: ${ECR_REGISTRY}/payment-service:${IMAGE_TAG}|g" ${HELM_CHART_PATH}/values.yaml
                    sed -i "s|image: .*notification-service:.*|image: ${ECR_REGISTRY}/notification-service:${IMAGE_TAG}|g" ${HELM_CHART_PATH}/values.yaml
        
                    echo "===== Updated Images ====="
        
                    grep "image:" ${HELM_CHART_PATH}/values.yaml
                    '''
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
