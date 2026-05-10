# TravelBooking — Full-Stack Microservices Travel Booking Platform

A production-grade travel booking application built with microservices architecture, deployed on Google Kubernetes Engine (GKE) with a complete DevOps lifecycle — Terraform, Helm, Jenkins CI/CD, Prometheus & Grafana monitoring, and HTTPS with Let's Encrypt.

---

## Architecture Overview

```mermaid
flowchart TB
    subgraph USER["User"]
        BROWSER["Browser"]
    end

    subgraph DNS["DNS & SSL"]
        GODADDY["GoDaddy DNS\nA Record"]
        LETSENCRYPT["Let's Encrypt\nFree SSL"]
    end

    subgraph GCP["Google Cloud Platform"]

        subgraph TERRAFORM["Infrastructure (Terraform)"]
            STATICIP["Global Static IP\ntravel-booking-ip"]
            VPC["VPC\ntravelbooking-vpc\n10.0.0.0/16"]
            FIREWALL["Firewall Rules\nSSH | HTTP | HTTPS\nInternal | Health Checks"]
            ARTIFACTREGISTRY["Artifact Registry\ntravel-booking\nDocker Images\nHelm Charts"]
        end

        subgraph GKE["GKE Cluster\ne2-standard-2 | Autoscale 2-5 Nodes"]

            subgraph GATEWAY["Gateway API — Load Balancer"]
                GW["Gateway\nHTTP :80 | HTTPS :443"]
                ROUTES["HTTPRoutes\n/ | /api/* | /jenkins\n/grafana | /prometheus | /alertmanager"]
            end

            subgraph APP["Namespace: travel-booking"]
                direction LR
                FE["Frontend\nReact.js\nNginx :80"]
                US["User Service\nGo :3001"]
                SS["Search Service\nGo :3002"]
                BS["Booking Service\nGo :3003"]
                PS["Payment Service\nGo :3004"]
                NS["Notification\nService\nGo :3005"]
            end

            subgraph DATA["Data Layer"]
                PG["PostgreSQL\nStatefulSet :5432\n5 Databases"]
                RD["Redis\nCache :6379"]
            end

            subgraph JENKINS["Namespace: default"]
                JK["Jenkins\nCI/CD :8080"]
                AGENT["Jenkins Agent\nDynamic Pods\ndocker | golang\nnodejs | helm | gcloud"]
            end

            subgraph MON["Namespace: monitoring"]
                PROM["Prometheus\nMetrics :9090"]
                GRAF["Grafana\nDashboards :3000"]
                ALERT["Alertmanager\nAlerts :9093"]
            end

            subgraph CERTMGR["Namespace: cert-manager"]
                CM["cert-manager\nAuto TLS Renewal"]
            end

        end
    end

    subgraph GITHUB["GitHub (Private Repo)"]
        REPO["Source Code\nHelm Charts\nJenkinsfile\nTerraform\nDocs"]
    end

    BROWSER -->|"https://domain.com"| GODADDY
    GODADDY -->|"A Record"| STATICIP
    STATICIP --> GW
    GW --> ROUTES

    ROUTES -->|"/"| FE
    ROUTES -->|"/api/users"| US
    ROUTES -->|"/api/search"| SS
    ROUTES -->|"/api/bookings"| BS
    ROUTES -->|"/api/payments"| PS
    ROUTES -->|"/api/notifications"| NS
    ROUTES -->|"/jenkins"| JK
    ROUTES -->|"/grafana"| GRAF
    ROUTES -->|"/prometheus"| PROM
    ROUTES -->|"/alertmanager"| ALERT

    US --> PG
    SS --> PG
    BS --> PG
    PS --> PG
    NS --> PG
    SS --> RD
    NS --> RD

    PROM -->|"Scrape /metrics"| US
    PROM -->|"Scrape /metrics"| SS
    PROM -->|"Scrape /metrics"| BS
    PROM -->|"Scrape /metrics"| PS
    PROM -->|"Scrape /metrics"| NS
    GRAF -->|"Query"| PROM
    PROM -->|"Fire Alerts"| ALERT

    CM -->|"HTTP01 Challenge"| LETSENCRYPT
    CM -->|"TLS Secret"| GW

    REPO -->|"Git Clone"| JK
    JK --> AGENT
    AGENT -->|"Push Images\nPush Charts"| ARTIFACTREGISTRY
    AGENT -->|"helm upgrade"| GW
```

---

## CI/CD Pipeline Flow (Jenkins)

```mermaid
flowchart LR
    subgraph PIPELINE["Jenkins Pipeline — 14 Stages"]
        direction LR
        S1["Git\nClone"]
        S2["Test\nGo Services"]
        S3["Test\nFrontend"]
        S4["Docker\nLogin"]
        S5["Build & Push\n6 Docker Images"]
        S6["Trivy\nSecurity Scan"]
        S7["Update\nHelm Values"]
        S8["Package &\nPush Helm Chart"]
        S9["Deploy\nto GKE"]
    end

    GH["GitHub\nPrivate Repo"] --> S1
    S1 --> S2 --> S3 --> S4 --> S5 --> S6 --> S7 --> S8 --> S9
    S5 -->|"Images"| AR["Artifact\nRegistry"]
    S8 -->|"Chart"| AR
    S9 -->|"helm upgrade\n--install"| GKE["GKE\nCluster"]
```

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| **Frontend** | React.js 18, Tailwind CSS, Nginx |
| **Backend** | Go 1.21, Gin Framework, GORM |
| **Database** | PostgreSQL 15 (5 databases) |
| **Cache** | Redis 7 |
| **Container** | Docker (multi-stage builds) |
| **Orchestration** | Kubernetes (GKE) |
| **Infrastructure** | Terraform (modular) |
| **Packaging** | Helm Charts |
| **CI/CD** | Jenkins (on GKE) |
| **Monitoring** | Prometheus, Grafana, Alertmanager |
| **TLS/SSL** | cert-manager, Let's Encrypt |
| **DNS** | GoDaddy |
| **Registry** | Google Artifact Registry |
| **Version Control** | GitHub (private) |

---

## Microservices

| Service | Language | Port | Database | Purpose |
|---------|----------|------|----------|---------|
| **Frontend** | React.js | 80 | - | User interface |
| **User Service** | Go | 3001 | userdb | Registration, login, JWT auth |
| **Search Service** | Go | 3002 | searchdb | Flight & hotel search, Redis cache |
| **Booking Service** | Go | 3003 | bookingdb | Create & manage bookings |
| **Payment Service** | Go | 3004 | paymentdb | Payment processing |
| **Notification Service** | Go | 3005 | notificationdb | Booking notifications |
| **PostgreSQL** | - | 5432 | 5 DBs | Data storage (StatefulSet) |
| **Redis** | - | 6379 | - | Search cache & message queue |

---

## Kubernetes Resources (Helm Chart)

| Resource | Count | Purpose |
|----------|-------|---------|
| Deployments | 7 | Application containers |
| StatefulSet | 1 | PostgreSQL with persistent storage |
| Services | 8 | Internal networking |
| ConfigMaps | 6 | Environment variables |
| Secrets | 5 | DB passwords, JWT secrets |
| HPAs | 6 | Auto-scaling (1-5 replicas) |
| Gateway | 1 | GCP Load Balancer |
| HTTPRoutes | 6 | URL path routing |

---

## GCP Infrastructure (Terraform)

| Resource | Name | Purpose |
|----------|------|---------|
| VPC | travelbooking-vpc | Network isolation |
| Subnet | travelbooking-subnet | 10.0.0.0/16 CIDR |
| Firewall | 4 rules | SSH, HTTP/S, Internal, Health Checks |
| GKE Cluster | travelbooking-gke | Kubernetes with Gateway API |
| Node Pool | e2-standard-2 | Autoscale 2-5 nodes |
| Artifact Registry | travel-booking | Docker images & Helm charts |
| Static IP | travel-booking-ip | Global IP for Gateway |

---

## Monitoring Stack

| Tool | Purpose | Access |
|------|---------|--------|
| **Prometheus** | Metrics collection (15s scrape interval) | /prometheus |
| **Grafana** | 6 custom dashboards + Kubernetes dashboards | /grafana |
| **Alertmanager** | Alert rules: PodDown, HighCPU, HighMemory, HTTPErrors | /alertmanager |
| **ServiceMonitors** | Auto-discover & scrape 5 Go services | - |
| **Node Exporter** | Node-level CPU, memory, disk metrics | - |
| **kube-state-metrics** | Pod, deployment, service status metrics | - |

---

## Project Structure

```
travelbooking/
├── frontend/                  # React.js frontend
├── user-service/              # Go — user management & JWT auth
├── search-service/            # Go — flight & hotel search with Redis cache
├── booking-service/           # Go — booking management
├── payment-service/           # Go — payment processing
├── notification-service/      # Go — notifications
├── postgres/                  # Database init script (5 databases)
├── nginx/                     # Reverse proxy config (local dev)
├── helm/travel-booking/       # Helm chart for Kubernetes deployment
├── gcp-terraform/             # Terraform modules for GCP infrastructure
├── jenkins/                   # Jenkins Helm values & setup guide
├── monitoring/                # Prometheus, Grafana, alerts, dashboards
├── https/                     # cert-manager & Let's Encrypt config
├── docs/                      # All documentation
│   ├── postgresql-database-guide.md
│   ├── gateway-api-dns-guide.md
│   ├── docker-compose-local-setup-guide.md
│   └── https-setup-guide.md
├── docker-compose.yml         # Local development setup
├── Jenkinsfile                # CI/CD pipeline (14 stages)
└── Makefile                   # Build commands
```

---

## Deployment Order

```
1. Terraform       → Create VPC, GKE, Artifact Registry, Static IP
2. Helm Chart      → Deploy TravelBooking app (8 pods)
3. Jenkins         → Install CI/CD on GKE
4. Monitoring      → Prometheus + Grafana + Alertmanager
5. DNS             → Point domain to Gateway IP (GoDaddy)
6. HTTPS           → cert-manager + Let's Encrypt + HTTP→HTTPS redirect
```

---

## Local Development

```bash
# Run the entire application locally
docker compose up -d --build

# Access at http://localhost:8080

# Stop
docker compose down
```

---

## Documentation

| Guide | Description |
|-------|-------------|
| [Helm Chart README](helm/travel-booking/README.md) | Helm commands & chart details |
| [Terraform README](gcp-terraform/README.md) | GCP infrastructure setup |
| [Jenkins Guide](jenkins/jenkins.md) | Jenkins installation & pipeline |
| [Monitoring Guide](monitoring/monitoring.md) | Prometheus & Grafana setup |
| [PostgreSQL Guide](docs/postgresql-database-guide.md) | Database queries & access |
| [Gateway & DNS Guide](docs/gateway-api-dns-guide.md) | Gateway API & domain setup |
| [HTTPS Guide](docs/https-setup-guide.md) | SSL/TLS with Let's Encrypt |
| [Docker Compose Guide](docs/docker-compose-local-setup-guide.md) | Local development setup |
