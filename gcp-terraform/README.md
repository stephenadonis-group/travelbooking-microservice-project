# TravelBooking — GCP Terraform Infrastructure

This folder contains **Terraform scripts** to create all the Google Cloud infrastructure needed to deploy the TravelBooking application.

---

## What is Terraform?

Terraform is an **Infrastructure as Code (IaC)** tool. Instead of manually clicking buttons in the Google Cloud Console to create VPCs, clusters, and firewalls, you write simple configuration files that describe what you want. Terraform then creates, updates, or destroys those resources for you.

**Key benefits:**
- **Repeatable** — Run the same scripts to create identical infrastructure every time
- **Version controlled** — Infrastructure changes are tracked in Git, just like code
- **Automated** — One command creates everything, another destroys everything
- **Modular** — Each resource type is a separate, reusable module

---

## What GCP Resources Will This Create?

| # | Resource | Name | Description |
|---|----------|------|-------------|
| 1 | **VPC Network** | `travelbooking-vpc` | Private virtual network that isolates your resources |
| 2 | **Subnet** | `travelbooking-subnet` | IP range (`10.0.0.0/16`) within the VPC for your GKE nodes |
| 3 | **Firewall: SSH** | `travelbooking-allow-ssh` | Allows SSH access (port 22) from anywhere |
| 4 | **Firewall: HTTP/HTTPS** | `travelbooking-allow-http-https` | Allows web traffic (ports 80, 443) from the internet |
| 5 | **Firewall: Internal** | `travelbooking-allow-internal` | Allows all traffic between resources within the VPC |
| 6 | **Firewall: Health Checks** | `travelbooking-allow-health-checks` | Allows GCP load balancer health checks to reach pods |
| 7 | **GKE Cluster** | `travelbooking-gke` | Kubernetes cluster with Gateway API enabled |
| 8 | **GKE Node Pool** | `travelbooking-nodepool` | Worker nodes (e2-medium) with autoscaling: min 2, max 5 |
| 9 | **Artifact Registry** | `travel-booking` | Docker image repository for all microservice images |
| 10 | **Static IP** | `travel-booking-ip` | Global static IP for the Gateway load balancer |

---

## Folder Structure

```
gcp-terraform/
├── README.md               # This file
├── provider.tf             # Terraform & GCP provider configuration + GCS backend
├── variables.tf            # All variable declarations
├── terraform.tfvars        # Variable values (YOU EDIT THIS FILE)
├── main.tf                 # Root module — calls all child modules
├── outputs.tf              # Values displayed after terraform apply
├── keys.json               # Your GCP service account key (YOU ADD THIS FILE)
│
└── modules/                # Reusable infrastructure modules
    ├── vpc/                # VPC network + subnet
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── firewall/           # Firewall rules (SSH, HTTP, internal, health checks)
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── gke/                # GKE cluster + node pool with autoscaling + Gateway API
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── artifact-registry/  # Docker image repository
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── static-ip/          # Global static IP address
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

---

## Prerequisites

Before running Terraform, you need:

1. **Terraform installed** — [Download Terraform](https://developer.hashicorp.com/terraform/downloads)
   ```bash
   terraform --version   # should show v1.5+
   ```

2. **gcloud CLI installed** — [Install gcloud](https://cloud.google.com/sdk/docs/install)
   ```bash
   gcloud --version
   ```

3. **A GCP project** with billing enabled

4. **A GCP service account** with these roles:
   - `Compute Admin`
   - `Kubernetes Engine Admin`
   - `Artifact Registry Admin`
   - `Service Account User`

5. **Enable these GCP APIs** (run once):
   ```bash
   gcloud services enable compute.googleapis.com
   gcloud services enable container.googleapis.com
   gcloud services enable artifactregistry.googleapis.com
   ```

---

## What You Need to Change Before Running

### Step 1: Create a GCS Bucket for Terraform State

Terraform needs a place to store its state file. Create a Cloud Storage bucket:

```bash
gsutil mb -l us-central1 gs://YOUR-UNIQUE-BUCKET-NAME
```

Then open **`provider.tf`** and replace:
```hcl
bucket = "REPLACE_WITH_YOUR_BUCKET_NAME"
```
with your bucket name:
```hcl
bucket = "YOUR-UNIQUE-BUCKET-NAME"
```

### Step 2: Add Your Service Account Key

Copy your GCP service account JSON key to this folder and name it `keys.json`:

```bash
cp /path/to/your/service-account.json ./keys.json
```

### Step 3: Update `terraform.tfvars`

Open **`terraform.tfvars`** and update these values:

```hcl
# REQUIRED — Change these
project-id       = "your-gcp-project-id"      # Your actual GCP project ID
region           = "us-central1"               # Your preferred region
credentials-file = "./keys.json"               # Path to your service account key

# OPTIONAL — Change if you want different names/sizes
cluster-zone      = "us-central1-a"            # Zone for the GKE cluster
node-machine-type = "e2-medium"                # Node size (e2-small, e2-medium, etc.)
min-node-count    = 2                          # Minimum autoscaler nodes
max-node-count    = 5                          # Maximum autoscaler nodes
```

### Summary of Changes

| File | What to Change | Required? |
|------|---------------|-----------|
| `provider.tf` | GCS bucket name for Terraform state | Yes |
| `terraform.tfvars` | GCP project ID | Yes |
| `terraform.tfvars` | Region (if not `us-central1`) | Optional |
| `terraform.tfvars` | Machine type, node counts, etc. | Optional |
| `keys.json` | Add your service account JSON key file | Yes |

---

## How to Run

### 1. Initialize Terraform

This downloads the required providers and sets up the GCS backend:

```bash
cd gcp-terraform
terraform init
```

**What it does:** Downloads the Google provider plugin and connects to your GCS bucket for state storage.

### 2. Preview the Changes

See what resources Terraform will create without actually creating them:

```bash
terraform plan
```

**What it does:** Shows a list of all 10 resources that will be created. Review this to make sure everything looks correct.

### 3. Create All Resources

Apply the configuration to create everything on GCP:

```bash
terraform apply
```

Terraform will show the plan and ask for confirmation. Type `yes` to proceed.

**What it does:** Creates the VPC, subnet, firewalls, GKE cluster, Artifact Registry, and static IP in your GCP project. This takes approximately **10-15 minutes** (GKE cluster creation is the slowest part).

### 4. Connect to the GKE Cluster

After `terraform apply` completes, connect kubectl to the new cluster:

```bash
# Terraform outputs this command for you
gcloud container clusters get-credentials travelbooking-gke --zone us-central1-a --project YOUR_PROJECT_ID
```

### 5. Verify Everything

```bash
# Check cluster is running
kubectl get nodes

# Check Artifact Registry
gcloud artifacts repositories list --location=us-central1

# Check static IP
gcloud compute addresses list --global
```

---

## How to Destroy Everything

To delete all resources created by Terraform:

```bash
terraform destroy
```

Type `yes` to confirm. This will delete:
- The GKE cluster and all its nodes
- The VPC, subnet, and firewall rules
- The Artifact Registry (and all images inside it)
- The static IP address

---

## Useful Terraform Commands

| Command | What It Does |
|---------|-------------|
| `terraform init` | Initialize Terraform and download providers |
| `terraform plan` | Preview what will be created/changed/destroyed |
| `terraform apply` | Create or update all resources |
| `terraform destroy` | Delete all resources |
| `terraform output` | Show output values (cluster name, IP, etc.) |
| `terraform state list` | List all resources Terraform is managing |
| `terraform fmt` | Auto-format all `.tf` files |
| `terraform validate` | Check for syntax errors |

---

## After Terraform — Next Steps

Once the infrastructure is created, deploy the TravelBooking application:

1. **Build and push Docker images** to Artifact Registry:
   ```bash
   gcloud builds submit --tag us-central1-docker.pkg.dev/YOUR_PROJECT/travel-booking/frontend:latest ./frontend
   gcloud builds submit --tag us-central1-docker.pkg.dev/YOUR_PROJECT/travel-booking/user-service:latest ./user-service
   # ... repeat for all services
   ```

2. **Deploy the Helm chart**:
   ```bash
   kubectl create namespace travel-booking
   helm install travel-booking ./helm/travel-booking -n travel-booking
   ```

3. **Access the application** via the static IP:
   ```bash
   terraform output static_ip_address
   ```
