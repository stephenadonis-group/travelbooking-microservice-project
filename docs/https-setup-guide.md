# TravelBooking — HTTPS Setup Guide (cert-manager + Let's Encrypt)

This guide explains how to set up HTTPS (SSL/TLS) for the TravelBooking application using **cert-manager** and **Let's Encrypt** on GKE.

---

## What is HTTPS and Why Do We Need It?

HTTPS encrypts all traffic between the user's browser and your server. Without it:
- Passwords and credit card details are sent in plain text
- Browsers show "Not Secure" warning
- Search engines rank HTTP sites lower

**Our setup:**
- **cert-manager** — Kubernetes add-on that automatically manages TLS certificates
- **Let's Encrypt** — Free certificate authority that issues trusted SSL certificates
- **How it works:** cert-manager requests a certificate from Let's Encrypt, proves you own the domain via HTTP challenge, gets the certificate, and stores it as a Kubernetes Secret. The Gateway uses this Secret to serve HTTPS.

```
Browser (https://vijaygiduthuri.in)
    │
    ▼ (TLS encrypted)
┌──────────────────────────┐
│  GKE Gateway             │
│  - Terminates TLS        │
│  - Uses Let's Encrypt    │
│    certificate           │
└──────────┬───────────────┘
           │ (plain HTTP inside cluster)
           ▼
    Application Pods
```

---

## Prerequisites

Before starting, make sure:

1. **TravelBooking app is deployed** on GKE with the Gateway running
2. **DNS is configured** — your domain points to the Gateway static IP
3. **Gateway has `allowedRoutes.namespaces.from: All`** set
4. **HTTP access works** — `http://vijaygiduthuri.in` loads the application
5. **Helm is installed** on your local machine

---

## Step 1: Install cert-manager

```bash
# Add Helm repo
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Create namespace
kubectl create namespace cert-manager

# Install cert-manager with Gateway API support enabled
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --set crds.enabled=true \
  --set config.apiVersion="controller.config.cert-manager.io/v1alpha1" \
  --set config.kind="ControllerConfiguration" \
  --set config.enableGatewayAPI=true \
  --wait --timeout 3m
```

**What this does:**
- Installs cert-manager (3 pods: controller, webhook, cainjector)
- `crds.enabled=true` — installs the Certificate, Issuer, ClusterIssuer CRDs
- `enableGatewayAPI=true` — enables cert-manager to work with Gateway API (creates HTTPRoutes for HTTP01 challenges)

**Verify:**
```bash
kubectl get pods -n cert-manager
# All 3 pods should be Running
```

---

## Step 2: Create Let's Encrypt ClusterIssuer

The ClusterIssuer tells cert-manager how to request certificates from Let's Encrypt.

```bash
kubectl apply -f - <<'EOF'
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: vijaygiduthuri@gmail.com
    privateKeySecretRef:
      name: letsencrypt-prod-key
    solvers:
    - http01:
        gatewayHTTPRoute:
          parentRefs:
          - name: travel-booking-gateway
            namespace: travel-booking
            kind: Gateway
EOF
```

> **Note:** Update the `email` field with your email address. Let's Encrypt uses this to send certificate expiry warnings.

**What this does:**
- Creates a ClusterIssuer named `letsencrypt-prod`
- Uses Let's Encrypt **production** server (trusted by all browsers)
- Uses **HTTP01 challenge** — cert-manager creates a temporary HTTPRoute to prove domain ownership
- The challenge route attaches to your existing Gateway

**Verify:**
```bash
kubectl get clusterissuer letsencrypt-prod
# READY should be True
```

---

## Step 3: Create Certificate

Request a TLS certificate for your domain.

```bash
kubectl apply -f - <<'EOF'
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: travel-booking-tls
  namespace: travel-booking
spec:
  secretName: travel-booking-tls-secret
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - vijaygiduthuri.in
EOF
```

**What happens after you apply this:**

1. cert-manager creates a CertificateRequest
2. It creates an HTTP01 challenge — a temporary pod + service + HTTPRoute
3. Let's Encrypt sends a request to `http://vijaygiduthuri.in/.well-known/acme-challenge/xxxxx`
4. The temporary HTTPRoute routes this to the solver pod which responds with the challenge token
5. Let's Encrypt verifies the response and issues the certificate
6. cert-manager stores the certificate in a Kubernetes Secret called `travel-booking-tls-secret`
7. The temporary challenge resources are cleaned up automatically

**Monitor progress:**
```bash
# Check certificate status
kubectl get certificate -n travel-booking
# READY should change from False to True (takes 2-5 minutes)

# Check challenge progress
kubectl get challenges -A
# State should go from "pending" to disappearing (means it passed)

# Check if TLS secret was created
kubectl get secret travel-booking-tls-secret -n travel-booking
# TYPE should be kubernetes.io/tls
```

> **Note:** The HTTP01 challenge requires the GCP load balancer to program a new backend route. This can take **3-5 minutes**. Be patient — don't delete and recreate if it's still pending.

---

## Step 4: Update Gateway with HTTPS Listener

Once the certificate is ready (`READY: True`), add an HTTPS listener to the Gateway.

```bash
kubectl apply -f - <<'EOF'
apiVersion: gateway.networking.k8s.io/v1beta1
kind: Gateway
metadata:
  name: travel-booking-gateway
  namespace: travel-booking
spec:
  gatewayClassName: gke-l7-global-external-managed
  addresses:
  - type: NamedAddress
    value: travel-booking-ip
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    hostname: vijaygiduthuri.in
    allowedRoutes:
      namespaces:
        from: All
  - name: https
    port: 443
    protocol: HTTPS
    hostname: vijaygiduthuri.in
    tls:
      mode: Terminate
      certificateRefs:
      - name: travel-booking-tls-secret
        namespace: travel-booking
    allowedRoutes:
      namespaces:
        from: All
EOF
```

**What this does:**
- Keeps the existing HTTP listener (port 80)
- Adds a new HTTPS listener (port 443) with TLS termination
- References the `travel-booking-tls-secret` created by cert-manager
- Both listeners have `hostname` set to your domain
- Both listeners allow routes from all namespaces

---

## Step 5: HTTP → HTTPS Redirect (Optional)

After HTTPS is working, you can redirect all HTTP traffic to HTTPS automatically. This means if a user visits `http://vijaygiduthuri.in`, they are automatically redirected to `https://vijaygiduthuri.in`.

Create an HTTPRoute with a redirect filter:

```bash
kubectl apply -f - <<'EOF'
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: http-to-https-redirect
  namespace: travel-booking
spec:
  parentRefs:
  - name: travel-booking-gateway
    namespace: travel-booking
    sectionName: http
  hostnames:
  - vijaygiduthuri.in
  rules:
  - filters:
    - type: RequestRedirect
      requestRedirect:
        scheme: https
        statusCode: 301
EOF
```

**What this does:**
- `sectionName: http` — this route only attaches to the HTTP listener (port 80), not HTTPS
- `RequestRedirect` filter — redirects every HTTP request to HTTPS
- `statusCode: 301` — permanent redirect (browsers cache this, good for SEO)
- After applying, `http://vijaygiduthuri.in/search` automatically becomes `https://vijaygiduthuri.in/search`

**Verify:**
```bash
# Test HTTP redirect (should return 301 with Location header pointing to HTTPS)
curl -s -o /dev/null -w "HTTP %{http_code}\n" http://vijaygiduthuri.in/
# Expected: HTTP 301

# Check the redirect location
curl -sI http://vijaygiduthuri.in/ | grep -i location
# Expected: location: https://vijaygiduthuri.in/
```

> **Note:** After applying this redirect, all HTTP traffic goes to HTTPS. The only exception is the `/.well-known/acme-challenge/` path used by cert-manager for certificate renewal — cert-manager creates its own temporary HTTPRoute with higher priority during renewal, so auto-renewal still works.

---

## Step 6: Verify HTTPS

> **Note:** All HTTPRoutes must have `hostnames` set for HTTPS to work. If you followed the **gateway-api-dns-guide.md** (Step 5b), this is already done — no action needed here.

Wait **3-5 minutes** for the GCP load balancer to program the HTTPS listener, then test:

```bash
# Test HTTPS
curl -sk -o /dev/null -w "HTTPS Frontend: %{http_code}\n" https://vijaygiduthuri.in/
curl -sk -o /dev/null -w "HTTPS API:      %{http_code}\n" "https://vijaygiduthuri.in/api/search/flights?from=NYC&to=LAX"
curl -sk -o /dev/null -w "HTTPS Jenkins:  %{http_code}\n" https://vijaygiduthuri.in/jenkins/login
curl -sk -o /dev/null -w "HTTPS Grafana:  %{http_code}\n" https://vijaygiduthuri.in/grafana/

# Check TLS certificate details
curl -svk https://vijaygiduthuri.in/ 2>&1 | grep -E "subject:|issuer:|expire"
# Expected:
# subject: CN=vijaygiduthuri.in
# issuer: C=US; O=Let's Encrypt; CN=R13
# expire date: <3 months from now>
```

Open in browser: **`https://vijaygiduthuri.in`** — you should see the padlock icon.

---

## Certificate Auto-Renewal

Let's Encrypt certificates expire after **90 days**. cert-manager automatically renews them **30 days before expiry** — no manual action needed.

Check renewal status:
```bash
kubectl get certificate -n travel-booking
# READY: True means the certificate is valid
# The certificate will auto-renew when it's within 30 days of expiry
```

---

## Complete Installation — All Commands in Order

```bash
# ─── Step 1: Install cert-manager ─────────────────────────────────────────────
helm repo add jetstack https://charts.jetstack.io
helm repo update

kubectl create namespace cert-manager

helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --set crds.enabled=true \
  --set config.apiVersion="controller.config.cert-manager.io/v1alpha1" \
  --set config.kind="ControllerConfiguration" \
  --set config.enableGatewayAPI=true \
  --wait --timeout 3m

# ─── Step 2: Create ClusterIssuer ──────────────────────────────────────────────
# Update the email field with your email address
kubectl apply -f https-clusterissuer.yaml

# ─── Step 3: Create Certificate ───────────────────────────────────────────────
# Replace vijaygiduthuri.in with your domain
kubectl apply -f https-certificate.yaml

# Wait for certificate to be ready (2-5 minutes)
kubectl get certificate -n travel-booking -w

# ─── Step 4: Update Gateway with HTTPS ─────────────────────────────────────────
kubectl apply -f https-gateway.yaml

# ─── Step 5: HTTP → HTTPS Redirect (Optional) ─────────────────────────────────
kubectl apply -f https-redirect.yaml

# ─── Step 6: Verify ───────────────────────────────────────────────────────────
# Note: HTTPRoutes must have hostnames set (already done in gateway-api-dns-guide.md)
curl -sk https://vijaygiduthuri.in/
curl -s -o /dev/null -w "%{http_code}" http://vijaygiduthuri.in/   # Should return 301
```

---

## How to Uninstall

```bash
# Delete certificate and secret
kubectl delete certificate travel-booking-tls -n travel-booking
kubectl delete secret travel-booking-tls-secret -n travel-booking

# Delete ClusterIssuer
kubectl delete clusterissuer letsencrypt-prod

# Uninstall cert-manager
helm uninstall cert-manager -n cert-manager
kubectl delete namespace cert-manager
```

---

## Troubleshooting

### Certificate stuck at READY: False

Check the challenge status:
```bash
kubectl describe certificate travel-booking-tls -n travel-booking
kubectl get challenges -A
kubectl describe challenge -n travel-booking
```

Common causes:
- **DNS not pointing to Gateway IP** — verify with `dig vijaygiduthuri.in +short`
- **Gateway API not enabled in cert-manager** — check `enableGatewayAPI=true` is set
- **GCP LB slow to program** — wait 5 minutes for the challenge HTTPRoute to work

### "gateway api is not enabled" error

cert-manager needs Gateway API support enabled:
```bash
helm upgrade cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --set crds.enabled=true \
  --set config.apiVersion="controller.config.cert-manager.io/v1alpha1" \
  --set config.kind="ControllerConfiguration" \
  --set config.enableGatewayAPI=true \
  --wait
```

### HTTPS returns 404 but HTTP works

All HTTPRoutes must have `hostnames` set when using HTTPS. Routes without hostnames won't match the HTTPS listener. See Step 5.

### Browser shows "Not Secure" despite HTTPS

The certificate might still be provisioning. Check:
```bash
kubectl get certificate -n travel-booking
```
Wait until READY is True.

### Certificate expired

cert-manager should auto-renew. If it didn't:
```bash
# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Force renewal by deleting the secret
kubectl delete secret travel-booking-tls-secret -n travel-booking
# cert-manager will automatically request a new certificate
```

---

## Quick Reference

| Resource | Command |
|----------|---------|
| Check certificate | `kubectl get certificate -n travel-booking` |
| Check challenges | `kubectl get challenges -A` |
| Check ClusterIssuer | `kubectl get clusterissuer` |
| Check TLS secret | `kubectl get secret travel-booking-tls-secret -n travel-booking` |
| cert-manager logs | `kubectl logs -n cert-manager deployment/cert-manager` |
| Force renewal | `kubectl delete secret travel-booking-tls-secret -n travel-booking` |

| Info | Value |
|------|-------|
| Certificate Authority | Let's Encrypt |
| Certificate Validity | 90 days |
| Auto-Renewal | 30 days before expiry |
| Challenge Type | HTTP01 via Gateway API |
