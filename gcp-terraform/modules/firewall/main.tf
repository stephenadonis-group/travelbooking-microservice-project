# ─── Allow SSH ────────────────────────────────────────────────────────────────

resource "google_compute_firewall" "allow-ssh" {
  name    = "travelbooking-allow-ssh"
  network = var.vpc-name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  description   = "Allow SSH access to all instances in the VPC"
}

# ─── Allow HTTP & HTTPS ──────────────────────────────────────────────────────

resource "google_compute_firewall" "allow-http-https" {
  name    = "travelbooking-allow-http-https"
  network = var.vpc-name

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  description   = "Allow HTTP and HTTPS traffic from the internet"
}

# ─── Allow Internal Communication ─────────────────────────────────────────────

resource "google_compute_firewall" "allow-internal" {
  name    = "travelbooking-allow-internal"
  network = var.vpc-name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.0.0.0/16"]
  description   = "Allow all internal traffic within the VPC subnet"
}

# ─── Allow GKE Health Checks ─────────────────────────────────────────────────

resource "google_compute_firewall" "allow-health-checks" {
  name    = "travelbooking-allow-health-checks"
  network = var.vpc-name

  allow {
    protocol = "tcp"
  }

  # Google Cloud health check IP ranges
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  description   = "Allow GCP load balancer health checks to reach GKE pods"
}
