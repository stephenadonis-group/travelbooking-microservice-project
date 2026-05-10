output "ssh_firewall_name" {
  value       = google_compute_firewall.allow-ssh.name
  description = "SSH firewall rule name"
}

output "http_https_firewall_name" {
  value       = google_compute_firewall.allow-http-https.name
  description = "HTTP/HTTPS firewall rule name"
}

output "internal_firewall_name" {
  value       = google_compute_firewall.allow-internal.name
  description = "Internal traffic firewall rule name"
}

output "health_check_firewall_name" {
  value       = google_compute_firewall.allow-health-checks.name
  description = "Health check firewall rule name"
}
