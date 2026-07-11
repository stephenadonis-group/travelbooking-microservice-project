# TravelBooking — Full-Stack Microservices Travel Booking Platform

A cloud-native microservices-based travel booking application, deployed on Elastic Kubernetes Engine (EKS) with a complete DevOps lifecycle — Terraform, Helm, Jenkins CI/CD, Prometheus & Grafana monitoring, Amazon ECR, AWS Load Balancer Controller, ACM & Route53.

---


## About the Project

TravelBooking is a cloud-native microservices travel application where users can search flights and hotels, make bookings, and process payments — similar to MakeMyTrip or Booking.com. The main focus of this project is to showcase a complete DevOps lifecycle on Amazon Web Services (AWS).

🏗️ **Architecture** — The app is built using **microservices architecture** with 6 services — a React frontend and 5 Go backend services (user, search, booking, payment, notification). Data is stored in PostgreSQL with 5 separate databases (one per service), and Redis is used for caching search results.

☸️ **Kubernetes & Infrastructure** — Everything runs on **Amazon Elastic Kubernetes Service (Amazon EKS)**. The AWS infrastructure (VPC, subnets, security-groups, ECR Registry, EKS) is created using **Terraform** . The application is deployed using a custom **Helm chart** that creates all Kubernetes resources with one command.

⚙️ **CI/CD with Jenkins** — **Jenkins** runs inside the same EKS cluster and handles CI/CD. The 14-stage pipeline clones code from GitHub, tests services, builds and pushes Docker images to Artifact Registry, scans images with Trivy, packages the Helm chart, and deploys to GKE automatically.

📊 **Monitoring** — Set up with Prometheus, Grafana, and Alertmanager. Each service exposes metrics that Prometheus scrapes every 15 seconds. Grafana shows 6 custom dashboards, and Alertmanager fires alerts on pod failures, high CPU/memory, or HTTP errors.

🔒 **HTTPS & SSL** — Handled by AWS Certificate Manager (ACM) integrated with the AWS Load Balancer Controller.

🌐 **DNS & Domain Access** — The application is accessible through a custom domain managed via Amazon Route53 Alias records pointing to an AWS Application Load Balancer (ALB). with Hostinger domain





<p align="center">
  <img src="assets/demo.gif" width="100%">
</p>

## 🎥 Project Walkthrough

📺 YouTube Demo: https://www.youtube.com/watch?v=7vjscHtgD5Y
---

## Architecture Overview

```mermaid
flowchart TB

    %% =========================
    %% User
    %% =========================
    subgraph USER["User"]
        BROWSER["Web Browser"]
    end

    %% =========================
    %% DNS
    %% =========================
    subgraph DNS["DNS"]
        ROUTE53["Amazon Route 53<br/>Hosted Zone"]
    end

    %% =========================
    %% AWS
    %% =========================
    subgraph AWS["Amazon Web Services (AWS)"]

        %% Terraform
        subgraph TERRAFORM["Infrastructure Provisioned with Terraform"]

            VPC["Amazon VPC<br/>10.0.0.0/16"]

            PUBLIC["Public Subnets"]

            PRIVATE["Private Subnets"]

            IGW["Internet Gateway"]

            NAT["NAT Gateway"]

            IAM["IAM Roles"]

            ECR["Amazon ECR<br/>Docker Images<br/>Helm Charts"]

        end

        %% Certificate
        subgraph CERT["SSL/TLS"]

            ACM["AWS Certificate Manager<br/>SSL Certificate"]

        end

        %% EKS
        subgraph EKS["Amazon EKS Cluster<br/>Managed Node Group (2–5 EC2 Nodes)"]

            %% Load Balancer
            subgraph LB["AWS Load Balancer Controller"]

                ALB["Application Load Balancer<br/>HTTP :80<br/>HTTPS :443"]

                INGRESS["Ingress Rules<br/>/ <br/>/api/*<br/>/jenkins<br/>/grafana<br/>prometheus.steveops.site<br/>alertmanager.steveops.site"]

            end

            %% Application
            subgraph APP["Namespace: travel-booking"]

                direction LR

                FE["Frontend<br/>React.js<br/>Nginx :80"]

                US["User Service<br/>Go :3001"]

                SS["Search Service<br/>Go :3002"]

                BS["Booking Service<br/>Go :3003"]

                PS["Payment Service<br/>Go :3004"]

                NS["Notification Service<br/>Go :3005"]

            end

            %% Database
            subgraph DATA["Data Layer"]

                PG["PostgreSQL<br/>StatefulSet :5432<br/>5 Databases"]

                REDIS["Redis Cache :6379"]

            end

            %% Jenkins
            subgraph JENKINS["Namespace: jenkins"]

                JK["Jenkins Controller"]

                AGENT["Dynamic Jenkins Agents<br/>docker<br/>golang<br/>nodejs<br/>helm<br/>aws-cli"]

            end

            %% Monitoring
            subgraph MONITORING["Namespace: monitoring"]

                GRAFANA["Grafana<br/>Dashboards"]

                PROM["Prometheus<br/>Metrics"]

                ALERT["Alertmanager<br/>Alerts"]

            end

        end
    end

    %% =========================
    %% GitHub
    %% =========================
    subgraph GITHUB["GitHub"]

        REPO["Application Source Code<br/>Terraform<br/>Helm Charts<br/>Jenkinsfile"]

    end

    %% =========================
    %% User Flow
    %% =========================

    BROWSER -->|"https://steveops.site"| ROUTE53

    ROUTE53 -->|"Alias Record"| ALB

    ACM -->|"HTTPS Certificate"| ALB

    ALB --> INGRESS

    %% =========================
    %% Ingress Routing
    %% =========================

    INGRESS -->|"/"| FE

    INGRESS -->|"/api/users"| US

    INGRESS -->|"/api/search"| SS

    INGRESS -->|"/api/bookings"| BS

    INGRESS -->|"/api/payments"| PS

    INGRESS -->|"/api/notifications"| NS

    INGRESS -->|"/jenkins"| JK

    INGRESS -->|"/grafana"| GRAFANA

    INGRESS -->|"prometheus.steveops.site"| PROM

    INGRESS -->|"alertmanager.steveops.site"| ALERT

    %% =========================
    %% Databases
    %% =========================

    US --> PG

    SS --> PG

    BS --> PG

    PS --> PG

    NS --> PG

    SS --> REDIS

    NS --> REDIS

    %% =========================
    %% Monitoring
    %% =========================

    PROM -->|"Scrapes /metrics"| US

    PROM -->|"Scrapes /metrics"| SS

    PROM -->|"Scrapes /metrics"| BS

    PROM -->|"Scrapes /metrics"| PS

    PROM -->|"Scrapes /metrics"| NS

    GRAFANA -->|"Queries"| PROM

    PROM -->|"Fires Alerts"| ALERT

    %% =========================
    %% CI/CD
    %% =========================

    REPO -->|"Git Clone"| JK

    JK --> AGENT

    AGENT -->|"Build & Push Images"| ECR

    AGENT -->|"Package & Push Helm Chart"| ECR

    AGENT -->|"helm upgrade --install"| EKS
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
| **Orchestration** | Kubernetes (EKS) |
| **Infrastructure** | Terraform (modular) |
| **Packaging** | Helm Charts |
| **CI/CD** | Jenkins (on EKS) |
| **Monitoring** | Prometheus, Grafana, Alertmanager |
| **TLS/SSL** | ACM |
| **DNS** | Hostinger |
| **Registry** | ECR Registry |
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
| Ingress | 1 | AWS Load Balancer Controller |
| HTTPRoutes | 6 | URL path routing |

---

## AWS Infrastructure (Terraform)

| Resource | Name | Purpose |
|----------|------|---------|
| VPC | travelbooking-vpc | Network isolation |
| Subnet | travelbooking-subnet | 10.0.0.0/16 CIDR |
| Security-groups | 4 rules | SSH, HTTP/S, Internal, Health Checks |
| EKS Cluster | travelbooking-eks | 
| Node Pool | t2.medium | Autoscale 2-5 nodes |
| ECR Registry | travel-booking | Docker images & Helm charts |


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
├── AWS-terraform1/             # Terraform modules for AWS infrastructure
├── jenkins/                   # Jenkins Helm values & setup guide
├── monitoring/                # Prometheus, Grafana, alerts, dashboards
├── https/                     # ACM
├── docs/                      # All documentation
│   ├── postgresql-database-guide.md
│   ├── gateway-api-dns-guide.md
│   ├── docker-compose-local-setup-guide.md
│   └── https-setup-guide.md
├── docker-compose.yml         # Local development setup
├── Jenkinsfile                # CI/CD pipeline 
└── Makefile                   # Build commands
```

---

## Deployment Order

```
1. Terraform       → Create VPC, EKS, ECR Registry, IAM Roles
2. Helm Chart      → Deploy TravelBooking app (8 pods)
3. Jenkins         → Install CI/CD on EKS
4. Monitoring      → Prometheus + Grafana + Alertmanager
5. DNS             → Route53
6. HTTPS           → ACM
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
| [Jenkins Guide](jenkins/jenkins.md) | Jenkins installation & pipeline |
| [Monitoring Guide](monitoring/monitoring.md) | Prometheus & Grafana setup |
| [PostgreSQL Guide](docs/postgresql-database-guide.md) | Database queries & access |
| [Docker Compose Guide](docs/docker-compose-local-setup-guide.md) | Local development setup |



<p align="center">
<img src="assets/pic1.JPG" width="900">
</p>

<p align="center">
<img src="assets/pic2.JPG" width="900">
</p>

<p align="center">
<img src="assets/pic3.JPG" width="900">
</p>

<p align="center">
<img src="assets/pic4.JPG" width="900">
</p>

<p align="center">
<img src="assets/pic5.JPG" width="900">
</p>
