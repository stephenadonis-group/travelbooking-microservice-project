# TravelBooking — Monitoring Stack Setup Guide

This guide explains the complete monitoring setup for the TravelBooking application running on EKS using **Prometheus**, **Grafana**, and **Alertmanager**.

---

## What is the Monitoring Stack?

The monitoring stack consists of multiple tools working together to collect, store, visualize, and alert on application metrics.

```
┌──────────────────────────────────────────────────────────────────────┐
│                    Monitoring Architecture                            │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐           │
│  │ user-service  │    │search-service│    │booking-service│          │
│  │   /metrics    │    │   /metrics   │    │   /metrics    │          │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘           │
│         │                   │                   │                    │
│         ▼                   ▼                   ▼                    │
│  ┌──────────────────────────────────────────────────────┐           │
│  │              ServiceMonitors                          │           │
│  │  (Tell Prometheus which services to scrape)           │           │
│  └──────────────────────┬───────────────────────────────┘           │
│                         │                                            │
│                         ▼                                            │
│  ┌──────────────────────────────────────────────────────┐           │
│  │              Prometheus                               │           │
│  │  - Scrapes /metrics from all services every 15s       │           │
│  │  - Stores metrics data for 15 days                    │           │
│  │  - Evaluates alert rules                              │           │
│  └─────────┬───────────────────────┬────────────────────┘           │
│            │                       │                                 │
│            ▼                       ▼                                 │
│  ┌─────────────────┐    ┌──────────────────┐                        │
│  │    Grafana       │    │  Alertmanager     │                       │
│  │  - Dashboards    │    │  - Sends alerts   │                       │
│  │  - Graphs        │    │  - Email/Slack    │                       │
│  │  - Visualize     │    │  - PagerDuty      │                       │
│  └─────────────────┘    └──────────────────┘                        │
│                                                                      │
│  ┌──────────────────────────────────────────────────────┐           │
│  │  Node Exporter        │  kube-state-metrics           │           │
│  │  (Node CPU/Mem/Disk)  │  (Pod/Deploy/Service status)  │           │
│  └──────────────────────────────────────────────────────┘           │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

---

## What Each Component Does

| Component | What It Does | Why We Need It |
|-----------|-------------|----------------|
| **Prometheus** | Collects and stores metrics from all services | Central metrics database — stores CPU, memory, request counts, response times |
| **Grafana** | Displays metrics as dashboards and graphs | Visual monitoring — see what's happening at a glance |
| **Alertmanager** | Sends notifications when something goes wrong | Get alerted when a pod is down, CPU is high, or errors spike |
| **Node Exporter** | Collects metrics from EKS nodes (CPU, memory, disk) | Monitor the infrastructure itself, not just the app |
| **kube-state-metrics** | Collects Kubernetes object metrics (pods, deployments) | Know how many pods are running, restarting, or failing |
| **ServiceMonitors** | Tell Prometheus which services to scrape | Automatically discover and scrape our Go services' `/metrics` endpoints |

---

## What Gets Monitored

### Application Metrics (from Go services)

Each Go service exposes a `/metrics` endpoint with Prometheus metrics:

| Metric | Description | Service |
|--------|-------------|---------|
| `gin_requests_total` | Total HTTP requests by method, path, status | All 5 Go services |
| `gin_request_duration_seconds` | HTTP request latency (histogram) | All 5 Go services |
| `go_goroutines` | Number of active goroutines | All 5 Go services |
| `go_memstats_alloc_bytes` | Current memory allocation | All 5 Go services |
| `process_cpu_seconds_total` | CPU time used | All 5 Go services |

### Kubernetes Metrics (from kube-state-metrics)

| Metric | Description |
|--------|-------------|
| `kube_pod_status_phase` | Pod status (Running, Pending, Failed) |
| `kube_pod_container_status_restarts_total` | Pod restart count |
| `kube_deployment_status_replicas_available` | Available replicas per deployment |
| `kube_deployment_status_replicas_unavailable` | Unavailable replicas |

### Node Metrics (from Node Exporter)

| Metric | Description |
|--------|-------------|
| `node_cpu_seconds_total` | Node CPU usage |
| `node_memory_MemAvailable_bytes` | Available memory on nodes |
| `node_filesystem_avail_bytes` | Available disk space |
| `node_network_receive_bytes_total` | Network traffic received |

---

## Folder Structure

```
monitoring/
├── monitoring.md                    # This guide
├── prometheus-values.yaml           # Custom values for kube-prometheus-stack (alternative)
├── grafana-dashboard-configmap.yaml # Pre-built dashboard (alternative)
│___ingress.yaml
├── helm/
│   ├── INSTALL.txt                  # Quick install commands
│   └── values.yaml                  # Helm values for kube-prometheus-stack
│
├── servicemonitors/                 # ServiceMonitor for each Go service
│   ├── user-service-monitor.yaml
│   ├── search-service-monitor.yaml
│   ├── booking-service-monitor.yaml
│   ├── payment-service-monitor.yaml
│   └── notification-service-monitor.yaml
│
├── alertrules/                      # Prometheus alert rules
│   └── travel-booking-alerts.yaml
│
└── dashboards/                      # Grafana dashboard ConfigMaps
    ├── overview-dashboard.yaml
    ├── user-service-dashboard.yaml
    ├── search-service-dashboard.yaml
    ├── booking-service-dashboard.yaml
    ├── payment-service-dashboard.yaml
    └── notification-service-dashboard.yaml
```

---

## Prerequisites

Before starting, make sure:

Before starting, make sure:

1. Amazon EKS cluster is running with the TravelBooking application deployed
2. kubectl is connected to your EKS cluster
3. kubectl is connected to your EKS cluster
4. Helm is installed on your local machine
5. AWS Load Balancer Controller is installed in the cluster
6. Amazon EBS CSI Driver is installed (required for persistent volumes)
7. Your default StorageClass is configured (or standard StorageClass exists)


```bash
# Verify
kubectl get nodes
kubectl get pods -n travel-booking
helm version
```

---

## Step 1: Add Prometheus Helm Repository

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

**What this does:**
- Adds the official Prometheus community Helm chart repository
- Updates the local chart cache with the latest versions

---

## Step 2: Create Monitoring Namespace

```bash
kubectl create namespace monitoring
```

**What this does:**
- Creates a separate namespace called `monitoring` to keep all monitoring resources isolated from the application

---

## Step 3: Install the kube-prometheus-stack

```bash
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f monitoring/helm/values.yaml \
  --wait
```
If upgrading later:
```
helm upgrade kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f monitoring/helm/values.yaml
```

AWS-specific configuration in values.yaml
The values.yaml file already configures:

| Component        | Configuration                        |
| ---------------- | ------------------------------------ |
| Prometheus       | 50Gi Amazon EBS Persistent Volume    |
| Grafana          | 10Gi Amazon EBS Persistent Volume    |
| Alertmanager     | 5Gi Amazon EBS Persistent Volume     |
| StorageClass     | `standard` (Amazon EBS CSI Driver)   |
| Prometheus URL   | `https://prometheus.steveops.site`   |
| Grafana URL      | `https://steveops.site/grafana`      |
| Alertmanager URL | `https://alertmanager.steveops.site` |

**What this does:**
- `kube-prometheus-stack` is the release name
- `prometheus-community/kube-prometheus-stack` is the chart (includes Prometheus + Grafana + Alertmanager + Node Exporter + kube-state-metrics — all in one)
- `--values monitoring/helm/values.yaml` uses our custom configuration
- `--wait` waits until all pods are running before returning

**This single command installs:**
- Prometheus server (scrapes and stores metrics) — accessible at `/prometheus`
- Grafana (dashboards and visualization) — accessible at `/grafana`
- Alertmanager (alert notifications) — accessible at `/alertmanager`
- Node Exporter (node-level metrics, runs on every node)
- kube-state-metrics (Kubernetes object metrics)
- Pre-configured dashboards for Kubernetes monitoring

**This takes about 2-5 minutes.**

---

## Step 4: Verify Installation

```bash
# Check all pods in monitoring namespace
kubectl get pods -n monitoring

# Expected output (all should be Running):
# NAME                                                        READY   STATUS    AGE
# alertmanager-kube-prometheus-stack-alertmanager-0            2/2     Running   2m
# kube-prometheus-stack-grafana-xxxxx                          3/3     Running   2m
# kube-prometheus-stack-kube-state-metrics-xxxxx               1/1     Running   2m
# kube-prometheus-stack-operator-xxxxx                         1/1     Running   2m
# kube-prometheus-stack-prometheus-node-exporter-xxxxx         1/1     Running   2m
# kube-prometheus-stack-prometheus-node-exporter-xxxxx         1/1     Running   2m
# prometheus-kube-prometheus-stack-prometheus-0                2/2     Running   2m

# Check services
kubectl get svc -n monitoring

# Check persistent volumes
kubectl get pvc -n monitoring
```

---

## Step 5: Apply ServiceMonitors

ServiceMonitors tell Prometheus to scrape the `/metrics` endpoint of our TravelBooking services.

```bash
kubectl apply -f monitoring/servicemonitors/ -n travel-booking
```

**What this does:**
- Creates 5 ServiceMonitor resources (one per Go service)
- Each ServiceMonitor tells Prometheus: "scrape this service on port `http` at path `/metrics` every 15 seconds"
- ServiceMonitors are created in the `travel-booking` namespace (same as the services they monitor)

**Verify:**
```bash
kubectl get servicemonitors -n travel-booking
```

Expected:
```
NAME                         AGE
booking-service-monitor      10s
notification-service-monitor 10s
payment-service-monitor      10s
search-service-monitor       10s
user-service-monitor         10s
```

---

## Step 6: Apply Alert Rules

Alert rules define conditions that trigger alerts (e.g., pod down, high CPU, high error rate).

```bash
kubectl apply -f monitoring/alertrules/ -n monitoring
```

**What this does:**
- Creates PrometheusRule resources in the `monitoring` namespace
- Prometheus evaluates these rules continuously
- When a condition is true for the specified duration, it fires an alert to Alertmanager

**Alerts configured:**

## Create Monitoring Ingress
To expose the monitoring stack externally, create an AWS ALB Ingress that routes traffic to Grafana, Prometheus, and Alertmanager.
Apply the Ingress:
```
kubectl apply -f monitoring/ingress.yaml
```
What this does
1. Creates an AWS Application Load Balancer (ALB) Ingress that exposes the monitoring services.
2. The monitoring Ingress is configured to use the same ALB as the TravelBooking application by sharing the same Ingress Group.
This allows a single ALB to serve both the application and the monitoring stack.

Ingress Features

The monitoring Ingress uses:

AWS Load Balancer Controller
Internet-facing Application Load Balancer
ACM SSL Certificate
HTTPS redirect
IP Target Mode
Shared ALB Ingress Group (travel-booking

Verify the Ingress
```
kubectl get ingress -A
```
Expected:
NAMESPACE        NAME
travel-booking   travel-booking-ingress
monitoring       monitoring-ingress

Describe the monitoring ingress:
```
kubectl describe ingress monitoring-ingress -n monitoring
```
You should see routes similar to:
```
Host: steveops.site
  /grafana

Host: prometheus.steveops.site
  /

Host: alertmanager.steveops.site
  /
```
Step 7: Configure Route 53
Create DNS records pointing the monitoring subdomains to the existing AWS Application Load Balancer.
| Record Type | Name                       | Alias Target      |
| ----------- | -------------------------- | ----------------- |
| A (Alias)   | prometheus.steveops.site   | TravelBooking ALB |
| A (Alias)   | alertmanager.steveops.site | TravelBooking ALB |

Grafana continues to use:
```
https://steveops.site/grafana
```
No additional Route 53 record is required for Grafana because it is served as a subpath of the main application domain.
# Verify Monitoring Access
Wait a few minutes for the ALB and Route 53 changes to propagate.
Test each endpoint:
```
curl -I https://steveops.site/grafana

curl -I https://prometheus.steveops.site

curl -I https://alertmanager.steveops.site
```
Expected responses:
| Endpoint     | Expected Response          |
| ------------ | -------------------------- |
| Grafana      | HTTP 302 Redirect to Login |
| Prometheus   | HTTP 200 OK                |
| Alertmanager | HTTP 200 OK                |

Monitoring Endpoints
| Component    | URL                                                                      |
| ------------ | ------------------------------------------------------------------------ |
| Grafana      | [https://steveops.site/grafana](https://steveops.site/grafana)           |
| Prometheus   | [https://prometheus.steveops.site](https://prometheus.steveops.site)     |
| Alertmanager | [https://alertmanager.steveops.site](https://alertmanager.steveops.site) |

| Alert Name | Condition | Severity | Fires After |
|------------|-----------|----------|-------------|
| `PodDown` | Any pod in travel-booking is down | Critical | 1 minute |
| `HighCPUUsage` | Pod CPU usage > 80% | Warning | 5 minutes |
| `HighMemoryUsage` | Pod memory usage > 80% | Warning | 5 minutes |
| `HighHTTPErrorRate` | HTTP 5xx errors > 5% | Critical | 2 minutes |
| `HighResponseTime` | 95th percentile response time > 2 seconds | Warning | 5 minutes |
| `PodRestartLoop` | Pod restarted > 5 times in 15 minutes | Critical | 0 (immediate) |

**Verify:**
```bash
kubectl get prometheusrules -n monitoring
```


---

## Step 7: Apply Grafana Dashboards

Pre-built dashboards for visualizing TravelBooking application metrics.

```bash
kubectl apply -f monitoring/dashboards/ -n monitoring
```

**What this does:**
- Creates ConfigMap resources with Grafana dashboard JSON
- Grafana's sidecar container automatically detects ConfigMaps with label `grafana_dashboard: "1"` and loads them

**Dashboards included:**

| Dashboard | What It Shows |
|-----------|-------------|
| **Overview** | Total request rate, error rate, active pods, overall health |
| **User Service** | Registration/login rates, response times, error rates |
| **Search Service** | Search queries per second, cache hit rate, response times |
| **Booking Service** | Bookings created, cancellations, response times |
| **Payment Service** | Payment processing rate, success/failure ratio |
| **Notification Service** | Notifications sent, delivery success rate |

**Verify:**
```bash
kubectl get configmaps -n monitoring -l grafana_dashboard=1
```

---





## Step 8: Access Grafana, Prometheus & Alertmanager

After the monitoring Ingress has been created and the Route 53 records have propagated (this may take a few minutes), verify that the monitoring services are accessible through your domain.
Verify the Monitoring Ingress
```
kubectl get ingress -A

kubectl describe ingress monitoring-ingress -n monitoring
```
You should see the monitoring ingress associated with the same AWS Application Load Balancer as your TravelBooking application.

Test the Endpoints:
Use curl to verify each endpoint.
```
curl -I https://steveops.site/grafana

curl -I https://prometheus.steveops.site

curl -I https://alertmanager.steveops.site
```
Expected responses:
| Endpoint     | Expected Response          |
| ------------ | -------------------------- |
| Grafana      | HTTP 302 Redirect to Login |
| Prometheus   | HTTP 200 OK                |
| Alertmanager | HTTP 200 OK                |

Access URLs

Open the following URLs in your browser:
| Tool             | URL                                  | Purpose                              |
| ---------------- | ------------------------------------ | ------------------------------------ |
| **Grafana**      | `https://steveops.site/grafana`      | Dashboards and visualization         |
| **Prometheus**   | `https://prometheus.steveops.site`   | Metrics queries and targets          |
| **Alertmanager** | `https://alertmanager.steveops.site` | View active alerts and alert history |


### Grafana Login Credentials

| Setting | Value |
|---------|-------|
| **Username** | `admin` |
| **Password** | `TravelBook@Admin123` |

### After Logging into Grafana

1. Click **Dashboards** (left sidebar) → **Browse**
2. You should see the TravelBooking dashboards:
   - Travel Booking - Overview
   - User Service Dashboard
   - Search Service Dashboard
   - Booking Service Dashboard
   - Payment Service Dashboard
   - Notification Service Dashboard
3. Click on **Travel Booking - Overview** to see the main dashboard

### Prometheus Queries

Open the Prometheus UI , paste a query in the **Expression** box, and click the **Execute** button (blue play icon on the left side of the expression box). Results appear in the **Table** tab below.

> **Tip:** After pasting the query, you must click the **Execute** button (the `>_` icon). Pressing Enter alone may not work in the new Prometheus UI.

> **Note:** When a query result shows `{}` with a number next to it — `{}` means "no labels" and the number IS the result. Scroll right if needed to see the value.

#### Query 1: Are all targets UP?

```
up
```
Shows every target Prometheus is scraping. You should see rows with value **1** (UP). Look for `travel-booking` services in the `namespace` column.

#### Query 2: Show all TravelBooking targets

```
up{namespace="travel-booking"}
```
Filters to show only the 5 TravelBooking services. All should show value **1**.

#### Query 3: HTTP requests handled by user-service

```
user_http_requests_total
```
Shows total HTTP requests handled by user-service since it started. Each row shows a different route (/, /health, /metrics, /api/users/register, etc.) with the total request count.

#### Query 4: HTTP requests handled by search-service

```
search_http_requests_total
```
Same as above but for search-service.

#### Query 5: HTTP requests handled by booking-service

```
booking_http_requests_total
```
Same as above but for booking-service.

#### Query 6: HTTP requests handled by payment-service

```
payment_http_requests_total
```
Same as above but for payment-service.

#### Query 7: HTTP requests handled by notification-service

```
notification_http_requests_total
```
Same as above but for notification-service.

#### Query 8: Successful payments

```
payment_success_total
```
Shows total number of successful payments processed.

#### Query 9: Failed payments

```
payment_failure_total
```
Shows total number of failed payments. Should be **0** or very low.

#### Query 10: Total money processed (USD)

```
payment_total_amount_processed
```
Shows total USD amount processed by the payment service.

#### Query 11: Search cache hits from Redis

```
search_cache_hits_total
```
Shows how many search results came from Redis cache instead of the database.

#### Query 12: Notification queue size

```
notification_queue_size
```
Shows how many notifications are waiting to be sent. **0** when idle.

#### Query 13: Pod restart counts

```
kube_pod_container_status_restarts_total{namespace="travel-booking"}
```
Shows restart count for each pod. Each row shows a pod name and its restart count. **0 is ideal.**

#### Query 14: Deployment replicas available

```
kube_deployment_status_replicas_available{namespace="travel-booking"}
```
Shows available replicas for each deployment. Each row shows a deployment name and replica count.

#### Query 15: Memory usage per container (in MB)

```
container_memory_working_set_bytes{namespace="travel-booking", container!="POD", container!=""}
```
Shows raw memory bytes for each container. Look at the `container` label to identify the service.

### Alertmanager

Open the Alertmanager UI to see:
- Active alerts (firing)
- Silenced alerts
- Alert history

---

## Custom Values Explained

The `monitoring/helm/values.yaml` file configures the entire stack. Here's what each section does:


### Prometheus Settings

| Setting                                   | Value                              | Why                                                                           |
| ----------------------------------------- | ---------------------------------- | ----------------------------------------------------------------------------- |
| `service.type`                            | `ClusterIP`                        | Exposes Prometheus internally. Traffic is routed through the AWS ALB Ingress. |
| `retention`                               | `15d`                              | Retains metrics for 15 days.                                                  |
| `storageClassName`                        | `standard`                         | Uses the Amazon EBS CSI StorageClass for persistent storage.                  |
| `storage`                                 | `50Gi`                             | Persistent storage for Prometheus metrics.                                    |
| `externalUrl`                             | `https://prometheus.steveops.site` | Configures Prometheus to use its public URL.                                  |
| `serviceMonitorSelectorNilUsesHelmValues` | `false`                            | Allows Prometheus to discover ServiceMonitors outside the Helm release.       |
| `serviceMonitorSelector`                  | `{}`                               | Selects all ServiceMonitors.                                                  |
| `serviceMonitorNamespaceSelector`         | `{}`                               | Watches ServiceMonitors in all namespaces.                                    |
| `ruleSelectorNilUsesHelmValues`           | `false`                            | Allows Prometheus to discover custom PrometheusRule resources.                |
| `ruleSelector`                            | `{}`                               | Selects all PrometheusRule resources.                                         |
| `resources.requests.cpu`                  | `200m`                             | Minimum CPU reserved for Prometheus.                                          |
| `resources.limits.memory`                 | `2Gi`                              | Maximum memory allowed for Prometheus.                                        |


### Grafana Settings

| Setting                       | Value                           | Why                                                                    |
| ----------------------------- | ------------------------------- | ---------------------------------------------------------------------- |
| `adminUser`                   | `admin`                         | Grafana administrator username.                                        |
| `adminPassword`               | `TravelBook@Admin123`           | Grafana administrator password.                                        |
| `service.type`                | `ClusterIP`                     | Internal service exposed through the AWS ALB Ingress.                  |
| `root_url`                    | `https://steveops.site/grafana` | Configures Grafana to operate correctly behind the `/grafana` subpath. |
| `serve_from_sub_path`         | `true`                          | Enables Grafana to serve assets from `/grafana`.                       |
| `persistence.enabled`         | `true`                          | Enables persistent storage for dashboards and settings.                |
| `storageClassName`            | `standard`                      | Uses Amazon EBS CSI volumes.                                           |
| `persistence.size`            | `10Gi`                          | Persistent storage for Grafana.                                        |
| `sidecar.dashboards.enabled`  | `true`                          | Automatically imports dashboards from ConfigMaps.                      |
| `sidecar.datasources.enabled` | `true`                          | Automatically provisions Prometheus as the Grafana datasource.         |


### Alertmanager Settings

| Setting            | Value                                | Why                                                   |
| ------------------ | ------------------------------------ | ----------------------------------------------------- |
| `service.type`     | `ClusterIP`                          | Internal service exposed through the AWS ALB Ingress. |
| `externalUrl`      | `https://alertmanager.steveops.site` | Public URL for Alertmanager.                          |
| `storageClassName` | `standard`                           | Uses Amazon EBS CSI persistent storage.               |
| `storage`          | `5Gi`                                | Persistent storage for alert data.                    |


---

## Complete Installation — All Commands in Order

```bash
# ─── Step 1: Add Helm Repository ──────────────────────────────────────────────
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# ─── Step 2: Create Monitoring Namespace ──────────────────────────────────────
kubectl create namespace monitoring

# ─── Step 3: Install kube-prometheus-stack ────────────────────────────────────
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  -f monitoring/helm/values.yaml

# ─── Step 4: Verify Installation ──────────────────────────────────────────────
kubectl get pods -n monitoring
kubectl get svc -n monitoring
kubectl get pvc -n monitoring

# ─── Step 5: Apply ServiceMonitors ────────────────────────────────────────────
kubectl apply -f monitoring/servicemonitors/

# ─── Step 6: Apply Alert Rules ────────────────────────────────────────────────
kubectl apply -f monitoring/alertrules/

# ─── Step 7: Apply Grafana Dashboards ─────────────────────────────────────────
kubectl apply -f monitoring/dashboards/

# ─── Step 8: Create Monitoring Ingress ────────────────────────────────────────
kubectl apply -f monitoring/ingress.yaml

# ─── Step 9: Verify the Monitoring Ingress ────────────────────────────────────
kubectl get ingress -A
kubectl describe ingress monitoring-ingress -n monitoring

# ─── Step 10: Configure Route 53 ──────────────────────────────────────────────
# Create the following Alias A records:
#
# prometheus.steveops.site   → TravelBooking ALB
# alertmanager.steveops.site → TravelBooking ALB
#
# Grafana remains available at:
# https://steveops.site/grafana

# ─── Step 11: Verify Access ───────────────────────────────────────────────────
curl -I https://steveops.site/grafana
curl -I https://prometheus.steveops.site
curl -I https://alertmanager.steveops.site

# Grafana Credentials
# Username: admin
# Password: TravelBook@Admin123
```

---

## How to Uninstall

```bash
# Remove dashboards, alerts, and service monitors
kubectl delete -f monitoring/dashboards/ -n monitoring
kubectl delete -f monitoring/alertrules/ -n monitoring
kubectl delete -f monitoring/servicemonitors/ -n travel-booking

# Uninstall the Helm release
helm uninstall kube-prometheus-stack -n monitoring

# Delete the namespace
kubectl delete namespace monitoring
```

---

## How to Upgrade

After changing `monitoring/helm/values.yaml`:

```bash
helm upgrade kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  -f monitoring/helm/values.yaml
```
Wait for the rollout to complete:
```
kubectl rollout status statefulset/prometheus-kube-prometheus-stack-prometheus -n monitoring

kubectl rollout status statefulset/alertmanager-kube-prometheus-stack-alertmanager -n monitoring

kubectl rollout status deployment/kube-prometheus-stack-grafana -n monitoring
```

---

## Troubleshooting

### Grafana shows no data

1. Check if Prometheus is scraping the services:
   - Open Prometheus UI → **Status** → **Targets**
   - Look for `travel-booking` targets — they should show `UP`

2. If targets are missing, check ServiceMonitors:
   ```bash
   kubectl get servicemonitors -n travel-booking
   kubectl describe servicemonitor user-service-monitor -n travel-booking
   ```

3. Check if the service labels match:
   ```bash
   kubectl get svc -n travel-booking --show-labels
   ```

### Prometheus targets show "DOWN"

The service might not be exposing `/metrics`:
```bash
# Test directly
kubectl port-forward svc/user-service-service 3001:3001 -n travel-booking
curl http://localhost:3001/metrics
```

### Alertmanager not sending alerts

Check if alert rules are loaded:
```bash
kubectl get prometheusrules -n monitoring
```

Open Prometheus UI → **Alerts** tab to see if rules are evaluated.

### Pods stuck in Pending

Check if there's enough storage:
```bash
kubectl get pvc -n monitoring
kubectl describe pvc -n monitoring
```

Check if storage class exists:
```bash
kubectl get storageclass
```

---

## Quick Reference

### Access via AWS Application Load Balancer (Recommended)

The monitoring services are exposed through the same AWS Application Load Balancer (ALB) that serves the TravelBooking application.
Public URLs:

| Tool             | URL                                  |
| ---------------- | ------------------------------------ |
| **Grafana**      | `https://steveops.site/grafana`      |
| **Prometheus**   | `https://prometheus.steveops.site`   |
| **Alertmanager** | `https://alertmanager.steveops.site` |


Verify the Monitoring Ingress
```
kubectl get ingress -A

kubectl describe ingress monitoring-ingress -n monitoring
```
expected output:

* Monitoring Ingress is Ready
* Uses the same AWS ALB as the TravelBooking application
* SSL certificate attached through AWS Certificate Manager (ACM)
* 
Verify Route 53 DNS
Verify that the monitoring subdomains resolve to your Application Load Balancer.
```
nslookup prometheus.steveops.site

nslookup alertmanager.steveops.site
```
Verify the Endpoints
```
curl -I https://steveops.site/grafana

curl -I https://prometheus.steveops.site

curl -I https://alertmanager.steveops.site
```

| Endpoint     | Expected Response |
| ------------ | ----------------- |
| Grafana      | HTTP 302 Redirect |
| Prometheus   | HTTP 200 OK       |
| Alertmanager | HTTP 200 OK       |

Expected responses:
All three should return **HTTP 200** or **HTTP 302** (redirect to login for Grafana).

# Updating the Monitoring Ingress

If you modify the monitoring ingress configuration:
```
kubectl apply -f monitoring/ingress.yaml
```
Verify the changes:
```
kubectl describe ingress monitoring-ingress -n monitoring
```
# Route 53 Configuration

Create the following Alias A Records in your Route 53 hosted zone:
| Record Name    | Type      | Alias Target                            |
| -------------- | --------- | --------------------------------------- |
| `prometheus`   | A (Alias) | TravelBooking Application Load Balancer |
| `alertmanager` | A (Alias) | TravelBooking Application Load Balancer |

Grafana continues to use the main application domain:
```
https://steveops.site/grafana
```
### Credentials

| Credential | Value |
|------------|-------|
| Grafana Username | `admin` |
| Grafana Password | `TravelBook@Admin123` |

# Verify Monitoring Resources
```
kubectl get pods -n monitoring

kubectl get svc -n monitoring

kubectl get pvc -n monitoring

kubectl get servicemonitors -A

kubectl get prometheusrules -A

kubectl get configmaps -n monitoring -l grafana_dashboard=1
```
