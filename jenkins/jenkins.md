# TravelBooking — Jenkins CI/CD Setup Guide

This guide explains how to install Jenkins on GKE using Helm and set up the CI/CD pipeline for the TravelBooking application.

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
│     ├── user-service      → Artifact Registry                        │
│     ├── search-service    → Artifact Registry                        │
│     ├── booking-service   → Artifact Registry                        │
│     ├── payment-service   → Artifact Registry                        │
│     ├── notification-service → Artifact Registry                     │
│     └── frontend          → Artifact Registry                        │
│                                                                      │
│  Stage 4: Trivy Security Scan                                        │
│     └── Scan all 6 images for HIGH/CRITICAL vulnerabilities          │
│                                                                      │
│  Stage 5: Update Helm Values                                         │
│     └── Update values.yaml with new image tags (1.0.BUILD_NUMBER)    │
│                                                                      │
│  Stage 6: Package & Push Helm Chart                                  │
│     └── Package chart → Push to Artifact Registry (OCI format)       │
│                                                                      │
│  Stage 7: Deploy to GKE                                              │
│     └── Pull chart from AR → helm upgrade --install on GKE           │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

Before starting, make sure you have:

1. **GKE cluster running** (created via Terraform or manually)
2. **kubectl connected** to the cluster
3. **Helm installed** on your local machine
4. **Artifact Registry** created (name: `travel-booking`)
5. **GCP service account JSON key** with these roles:
   - Artifact Registry Admin
   - Kubernetes Engine Admin
   - Storage Admin

---

## Step 1: Install Jenkins on GKE

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
- Username: `vijay`
- Password: `vijay@123`

---

## Step 2: Configure Jenkins Credentials

After logging in, you need to add GCP credentials so Jenkins can push images and deploy to GKE.

### 2a. Add GCP Service Account Key

1. Go to **Manage Jenkins** → **Credentials** → **System** → **Global credentials**
2. Click **Add Credentials**
3. Fill in:
   - **Kind:** Secret file
   - **File:** Upload your `service-account.json` (GCP key file)
   - **ID:** `gcp-service-account`
   - **Description:** GCP Service Account for Artifact Registry and GKE
4. Click **Create**

### 2b. Add GCP Project ID

1. Click **Add Credentials** again
2. Fill in:
   - **Kind:** Secret text
   - **Secret:** `<YOUR_PROJECT_ID>` (your GCP project ID)
   - **ID:** `gcp-project-id`
   - **Description:** GCP Project ID
3. Click **Create**

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
4. **Repository URL:** `https://github.com/vijaygiduthuri/travelbooking-app.git`
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
gcloud artifacts docker images list us-central1-docker.pkg.dev/YOUR_PROJECT/travel-booking

# Check Helm chart in Artifact Registry
gcloud artifacts docker tags list us-central1-docker.pkg.dev/YOUR_PROJECT/travel-booking/travel-booking

# Check Helm release on GKE
helm list -n travel-booking

# Check Gateway IP
kubectl get gateway -n travel-booking
```

---

## What Each Jenkins Agent Container Does

| Container | Image | Used In Stage | Purpose |
|-----------|-------|---------------|---------|
| `jnlp` | jenkins/inbound-agent | All | Jenkins agent communication |
| `docker` | docker:dind | Build & Push, Trivy | Build Docker images, run security scans |
| `golang` | golang:1.21 | Test Go Services | Compile and vet Go code |
| `nodejs` | node:20.10.0 | Test Frontend | Install and test Node.js dependencies |
| `helm` | alpine/helm:3.14.0 | Package Helm | Package Helm charts |
| `gcloud` | google/cloud-sdk:slim | Push Chart, Deploy | Authenticate with GCP, deploy to GKE |
| `kaniko` | kaniko-project/executor | (Alternative) | Build images without Docker daemon |

---

## Custom Values Explained

| Setting | Value | Why |
|---------|-------|-----|
| `admin.username` | vijay | Jenkins admin login |
| `admin.password` | vijay@123 | Jenkins admin password |
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

## Pipeline Credentials Summary

| Credential ID | Type | What It Contains | Used For |
|---------------|------|------------------|----------|
| `gcp-service-account` | Secret file | GCP service account JSON key | Docker login, gcloud auth, GKE access |
| `gcp-project-id` | Secret text | GCP project ID | Image paths, GKE connection |
| `github-credentials` | Username/Password | GitHub PAT (if private repo) | Git clone |

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
1. Check that `gcp-service-account` credential exists in Jenkins
2. Check that the service account has `Artifact Registry Writer` role
3. Test manually:
   ```bash
   cat service-account.json | docker login -u _json_key --password-stdin https://us-central1-docker.pkg.dev
   ```

### Pipeline can't connect to GKE

Verify:
1. The service account has `Kubernetes Engine Admin` role
2. The cluster name and zone in the Jenkinsfile match your cluster
3. Test manually:
   ```bash
   gcloud container clusters get-credentials cluster-2 --zone us-central1-a --project YOUR_PROJECT
   kubectl get nodes
   ```

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

## Access Jenkins via Domain Name (After DNS Setup)

> **Prerequisites:** This section should be done **after** the following steps are complete:
> 1. TravelBooking application is deployed on GKE via Jenkins pipeline
> 2. Gateway is running and has a static IP (`travel-booking-ip`)
> 3. DNS is updated on GoDaddy — `<DOMAIN_NAME>` A record points to the Gateway IP
> 4. Gateway is updated with `hostname: <DOMAIN_NAME>` and `allowedRoutes.namespaces.from: All`
> 5. You can already access the TravelBooking app at `http://<DOMAIN_NAME>`

Once the above is done, follow these steps to access Jenkins at `http://<DOMAIN_NAME>/jenkins`.

### Why does this work?

The `custom-values.yaml` already configures Jenkins with:
- `jenkinsUriPrefix: "/jenkins"` — Jenkins serves all pages under `/jenkins`
- `jenkinsUrl: "http://<DOMAIN_NAME>/jenkins/"` — Jenkins knows its own URL

So Jenkins is already configured for sub-path access. We just need to tell the Gateway to route `/jenkins` traffic to the Jenkins service.

### Step 1: Create Jenkins HealthCheckPolicy

GCP's load balancer needs to health check Jenkins. Jenkins serves its login page at `/jenkins/login`, so we tell GCP to use that as the health check path.

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.gke.io/v1
kind: HealthCheckPolicy
metadata:
  name: jenkins-healthcheck
  namespace: default
spec:
  targetRef:
    group: ""
    kind: Service
    name: jenkins
  default:
    checkIntervalSec: 5
    timeoutSec: 5
    healthyThreshold: 1
    unhealthyThreshold: 3
    config:
      type: HTTP
      httpHealthCheck:
        port: 8080
        requestPath: /jenkins/login
EOF
```

**What this does:**
- Tells GCP's load balancer to check Jenkins at `/jenkins/login` on port `8080`
- Without this, GCP probes `/` which returns a 404, and Jenkins shows as "no healthy upstream"

### Step 2: Create Jenkins HTTPRoute

This tells the Gateway to route all `/jenkins` requests to the Jenkins service.

```bash
kubectl apply -f - <<'EOF'
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: jenkins-httproute
  namespace: default
spec:
  parentRefs:
  - name: travel-booking-gateway
    namespace: travel-booking
  hostnames:
  - <DOMAIN_NAME>
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /jenkins
    backendRefs:
    - name: jenkins
      port: 8080
EOF
```

**What this does:**
- Routes all requests to `http://<DOMAIN_NAME>/jenkins/*` to the Jenkins service on port 8080
- The HTTPRoute is in the `default` namespace (same as Jenkins)
- It references the Gateway in the `travel-booking` namespace — this works because the Gateway has `allowedRoutes.namespaces.from: All`

### Step 3: Verify

Wait 2-5 minutes for GCP load balancer to reprogram, then:

```bash
# Check HealthCheckPolicy
kubectl get healthcheckpolicy -n default

# Check HTTPRoute
kubectl get httproute -n default

# Test Jenkins via domain
curl -s -o /dev/null -w "Jenkins: HTTP %{http_code}\n" http://<DOMAIN_NAME>/jenkins/login
# Expected: HTTP 200
```

Open in browser: **`http://<DOMAIN_NAME>/jenkins`**

Login with:
- **Username:** `vijay`
- **Password:** `vijay@123`

### Summary

| Access Method | URL | When to Use |
|---------------|-----|-------------|
| **NodePort** | `http://<NODE_IP>:<NODEPORT>/jenkins` | Before DNS setup, for quick access |
| **Port Forward** | `http://localhost:8080/jenkins` | Local access from your machine |
| **Domain** | `http://<DOMAIN_NAME>/jenkins` | After DNS is configured (recommended) |
