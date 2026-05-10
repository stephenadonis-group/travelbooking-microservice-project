terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.21.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.21.0"
    }
  }

  # ─── Remote State in GCS ──────────────────────────────────────────────────────
  # IMPORTANT: Create this bucket manually before running terraform init
  # Command: gsutil mb -l <REGION> gs://<BUCKET_NAME>
  # Example: gsutil mb -l us-central1 gs://travelbooking-tf-state
  backend "gcs" {
    bucket = "travelbooking-gcs" # <-- Change this to your GCS bucket name
    prefix = "terraform/state"
  }
}

provider "google" {
  project     = var.project-id
  region      = var.region
  credentials = file(var.credentials-file)
}

provider "google-beta" {
  project     = var.project-id
  region      = var.region
  credentials = file(var.credentials-file)
}
