output "repository_id" {
  value       = google_artifact_registry_repository.docker.repository_id
  description = "Artifact Registry repository ID"
}

output "repository_url" {
  value       = "${var.region}-docker.pkg.dev/${var.project-id}/${google_artifact_registry_repository.docker.repository_id}"
  description = "Full Docker repository URL for pushing images"
}
