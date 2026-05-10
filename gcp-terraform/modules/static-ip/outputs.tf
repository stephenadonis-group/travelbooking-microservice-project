output "ip_address" {
  value       = google_compute_global_address.static-ip.address
  description = "The allocated static IP address"
}

output "ip_name" {
  value       = google_compute_global_address.static-ip.name
  description = "Name of the static IP resource"
}
