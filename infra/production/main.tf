terraform {
  required_version = "~> 1.12.0"
  backend "gcs" { prefix = "production" }
  required_providers {
    google = { source = "hashicorp/google", version = "~> 7.0" }
    random = { source = "hashicorp/random", version = "~> 3.7" }
  }
}

variable "project_id" { type = string }
variable "region" { type = string }
variable "image" { type = string }
variable "google_client_id" {
  type    = string
  default = ""
}
provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_sql_database_instance" "api" {
  name             = "feswave-db"
  region           = var.region
  database_version = "POSTGRES_17"
  settings {
    tier                        = "db-f1-micro"
    edition                     = "ENTERPRISE"
    connector_enforcement       = "REQUIRED"
    deletion_protection_enabled = true
    disk_type                   = "PD_SSD"
    disk_size                   = 10
    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
    }
    ip_configuration {
      ipv4_enabled = true
      ssl_mode     = "ENCRYPTED_ONLY"
    }
  }
  lifecycle { prevent_destroy = true }
}
resource "google_sql_database" "api" {
  name     = "feswave"
  instance = google_sql_database_instance.api.name
}
resource "random_password" "database" {
  length  = 40
  special = false
}
resource "google_sql_user" "api" {
  name     = "feswave"
  instance = google_sql_database_instance.api.name
  password = random_password.database.result
}
resource "google_secret_manager_secret_version" "database" {
  secret      = "projects/${var.project_id}/secrets/feswave-database-url"
  secret_data = "postgresql://${google_sql_user.api.name}:${random_password.database.result}@localhost/${google_sql_database.api.name}?host=/cloudsql/${google_sql_database_instance.api.connection_name}"
}
resource "google_cloud_run_v2_service" "api" {
  name                 = "feswave-api"
  location             = var.region
  deletion_protection  = true
  invoker_iam_disabled = true
  template {
    service_account       = "feswave-runtime@${var.project_id}.iam.gserviceaccount.com"
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"
    scaling {
      min_instance_count = 0
      max_instance_count = 2
    }
    volumes {
      name = "cloudsql"
      cloud_sql_instance { instances = [google_sql_database_instance.api.connection_name] }
    }
    containers {
      image = var.image
      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }
      env {
        name = "DATABASE_URL"
        value_source {
          secret_key_ref {
            secret  = "feswave-database-url"
            version = google_secret_manager_secret_version.database.version
          }
        }
      }
      env {
        name  = "COOKIE_SECURE"
        value = "true"
      }
      env {
        name  = "GOOGLE_CLIENT_ID"
        value = var.google_client_id
      }
    }
  }
}
output "url" { value = google_cloud_run_v2_service.api.uri }
