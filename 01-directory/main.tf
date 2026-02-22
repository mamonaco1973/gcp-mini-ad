# ==============================================================================
# Google Cloud Provider Configuration
# ------------------------------------------------------------------------------
# Purpose:
#   - Configures the Google Cloud provider for this Terraform workspace.
#   - Loads authentication credentials from a local service account JSON file.
#   - Dynamically extracts the project_id from the credentials to avoid hard-
#     coding environment-specific values.
#
# Notes:
#   - The credentials file must exist at ../credentials.json relative to this
#     Terraform root.
#   - Protect this file appropriately; it contains private key material.
#   - Consider using environment variables (GOOGLE_APPLICATION_CREDENTIALS)
#     for production workflows instead of committing file paths.
# ==============================================================================

provider "google" {
  # ---------------------------------------------------------------------------
  # Project Configuration
  # ---------------------------------------------------------------------------
  # Uses the project_id parsed from the decoded credentials JSON.
  project = local.credentials.project_id

  # ---------------------------------------------------------------------------
  # Authentication
  # ---------------------------------------------------------------------------
  # Loads raw service account credentials from disk for API authentication.
  credentials = file("../credentials.json")
}

# ==============================================================================
# Local Variables: Credential Decoding
# ------------------------------------------------------------------------------
# Purpose:
#   - Reads the service account JSON file once.
#   - Decodes it into a structured map for easy attribute access.
#   - Exposes commonly used fields (project_id, client_email) for reuse.
#
# Notes:
#   - jsondecode(file(...)) converts the JSON document into a Terraform map.
#   - Avoid duplicating file() calls across the configuration for consistency.
# ==============================================================================

locals {
  # ---------------------------------------------------------------------------
  # Decode Credentials File
  # ---------------------------------------------------------------------------
  # Converts credentials.json into a map structure for attribute access.
  credentials = jsondecode(file("../credentials.json"))

  # ---------------------------------------------------------------------------
  # Extract Service Account Email
  # ---------------------------------------------------------------------------
  # Captures the service account email (client_email) for IAM bindings,
  # instance service account configuration, or module inputs.
  service_account_email = local.credentials.client_email
}