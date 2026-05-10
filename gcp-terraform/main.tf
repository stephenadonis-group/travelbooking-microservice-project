# ─── VPC & Subnet ─────────────────────────────────────────────────────────────

module "vpc" {
  source      = "./modules/vpc"
  vpc-name    = var.vpc-name
  subnet-name = var.subnet-name
  region      = var.region
  vpc-cidr    = var.vpc-cidr
}

# ─── Firewall Rules ───────────────────────────────────────────────────────────

module "firewall" {
  source   = "./modules/firewall"
  vpc-name = module.vpc.vpc_name
}

# ─── GKE Cluster & Node Pool ─────────────────────────────────────────────────

module "gke" {
  source            = "./modules/gke"
  project-id        = var.project-id
  cluster-name      = var.cluster-name
  cluster-zone      = var.cluster-zone
  cluster-version   = var.cluster-version
  vpc-id            = module.vpc.vpc_id
  subnet-id         = module.vpc.subnet_id
  pool-name         = var.pool-name
  node-image-type   = var.node-image-type
  node-disk-type    = var.node-disk-type
  node-disk-size    = var.node-disk-size
  node-machine-type = var.node-machine-type
  node-count        = var.node-count
  min-node-count    = var.min-node-count
  max-node-count    = var.max-node-count
}

# ─── Artifact Registry ────────────────────────────────────────────────────────

module "artifact-registry" {
  source     = "./modules/artifact-registry"
  name       = var.artifact-registry-name
  region     = var.region
  project-id = var.project-id
}

# ─── Static IP ────────────────────────────────────────────────────────────────

module "static-ip" {
  source     = "./modules/static-ip"
  name       = var.static-ip-name
  project-id = var.project-id
}
