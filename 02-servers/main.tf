# ==============================================================================
# main.tf
# ------------------------------------------------------------------------------
# Purpose:
#   - Configure the Google provider using a service account JSON credential file
#   - Decode the credential JSON for convenient access to project and SA details
#   - Lookup an existing VPC and subnet used by the deployment
#
# Notes:
#   - This uses a local credentials file at ../credentials.json
#   - Ensure the JSON file is not committed to source control
#   - Network and subnet data sources assume resources already exist
# ==============================================================================

# ==============================================================================
# Provider Configuration
# ------------------------------------------------------------------------------
# Configures the Google Cloud provider using:
#   - project: sourced from the decoded credential JSON
#   - credentials: loaded directly from the JSON file
# ==============================================================================

provider "google" {
  project     = local.credentials.project_id # Project ID from decoded credentials.
  credentials = file("../credentials.json")  # Service account JSON credentials.
}

# ==============================================================================
# Locals: Credential decoding and derived values
# ------------------------------------------------------------------------------
# Decodes the service account JSON file once and exposes:
#   - credentials: full decoded JSON map
#   - service_account_email: convenience value for IAM bindings, etc.
# ==============================================================================

locals {
  credentials           = jsondecode(file("../credentials.json"))
  service_account_email = local.credentials.client_email
}

# ==============================================================================
# Data Sources: Existing network and subnet lookups
# ------------------------------------------------------------------------------
# Reads existing networking resources by name so other modules can reference:
#   - VPC: mini-ad-vpc
#   - Subnet: ad-subnet in us-central1
# ==============================================================================

data "google_compute_network" "ad_vpc" {
  name = var.vpc_name
}

data "google_compute_subnetwork" "ad_subnet" {
  name   = var.subnet_name
  region = "us-central1" # Region where the subnet exists.
}