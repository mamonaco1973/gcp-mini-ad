#!/bin/bash
# ==============================================================================
# check_env.sh
# ------------------------------------------------------------------------------
# Purpose:
#   - Validate required CLI tools are installed and available in PATH
#   - Verify credentials.json exists locally
#   - Authenticate gcloud using the provided service account
#   - Export GOOGLE_APPLICATION_CREDENTIALS for Terraform / SDK usage
#   - Invoke api_setup.sh to enable required Google Cloud APIs
#
# Requirements:
#   - gcloud CLI installed
#   - terraform CLI installed
#   - jq installed (used in api_setup.sh)
#   - credentials.json present in current working directory
# ==============================================================================

echo "NOTE: Validating that required commands are found in the PATH."

# ------------------------------------------------------------------------------
# Validate required CLI tools
# ------------------------------------------------------------------------------
# Checks whether each required command exists in PATH before continuing.

commands=("gcloud" "terraform" "jq")
all_found=true

for cmd in "${commands[@]}"; do
  if ! command -v "$cmd" &> /dev/null; then
    echo "ERROR: $cmd is not found in the current PATH."
    all_found=false
  else
    echo "NOTE: $cmd is found in the current PATH."
  fi
done

# ------------------------------------------------------------------------------
# Exit early if required tools are missing
# ------------------------------------------------------------------------------

if [ "$all_found" = true ]; then
  echo "NOTE: All required commands are available."
else
  echo "ERROR: One or more commands are missing."
  exit 1
fi

# ------------------------------------------------------------------------------
# Validate credentials file
# ------------------------------------------------------------------------------
# Ensures the service account JSON file exists before attempting authentication.

echo "NOTE: Validating credentials.json and testing the gcloud command"

if [[ ! -f "./credentials.json" ]]; then
  echo "ERROR: The file './credentials.json' does not exist." >&2
  exit 1
fi

# ------------------------------------------------------------------------------
# Authenticate gcloud using service account
# ------------------------------------------------------------------------------
# Activates the service account so gcloud and Terraform can authenticate.

gcloud auth activate-service-account --key-file="./credentials.json"

# ------------------------------------------------------------------------------
# Export Application Default Credentials
# ------------------------------------------------------------------------------
# Sets GOOGLE_APPLICATION_CREDENTIALS so Terraform and other SDK-based tools
# automatically use this service account.

export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/credentials.json"

# ------------------------------------------------------------------------------
# Enable required APIs
# ------------------------------------------------------------------------------
# Delegates to api_setup.sh to enable Compute, Secret Manager, etc.

./api_setup.sh