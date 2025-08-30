# --- User: John Smith ---

# Generate a random password for John Smith
resource "random_password" "jsmith_password" {
  length           = 24
  special          = true
  override_special = "!@#$%"
}

# Create secret for John Smith's credentials in GCP Secret Manager
resource "google_secret_manager_secret" "jsmith_secret" {
  secret_id = "jsmith-ad-credentials"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "jsmith_secret_version" {
  secret      = google_secret_manager_secret.jsmith_secret.id
  secret_data = jsonencode({
    username = "MCLOUD\\jsmith"
    password = random_password.jsmith_password.result
  })
}

# --- User: Emily Davis ---

# Generate a random password for Emily Davis
resource "random_password" "edavis_password" {
  length           = 24
  special          = true
  override_special = "!@#$%"
}

# Create secret for Emily Davis' credentials
resource "google_secret_manager_secret" "edavis_secret" {
  secret_id = "edavis-ad-credentials"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "edavis_secret_version" {
  secret      = google_secret_manager_secret.edavis_secret.id
  secret_data = jsonencode({
    username = "MCLOUD\\edavis"
    password = random_password.edavis_password.result
  })
}

# --- User: Raj Patel ---

# Generate a random password for Raj Patel
resource "random_password" "rpatel_password" {
  length           = 24
  special          = true
  override_special = "!@#$%"
}

# Create secret for Raj Patel's credentials
resource "google_secret_manager_secret" "rpatel_secret" {
  secret_id = "rpatel-ad-credentials"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "rpatel_secret_version" {
  secret      = google_secret_manager_secret.rpatel_secret.id
  secret_data = jsonencode({
    username = "MCLOUD\\rpatel"
    password = random_password.rpatel_password.result
  })
}

# --- User: Amit Kumar ---

# Generate a random password for Amit Kumar
resource "random_password" "akumar_password" {
  length           = 24
  special          = true
  override_special = "!@#$%"
}

# Create secret for Amit Kumar's credentials
resource "google_secret_manager_secret" "akumar_secret" {
  secret_id = "akumar-ad-credentials"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "akumar_secret_version" {
  secret      = google_secret_manager_secret.akumar_secret.id
  secret_data = jsonencode({
    username = "MCLOUD\\akumar"
    password = random_password.akumar_password.result
  })
}

resource "google_secret_manager_secret" "admin_secret" {
  secret_id = "admin-ad-credentials"

  replication {
    auto {}
  }
}

# List of all secret IDs
locals {
  secrets = [
    google_secret_manager_secret.jsmith_secret.secret_id,
    google_secret_manager_secret.edavis_secret.secret_id,
    google_secret_manager_secret.rpatel_secret.secret_id,
    google_secret_manager_secret.akumar_secret.secret_id,
    google_secret_manager_secret.admin_secret.secret_id
  ]
}

# Grant the service account access to all secrets
resource "google_secret_manager_secret_iam_binding" "secret_access" {
  for_each = toset(local.secrets) # Loop through each secret
  secret_id = each.key
  role      = "roles/secretmanager.secretAccessor"

  members = [
    "serviceAccount:${local.service_account_email}" # Use the existing service account
  ]
}