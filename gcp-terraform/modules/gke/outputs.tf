output "cluster_name" {
  value       = google_container_cluster.cluster.name
  description = "GKE cluster name"
}

output "cluster_endpoint" {
  value       = google_container_cluster.cluster.endpoint
  description = "GKE cluster API endpoint"
}

output "cluster_ca_certificate" {
  value       = google_container_cluster.cluster.master_auth[0].cluster_ca_certificate
  description = "GKE cluster CA certificate (base64 encoded)"
}

output "cluster_location" {
  value       = google_container_cluster.cluster.location
  description = "GKE cluster zone"
}
