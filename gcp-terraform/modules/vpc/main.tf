# ─── VPC Network ──────────────────────────────────────────────────────────────

resource "google_compute_network" "vpc" {
  name                    = var.vpc-name
  auto_create_subnetworks = false
  description             = "Custom VPC for TravelBooking application"
}

# ─── Subnet ───────────────────────────────────────────────────────────────────

resource "google_compute_subnetwork" "subnet" {
  name          = var.subnet-name
  region        = var.region
  network       = google_compute_network.vpc.id
  ip_cidr_range = var.vpc-cidr
  description   = "Subnet for TravelBooking GKE cluster"
}
