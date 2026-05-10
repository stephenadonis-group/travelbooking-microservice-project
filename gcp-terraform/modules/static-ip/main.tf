# ─── Global Static IP Address ─────────────────────────────────────────────────
# Used by the GKE Gateway (external load balancer) as the entry point

resource "google_compute_global_address" "static-ip" {
  name        = var.name
  project     = var.project-id
  description = "Global static IP for TravelBooking Gateway load balancer"
}
