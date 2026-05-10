# TravelBooking — Monitoring Stack Setup Guide

This guide explains the complete monitoring setup for the TravelBooking application running on GKE using **Prometheus**, **Grafana**, and **Alertmanager**.

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
| **Node Exporter** | Collects metrics from GKE nodes (CPU, memory, disk) | Monitor the infrastructure itself, not just the app |
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
│
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

1. **GKE cluster is running** with the TravelBooking app deployed
2. **kubectl is connected** to the cluster
3. **Helm is installed** on your local machine

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
  --namespace monitoring \
  --values monitoring/helm/values.yaml \
  --set prometheus.prometheusSpec.resources.requests.cpu=50m \
  --set prometheus.prometheusSpec.resources.requests.memory=256Mi \
  --set prometheus.prometheusSpec.storageSpec=null \
  --set alertmanager.alertmanagerSpec.storage=null \
  --set grafana.persistence.enabled=false \
  --set 'grafana.grafana\.ini.server.root_url=http://<DOMAIN_NAME>/grafana' \
  --set 'grafana.grafana\.ini.server.serve_from_sub_path=true' \
  --set prometheus.prometheusSpec.externalUrl=http://<DOMAIN_NAME>/prometheus \
  --set prometheus.prometheusSpec.routePrefix=/prometheus \
  --set alertmanager.alertmanagerSpec.externalUrl=http://<DOMAIN_NAME>/alertmanager \
  --set alertmanager.alertmanagerSpec.routePrefix=/alertmanager \
  --wait
```

**What each `--set` flag does:**

| Flag | Purpose |
|------|---------|
| `prometheus...resources.requests.cpu=50m` | Reduces Prometheus CPU request to avoid pod Pending issues on smaller clusters |
| `prometheus...storageSpec=null` | Disables persistent storage for Prometheus (uses emptyDir instead) |
| `alertmanager...storage=null` | Disables persistent storage for Alertmanager |
| `grafana.persistence.enabled=false` | Disables persistent storage for Grafana |
| `grafana...root_url` | Tells Grafana it is served at `/grafana` sub-path |
| `grafana...serve_from_sub_path=true` | Makes Grafana serve all assets from `/grafana` prefix |
| `prometheus...externalUrl` | Tells Prometheus its external URL is at `/prometheus` |
| `prometheus...routePrefix=/prometheus` | Serves Prometheus UI at `/prometheus` instead of `/` |
| `alertmanager...externalUrl` | Tells Alertmanager its external URL is at `/alertmanager` |
| `alertmanager...routePrefix=/alertmanager` | Serves Alertmanager UI at `/alertmanager` instead of `/` |

> **Note:** Replace `<DOMAIN_NAME>` with your actual domain (e.g., `vijaygiduthuri.in`). If you don't have a domain yet, remove the Grafana `root_url`, `serve_from_sub_path`, `externalUrl`, and `routePrefix` flags — you can add them later when setting up domain access.

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

## Step 8: Create GCP Firewall Rule for NodePorts

All three monitoring services (Grafana, Prometheus, Alertmanager) are exposed as `NodePort` services. To access them from your browser, you need a GCP firewall rule that allows traffic on NodePort range (30000-32767).

```bash
gcloud compute firewall-rules create allow-monitoring-nodeports \
  --project YOUR_PROJECT_ID \
  --allow tcp:30000-32767 \
  --source-ranges 0.0.0.0/0 \
  --description "Allow access to monitoring NodePort services" \
  --network default
```

**What this does:**
- Opens ports 30000-32767 on all GKE nodes
- Allows your browser to reach Grafana, Prometheus, and Alertmanager via `http://<NODE_IP>:<NODE_PORT>`

> **Note:** This rule only needs to be created once. It persists until you delete it.

---

## Step 9: Access Grafana, Prometheus & Alertmanager

### Get NodePorts and Node IPs

```bash
# Get NodePort numbers for all monitoring services
kubectl get svc -n monitoring | grep NodePort

# Get external IPs of GKE nodes
kubectl get nodes -o wide | awk '{print $1, $7}'
```

### Access URLs

Use **any node's external IP** with the NodePort number:

| Tool | URL | What It Does |
|------|-----|-------------|
| **Grafana** | `http://<NODE_IP>:<GRAFANA_NODEPORT>` | Dashboards and visualization |
| **Prometheus** | `http://<NODE_IP>:<PROMETHEUS_NODEPORT>` | Metrics queries and targets |
| **Alertmanager** | `http://<NODE_IP>:<ALERTMANAGER_NODEPORT>` | Active alerts and alert history |

**Example** (your NodePorts may differ):
```
Grafana:      http://<NODE_IP>:<GRAFANA_NODEPORT>
Prometheus:   http://<NODE_IP>:<PROMETHEUS_NODEPORT>
Alertmanager: http://<NODE_IP>:<ALERTMANAGER_NODEPORT>
```

> **Tip:** To find your exact NodePorts, run:
> ```bash
> kubectl get svc kube-prometheus-stack-grafana -n monitoring -o jsonpath='{.spec.ports[0].nodePort}'
> kubectl get svc kube-prometheus-stack-prometheus -n monitoring -o jsonpath='{.spec.ports[0].nodePort}'
> kubectl get svc kube-prometheus-stack-alertmanager -n monitoring -o jsonpath='{.spec.ports[0].nodePort}'
> ```

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

Open the Prometheus UI (`http://<NODE_IP>:<PROMETHEUS_NODEPORT>`), paste a query in the **Expression** box, and click the **Execute** button (blue play icon on the left side of the expression box). Results appear in the **Table** tab below.

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

| Setting | Value | Why |
|---------|-------|-----|
| `service.type` | NodePort | Expose Prometheus externally via NodePort (no LoadBalancer cost) |
| `retention` | 15d | Keep metrics data for 15 days |
| `storage` | 50Gi | Storage for metrics data |
| `serviceMonitorSelectorNilUsesHelmValues: false` | - | Allow Prometheus to pick up ServiceMonitors from ANY namespace |
| `serviceMonitorSelector: {}` | - | Select ALL ServiceMonitors (no label filtering) |
| `resources.requests.cpu` | 200m | Minimum CPU for Prometheus |
| `resources.limits.memory` | 2Gi | Maximum memory for Prometheus |

### Grafana Settings

| Setting | Value | Why |
|---------|-------|-----|
| `adminPassword` | TravelBook@Admin123 | Grafana login password |
| `persistence.size` | 10Gi | Storage for dashboards and settings |
| `service.type` | NodePort | Expose Grafana externally via NodePort (no LoadBalancer cost) |
| `sidecar.dashboards.enabled` | true | Auto-load dashboards from ConfigMaps |

### Alertmanager Settings

| Setting | Value | Why |
|---------|-------|-----|
| `service.type` | NodePort | Expose Alertmanager externally via NodePort |
| `storage` | 5Gi | Storage for alert history |

---

## Complete Installation — All Commands in Order

```bash
# ─── Step 1: Add Helm repo ───────────────────────────────────────────────────
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# ─── Step 2: Create namespace ─────────────────────────────────────────────────
kubectl create namespace monitoring

# ─── Step 3: Install kube-prometheus-stack ────────────────────────────────────
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values monitoring/helm/values.yaml \
  --set prometheus.prometheusSpec.resources.requests.cpu=50m \
  --set prometheus.prometheusSpec.resources.requests.memory=256Mi \
  --set prometheus.prometheusSpec.storageSpec=null \
  --set alertmanager.alertmanagerSpec.storage=null \
  --set grafana.persistence.enabled=false \
  --set 'grafana.grafana\.ini.server.root_url=http://<DOMAIN_NAME>/grafana' \
  --set 'grafana.grafana\.ini.server.serve_from_sub_path=true' \
  --set prometheus.prometheusSpec.externalUrl=http://<DOMAIN_NAME>/prometheus \
  --set prometheus.prometheusSpec.routePrefix=/prometheus \
  --set alertmanager.alertmanagerSpec.externalUrl=http://<DOMAIN_NAME>/alertmanager \
  --set alertmanager.alertmanagerSpec.routePrefix=/alertmanager \
  --wait

# ─── Step 4: Verify pods are running ─────────────────────────────────────────
kubectl get pods -n monitoring

# ─── Step 5: Apply ServiceMonitors ────────────────────────────────────────────
kubectl apply -f monitoring/servicemonitors/ -n travel-booking

# ─── Step 6: Apply Alert Rules ────────────────────────────────────────────────
kubectl apply -f monitoring/alertrules/ -n monitoring

# ─── Step 7: Apply Dashboards ────────────────────────────────────────────────
kubectl apply -f monitoring/dashboards/ -n monitoring

# ─── Step 8: Create GCP Firewall Rule (one-time) ─────────────────────────────
gcloud compute firewall-rules create allow-monitoring-nodeports \
  --project YOUR_PROJECT_ID \
  --allow tcp:30000-32767 \
  --source-ranges 0.0.0.0/0 \
  --description "Allow access to monitoring NodePort services" \
  --network default

# ─── Step 9: Get Access URLs ─────────────────────────────────────────────────
kubectl get svc -n monitoring | grep NodePort
kubectl get nodes -o wide | awk '{print $1, $7}'
# Access Grafana:      http://<NODE_IP>:<GRAFANA_NODEPORT>
# Access Prometheus:   http://<NODE_IP>:<PROMETHEUS_NODEPORT>
# Access Alertmanager: http://<NODE_IP>:<ALERTMANAGER_NODEPORT>
# Grafana Username: admin
# Grafana Password: TravelBook@Admin123
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
  --values monitoring/helm/values.yaml \
  --set prometheus.prometheusSpec.resources.requests.cpu=50m \
  --set prometheus.prometheusSpec.resources.requests.memory=256Mi \
  --set prometheus.prometheusSpec.storageSpec=null \
  --set alertmanager.alertmanagerSpec.storage=null \
  --set grafana.persistence.enabled=false \
  --set 'grafana.grafana\.ini.server.root_url=http://<DOMAIN_NAME>/grafana' \
  --set 'grafana.grafana\.ini.server.serve_from_sub_path=true' \
  --set prometheus.prometheusSpec.externalUrl=http://<DOMAIN_NAME>/prometheus \
  --set prometheus.prometheusSpec.routePrefix=/prometheus \
  --set alertmanager.alertmanagerSpec.externalUrl=http://<DOMAIN_NAME>/alertmanager \
  --set alertmanager.alertmanagerSpec.routePrefix=/alertmanager \
  --wait
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

### Access via NodePort (External — No LoadBalancer Cost)

```bash
# Get NodePorts
kubectl get svc -n monitoring | grep NodePort

# Get Node External IPs
kubectl get nodes -o wide | awk '{print $1, $7}'

# Access: http://<ANY_NODE_IP>:<NODEPORT>
```

| Tool | Service Name | Default Port | How to Get NodePort |
|------|-------------|-------------|---------------------|
| **Grafana** | `kube-prometheus-stack-grafana` | 80 | `kubectl get svc kube-prometheus-stack-grafana -n monitoring -o jsonpath='{.spec.ports[0].nodePort}'` |
| **Prometheus** | `kube-prometheus-stack-prometheus` | 9090 | `kubectl get svc kube-prometheus-stack-prometheus -n monitoring -o jsonpath='{.spec.ports[0].nodePort}'` |
| **Alertmanager** | `kube-prometheus-stack-alertmanager` | 9093 | `kubectl get svc kube-prometheus-stack-alertmanager -n monitoring -o jsonpath='{.spec.ports[0].nodePort}'` |

### Access via Port Forward (Alternative — Local Only)

```bash
kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 -n monitoring       # http://localhost:3000
kubectl port-forward svc/kube-prometheus-stack-prometheus 9090:9090 -n monitoring   # http://localhost:9090
kubectl port-forward svc/kube-prometheus-stack-alertmanager 9093:9093 -n monitoring # http://localhost:9093
```

### Access via Domain Name (Recommended)

After DNS is configured and the TravelBooking Gateway is running, you can access Grafana, Prometheus, and Alertmanager via your domain name instead of NodePort.

| Tool | URL |
|------|-----|
| **Grafana** | `http://<DOMAIN_NAME>/grafana` |
| **Prometheus** | `http://<DOMAIN_NAME>/prometheus` |
| **Alertmanager** | `http://<DOMAIN_NAME>/alertmanager` |

To set this up, run the following steps after the monitoring stack is installed:

#### Step 1: Configure sub-paths on monitoring services

Upgrade the Helm release to tell Grafana, Prometheus, and Alertmanager to serve from sub-paths:

```bash
helm upgrade kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values monitoring/helm/values.yaml \
  --set 'grafana.grafana\.ini.server.root_url=http://<DOMAIN_NAME>/grafana' \
  --set 'grafana.grafana\.ini.server.serve_from_sub_path=true' \
  --set prometheus.prometheusSpec.externalUrl=http://<DOMAIN_NAME>/prometheus \
  --set prometheus.prometheusSpec.routePrefix=/prometheus \
  --set alertmanager.alertmanagerSpec.externalUrl=http://<DOMAIN_NAME>/alertmanager \
  --set alertmanager.alertmanagerSpec.routePrefix=/alertmanager \
  --wait
```

**What this does:**
- **Grafana:** Serves the UI at `/grafana` instead of `/`. All CSS, JS, and API calls use the `/grafana` prefix
- **Prometheus:** Serves the UI at `/prometheus`. The query page becomes `/prometheus/query`
- **Alertmanager:** Serves the UI at `/alertmanager`. The alerts page becomes `/alertmanager/#/alerts`

#### Step 2: Create HealthCheckPolicies

GCP's load balancer needs to know how to health check these services. Without this, GCP will probe `/` and get a 404, marking the service as unhealthy.

```bash
kubectl apply -f - <<'EOF'
---
apiVersion: networking.gke.io/v1
kind: HealthCheckPolicy
metadata:
  name: grafana-healthcheck
  namespace: monitoring
spec:
  targetRef:
    group: ""
    kind: Service
    name: kube-prometheus-stack-grafana
  default:
    checkIntervalSec: 10
    timeoutSec: 5
    healthyThreshold: 1
    unhealthyThreshold: 3
    config:
      type: HTTP
      httpHealthCheck:
        port: 3000
        requestPath: /api/health
---
apiVersion: networking.gke.io/v1
kind: HealthCheckPolicy
metadata:
  name: prometheus-healthcheck
  namespace: monitoring
spec:
  targetRef:
    group: ""
    kind: Service
    name: kube-prometheus-stack-prometheus
  default:
    checkIntervalSec: 10
    timeoutSec: 5
    healthyThreshold: 1
    unhealthyThreshold: 3
    config:
      type: HTTP
      httpHealthCheck:
        port: 9090
        requestPath: /prometheus/-/healthy
---
apiVersion: networking.gke.io/v1
kind: HealthCheckPolicy
metadata:
  name: alertmanager-healthcheck
  namespace: monitoring
spec:
  targetRef:
    group: ""
    kind: Service
    name: kube-prometheus-stack-alertmanager
  default:
    checkIntervalSec: 10
    timeoutSec: 5
    healthyThreshold: 1
    unhealthyThreshold: 3
    config:
      type: HTTP
      httpHealthCheck:
        port: 9093
        requestPath: /alertmanager/-/healthy
EOF
```

#### Step 3: Create HTTPRoutes

These routes tell the Gateway to forward `/grafana`, `/prometheus`, and `/alertmanager` traffic to the monitoring services.

> **Note:** The Gateway must have `allowedRoutes.namespaces.from: All` set so it accepts routes from the `monitoring` namespace. This was already configured in the gateway-api-dns-guide.

```bash
kubectl apply -f - <<'EOF'
---
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: grafana-route
  namespace: monitoring
spec:
  parentRefs:
  - name: travel-booking-gateway
    namespace: travel-booking
  hostnames:
  - vijaygiduthuri.in
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /grafana
    backendRefs:
    - name: kube-prometheus-stack-grafana
      port: 80
---
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: prometheus-route
  namespace: monitoring
spec:
  parentRefs:
  - name: travel-booking-gateway
    namespace: travel-booking
  hostnames:
  - vijaygiduthuri.in
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /prometheus
    backendRefs:
    - name: kube-prometheus-stack-prometheus
      port: 9090
---
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: alertmanager-route
  namespace: monitoring
spec:
  parentRefs:
  - name: travel-booking-gateway
    namespace: travel-booking
  hostnames:
  - vijaygiduthuri.in
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /alertmanager
    backendRefs:
    - name: kube-prometheus-stack-alertmanager
      port: 9093
EOF
```

#### Step 4: Verify domain access

Wait 2-5 minutes for the GCP load balancer to reprogram, then test:

```bash
curl -s -o /dev/null -w "Grafana: HTTP %{http_code}\n" http://<DOMAIN_NAME>/grafana/
curl -s -o /dev/null -w "Prometheus: HTTP %{http_code}\n" http://<DOMAIN_NAME>/prometheus/
curl -s -o /dev/null -w "Alertmanager: HTTP %{http_code}\n" http://<DOMAIN_NAME>/alertmanager/
```

All three should return **HTTP 200** or **HTTP 302** (redirect to login for Grafana).

### Credentials

| Credential | Value |
|------------|-------|
| Grafana Username | `admin` |
| Grafana Password | `TravelBook@Admin123` |
