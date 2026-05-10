output "vpc_id" {
  value       = google_compute_network.vpc.id
  description = "VPC network ID"
}

output "vpc_name" {
  value       = google_compute_network.vpc.name
  description = "VPC network name"
}

output "vpc_self_link" {
  value       = google_compute_network.vpc.self_link
  description = "VPC self link"
}

output "subnet_id" {
  value       = google_compute_subnetwork.subnet.id
  description = "Subnet ID"
}

output "subnet_name" {
  value       = google_compute_subnetwork.subnet.name
  description = "Subnet name"
}

output "subnet_self_link" {
  value       = google_compute_subnetwork.subnet.self_link
  description = "Subnet self link"
}
