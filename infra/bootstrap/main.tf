terraform {
  required_version = "~> 1.12.0"
  required_providers {
    google = { source = "hashicorp/google", version = "~> 7.0" }
  }
}

variable "project_id" { type = string }
variable "region" {
  type    = string
  default = "asia-northeast1"
}
provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_project" "current" {}

resource "google_project_service" "api" {
  for_each = toset([
    "artifactregistry.googleapis.com", "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com", "iamcredentials.googleapis.com", "run.googleapis.com",
    "secretmanager.googleapis.com", "sqladmin.googleapis.com", "storage.googleapis.com",
    "sts.googleapis.com", "compute.googleapis.com"
  ])
  service            = each.key
  disable_on_destroy = false
}

resource "google_storage_bucket" "state" {
  name                        = "${var.project_id}-feswave-tfstate"
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  versioning { enabled = true }
  depends_on = [google_project_service.api]
}

resource "google_artifact_registry_repository" "api" {
  location      = var.region
  repository_id = "feswave"
  format        = "DOCKER"
  depends_on    = [google_project_service.api]
}

resource "google_service_account" "deploy" {
  account_id = "feswave-deploy"
  depends_on = [google_project_service.api]
}
resource "google_service_account" "runtime" {
  account_id = "feswave-runtime"
  depends_on = [google_project_service.api]
}

resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "feswave-github"
  depends_on                = [google_project_service.api]
}
resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "actions"
  attribute_mapping = {
    "google.subject"          = "assertion.sub"
    "attribute.repository_id" = "assertion.repository_id"
  }
  # Immutable GitHub IDs prevent reuse of the owner or repository name.
  attribute_condition = "assertion.repository_owner_id == '134787738' && assertion.repository_id == '1449877447' && assertion.ref == 'refs/heads/main' && assertion.workflow_ref == 'mashumarrow/feswave/.github/workflows/api.yml@refs/heads/main'"
  oidc { issuer_uri = "https://token.actions.githubusercontent.com" }
}
resource "google_service_account_iam_member" "github" {
  service_account_id = google_service_account.deploy.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository_id/1449877447"
}

resource "google_storage_bucket_iam_member" "state" {
  bucket = google_storage_bucket.state.name
  role   = "roles/storage.objectAdmin"
  member = google_service_account.deploy.member
}
resource "google_artifact_registry_repository_iam_member" "push" {
  location   = var.region
  repository = google_artifact_registry_repository.api.name
  role       = "roles/artifactregistry.writer"
  member     = google_service_account.deploy.member
}
resource "google_project_iam_member" "deploy" {
  for_each = toset(["roles/run.admin", "roles/cloudsql.admin", "roles/serviceusage.serviceUsageConsumer"])
  project  = var.project_id
  role     = each.key
  member   = google_service_account.deploy.member
}
resource "google_service_account_iam_member" "act_as" {
  service_account_id = google_service_account.runtime.name
  role               = "roles/iam.serviceAccountUser"
  member             = google_service_account.deploy.member
}
resource "google_project_iam_member" "connect" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = google_service_account.runtime.member
}

resource "google_secret_manager_secret" "database" {
  secret_id = "feswave-database-url"
  replication {
    auto {}
  }
  depends_on = [google_project_service.api]
}
resource "google_secret_manager_secret_iam_member" "versions" {
  secret_id = google_secret_manager_secret.database.id
  role      = "roles/secretmanager.secretVersionManager"
  member    = google_service_account.deploy.member
}
resource "google_secret_manager_secret_iam_member" "read" {
  secret_id = google_secret_manager_secret.database.id
  role      = "roles/secretmanager.secretAccessor"
  member    = google_service_account.runtime.member
}

output "project_number" { value = data.google_project.current.number }
