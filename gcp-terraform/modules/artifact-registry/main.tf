# ─── Artifact Registry (Docker Repository) ────────────────────────────────────

resource "google_artifact_registry_repository" "docker" {
  repository_id = var.name
  location      = var.region
  project       = var.project-id
  format        = "DOCKER"
  description   = "Docker image registry for TravelBooking application services"
}
