# TravelBooking — Terraform Setup Guide

This guide explains how to create GCP resources for the TravelBooking application using Terraform.

> **Important:** We are **NOT** creating the GKE cluster using Terraform due to limited GCP free tier resources. The GKE cluster is created **manually** from the Google Cloud Console. All other resources (VPC, Subnet, Firewall rules, Artifact Registry, Static IP) are created using Terraform.

---

## What Terraform Will Create

| # | Resource | Name | Purpose |
|---|----------|------|---------|
| 1 | VPC Network | `travelbooking-vpc` | Private network for the application |
| 2 | Subnet | `travelbooking-subnet` | IP range `10.0.0.0/16` for the cluster |
| 3 | Firewall: SSH | `travelbooking-allow-ssh` | Allow SSH access (port 22) |
| 4 | Firewall: HTTP/HTTPS | `travelbooking-allow-http-https` | Allow web traffic (ports 80, 443) |
| 5 | Firewall: Internal | `travelbooking-allow-internal` | Allow all internal traffic within VPC |
| 6 | Firewall: Health Checks | `travelbooking-allow-health-checks` | Allow GCP load balancer health checks |
| 7 | Artifact Registry | `travel-booking` | Docker image storage |
| 8 | Static IP | `travel-booking-ip` | Global static IP for the Gateway |

**Total: 8 resources** created in **1-2 minutes**.

---

## What Will NOT Be Created (Manual Setup)

| Resource | How to Create |
|----------|---------------|
| **GKE Cluster** | Manually from Google Cloud Console |
| **Gateway API** | Enable manually after cluster creation |

---

## Prerequisites

Before running Terraform, make sure you have:

1. **Terraform installed** — `terraform --version` (should be 1.5+)
2. **gcloud CLI installed** — `gcloud --version`
3. **A GCP project** with billing enabled
4. **A GCS bucket** for Terraform state storage (create manually first)
5. **A GCP service account JSON key** with these roles:
   - Compute Admin
   - Artifact Registry Admin
   - Storage Admin
   - Service Account User

---

## Step 1: Update Configuration Files

### Update `terraform.tfvars`

Open the file and update these values with your own:

```hcl
project-id       = "<YOUR_PROJECT_ID>"   # Your GCP project ID
region           = "us-central1"          # Your preferred region
credentials-file = "./keys.json"          # Path to your service account JSON key
```

### Update `provider.tf`

Open the file and update the GCS bucket name where Terraform state will be stored:

```hcl
backend "gcs" {
  bucket = "<YOUR_GCS_BUCKET_NAME>"
  prefix = "terraform/state"
}
```

> **Note:** Create the GCS bucket manually before running Terraform:
> ```bash
> gsutil mb -l us-central1 gs://<YOUR_GCS_BUCKET_NAME>
> ```

### Place Your Service Account Key

Copy your GCP service account JSON key to the terraform directory and rename it to `keys.json`:

```bash
cp /path/to/your/service-account.json /home/vijay/Desktop/travelbooking_app/gcp-terraform/keys.json
```

---

## Step 2: Set Credentials Environment Variable

Before running any Terraform command, set this environment variable. Terraform's GCS backend (where state is stored) needs this to authenticate with your GCS bucket.

```bash
export GOOGLE_APPLICATION_CREDENTIALS=/home/vijay/Desktop/travelbooking_app/gcp-terraform/keys.json
```

> **Important:** This must be set in **every new terminal session** before running Terraform commands. Without this, you'll get an error: `storage.NewClient() failed: could not find default credentials`.

---

## Step 3: Initialize Terraform

Navigate to the terraform directory and initialize:

```bash
cd /home/vijay/Desktop/travelbooking_app/gcp-terraform
terraform init
```

**What this does:**
- Downloads the Google provider plugin
- Connects to your GCS bucket for state storage
- Initializes all the modules (vpc, firewall, gke, artifact-registry, static-ip)

You should see the message: `Terraform has been successfully initialized!`

---

## Step 4: Preview What Will Be Created

Before creating any resources, preview the plan:

```bash
terraform plan -target=module.vpc -target=module.firewall -target=module.artifact-registry -target=module.static-ip
```

**What this does:**
- Shows a list of 8 resources that will be created
- Does NOT actually create anything yet
- Lets you review and verify before applying

> **Why `-target` flags?** These flags tell Terraform to only work with specific modules. We exclude `module.gke` because we create the GKE cluster manually from the Google Cloud Console.

---

## Step 5: Create All Resources

Apply the configuration to create everything on GCP:

```bash
terraform apply -auto-approve -target=module.vpc -target=module.firewall -target=module.artifact-registry -target=module.static-ip
```

**What this does:**
- Creates VPC, Subnet, 4 Firewall rules, Artifact Registry, and Global Static IP
- Takes approximately **1-2 minutes**
- `-auto-approve` skips the confirmation prompt

After completion, you'll see outputs like:
```
artifact_registry_url = "us-central1-docker.pkg.dev/<PROJECT_ID>/travel-booking"
static_ip_address = "34.x.x.x"
vpc_name = "travelbooking-vpc"
subnet_name = "travelbooking-subnet"
```

> **Tip:** If you want to review and confirm manually, remove `-auto-approve` and type `yes` when prompted.

---

## Step 6: Verify Resources Were Created

Check the Terraform state to see all created resources:

```bash
terraform state list
```

Expected output:
```
module.artifact-registry.google_artifact_registry_repository.docker
module.firewall.google_compute_firewall.allow-health-checks
module.firewall.google_compute_firewall.allow-http-https
module.firewall.google_compute_firewall.allow-internal
module.firewall.google_compute_firewall.allow-ssh
module.static-ip.google_compute_global_address.static-ip
module.vpc.google_compute_network.vpc
module.vpc.google_compute_subnetwork.subnet
```

You can also verify in the Google Cloud Console:
- **VPC Networks** → Should see `travelbooking-vpc`
- **Firewall Rules** → Should see 4 `travelbooking-allow-*` rules
- **Artifact Registry** → Should see `travel-booking` repository
- **External IP Addresses** → Should see `travel-booking-ip` (global)

---

## Step 7: Create GKE Cluster Manually

Now that the network infrastructure is ready, create the GKE cluster manually:

1. Go to **Google Cloud Console** → **Kubernetes Engine** → **Clusters**
2. Click **Create**
3. Choose **Standard** cluster (not Autopilot)
4. **Cluster name:** any name (e.g., `test-cluster`)
5. **Location:** Zonal → `us-central1-a`
6. **Network settings:**
   - Network: `travelbooking-vpc` (created by Terraform)
   - Subnet: `travelbooking-subnet` (created by Terraform)
7. **Node pool settings:**
   - Machine type: `e2-standard-2` (recommended)
   - Disk size: `50 GB`
   - Number of nodes: `2`
   - Enable autoscaling: min `2`, max `5`
8. Click **Create** and wait ~5-10 minutes

After cluster creation, enable Gateway API:

```bash
gcloud container clusters update <CLUSTER_NAME> --gateway-api=standard --zone us-central1-a --project <PROJECT_ID>
```

Verify Gateway API is enabled:

```bash
kubectl get gatewayclasses
```

You should see `gke-l7-global-external-managed` in the list.

---

## How to Destroy All Resources

To delete all resources created by Terraform:

```bash
terraform destroy -auto-approve -target=module.vpc -target=module.firewall -target=module.artifact-registry -target=module.static-ip
```

> **Important:** Delete the GKE cluster **manually** first from Google Cloud Console before running this. Otherwise, the VPC deletion will fail because the GKE cluster is still using the network.

### Common Issue: VPC Deletion Fails

If destroy fails with "network is already being used", it means there are leftover firewall rules created by GKE Gateway. Delete them manually:

```bash
# List leftover firewall rules
gcloud compute firewall-rules list --project <PROJECT_ID> --filter="network:travelbooking-vpc" --format="value(name)"

# Delete each one
gcloud compute firewall-rules delete <RULE_NAME> --project <PROJECT_ID> --quiet
```

Then run `terraform destroy` again.

---

## Quick Reference

### Setup (First Time)

```bash
# 1. Set credentials
export GOOGLE_APPLICATION_CREDENTIALS=/home/vijay/Desktop/travelbooking_app/gcp-terraform/keys.json

# 2. Go to terraform directory
cd /home/vijay/Desktop/travelbooking_app/gcp-terraform

# 3. Initialize
terraform init

# 4. Plan
terraform plan -target=module.vpc -target=module.firewall -target=module.artifact-registry -target=module.static-ip

# 5. Apply
terraform apply -auto-approve -target=module.vpc -target=module.firewall -target=module.artifact-registry -target=module.static-ip
```

### Verify

```bash
terraform state list
```

### Destroy

```bash
terraform destroy -auto-approve -target=module.vpc -target=module.firewall -target=module.artifact-registry -target=module.static-ip
```

---

## Why This Approach?

| Aspect | Reason |
|--------|--------|
| **Why not create GKE with Terraform?** | GKE creation requires significant compute quota. Free tier accounts often hit quota limits. Manual creation gives more control over node configuration. |
| **Why use `-target` flags?** | To create only the network resources, not GKE. The GKE module exists in Terraform code but is skipped using these flags. |
| **Why GCS backend?** | To store Terraform state remotely so multiple team members can collaborate. Local state can be lost if the laptop crashes. |
| **Why separate static IP?** | The Gateway needs a permanent IP that doesn't change even if you redeploy. Creating it via Terraform ensures it's a global static IP (required by `gke-l7-global-external-managed`). |
