# ─── GCP Project Settings ─────────────────────────────────────────────────────

variable "project-id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for all resources"
  type        = string
}

variable "credentials-file" {
  description = "Path to the GCP service account JSON key file"
  type        = string
}

# ─── VPC & Subnet ─────────────────────────────────────────────────────────────

variable "vpc-name" {
  description = "Name of the VPC network"
  type        = string
}

variable "vpc-cidr" {
  description = "CIDR range for the subnet"
  type        = string
}

variable "subnet-name" {
  description = "Name of the subnet"
  type        = string
}

# ─── GKE Cluster ──────────────────────────────────────────────────────────────

variable "cluster-name" {
  description = "Name of the GKE cluster"
  type        = string
}

variable "cluster-zone" {
  description = "Zone for the GKE cluster (zonal cluster)"
  type        = string
}

variable "cluster-version" {
  description = "Kubernetes version for the GKE cluster"
  type        = string
}

# ─── GKE Node Pool ────────────────────────────────────────────────────────────

variable "pool-name" {
  description = "Name of the GKE node pool"
  type        = string
}

variable "node-image-type" {
  description = "OS image type for nodes"
  type        = string
}

variable "node-disk-type" {
  description = "Disk type for nodes"
  type        = string
}

variable "node-disk-size" {
  description = "Disk size in GB for each node"
  type        = number
}

variable "node-machine-type" {
  description = "Machine type for nodes (e.g., e2-medium)"
  type        = string
}

variable "node-count" {
  description = "Initial number of nodes per zone"
  type        = number
}

variable "min-node-count" {
  description = "Minimum number of nodes for autoscaling"
  type        = number
}

variable "max-node-count" {
  description = "Maximum number of nodes for autoscaling"
  type        = number
}

# ─── Artifact Registry ────────────────────────────────────────────────────────

variable "artifact-registry-name" {
  description = "Name of the Artifact Registry repository"
  type        = string
}

# ─── Static IP ────────────────────────────────────────────────────────────────

variable "static-ip-name" {
  description = "Name of the global static IP address"
  type        = string
}
