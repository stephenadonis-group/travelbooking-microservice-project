# TravelBooking — Jenkins CI/CD Setup Guide

This guide explains how to install Jenkins on Amazon EKS using Helm and configure a production-ready CI/CD pipeline for the TravelBooking microservices application.

Jenkins runs inside the EKS cluster and uses dynamic Kubernetes agents to build, scan, package, and deploy the application to Amazon EKS.
---

## What is Jenkins?

Jenkins is an **open-source automation server** used for CI/CD (Continuous Integration / Continuous Deployment). It automatically builds, tests, and deploys your application whenever you push code changes.

**In our setup:**
- Jenkins runs **inside the GKE cluster** as a Kubernetes pod
- Build agents (workers) are **dynamically created as pods** — they spin up when a job runs and get destroyed when done
- Each agent pod has multiple containers: Docker, Go, Node.js, Helm, gcloud — one for each task

---

## What the Pipeline Does

```
┌──────────────────────────────────────────────────────────────────────┐
│                    TravelBooking Jenkins Pipeline                     │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Stage 1: Git Clone                                                  │
│     └── Clone the repository from GitHub                             │
│                                                                      │
│  Stage 2: Run Tests                                                  │
│     ├── Go vet on all 5 Go services                                  │
│     └── npm install on frontend                                      │
│                                                                      │
│  Stage 3: Build, Tag & Push Docker Images (6 separate stages)        │
│     ├── user-service      → Amazon ECR                               │
│     ├── search-service    → Amazon ECR                               │
│     ├── booking-service   → Amazon ECR                               │
│     ├── payment-service   → Amazon ECR                               │
│     ├── notification-service → Amazon ECR                            │
│     └── frontend          → Amazon ECR                               │
│                                                                      │
│  Stage 4: Trivy Security Scan                                        │
│     └── Scan all 6 images for HIGH/CRITICAL vulnerabilities          │
│                                                                      │
│  Stage 5: Update Helm Values                                         │
│     └── Update values.yaml with new image tags (1.0.BUILD_NUMBER)    │
│                                                                      │
│  Stage 6: Deploy to AWS EKS                                          │
│     └──  → helm upgrade --install on AWS                             │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

Before starting, make sure you have:

1. **GKE cluster running** (created via Terraform or manually)
2. **kubectl connected** to the cluster
3. **Helm installed** on your local machine
4. **ECR Registry** created (name: `travel-booking`)
5. IAM User or IAM Role with:

AmazonEC2ContainerRegistryFullAccess
AmazonEKSClusterPolicy
AmazonEKSWorkerNodePolicy
AmazonEKS_CNI_Policy
AmazonEC2FullAccess (or least privilege equivalent)

---

## Step 1: Install Jenkins on EKS

### 1a. Add Jenkins Helm Repository

```bash
helm repo add jenkins https://charts.jenkins.io
helm repo update
```

### 1b. Verify the Repository

```bash
helm repo ls
helm search repo jenkins/jenkins --versions | head -10
```

### 1c. Download the Jenkins Chart

```bash
# Download chart version 5.8.53
helm pull jenkins/jenkins --version 5.8.53

# Extract to see the chart structure (optional)
tar -zxvf jenkins-5.8.53.tgz
ls jenkins/
```

### 1d. Preview What Will Be Installed

```bash
# Dry run — shows all Kubernetes resources that will be created
helm template jenkins jenkins -f custom-values.yaml
```

### 1e. Install Jenkins

```bash
# Install Jenkins using the custom values file
helm install jenkins jenkins -f custom-values.yaml
```

**What this command does:**
- `helm install` — install a new Helm release
- `jenkins` (first) — the release name
- `jenkins` (second) — the chart directory (extracted in step 1c)
- `-f custom-values.yaml` — use our custom configuration

### 1f. Verify Installation

```bash
# Check Helm release
helm ls
helm get values jenkins

# Check pods (Jenkins controller should be Running)
kubectl get pods

# Check services (note the NodePort number)
kubectl get svc

# Check persistent storage
kubectl get pv
kubectl get pvc
```

**Expected output:**
```
NAME                  READY   STATUS    AGE
jenkins-0             1/1     Running   2m

NAME            TYPE       CLUSTER-IP      PORT(S)
jenkins         NodePort   34.118.x.x      8080:3xxxx/TCP
jenkins-agent   ClusterIP  34.118.x.x      50000/TCP
```

### 1g. Access Jenkins

Get the NodePort:
```bash
kubectl get svc jenkins -o jsonpath='{.spec.ports[0].nodePort}'
```

Get a node's external IP:
```bash
kubectl get nodes -o wide | awk '{print $7}' | tail -1
```

Access Jenkins at: `http://<NODE_EXTERNAL_IP>:<NODE_PORT>/jenkins`

**Login credentials:**
- Username: `stephen`
- Password: `stephen@123`

---

## Step 2: Configure Jenkins Credentials

After logging in, you need to add AWS credentials so Jenkins can push images and deploy to AWS EKS.

### 2a. Add GCP Service Account Key

1. Go to **Manage Jenkins** → **Credentials** → **System** → **Global credentials**
2. Click **Add Credentials**
3. Fill in:
4. 
   | Credential ID                        | Type                   | What It Contains                              | Used For                                                         |
   | ------------------------------------ | ---------------------- | --------------------------------------------- | ---------------------------------------------------------------- |
   | `aws-credentials`                    | AWS Credentials        | AWS Access Key ID + AWS Secret Access Key     | Authenticate Jenkins with AWS for ECR, EKS, and AWS CLI commands |
   | `github-credentials`                 | Username with Password | GitHub Username + Personal Access Token (PAT) | Clone private GitHub repositories                                |
   | `dockerhub-credentials` *(optional)* | Username with Password | Docker Hub Username + Password/Access Token   | Push or pull Docker images from Docker Hub (if used)             |

Recommended Global Environment Variables (Manage Jenkins → Configure System → Global properties):

| Name                   | Value            |
| ---------------------- | ---------------- |
| **AWS_DEFAULT_REGION** | `us-east-1`      |
| **NAMESPACE**          | `travel-booking` |


### 2c. Add GitHub Credentials (if repository is private)

1. Click **Add Credentials**
2. Fill in:
   - **Kind:** Username with password
   - **Username:** your GitHub username
   - **Password:** your GitHub Personal Access Token
   - **ID:** `github-pat`
   - **Description:** GitHub Access
3. Click **Create**

---

## Step 3: Create the Pipeline Job

### 3a. Create New Pipeline

1. From Jenkins dashboard, click **New Item**
2. Enter name: `travel-booking-pipeline`
3. Select **Pipeline**
4. Click **OK**

### 3b. Configure Pipeline

1. Scroll down to **Pipeline** section
2. Select **Pipeline script from SCM**
3. **SCM:** Git
4. **Repository URL:** `https://github.com/stephenadonis-group/travelbooking-microservice-project.git`
5. **Branch:** `*/main`
6. **Script Path:** `Jenkinsfile`
7. Click **Save**

### 3c. Run the Pipeline

1. Click **Build Now** on the pipeline page
2. Click on the build number to see the progress
3. Click **Pipeline Stage View** to see all stages visually
4. Click **Console Output** for detailed logs

---

## Step 4: Verify the Pipeline

After a successful run, verify:

```bash
# Check deployed pods
kubectl get pods -n travel-booking

# Check images in Artifact Registry
aws ecr describe-repositories

# Check Helm release on EKS
helm list -n travel-booking

# Check AWS ALB Ingress Controller.
kubectl get ingress -n travel-booking```

---

## What Each Jenkins Agent Container Does

| Container | Image | Used In Stage | Purpose |
|-----------|-------|---------------|---------|
| `jnlp` | jenkins/inbound-agent | All | Jenkins agent communication |
| `docker` | docker:dind | Build & Push, Trivy | Build Docker images, run security scans |
| `golang` | golang:1.21 | Test Go Services | Compile and vet Go code |
| `nodejs` | node:20.10.0 | Test Frontend | Install and test Node.js dependencies |
| `helm` | alpine/helm:3.14.0 | Package Helm | Package Helm charts |
| `AWS` |amazon/aws-cli | Push Chart, Deploy | Authenticate with ECR, deploy to AWS |
| `kaniko` | kaniko-project/executor | (Alternative) | Build images without Docker daemon |

---

## Custom Values Explained

| Setting | Value | Why |
|---------|-------|-----|
| `admin.username` | stephen | Jenkins admin login |
| `admin.password` | stephen@123 | Jenkins admin password |
| `jenkinsUriPrefix` | /jenkins | Access Jenkins at `/jenkins` path |
| `serviceType` | NodePort | Exposes Jenkins on a node port |
| `persistence.size` | 15Gi | Storage for Jenkins data and plugins |
| `persistence.storageClass` | premium-rwo | High-performance SSD storage on GKE |
| `containerCapStr` | 10 | Max 10 agent pods running at once |
| `installPlugins` | (list) | Pre-installed plugins for pipelines, Git, Blue Ocean, etc. |

---

## Plugins Installed

| Plugin | Purpose |
|--------|---------|
| `kubernetes` | Run Jenkins agents as Kubernetes pods |
| `git` | Clone Git repositories |
| `blueocean` | Modern pipeline UI |
| `workflow-aggregator` | Pipeline support |
| `pipeline-stage-view` | Visual stage progress |
| `pipeline-graph-view` | Graph view of pipeline stages |
| `credentials-binding` | Use credentials in pipelines securely |
| `github` | GitHub integration |
| `configuration-as-code` | Configure Jenkins via YAML |
| `docker-workflow` | Docker support in pipelines |
| `pipeline-utility-steps` | Utility steps (readYaml, writeYaml, etc.) |
| `timestamper` | Add timestamps to console output |
| `ansicolor` | Colored console output |
| `ws-cleanup` | Clean workspace after builds |
| `rebuild` | Rebuild previous builds easily |
| `build-timeout` | Set build timeout limits |

---



---

## Troubleshooting

### Jenkins pod stuck in Pending

```bash
kubectl describe pod jenkins-0
```

Check if there's enough CPU/memory on the nodes. Jenkins requests 100m CPU and 1024Mi memory.

### Agent pod fails to start

Check the Jenkins system log:
- Go to **Manage Jenkins** → **System Log**
- Look for errors related to Kubernetes cloud configuration

### Docker build fails in pipeline

The Docker container needs privileged mode. Verify:
```bash
kubectl get pod <agent-pod-name> -o yaml | grep privileged
```

### Pipeline can't push to Artifact Registry

Verify credentials:
1 aws sts get-caller-identity

aws ecr get-login-password \
| docker login \
--username AWS \
--password-stdin <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com

### Pipeline can't connect to EKS

Verify:
1. aws eks update-kubeconfig \
  --region us-east-1 \
  --name travel-booking-cluster

kubectl get nodes

---

## Quick Reference Commands

```bash
# Install Jenkins
helm install jenkins jenkins -f custom-values.yaml

# Upgrade Jenkins (after changing values)
helm upgrade jenkins jenkins -f custom-values.yaml

# Uninstall Jenkins
helm uninstall jenkins

# View Jenkins logs
kubectl logs jenkins-0 -f

# Get Jenkins admin password (if you forgot)
kubectl get secret jenkins -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode; echo

# Restart Jenkins pod
kubectl delete pod jenkins-0

# Port forward (alternative to NodePort)
kubectl port-forward svc/jenkins 8080:8080
# Then access at http://localhost:8080/jenkins
```

---

## Access Jenkins via AWS Load Balancer ControlleR

apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: jenkins-ingress
  namespace: jenkins
  annotations:
    alb.ingress.kubernetes.io/group.name: travel-booking
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80},{"HTTPS":443}]'
    alb.ingress.kubernetes.io/certificate-arn: <your-acm-certificate-arn>
    alb.ingress.kubernetes.io/ssl-redirect: "443"
spec:
  ingressClassName: alb
  rules:
  - host: steveops.site
    http:
      paths:
      - path: /jenkins
        pathType: Prefix
        backend:
          service:
            name: jenkins
            port:
              number: 8080
        Then apply it with:
```
kubectl apply -f jenkins-ingress.yaml
```
Once the above is done, follow these steps to access Jenkins at `https://<DOMAIN_NAME>/jenkins`.
Verify:
```
kubectl get ingress -n jenkins
kubectl describe ingress jenkins-ingress -n jenkins
```
Test:
```
curl -I https://steveops.site/jenkins
```
Expected response:
```
HTTP/2 302
```
or
```
HTTP/2 200
```
