# ─── GKE Cluster ──────────────────────────────────────────────────────────────
# Uses google-beta provider to enable Gateway API on the cluster

resource "google_container_cluster" "cluster" {
  provider = google-beta

  project  = var.project-id
  name     = var.cluster-name
  location = var.cluster-zone

  network    = var.vpc-id
  subnetwork = var.subnet-id

  min_master_version  = var.cluster-version
  deletion_protection = false

  # We manage our own node pool — remove the default one
  remove_default_node_pool = true
  initial_node_count       = 1

  # Enable Gateway API on the cluster
  gateway_api_config {
    channel = "CHANNEL_STANDARD"
  }
}

# ─── GKE Node Pool ────────────────────────────────────────────────────────────

resource "google_container_node_pool" "nodepool" {
  name     = var.pool-name
  project  = google_container_cluster.cluster.project
  cluster  = google_container_cluster.cluster.name
  location = google_container_cluster.cluster.location

  node_count = var.node-count

  node_config {
    image_type   = var.node-image-type
    disk_size_gb = var.node-disk-size
    disk_type    = var.node-disk-type
    machine_type = var.node-machine-type

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }

  # Autoscaler: automatically scales nodes between min and max
  autoscaling {
    min_node_count = var.min-node-count
    max_node_count = var.max-node-count
  }

  # Auto repair crashed nodes, auto upgrade Kubernetes version
  management {
    auto_repair  = true
    auto_upgrade = true
  }
}
