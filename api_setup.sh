#!/bin/bash
# ==============================================================================
# api_setup.sh
# ------------------------------------------------------------------------------
# Purpose:
#   - Validate presence of GCP service account credentials (credentials.json)
#   - Authenticate gcloud using the service account
#   - Set the active GCP project from the credential file
#   - Enable required Google Cloud APIs for the Terraform build
#
# Requirements:
#   - gcloud CLI installed and available in PATH
#   - jq installed (used to extract project_id from JSON)
#   - credentials.json present in current directory
# ==============================================================================

echo "NOTE: Validating credentials.json and test the gcloud command"

# ------------------------------------------------------------------------------
# Validate credentials file exists
# ------------------------------------------------------------------------------
# Ensure the service account JSON file is present before attempting auth.

if [[ ! -f "./credentials.json" ]]; then
  echo "ERROR: The file './credentials.json' does not exist." >&2
  exit 1
fi

# ------------------------------------------------------------------------------
# Authenticate using service account
# ------------------------------------------------------------------------------
# Activates the service account defined in credentials.json so subsequent
# gcloud commands run under this identity.

gcloud auth activate-service-account --key-file="./credentials.json"

# ------------------------------------------------------------------------------
# Extract project_id from credentials.json
# ------------------------------------------------------------------------------
# Uses jq to parse the JSON file and retrieve the project_id field.

project_id=$(jq -r '.project_id' "./credentials.json")

# ------------------------------------------------------------------------------
# Enable required Google Cloud APIs
# ------------------------------------------------------------------------------
# Sets the active project and enables APIs required by the infrastructure
# deployment (Compute Engine, Firestore, Resource Manager, Storage, Secrets).

echo "NOTE: Enabling APIs needed for build."

gcloud config set project "$project_id"

gcloud services enable compute.googleapis.com
gcloud services enable firestore.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
gcloud services enable storage.googleapis.com
gcloud services enable secretmanager.googleapis.com