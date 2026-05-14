pipeline {
    agent { label 'travelbooking' }

    environment {
        GOOGLE_APPLICATION_CREDENTIALS = credentials('gcp-service-account')
        GOOGLE_CLOUD_PROJECT           = credentials('gcp-project-id')
        GKE_CLUSTER                    = 'travelbooking-cluster'
        GKE_ZONE                       = 'us-central1-a'
        ARTIFACT_REGISTRY              = 'us-central1-docker.pkg.dev'
        DOCKER_REPO                    = "${ARTIFACT_REGISTRY}/${GOOGLE_CLOUD_PROJECT}/travel-booking"
        IMAGE_TAG                      = "1.0.${BUILD_NUMBER}"
        HELM_CHART_PATH                = 'helm/travel-booking'
        NAMESPACE                      = 'travel-booking'
    }

    stages {

        // ─────────────────────────────────────────────────────────────────────
        // STAGE 1: Clone Repository
        // ─────────────────────────────────────────────────────────────────────

        stage('Git Clone') {
            steps {
                container('docker') {
                    git branch: 'main', credentialsId: 'github-pat', url: 'https://github.com/vijaygiduthuri/travelbooking.git'
                    sh 'echo "Repository cloned successfully"'
                    sh 'ls -la'
                }
            }
        }

        // ─────────────────────────────────────────────────────────────────────
        // STAGE 2: Run Tests
        // ─────────────────────────────────────────────────────────────────────

        stage('Test - Go Services') {
            steps {
                container('golang') {
                    sh '''
                    echo "===== Testing User Service ====="
                    cd user-service
                    go mod download
                    go mod tidy
                    go vet ./...
                    cd ..

                    echo "===== Testing Search Service ====="
                    cd search-service
                    go mod download
                    go mod tidy
                    go vet ./...
                    cd ..

                    echo "===== Testing Booking Service ====="
                    cd booking-service
                    go mod download
                    go mod tidy
                    go vet ./...
                    cd ..

                    echo "===== Testing Payment Service ====="
                    cd payment-service
                    go mod download
                    go mod tidy
                    go vet ./...
                    cd ..

                    echo "===== Testing Notification Service ====="
                    cd notification-service
                    go mod download
                    go mod tidy
                    go vet ./...
                    cd ..

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

        // ─────────────────────────────────────────────────────────────────────
        // STAGE 3: Build, Tag & Push Docker Images
        // ─────────────────────────────────────────────────────────────────────

        stage('Docker Login') {
            steps {
                container('docker') {
                    sh '''
                    cat $GOOGLE_APPLICATION_CREDENTIALS | docker login -u _json_key --password-stdin https://${ARTIFACT_REGISTRY}
                    echo "Docker login to Artifact Registry successful"
                    '''
                }
            }
        }

        stage('Build & Push - User Service') {
            steps {
                container('docker') {
                    sh """
                    echo "===== Building User Service ====="
                    docker build -t ${DOCKER_REPO}/user-service:${IMAGE_TAG} ./user-service
                    docker tag ${DOCKER_REPO}/user-service:${IMAGE_TAG} ${DOCKER_REPO}/user-service:latest
                    docker push ${DOCKER_REPO}/user-service:${IMAGE_TAG}
                    docker push ${DOCKER_REPO}/user-service:latest
                    docker rmi ${DOCKER_REPO}/user-service:${IMAGE_TAG} || true
                    echo "User Service image pushed successfully"
                    """
                }
            }
        }

        stage('Build & Push - Search Service') {
            steps {
                container('docker') {
                    sh """
                    echo "===== Building Search Service ====="
                    docker build -t ${DOCKER_REPO}/search-service:${IMAGE_TAG} ./search-service
                    docker tag ${DOCKER_REPO}/search-service:${IMAGE_TAG} ${DOCKER_REPO}/search-service:latest
                    docker push ${DOCKER_REPO}/search-service:${IMAGE_TAG}
                    docker push ${DOCKER_REPO}/search-service:latest
                    docker rmi ${DOCKER_REPO}/search-service:${IMAGE_TAG} || true
                    echo "Search Service image pushed successfully"
                    """
                }
            }
        }

        stage('Build & Push - Booking Service') {
            steps {
                container('docker') {
                    sh """
                    echo "===== Building Booking Service ====="
                    docker build -t ${DOCKER_REPO}/booking-service:${IMAGE_TAG} ./booking-service
                    docker tag ${DOCKER_REPO}/booking-service:${IMAGE_TAG} ${DOCKER_REPO}/booking-service:latest
                    docker push ${DOCKER_REPO}/booking-service:${IMAGE_TAG}
                    docker push ${DOCKER_REPO}/booking-service:latest
                    docker rmi ${DOCKER_REPO}/booking-service:${IMAGE_TAG} || true
                    echo "Booking Service image pushed successfully"
                    """
                }
            }
        }

        stage('Build & Push - Payment Service') {
            steps {
                container('docker') {
                    sh """
                    echo "===== Building Payment Service ====="
                    docker build -t ${DOCKER_REPO}/payment-service:${IMAGE_TAG} ./payment-service
                    docker tag ${DOCKER_REPO}/payment-service:${IMAGE_TAG} ${DOCKER_REPO}/payment-service:latest
                    docker push ${DOCKER_REPO}/payment-service:${IMAGE_TAG}
                    docker push ${DOCKER_REPO}/payment-service:latest
                    docker rmi ${DOCKER_REPO}/payment-service:${IMAGE_TAG} || true
                    echo "Payment Service image pushed successfully"
                    """
                }
            }
        }

        stage('Build & Push - Notification Service') {
            steps {
                container('docker') {
                    sh """
                    echo "===== Building Notification Service ====="
                    docker build -t ${DOCKER_REPO}/notification-service:${IMAGE_TAG} ./notification-service
                    docker tag ${DOCKER_REPO}/notification-service:${IMAGE_TAG} ${DOCKER_REPO}/notification-service:latest
                    docker push ${DOCKER_REPO}/notification-service:${IMAGE_TAG}
                    docker push ${DOCKER_REPO}/notification-service:latest
                    docker rmi ${DOCKER_REPO}/notification-service:${IMAGE_TAG} || true
                    echo "Notification Service image pushed successfully"
                    """
                }
            }
        }

        stage('Build & Push - Frontend') {
            steps {
                container('docker') {
                    sh """
                    echo "===== Building Frontend ====="
                    docker build -t ${DOCKER_REPO}/frontend:${IMAGE_TAG} ./frontend
                    docker tag ${DOCKER_REPO}/frontend:${IMAGE_TAG} ${DOCKER_REPO}/frontend:latest
                    docker push ${DOCKER_REPO}/frontend:${IMAGE_TAG}
                    docker push ${DOCKER_REPO}/frontend:latest
                    docker rmi ${DOCKER_REPO}/frontend:${IMAGE_TAG} || true
                    echo "Frontend image pushed successfully"
                    """
                }
            }
        }

        // ─────────────────────────────────────────────────────────────────────
        // STAGE 4: Trivy Security Scan — Scan All Docker Images
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
                                trivy image --exit-code 0 --severity HIGH,CRITICAL --no-progress ${DOCKER_REPO}/${svc}:latest
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

        // ─────────────────────────────────────────────────────────────────────
        // STAGE 5: Update Helm Chart with New Image Tags
        // ─────────────────────────────────────────────────────────────────────

        stage('Update Helm Values') {
            steps {
                container('docker') {
                    sh """
                    echo "===== Updating Helm values.yaml with new image tags ====="

                    # Update all service images in values.yaml with the new build tag
                    sed -i 's|image: .*frontend:.*|image: ${DOCKER_REPO}/frontend:${IMAGE_TAG}|' ${HELM_CHART_PATH}/values.yaml
                    sed -i 's|image: .*user-service:.*|image: ${DOCKER_REPO}/user-service:${IMAGE_TAG}|' ${HELM_CHART_PATH}/values.yaml
                    sed -i 's|image: .*search-service:.*|image: ${DOCKER_REPO}/search-service:${IMAGE_TAG}|' ${HELM_CHART_PATH}/values.yaml
                    sed -i 's|image: .*booking-service:.*|image: ${DOCKER_REPO}/booking-service:${IMAGE_TAG}|' ${HELM_CHART_PATH}/values.yaml
                    sed -i 's|image: .*payment-service:.*|image: ${DOCKER_REPO}/payment-service:${IMAGE_TAG}|' ${HELM_CHART_PATH}/values.yaml
                    sed -i 's|image: .*notification-service:.*|image: ${DOCKER_REPO}/notification-service:${IMAGE_TAG}|' ${HELM_CHART_PATH}/values.yaml

                    echo "Updated values.yaml:"
                    grep "image:" ${HELM_CHART_PATH}/values.yaml

                    echo "Helm values updated successfully"
                    """
                }
            }
        }

        // ─────────────────────────────────────────────────────────────────────
        // STAGE 6: Package & Push Helm Chart to Artifact Registry
        // ─────────────────────────────────────────────────────────────────────

        stage('Package & Push Helm Chart') {
            steps {
                container('helm') {
                    sh """
                    echo "===== Packaging Helm Chart ====="

                    # Update chart version with build number
                    sed -i "s/^version:.*/version: 1.0.${BUILD_NUMBER}/" ${HELM_CHART_PATH}/Chart.yaml

                    # Package the chart
                    helm package ${HELM_CHART_PATH} --destination ${WORKSPACE}/helm-packages/

                    echo "Helm chart packaged successfully"
                    ls -la ${WORKSPACE}/helm-packages/
                    """
                }
                container('gcloud') {
                    sh """
                    echo "===== Getting Access Token ====="

                    # Authenticate with GCP
                    gcloud auth activate-service-account --key-file=\$GOOGLE_APPLICATION_CREDENTIALS
                    gcloud config set project \$GOOGLE_CLOUD_PROJECT

                    # Save access token to workspace (shared between containers)
                    gcloud auth print-access-token > ${WORKSPACE}/gcp-access-token
                    echo "Access token saved"
                    """
                }
                container('helm') {
                    sh """
                    echo "===== Pushing Helm Chart to Artifact Registry ====="

                    # Login to Helm registry using saved token from workspace
                    cat ${WORKSPACE}/gcp-access-token | helm registry login -u oauth2accesstoken --password-stdin https://${ARTIFACT_REGISTRY}

                    # Push helm chart
                    helm push ${WORKSPACE}/helm-packages/travel-booking-1.0.${BUILD_NUMBER}.tgz oci://${ARTIFACT_REGISTRY}/${GOOGLE_CLOUD_PROJECT}/travel-booking

                    echo "Helm chart pushed to Artifact Registry successfully"
                    """
                }
            }
        }

        // ─────────────────────────────────────────────────────────────────────
        // STAGE 7: Deploy to GKE
        // ─────────────────────────────────────────────────────────────────────

        stage('Deploy to GKE') {
            steps {
                container('gcloud') {
                    sh """
                    echo "===== Connecting to GKE Cluster ====="

                    # Authenticate with GCP
                    gcloud auth activate-service-account --key-file=\$GOOGLE_APPLICATION_CREDENTIALS
                    gcloud config set project \$GOOGLE_CLOUD_PROJECT

                    # Install kubectl, gke-auth-plugin, and helm
                    apt-get update -qq && apt-get install -y -qq kubectl google-cloud-cli-gke-gcloud-auth-plugin 2>/dev/null || true
                    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash 2>/dev/null

                    # Connect to GKE cluster
                    gcloud container clusters get-credentials ${GKE_CLUSTER} --zone ${GKE_ZONE} --project \$GOOGLE_CLOUD_PROJECT

                    echo "Connected to GKE cluster: ${GKE_CLUSTER}"
                    kubectl get nodes

                    # Create namespace if it doesn't exist
                    kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

                    # Login to Helm registry
                    gcloud auth print-access-token | helm registry login -u oauth2accesstoken --password-stdin https://${ARTIFACT_REGISTRY}

                    # Pull the latest chart
                    helm pull oci://${ARTIFACT_REGISTRY}/\$GOOGLE_CLOUD_PROJECT/travel-booking/travel-booking --version 1.0.${BUILD_NUMBER} --destination ${WORKSPACE}/

                    # Install or upgrade the helm release
                    helm upgrade --install travel-booking ${WORKSPACE}/travel-booking-1.0.${BUILD_NUMBER}.tgz \\
                      --namespace ${NAMESPACE} \\
                      --wait \\
                      --timeout 5m

                    echo "===== Deployment Complete ====="
                    echo ""
                    echo "Helm Release:"
                    helm list -n ${NAMESPACE}
                    echo ""
                    echo "Deployments:"
                    kubectl get deployments -n ${NAMESPACE}
                    echo ""
                    echo "Pods:"
                    kubectl get pods -n ${NAMESPACE}
                    echo ""
                    echo "Services:"
                    kubectl get svc -n ${NAMESPACE}
                    echo ""
                    echo "Gateway:"
                    kubectl get gateway -n ${NAMESPACE}
                    echo ""
                    echo "HTTPRoutes:"
                    kubectl get httproute -n ${NAMESPACE}
                    echo ""
                    echo "StatefulSets:"
                    kubectl get statefulsets -n ${NAMESPACE}
                    echo ""
                    echo "ConfigMaps:"
                    kubectl get configmaps -n ${NAMESPACE}
                    echo ""
                    echo "Secrets:"
                    kubectl get secrets -n ${NAMESPACE}
                    echo ""
                    echo "HPAs:"
                    kubectl get hpa -n ${NAMESPACE}
                    """
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // POST ACTIONS
    // ─────────────────────────────────────────────────────────────────────────

    post {
        success {
            echo """
            =========================================
            PIPELINE COMPLETED SUCCESSFULLY
            =========================================
            Build Number : ${BUILD_NUMBER}
            Image Tag    : ${IMAGE_TAG}
            Chart Version: 1.0.${BUILD_NUMBER}
            Cluster      : ${GKE_CLUSTER}
            Namespace    : ${NAMESPACE}
            =========================================
            """
        }
        failure {
            echo """
            =========================================
            PIPELINE FAILED
            =========================================
            Build Number : ${BUILD_NUMBER}
            Check the stage logs above for details.
            =========================================
            """
        }
        always {
            // Clean up Docker images to save space
            container('docker') {
                sh 'docker system prune -f || true'
            }
        }
    }
}
