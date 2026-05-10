# ─── Project ──────────────────────────────────────────────────────────────────

output "project_id" {
  value       = var.project-id
  description = "GCP Project ID"
}

output "region" {
  value       = var.region
  description = "GCP Region"
}

# ─── VPC & Subnet ─────────────────────────────────────────────────────────────

output "vpc_name" {
  value       = module.vpc.vpc_name
  description = "VPC network name"
}

output "vpc_self_link" {
  value       = module.vpc.vpc_self_link
  description = "VPC self link"
}

output "subnet_name" {
  value       = module.vpc.subnet_name
  description = "Subnet name"
}

output "subnet_self_link" {
  value       = module.vpc.subnet_self_link
  description = "Subnet self link"
}

# ─── GKE ──────────────────────────────────────────────────────────────────────

output "gke_cluster_name" {
  value       = module.gke.cluster_name
  description = "GKE cluster name"
}

output "gke_cluster_endpoint" {
  value       = module.gke.cluster_endpoint
  description = "GKE cluster API endpoint"
  sensitive   = true
}

output "gke_cluster_ca_certificate" {
  value       = module.gke.cluster_ca_certificate
  description = "GKE cluster CA certificate"
  sensitive   = true
}

output "gke_connect_command" {
  value       = "gcloud container clusters get-credentials ${module.gke.cluster_name} --zone ${var.cluster-zone} --project ${var.project-id}"
  description = "Command to connect kubectl to the GKE cluster"
}

# ─── Artifact Registry ────────────────────────────────────────────────────────

output "artifact_registry_url" {
  value       = module.artifact-registry.repository_url
  description = "Artifact Registry Docker repository URL"
}

# ─── Static IP ────────────────────────────────────────────────────────────────

output "static_ip_address" {
  value       = module.static-ip.ip_address
  description = "Global static IP address for the Gateway"
}
