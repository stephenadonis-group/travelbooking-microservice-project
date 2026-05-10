# TravelBooking — Gateway API & DNS Configuration Guide

This guide explains the GKE Gateway API setup, how the Helm chart creates the Gateway and HTTPRoutes, and how to connect your custom domain **vijaygiduthuri.in** via GoDaddy DNS.

---

## What is Gateway API?

Gateway API is the **next generation of Kubernetes Ingress**. It replaces the older Ingress resource with a more powerful and flexible way to route external traffic into your Kubernetes cluster.

**How it works in simple terms:**

```
User's Browser
      │
      ▼
┌─────────────────────────┐
│   Google Cloud           │
│   Load Balancer          │  ← Created by the Gateway resource
│   (Static IP)            │
└─────────┬───────────────┘
          │
          ▼
┌─────────────────────────┐
│   Gateway                │  ← Entry point - listens on port 80
│   (travel-booking-gw)    │
└─────────┬───────────────┘
          │
          ▼
┌─────────────────────────┐
│   HTTPRoutes             │  ← Traffic rules - which path goes where
│                          │
│   /              → frontend-service:80
│   /api/users     → user-service:3001
│   /api/search    → search-service:3002
│   /api/bookings  → booking-service:3003
│   /api/payments  → payment-service:3004
│   /api/notifications → notification-service:3005
└─────────────────────────┘
```

---

## What the Helm Chart Creates

When you run `helm install` or `helm upgrade`, the chart automatically creates:

### 1. Gateway Resource

**File:** `templates/gateway.yaml`

```yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: Gateway
metadata:
  name: travel-booking-gateway
  annotations:
    kubernetes.io/ingress.global-static-ip-name: travel-booking-ip
spec:
  gatewayClassName: gke-l7-global-external-managed
  listeners:
  - name: http
    port: 80
    protocol: HTTP
```

**What this does:**
- Creates a Google Cloud Global HTTP Load Balancer
- Attaches it to the static IP `travel-booking-ip`
- Listens on port 80 (HTTP)
- Uses `gke-l7-global-external-managed` — this is GKE's built-in Gateway class that provisions a real GCP load balancer

### 2. HTTPRoute Resources (6 total)

Each HTTPRoute defines a URL path and which backend service handles it:

| HTTPRoute | Path Match | Routes To | Port | Purpose |
|-----------|-----------|-----------|------|---------|
| `frontend-route` | `/` (everything else) | `frontend-service` | 80 | React UI — serves the website |
| `user-route` | `/api/users/*` | `user-service-service` | 3001 | Registration, login, profile |
| `search-route` | `/api/search/*` | `search-service-service` | 3002 | Search flights and hotels |
| `booking-route` | `/api/bookings/*` | `booking-service-service` | 3003 | Create and manage bookings |
| `payment-route` | `/api/payments/*` | `payment-service-service` | 3004 | Process payments |
| `notification-route` | `/api/notifications/*` | `notification-service-service` | 3005 | User notifications |

**How routing works:**
- The Gateway receives ALL incoming HTTP traffic
- It checks the URL path of each request
- If the path starts with `/api/users`, it sends it to the user-service
- If the path starts with `/api/search`, it sends it to the search-service
- If nothing else matches, `/` catches everything and sends it to the frontend
- The frontend route MUST be last because `/` matches everything

---

## After Deploying — Verify Gateway is Working

### Check Gateway Status

```bash
kubectl get gateway -n travel-booking
```

**Expected output:**
```
NAME                     CLASS                            ADDRESS         PROGRAMMED   AGE
travel-booking-gateway   gke-l7-global-external-managed   34.x.x.x       True         5m
```

- `ADDRESS` — the IP assigned by GCP (should match your static IP)
- `PROGRAMMED: True` — means the load balancer is ready

> **Note:** It takes **5-15 minutes** for the Gateway to become `PROGRAMMED` after the first deploy. The GCP load balancer needs time to provision.

### Check HTTPRoutes

```bash
kubectl get httproute -n travel-booking
```

**Expected output:**
```
NAME                 AGE
booking-route        5m
frontend-route       5m
notification-route   5m
payment-route        5m
search-route         5m
user-route           5m
```

### Check Gateway IP

```bash
kubectl get gateway -n travel-booking -o jsonpath='{.items[0].status.addresses[0].value}'
```

Or via gcloud:

```bash
gcloud compute addresses list --global --filter="name=travel-booking-ip"
```

### Test the Gateway

```bash
# Get the Gateway IP
GATEWAY_IP=$(kubectl get gateway -n travel-booking -o jsonpath='{.items[0].status.addresses[0].value}')

# Test frontend
curl -s -o /dev/null -w "%{http_code}" http://$GATEWAY_IP/
# Expected: 200

# Test user API
curl -s -o /dev/null -w "%{http_code}" http://$GATEWAY_IP/api/users/register
# Expected: 400 (no body sent, but proves the route works)

# Test search API
curl -s http://$GATEWAY_IP/api/search/flights?from=NYC&to=LAX
# Expected: JSON response with flights
```

---

## Configure Custom Domain: vijaygiduthuri.in

### Step 1: Get the Gateway IP Address

```bash
kubectl get gateway -n travel-booking -o jsonpath='{.items[0].status.addresses[0].value}'
```

Note down this IP address. For example: `<GATEWAY_IP>`

### Step 2: Update DNS on GoDaddy

1. **Login to GoDaddy** → [https://dcc.godaddy.com](https://dcc.godaddy.com)

2. Go to **My Products** → Find **vijaygiduthuri.in** → Click **DNS**

3. **Add or update these DNS records:**

#### Option A: Use Root Domain (vijaygiduthuri.in)

| Type | Name | Value | TTL |
|------|------|-------|-----|
| **A** | `@` | `<GATEWAY_IP>` | 600 |

This maps `vijaygiduthuri.in` → Gateway IP

#### Option B: Use Subdomain (travel.vijaygiduthuri.in)

| Type | Name | Value | TTL |
|------|------|-------|-----|
| **A** | `travel` | `<GATEWAY_IP>` | 600 |

This maps `travel.vijaygiduthuri.in` → Gateway IP

#### Option C: Use Both (Recommended)

| Type | Name | Value | TTL |
|------|------|-------|-----|
| **A** | `@` | `<GATEWAY_IP>` | 600 |
| **A** | `travel` | `<GATEWAY_IP>` | 600 |

> **Replace `<GATEWAY_IP>` with your actual Gateway IP address from `kubectl get gateway -n travel-booking`**

4. Click **Save** on each record

### Step 3: Wait for DNS Propagation

DNS changes take **5 to 30 minutes** to propagate worldwide. You can check the status:

```bash
# Check if DNS is pointing to your IP
nslookup vijaygiduthuri.in
# or
dig vijaygiduthuri.in +short
```

Expected output should show your Gateway IP.

### Step 4: Test with Your Domain

Once DNS propagates:

```bash
# Test the website
curl -s -o /dev/null -w "%{http_code}" http://vijaygiduthuri.in/
# Expected: 200

# Test API
curl -s http://vijaygiduthuri.in/api/search/flights?from=NYC&to=LAX
# Expected: JSON response
```

Open in browser: **http://vijaygiduthuri.in**

---

## Step 5: Update Gateway & HTTPRoutes with Domain Name

After DNS is pointing to the Gateway IP and you can verify with `dig vijaygiduthuri.in +short`, you need to update the Gateway and all HTTPRoutes to use the domain name. This is important because:

- **Gateway** — needs the domain in the listener so it correctly routes traffic for your domain
- **HTTPRoutes** — need the `hostnames` field so the Gateway only accepts traffic from your domain (security best practice)

### Why is this needed?

Without updating, the Gateway accepts requests from **any hostname** (including the raw IP). After updating:
- Only requests to `vijaygiduthuri.in` are accepted
- Raw IP access will show "fault filter abort" (expected — forces users to use the domain)

### 5a. Update the Gateway

Connect to your GKE cluster:

```bash
gcloud container clusters get-credentials travelbooking-gke --zone us-central1-a --project YOUR_PROJECT_ID
```

Apply the updated Gateway:

```bash
kubectl apply -f - <<'EOF'
apiVersion: gateway.networking.k8s.io/v1beta1
kind: Gateway
metadata:
  name: travel-booking-gateway
  namespace: travel-booking
  annotations:
    kubernetes.io/ingress.global-static-ip-name: travel-booking-ip
spec:
  gatewayClassName: gke-l7-global-external-managed
  listeners:
  # HTTP listener — accepts traffic only for your domain
  - name: http
    port: 80
    protocol: HTTP
    hostname: vijaygiduthuri.in
    allowedRoutes:
      namespaces:
        from: All
EOF
```

**What changed:**
- Added `hostname: vijaygiduthuri.in` to the HTTP listener — now it only accepts requests with this domain
- Changed `allowedRoutes.namespaces.from` to `All` — this allows HTTPRoutes from **any namespace** (needed because Jenkins runs in `default` namespace while the app runs in `travel-booking` namespace)
- Requests via raw IP will get "fault filter abort" (expected — forces users to use the domain)

### 5b. Update All HTTPRoutes with Domain Name

Apply all 6 updated HTTPRoutes at once:

```bash
kubectl apply -f - <<'EOF'
---
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: frontend-route
  namespace: travel-booking
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
        value: /
    backendRefs:
    - name: frontend-service
      port: 80
---
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: user-route
  namespace: travel-booking
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
        value: /api/users
    backendRefs:
    - name: user-service-service
      port: 3001
---
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: search-route
  namespace: travel-booking
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
        value: /api/search
    backendRefs:
    - name: search-service-service
      port: 3002
---
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: booking-route
  namespace: travel-booking
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
        value: /api/bookings
    backendRefs:
    - name: booking-service-service
      port: 3003
---
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: payment-route
  namespace: travel-booking
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
        value: /api/payments
    backendRefs:
    - name: payment-service-service
      port: 3004
---
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: notification-route
  namespace: travel-booking
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
        value: /api/notifications
    backendRefs:
    - name: notification-service-service
      port: 3005
EOF
```

**What changed in each HTTPRoute:**
- Added `hostnames: [vijaygiduthuri.in]` — the route now only matches requests coming through your domain

### 5c. Configure Jenkins Gateway Access

Jenkins runs in the `default` namespace (not `travel-booking`). We need to create an HTTPRoute and a HealthCheckPolicy so the Gateway can route `/jenkins` traffic to the Jenkins service.

**Why do we need a HealthCheckPolicy?**

By default, GCP's load balancer health check probes `/` on the backend service. But Jenkins is configured with a URI prefix `/jenkins`, so its health endpoint is at `/jenkins/login` — not `/`. Without the HealthCheckPolicy, GCP will mark Jenkins as **UNHEALTHY** and return "no healthy upstream".

#### Apply Jenkins HealthCheckPolicy

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
- Tells GCP's load balancer to health check Jenkins at `/jenkins/login` on port `8080`
- Without this, GCP probes `/` which returns a redirect, and Jenkins shows as unhealthy

#### Apply Jenkins HTTPRoute

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
  - vijaygiduthuri.in
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
- Routes all requests to `http://vijaygiduthuri.in/jenkins/*` to the Jenkins service on port 8080
- The HTTPRoute lives in the `default` namespace (same as Jenkins)
- It references the Gateway in `travel-booking` namespace via `parentRefs`
- This works because we set `allowedRoutes.namespaces.from: All` in the Gateway

#### Verify Jenkins Route

```bash
# Check HTTPRoute is accepted
kubectl get httproute jenkins-httproute -n default

# Check HealthCheckPolicy
kubectl get healthcheckpolicy -n default

# Test Jenkins access via domain (after DNS is configured)
curl -s -o /dev/null -w "%{http_code}" http://vijaygiduthuri.in/jenkins/login
# Expected: 200
```

### 5d. Verify Everything

```bash
# Check Gateway has the domain
kubectl get gateway -n travel-booking
# ADDRESS should show your static IP, PROGRAMMED should be True

# Check all HTTPRoutes (both namespaces)
kubectl get httproute -n travel-booking
kubectl get httproute -n default
# HOSTNAMES column should show vijaygiduthuri.in for each route

# Test frontend
curl -s -o /dev/null -w "%{http_code}" http://vijaygiduthuri.in/
# Expected: 200

# Test API
curl -s http://vijaygiduthuri.in/api/search/flights?from=NYC&to=LAX
# Expected: JSON response with flights

# Test Jenkins
curl -s -o /dev/null -w "%{http_code}" http://vijaygiduthuri.in/jenkins/login
# Expected: 200

# Verify raw IP no longer works (expected — domain is required now)
curl -s -o /dev/null -w "%{http_code}" http://<GATEWAY_IP>/
# Expected: 404 or "fault filter abort"
```

### Quick Summary of Steps

| # | Action | Command/Where |
|---|--------|---------------|
| 1 | Get Gateway IP | `kubectl get gateway -n travel-booking` |
| 2 | Add A record on GoDaddy | GoDaddy DNS → `@` → Gateway IP |
| 3 | Wait for DNS propagation | `dig vijaygiduthuri.in +short` |
| 4 | Update Gateway with domain + `from: All` | `kubectl apply -f` (Gateway YAML above) |
| 5 | Update all app HTTPRoutes with hostname | `kubectl apply -f` (6 HTTPRoutes above) |
| 6 | Apply Jenkins HealthCheckPolicy | `kubectl apply -f` (HealthCheckPolicy above) |
| 7 | Apply Jenkins HTTPRoute | `kubectl apply -f` (Jenkins HTTPRoute above) |
| 8 | Verify HTTP works | `curl http://vijaygiduthuri.in/` |
| 9 | Verify Jenkins works | `curl http://vijaygiduthuri.in/jenkins/login` |

---

## All Application URLs with Custom Domain

Once DNS is configured, you can access the application at:

### Website (Frontend)

| URL | Description |
|-----|-------------|
| `http://vijaygiduthuri.in/` | Home page (redirects to search) |
| `http://vijaygiduthuri.in/login` | Login page |
| `http://vijaygiduthuri.in/register` | Registration page |
| `http://vijaygiduthuri.in/search` | Search flights and hotels |
| `http://vijaygiduthuri.in/booking-summary` | Booking review page |
| `http://vijaygiduthuri.in/payment` | Payment page |
| `http://vijaygiduthuri.in/my-trips` | View all bookings |

### Jenkins (CI/CD)

| URL | Description |
|-----|-------------|
| `http://vijaygiduthuri.in/jenkins/` | Jenkins dashboard |
| `http://vijaygiduthuri.in/jenkins/login` | Jenkins login page |
| `http://vijaygiduthuri.in/jenkins/blue` | Blue Ocean pipeline UI |

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
