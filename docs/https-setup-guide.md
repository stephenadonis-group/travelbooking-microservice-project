# TravelBooking — HTTPS Setup Guide (AWS Certificate Manager + Amazon Route 53)

This guide explains how to configure HTTPS (SSL/TLS) for the **TravelBooking** application running on **Amazon EKS** using **AWS Certificate Manager (ACM)**, **Amazon Route 53**, and the **AWS Load Balancer Controller**.

---

# What is HTTPS and Why Do We Need It?

HTTPS encrypts all communication between your users and your application.

Without HTTPS:

* Browsers display **Not Secure**
* Passwords and sensitive data are transmitted in plain text
* API requests are unencrypted
* Search engines rank HTTP websites lower

## Our AWS HTTPS Architecture

The TravelBooking application uses:

* **Amazon Route 53** for DNS management
* **AWS Certificate Manager (ACM)** for SSL/TLS certificates
* **AWS Load Balancer Controller** to provision an Application Load Balancer
* **Application Load Balancer (ALB)** for SSL termination

The ALB terminates HTTPS traffic and forwards normal HTTP traffic securely to the Kubernetes services running inside the EKS cluster.

```text
Browser
      │ HTTPS
      ▼
Application Load Balancer (ACM Certificate)
      │ HTTP
      ▼
Kubernetes Ingress
      │
      ▼
TravelBooking Services
```

---

# Prerequisites

Before starting, make sure:

* Amazon EKS cluster is running.
* AWS Load Balancer Controller is installed.
* Amazon Route 53 Hosted Zone is configured.
* Your domain name points to the Application Load Balancer.
* kubectl is connected to your EKS cluster.

Verify:

```bash
kubectl get nodes

kubectl get ingress -A

kubectl get pods -n kube-system
```

---

# Step 1: Request an ACM Certificate

Open the AWS Console.

Navigate to:

```
AWS Certificate Manager
```

Click:

```
Request Certificate
```

Choose:

```
Request a Public Certificate
```

Enter your domain names.

Example:

```
steveops.site

*.steveops.site
```

Select:

```
DNS Validation
```

Click:

```
Request
```

---

# Step 2: Validate the Certificate Using Route 53

After requesting the certificate, ACM generates DNS validation records.

If your domain is hosted in Amazon Route 53:

Click:

```
Create records in Route 53
```

AWS automatically creates the required validation records.

Wait several minutes until the certificate status changes to:

```
Issued
```

---

# Step 3: Configure Route 53 DNS Records

Create Alias records pointing to your Application Load Balancer.

Example:

| Record                     | Type      | Target                    |
| -------------------------- | --------- | ------------------------- |
| steveops.site              | A (Alias) | Application Load Balancer |
| prometheus.steveops.site   | A (Alias) | Application Load Balancer |
| alertmanager.steveops.site | A (Alias) | Application Load Balancer |

Once DNS propagation completes, your domain will resolve to the Application Load Balancer.

---

# Step 4: Configure Kubernetes Ingress

Update your Kubernetes Ingress to use the ACM certificate.

Example annotation:

```yaml
alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-east-1:123456789012:certificate/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

Enable both HTTP and HTTPS listeners:

```yaml
alb.ingress.kubernetes.io/listen-ports: |
  [{"HTTP":80},{"HTTPS":443}]

alb.ingress.kubernetes.io/ssl-redirect: "443"
```

Specify the ALB ingress class:

```yaml
spec:
  ingressClassName: alb
```

Apply the updated Ingress:

```bash
kubectl apply -f monitoring-ingress.yaml
```

---

# Step 5: Verify the Ingress

Check that the Application Load Balancer has been created.

```bash
kubectl get ingress -A

kubectl describe ingress monitoring-ingress
```

Expected output:

```
ADDRESS

xxxxxxxx.us-east-1.elb.amazonaws.com
```

---

# Step 6: Verify HTTPS

Verify that HTTPS is working correctly.

Frontend

```bash
curl -I https://steveops.site
```

Grafana

```bash
curl -I https://steveops.site/grafana
```

Prometheus

```bash
curl -I https://prometheus.steveops.site
```

Alertmanager

```bash
curl -I https://alertmanager.steveops.site
```

Expected response:

```
HTTP/2 200
```

or

```
HTTP/2 302
```

A **302** response from Grafana is expected because it redirects users to the login page.

---

# Automatic Certificate Renewal

Unlike Let's Encrypt, ACM automatically renews certificates before they expire.

No manual renewal is required.

AWS manages the entire certificate lifecycle automatically.

---

# Complete Installation — All Steps

```bash
# ─── Step 1: Request ACM Certificate ──────────────────────────────────────
AWS Console → Certificate Manager → Request Public Certificate

# ─── Step 2: Validate Domain ───────────────────────────────────────────────
Create Route53 DNS validation records

# ─── Step 3: Wait Until Certificate Is Issued ──────────────────────────────

# ─── Step 4: Apply Kubernetes Ingress ──────────────────────────────────────
kubectl apply -f monitoring-ingress.yaml

# ─── Step 5: Verify Ingress ────────────────────────────────────────────────
kubectl get ingress

# ─── Step 6: Verify HTTPS ──────────────────────────────────────────────────
curl -I https://steveops.site

curl -I https://prometheus.steveops.site

curl -I https://alertmanager.steveops.site
```

---

# Troubleshooting

## Certificate Status Remains Pending Validation

Verify that the Route 53 validation CNAME records exist.

Navigate to:

```
AWS Console

↓

Certificate Manager

↓

Certificate

↓

Validation
```

The DNS validation records must exactly match those generated by ACM.

---

## HTTPS Is Not Working

Describe the Kubernetes Ingress.

```bash
kubectl describe ingress monitoring-ingress
```

Verify the annotation:

```
alb.ingress.kubernetes.io/certificate-arn
```

Ensure the ARN matches your ACM certificate.

---

## Domain Does Not Resolve

Verify your Route 53 records.

```bash
nslookup steveops.site

nslookup prometheus.steveops.site

nslookup alertmanager.steveops.site
```

---

## Application Load Balancer Was Not Created

Verify the AWS Load Balancer Controller.

```bash
kubectl get pods -n kube-system

kubectl logs deployment/aws-load-balancer-controller -n kube-system
```

---

# Quick Reference

| Resource          | Command                                                |
| ----------------- | ------------------------------------------------------ |
| Check Ingress     | `kubectl get ingress -A`                               |
| Describe Ingress  | `kubectl describe ingress monitoring-ingress`          |
| Check ALB Address | `kubectl get ingress monitoring-ingress -n monitoring` |
| Verify DNS        | `nslookup steveops.site`                               |
| Test HTTPS        | `curl -I https://steveops.site`                        |
| Test Grafana      | `curl -I https://steveops.site/grafana`                |
| Test Prometheus   | `curl -I https://prometheus.steveops.site`             |
| Test Alertmanager | `curl -I https://alertmanager.steveops.site`           |

| Component              | Service                             |
| ---------------------- | ----------------------------------- |
| DNS                    | Amazon Route 53                     |
| SSL Certificates       | AWS Certificate Manager (ACM)       |
| Load Balancer          | AWS Application Load Balancer (ALB) |
| SSL Termination        | Application Load Balancer           |
| Certificate Renewal    | Automatic by ACM                    |
| Kubernetes Integration | AWS Load Balancer Controller        |
