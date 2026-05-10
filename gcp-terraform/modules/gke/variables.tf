variable "project-id" {
  description = "GCP project ID"
  type        = string
}

variable "cluster-name" {
  description = "Name of the GKE cluster"
  type        = string
}

variable "cluster-zone" {
  description = "Zone for the GKE cluster"
  type        = string
}

variable "cluster-version" {
  description = "Kubernetes version"
  type        = string
}

variable "vpc-id" {
  description = "VPC network ID"
  type        = string
}

variable "subnet-id" {
  description = "Subnet ID"
  type        = string
}

variable "pool-name" {
  description = "Name of the node pool"
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
  description = "Machine type for nodes"
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
