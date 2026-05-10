# TravelBooking — Helm Chart

---

## What is Helm?

Helm is a **package manager for Kubernetes** — just like `apt` is for Ubuntu or `npm` is for Node.js.

Without Helm, to deploy an application on Kubernetes you would need to manually write and apply dozens of individual YAML files (Deployments, Services, ConfigMaps, Secrets, etc.) one by one. If you want to update something, you'd have to find and edit each file separately.

**Helm solves this by bundling all those YAML files into a single package called a "Chart".**

---

## Why Use Helm? (Advantages)

| Advantage | What it means in simple terms |
|-----------|-------------------------------|
| **Single command deploy** | Deploy your entire application with one command instead of 40+ `kubectl apply` commands |
| **Easy upgrades** | Change a value and run one command — Helm figures out what changed and updates only that |
| **Rollback in seconds** | If something breaks after an upgrade, one command takes you back to the previous working version |
| **Reusable templates** | Write your YAML once with variables (`{{ .Values.image }}`), reuse for dev/staging/prod environments |
| **Version history** | Helm tracks every deployment as a numbered revision — you can see what changed and when |
| **Atomic deployments** | If any resource fails to deploy, Helm can roll back everything automatically |
| **Environment management** | Use the same chart for different environments just by changing `values.yaml` |

---

## What Does This Helm Chart Deploy?

This chart deploys the complete **TravelBooking** application on Kubernetes.

### Services (8 total)

| # | Service | Type | Port | Purpose |
|---|---------|------|------|---------|
| 1 | **frontend** | React App (Nginx) | 80 | The user interface — what users see in their browser |
| 2 | **user-service** | Go API | 3001 | Handles user registration, login, JWT authentication |
| 3 | **search-service** | Go API | 3002 | Searches for available flights and hotels |
| 4 | **booking-service** | Go API | 3003 | Creates and manages flight/hotel bookings |
| 5 | **payment-service** | Go API | 3004 | Processes payments for bookings |
| 6 | **notification-service** | Go API | 3005 | Sends booking confirmation notifications |
| 7 | **PostgreSQL** | Database (StatefulSet) | 5432 | Single database server holding 5 separate databases |
| 8 | **Redis** | Cache | 6379 | Caches search results for faster response times |

### Kubernetes Resources Created (40 total)

| Resource Type | Count | Purpose |
|---------------|-------|---------|
| Deployments | 7 | Runs the application containers (6 services + Redis) |
| StatefulSet | 1 | Runs PostgreSQL with persistent storage |
| Services | 8 | Internal networking between pods |
| ConfigMaps | 6 | Environment variables for each service (DB host, port, etc.) |
| Secrets | 5 | Sensitive data like DB passwords and JWT secrets |
| HorizontalPodAutoscalers | 6 | Auto-scales pods up/down based on CPU/memory usage |
| HTTPRoutes | 6 | URL routing rules (e.g. `/api/bookings` → booking-service) |
| Gateway | 1 | The main entry point — GCP Load Balancer |
| ConfigMap (postgres init) | 1 | SQL script that creates all 5 databases on first start |

---

## Chart Structure

```
helm/travel-booking/
├── Chart.yaml              # Chart metadata (name, version, description)
├── values.yaml             # All configurable values (images, replicas, ports, etc.)
├── README.md               # This file
└── templates/              # All Kubernetes resource templates
    ├── gateway.yaml
    ├── frontend-*.yaml
    ├── user-service-*.yaml
    ├── search-service-*.yaml
    ├── booking-service-*.yaml
    ├── payment-service-*.yaml
    ├── notification-service-*.yaml
    ├── postgres-*.yaml
    └── redis-*.yaml
```

---

## Complete Command Reference

### 1. Install the Chart (First-time Deployment)

```bash
helm install travel-booking ./helm/travel-booking -n travel-booking
```

**What this does:**
- `helm install` — tells Helm to deploy this chart for the first time
- `travel-booking` — the name you give to this release (you can call it anything)
- `./helm/travel-booking` — path to the chart folder
- `-n travel-booking` — deploy into the Kubernetes namespace called `travel-booking`

> This is the command you run **once** when deploying for the first time.

---

### 2. Create Namespace Before Installing

```bash
kubectl create namespace travel-booking
```

**What this does:**
- Creates a dedicated namespace (like a folder) called `travel-booking` in your cluster
- All resources deployed by this chart will live inside this namespace
- Keeps your application isolated from other things running in the cluster

> Run this **before** `helm install` if the namespace doesn't exist yet.

---

### 3. Upgrade (Update an Existing Deployment)

```bash
helm upgrade travel-booking ./helm/travel-booking -n travel-booking
```

**What this does:**
- `helm upgrade` — updates an already-deployed chart with new changes
- Helm compares the current state with the new templates and applies only the differences
- Kubernetes does a **rolling update** — new pods start before old ones stop, so there's zero downtime

> Use this every time you change `values.yaml` or any template file.

---

### 4. Install or Upgrade in One Command

```bash
helm upgrade --install travel-booking ./helm/travel-booking -n travel-booking
```

**What this does:**
- `--install` flag means: "if the release doesn't exist, install it; if it does, upgrade it"
- This is the safest command to use in CI/CD pipelines because it works whether the chart is already deployed or not

> This is the **recommended command** for automation/scripts.

---

### 5. Install with Custom Values

```bash
helm upgrade --install travel-booking ./helm/travel-booking \
  -n travel-booking \
  --set frontend.replicas=2 \
  --set secrets.dbPassword=mypassword
```

**What this does:**
- `--set key=value` — overrides specific values from `values.yaml` without editing the file
- Useful for passing secrets or environment-specific settings at deploy time
- Multiple `--set` flags can be used together

> Use this when you want to change a value temporarily without modifying `values.yaml`.

---

### 6. Install with a Custom Values File

```bash
helm upgrade --install travel-booking ./helm/travel-booking \
  -n travel-booking \
  -f my-custom-values.yaml
```

**What this does:**
- `-f filename.yaml` — loads an additional values file that overrides `values.yaml`
- Great for maintaining separate configurations for different environments (dev, staging, production)

> Example: Create `production-values.yaml` with production-specific images and passwords.

---

### 7. View Current Release Status

```bash
helm status travel-booking -n travel-booking
```

**What this does:**
- Shows whether the release is deployed, failed, or being upgraded
- Shows the timestamp of the last deployment
- Shows the chart version and app version

---

### 8. List All Releases

```bash
helm list -n travel-booking
```

**What this does:**
- Shows all Helm releases in the `travel-booking` namespace
- Displays: release name, namespace, revision number, deploy time, status, chart name

**Sample output:**
```
NAME            NAMESPACE       REVISION  STATUS    CHART
travel-booking  travel-booking  7         deployed  travel-booking-0.1.0
```

> `REVISION` tells you how many times this chart has been installed/upgraded.

---

### 9. View Deployment History

```bash
helm history travel-booking -n travel-booking
```

**What this does:**
- Lists every revision (deployment) of this release with timestamps
- Shows which revision succeeded or failed
- Helps you understand what changed and when

**Sample output:**
```
REVISION  STATUS     DESCRIPTION
1         superseded  Install complete
2         superseded  Upgrade complete
3         deployed    Upgrade complete
```

---

### 10. Rollback to a Previous Version

```bash
helm rollback travel-booking 1 -n travel-booking
```

**What this does:**
- `rollback` — reverts the deployment to a previous revision
- `1` — the revision number to go back to (get this from `helm history`)
- Kubernetes will roll back all changed resources to their previous state

> This is one of Helm's most powerful features. If an upgrade breaks something, one command fixes it.

---

### 11. Rollback to the Previous Revision

```bash
helm rollback travel-booking -n travel-booking
```

**What this does:**
- Without specifying a revision number, Helm rolls back to the **immediately previous** revision
- Quick fix when the latest upgrade caused issues

---

### 12. Preview Changes Before Deploying (Dry Run)

```bash
helm upgrade --install travel-booking ./helm/travel-booking \
  -n travel-booking \
  --dry-run
```

**What this does:**
- `--dry-run` — renders all the templates and validates them **without actually deploying anything**
- Shows you exactly what YAML Kubernetes would receive
- Catches errors before they affect your running application

> Always use `--dry-run` first when making risky changes.

---

### 13. See the Rendered YAML Templates

```bash
helm template travel-booking ./helm/travel-booking -n travel-booking
```

**What this does:**
- Renders all templates with values substituted — shows the final YAML that would be applied
- Does NOT connect to the cluster — works completely offline
- Useful for debugging template issues or reviewing what will be deployed

---

### 14. Validate the Chart for Errors

```bash
helm lint ./helm/travel-booking
```

**What this does:**
- Checks the chart for common mistakes and formatting errors
- Validates `Chart.yaml`, `values.yaml`, and all templates
- Reports warnings and errors before you deploy

> Run this after making changes to templates to catch mistakes early.

---

### 15. Uninstall (Delete Everything)

```bash
helm uninstall travel-booking -n travel-booking
```

**What this does:**
- Removes ALL Kubernetes resources that were created by this chart
- Deployments, Services, ConfigMaps, Secrets, HPAs, Routes — everything gets deleted
- The namespace itself is NOT deleted (only the resources inside it)

> ⚠️ **Warning:** This will delete your running application. PostgreSQL PVC data may persist depending on your storage class.

---

### 16. Uninstall and Keep History

```bash
helm uninstall travel-booking -n travel-booking --keep-history
```

**What this does:**
- Deletes all resources but keeps the release history in Helm
- Allows you to run `helm rollback` to restore the application later
- Without `--keep-history`, the history is also deleted permanently

---

### 17. Get All Values for a Release

```bash
helm get values travel-booking -n travel-booking
```

**What this does:**
- Shows all the custom values that were used in the last deployment
- Only shows values that were overridden from defaults

```bash
helm get values travel-booking -n travel-booking --all
```

- `--all` flag shows every value including defaults from `values.yaml`

---

### 18. Get the Manifest (Deployed YAML)

```bash
helm get manifest travel-booking -n travel-booking
```

**What this does:**
- Shows the exact YAML that was applied to Kubernetes during the last deployment
- Useful for debugging what is actually running vs what you think is running

---

## Quick Reference Card

```bash
# First time setup
kubectl create namespace travel-booking
helm install travel-booking ./helm/travel-booking -n travel-booking

# Day-to-day operations
helm upgrade travel-booking ./helm/travel-booking -n travel-booking   # Deploy changes
helm status travel-booking -n travel-booking                          # Check status
helm list -n travel-booking                                           # List releases
helm history travel-booking -n travel-booking                         # View history

# Safety commands
helm lint ./helm/travel-booking                                       # Validate chart
helm template travel-booking ./helm/travel-booking -n travel-booking  # Preview YAML
helm upgrade --install travel-booking ./helm/travel-booking --dry-run # Dry run

# Recovery
helm rollback travel-booking -n travel-booking                        # Rollback last change
helm rollback travel-booking 1 -n travel-booking                      # Rollback to revision 1

# Cleanup
helm uninstall travel-booking -n travel-booking                       # Delete everything
```

---

## Current Deployment Info

- **GKE Cluster:** Run `kubectl config current-context` to check
- **GCP Project:** Run `gcloud config get-value project` to check
- **Artifact Registry:** `us-central1-docker.pkg.dev/<PROJECT_ID>/travel-booking/`
- **Gateway IP:** Run `kubectl get gateway -n travel-booking` to get the IP
- **Access URL:** `http://<GATEWAY_IP>` or `http://<DOMAIN_NAME>`

### Connect to the Cluster

```bash
export GOOGLE_APPLICATION_CREDENTIALS=./service-account.json
gcloud container clusters get-credentials <CLUSTER_NAME> --zone <ZONE> --project <PROJECT_ID>
```
