# TravelBooking — AWS ALB & Route 53 Configuration Guide

This guide explains how the TravelBooking application is exposed using the **AWS Load Balancer Controller**, an **Application Load Balancer (ALB)**, and **Amazon Route 53**.

---

# Architecture

```
                   User Browser
                        │
                        ▼
               travelbooking.example.com
                        │
                        ▼
                Amazon Route 53 (DNS)
                        │
                        ▼
        AWS Application Load Balancer (ALB)
                        │
                        ▼
              Kubernetes Ingress Resource
                        │
     ┌──────────┬──────────┬──────────┬──────────┬──────────┐
     ▼          ▼          ▼          ▼          ▼
 Frontend    User API   Search API Booking API Payment API
```

---

# How It Works

The AWS Load Balancer Controller watches Kubernetes Ingress resources.

When the Helm chart is deployed it automatically:

- Creates an Application Load Balancer (ALB)
- Configures HTTP routing rules
- Registers Kubernetes services as Target Groups
- Performs health checks
- Exposes the application to the internet

---

# Application Routes

| Path | Backend Service |
|-------|-----------------|
| `/` | frontend-service |
| `/api/users` | user-service |
| `/api/search` | search-service |
| `/api/bookings` | booking-service |
| `/api/payments` | payment-service |
| `/api/notifications` | notification-service |
| `/jenkins` | Jenkins |

---

# Verify the ALB

View the Ingress resource:

```bash
kubectl get ingress -n travel-booking
```

Expected output:

```text
NAME                     CLASS   HOSTS   ADDRESS
travel-booking-ingress   alb     *       k8s-travel-xxxxxxxx.eu-west-3.elb.amazonaws.com
```

Describe the Ingress:

```bash
kubectl describe ingress travel-booking-ingress -n travel-booking
```

---

# Configure Route 53

After the ALB has been created, copy its DNS name:

```bash
kubectl get ingress -n travel-booking
```

Example:

```
k8s-travel-xxxxxxxx.eu-west-3.elb.amazonaws.com
```

Open **AWS Console**

```
Route 53
    ↓
Hosted Zones
    ↓
your-domain.com
```

Create an Alias Record:

| Type | Name | Value |
|------|------|-------|
| A | @ | Alias → Application Load Balancer |

Or for a subdomain:

| Type | Name |
|------|------|
| A | travel |

Alias Target:

```
k8s-travel-xxxxxxxx.eu-west-3.elb.amazonaws.com
```

Save the record.

DNS propagation usually completes within a few minutes.

---

# Verify DNS

```bash
nslookup your-domain.com

dig your-domain.com
```

The domain should resolve to the ALB.

---

# Test the Application

Homepage

```bash
curl http://your-domain.com
```

User API

```bash
curl http://your-domain.com/api/users
```

Search API

```bash
curl http://your-domain.com/api/search
```

Jenkins

```bash
http://your-domain.com/jenkins
```

---

# Deployment Workflow

```
Terraform
      │
      ▼
Create AWS Infrastructure
(VPC • EKS • IAM • Route53)

      │
      ▼
Install AWS Load Balancer Controller

      │
      ▼
Deploy Application with Helm

      │
      ▼
Ingress creates AWS ALB

      │
      ▼
Route53 points Domain to ALB

      │
      ▼
Users access the application
```

---

# Troubleshooting

### ALB not created

```bash
kubectl get ingress -A

kubectl describe ingress travel-booking-ingress -n travel-booking
```

---

### Check AWS Load Balancer Controller

```bash
kubectl get pods -n kube-system
```

---

### Check Target Health

AWS Console

```
EC2
  ↓
Target Groups
  ↓
Targets
```

Targets should show **Healthy**.

---

### DNS not working

```bash
dig your-domain.com
```

Verify that Route 53 points to the ALB.

---

### Application returns 503

Check pods:

```bash
kubectl get pods -n travel-booking

kubectl get svc -n travel-booking

kubectl logs deployment/<service-name> -n travel-booking
```

---

# Application URLs

```
http://your-domain.com
```

Frontend

```
/
```

User Service

```
/api/users
```

Search Service

```
/api/search
```

Booking Service

```
/api/bookings
```

Payment Service

```
/api/payments
```

Notification Service

```
/api/notifications
```

Jenkins

```
/jenkins
```


### API Endpoints (Backend Services)

| Service | Base URL | Key Endpoints |
|---------|----------|---------------|
| **User Service** | `http://vijaygiduthuri.in/api/users` | |
| | `POST /api/users/register` | Register a new user |
| | `POST /api/users/login` | Login and get JWT token |
| | `GET /api/users/profile` | Get user profile (auth required) |
| | `PUT /api/users/profile` | Update user profile (auth required) |
| **Search Service** | `http://vijaygiduthuri.in/api/search` | |
| | `GET /api/search/flights?from=NYC&to=LAX` | Search flights |
| | `GET /api/search/flights/:id` | Get flight by ID |
| | `GET /api/search/hotels?city=Paris` | Search hotels |
| | `GET /api/search/hotels/:id` | Get hotel by ID |
| **Booking Service** | `http://vijaygiduthuri.in/api/bookings` | |
| | `POST /api/bookings/flight` | Book a flight (auth required) |
| | `POST /api/bookings/hotel` | Book a hotel (auth required) |
| | `GET /api/bookings/user/:userId` | Get user's bookings (auth required) |
| | `GET /api/bookings/:bookingId` | Get booking details (auth required) |
| | `PUT /api/bookings/:bookingId/cancel` | Cancel a booking (auth required) |
| **Payment Service** | `http://vijaygiduthuri.in/api/payments` | |
| | `POST /api/payments/process` | Process a payment (auth required) |
| | `GET /api/payments/:paymentId` | Get payment details (auth required) |
| | `GET /api/payments/booking/:bookingId` | Get payment by booking (auth required) |
| | `POST /api/payments/refund` | Refund a payment (auth required) |
| **Notification Service** | `http://vijaygiduthuri.in/api/notifications` | |
| | `GET /api/notifications/user/:userId` | Get user notifications |
| | `PUT /api/notifications/:id/read` | Mark notification as read |

### Health Check Endpoints (for monitoring)

| URL | Service |
|-----|---------|
| `http://vijaygiduthuri.in/api/users/../health` | User Service |
| Direct pod: `user-service-service:3001/health` | User Service |
| Direct pod: `search-service-service:3002/health` | Search Service |
| Direct pod: `booking-service-service:3003/health` | Booking Service |
| Direct pod: `payment-service-service:3004/health` | Payment Service |
| Direct pod: `notification-service-service:3005/health` | Notification Service |

> **Note:** Health endpoints are accessible internally within the cluster. The Gateway routes `/api/*` paths to specific services, so `/health` from outside goes to the frontend, not the backend services.

---

## Complete Deployment Workflow

Here is the full workflow from infrastructure to live application:

```
Step 1: Create GCP Infrastructure (Terraform)
    └── VPC, Subnet, Firewalls, GKE, Artifact Registry, Static IP
         │
Step 2: Install Jenkins on GKE (Helm)  ← To be configured later
    └── Jenkins pipeline for CI/CD
         │
Step 3: Build & Deploy Application (Jenkins Pipeline)  ← To be configured later
    └── Build images → Push to AR → Package Helm → Deploy to GKE
         │
Step 4: Configure DNS (This Guide)
    └── Get Gateway IP → Add A record on GoDaddy → Verify
         │
Step 5: Access Application
    └── http://vijaygiduthuri.in
```

---

## Troubleshooting

### Gateway shows "Unknown" or no IP

The GCP load balancer takes 5-15 minutes to provision. Wait and check again:

```bash
kubectl describe gateway travel-booking-gateway -n travel-booking
```

Look at the `Events` section for progress.

### "fault filter abort" error in browser

This means the request reached the Gateway but no HTTPRoute matched. Check:

```bash
kubectl get httproute -n travel-booking
```

All 6 routes should be listed.

### "no healthy upstream" error

The backend pods are not passing GCP health checks. Check pod status:

```bash
kubectl get pods -n travel-booking
kubectl logs -n travel-booking deployment/<service-name>-deployment
```

### DNS not resolving

Check if DNS has propagated:

```bash
dig vijaygiduthuri.in +short
```

If it shows nothing, wait 15-30 minutes. GoDaddy DNS can be slow to update.

### Website loads but API calls fail

Check if the API routes are healthy:

```bash
curl -v http://vijaygiduthuri.in/api/search/flights?from=NYC&to=LAX
```

If you get 503, the backend service health check is failing. Check:

```bash
gcloud compute backend-services list --global | grep travel
gcloud compute backend-services get-health <backend-name> --global
```
