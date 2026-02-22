# ==============================================================================
# Google Secret Manager: AD User Credential Secrets
# ------------------------------------------------------------------------------
# Purpose:
#   - Generates strong random passwords for a set of AD users.
#   - Stores each user's credentials (domain\username + password) as a JSON blob
#     in Google Secret Manager.
#   - Grants a service account read access (secretAccessor) to all created
#     secrets so downstream automation (cloud-init, startup scripts, CI/CD, etc.)
#     can retrieve credentials at runtime.
#
# Notes:
#   - Each user has:
#       1) random_password (generated at plan/apply time)
#       2) google_secret_manager_secret (the secret container)
#       3) google_secret_manager_secret_version (the secret payload)
#   - Passwords are stored in Secret Manager; they will appear in Terraform state
#     because they are Terraform-managed values. Protect your state accordingly.
# ==============================================================================

# ==============================================================================
# User: Admin
# ==============================================================================

# ------------------------------------------------------------------------------
# Generate a random password for the Admin user.
# - length: 24 characters for strong entropy
# - special: include special characters
# - override_special: restrict special chars to a known-safe set for AD tooling
# ------------------------------------------------------------------------------
resource "random_password" "admin_password" {
  length           = 24
  special          = true
  override_special = "-_"
}

# ------------------------------------------------------------------------------
# Create a Secret Manager secret container for Admin credentials.
# - secret_id: stable identifier for the secret in the project
# - replication.auto: Google-managed multi-region replication
# ------------------------------------------------------------------------------
resource "google_secret_manager_secret" "admin_secret" {
  secret_id = "admin-ad-credentials-mini"

  replication {
    auto {}
  }
}

# ------------------------------------------------------------------------------
# Store Admin credential payload as the initial (or next) secret version.
# - secret_data is JSON encoded to keep a consistent schema:
#     { "username": "DOMAIN\\user", "password": "<generated>" }
# ------------------------------------------------------------------------------
resource "google_secret_manager_secret_version" "admin_secret_version" {
  secret = google_secret_manager_secret.admin_secret.id
  secret_data = jsonencode({
    username = "MCLOUD\\admin"
    password = random_password.admin_password.result
  })
}

# ==============================================================================
# User: John Smith
# ==============================================================================

# ------------------------------------------------------------------------------
# Generate a random password for John Smith.
# - override_special uses a broader set of specials
# ------------------------------------------------------------------------------
resource "random_password" "jsmith_password" {
  length           = 24
  special          = true
  override_special = "!@#$%"
}

# ------------------------------------------------------------------------------
# Create Secret Manager secret container for John Smith's credentials.
# ------------------------------------------------------------------------------
resource "google_secret_manager_secret" "jsmith_secret" {
  secret_id = "jsmith-ad-credentials-mini"

  replication {
    auto {}
  }
}

# ------------------------------------------------------------------------------
# Store John Smith credential payload as a secret version.
# ------------------------------------------------------------------------------
resource "google_secret_manager_secret_version" "jsmith_secret_version" {
  secret = google_secret_manager_secret.jsmith_secret.id
  secret_data = jsonencode({
    username = "MCLOUD\\jsmith"
    password = random_password.jsmith_password.result
  })
}

# ==============================================================================
# User: Emily Davis
# ==============================================================================

# ------------------------------------------------------------------------------
# Generate a random password for Emily Davis.
# ------------------------------------------------------------------------------
resource "random_password" "edavis_password" {
  length           = 24
  special          = true
  override_special = "!@#$%"
}

# ------------------------------------------------------------------------------
# Create Secret Manager secret container for Emily Davis' credentials.
# ------------------------------------------------------------------------------
resource "google_secret_manager_secret" "edavis_secret" {
  secret_id = "edavis-ad-credentials-mini"

  replication {
    auto {}
  }
}

# ------------------------------------------------------------------------------
# Store Emily Davis credential payload as a secret version.
# ------------------------------------------------------------------------------
resource "google_secret_manager_secret_version" "edavis_secret_version" {
  secret = google_secret_manager_secret.edavis_secret.id
  secret_data = jsonencode({
    username = "MCLOUD\\edavis"
    password = random_password.edavis_password.result
  })
}

# ==============================================================================
# User: Raj Patel
# ==============================================================================

# ------------------------------------------------------------------------------
# Generate a random password for Raj Patel.
# ------------------------------------------------------------------------------
resource "random_password" "rpatel_password" {
  length           = 24
  special          = true
  override_special = "!@#$%"
}

# ------------------------------------------------------------------------------
# Create Secret Manager secret container for Raj Patel's credentials.
# ------------------------------------------------------------------------------
resource "google_secret_manager_secret" "rpatel_secret" {
  secret_id = "rpatel-ad-credentials-mini"

  replication {
    auto {}
  }
}

# ------------------------------------------------------------------------------
# Store Raj Patel credential payload as a secret version.
# ------------------------------------------------------------------------------
resource "google_secret_manager_secret_version" "rpatel_secret_version" {
  secret = google_secret_manager_secret.rpatel_secret.id
  secret_data = jsonencode({
    username = "MCLOUD\\rpatel"
    password = random_password.rpatel_password.result
  })
}

# ==============================================================================
# User: Amit Kumar
# ==============================================================================

# ------------------------------------------------------------------------------
# Generate a random password for Amit Kumar.
# ------------------------------------------------------------------------------
resource "random_password" "akumar_password" {
  length           = 24
  special          = true
  override_special = "!@#$%"
}

# ------------------------------------------------------------------------------
# Create Secret Manager secret container for Amit Kumar's credentials.
# ------------------------------------------------------------------------------
resource "google_secret_manager_secret" "akumar_secret" {
  secret_id = "akumar-ad-credentials-mini"

  replication {
    auto {}
  }
}

# ------------------------------------------------------------------------------
# Store Amit Kumar credential payload as a secret version.
# ------------------------------------------------------------------------------
resource "google_secret_manager_secret_version" "akumar_secret_version" {
  secret = google_secret_manager_secret.akumar_secret.id
  secret_data = jsonencode({
    username = "MCLOUD\\akumar"
    password = random_password.akumar_password.result
  })
}

# ==============================================================================
# Aggregate secret IDs for IAM binding
# ==============================================================================

# ------------------------------------------------------------------------------
# Build a list of all secret_ids so we can grant access in a single loop.
# - secret_id is the human-readable Secret Manager identifier
# ------------------------------------------------------------------------------
locals {
  secrets = [
    google_secret_manager_secret.jsmith_secret.secret_id,
    google_secret_manager_secret.edavis_secret.secret_id,
    google_secret_manager_secret.rpatel_secret.secret_id,
    google_secret_manager_secret.akumar_secret.secret_id,
    google_secret_manager_secret.admin_secret.secret_id
  ]
}

# ==============================================================================
# IAM: Grant service account access to read all secrets
# ==============================================================================

# ------------------------------------------------------------------------------
# Grants roles/secretmanager.secretAccessor to the service account for each secret.
# - for_each: iterates across the secret_id set
# - secret_id: binds IAM at the individual secret resource
# - members: service account principal that will fetch the secret values
# ------------------------------------------------------------------------------
resource "google_secret_manager_secret_iam_binding" "secret_access" {
  for_each  = toset(local.secrets) # Loop through each secret
  secret_id = each.key
  role      = "roles/secretmanager.secretAccessor"

  members = [
    "serviceAccount:${local.service_account_email}" # Use the existing service account
  ]
}