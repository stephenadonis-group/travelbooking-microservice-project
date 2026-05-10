# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║  IMPORTANT: Update these values before running terraform apply              ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝

# ─── GCP Project Settings ─────────────────────────────────────────────────────
project-id       = "test-project-492810"   # <-- Your GCP project ID
region           = "us-central1"                     # <-- Your preferred region
credentials-file = "./keys.json"                     # <-- Path to your service account JSON key

# ─── VPC & Subnet ─────────────────────────────────────────────────────────────
vpc-name    = "travelbooking-vpc"
subnet-name = "travelbooking-subnet"
vpc-cidr    = "10.0.0.0/16"

# ─── GKE Cluster ──────────────────────────────────────────────────────────────
cluster-name    = "travelbooking-gke"
cluster-zone    = "us-central1-a"
cluster-version = "1.31"

# ─── GKE Node Pool ────────────────────────────────────────────────────────────
pool-name         = "travelbooking-nodepool"
node-image-type   = "COS_CONTAINERD"
node-disk-type    = "pd-standard"
node-disk-size    = 50
node-machine-type = "e2-standard-2"
node-count        = 2
min-node-count    = 2
max-node-count    = 5

# ─── Artifact Registry ────────────────────────────────────────────────────────
artifact-registry-name = "travel-booking"

# ─── Static IP ────────────────────────────────────────────────────────────────
static-ip-name = "travel-booking-ip"
