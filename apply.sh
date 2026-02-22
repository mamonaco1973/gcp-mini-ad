#!/bin/bash
# ==============================================================================
# apply.sh
# ------------------------------------------------------------------------------
# Purpose:
#   - Run environment validation
#   - Deploy infrastructure in two phases:
#       1) Mini-AD (01-directory)
#       2) Mini-AD-connected servers (02-servers)
#
# Behavior:
#   - Fail fast on any error (set -euo pipefail)
#   - Stop immediately if any command exits non-zero
#
# Requirements:
#   - terraform installed and authenticated
#   - gcloud authenticated (if required by modules)
#   - check_env.sh present and executable
# ==============================================================================

# ------------------------------------------------------------------------------
# Fail Fast Settings
# ------------------------------------------------------------------------------
# -e  : Exit immediately on any command failure
# -u  : Treat unset variables as errors
# -o pipefail : Fail if any command in a pipeline fails
# ------------------------------------------------------------------------------

set -euo pipefail

# ------------------------------------------------------------------------------
# Phase 0: Environment validation
# ------------------------------------------------------------------------------
# Ensures required tools, credentials, and environment variables are present.
# Script will exit automatically if this fails (due to set -e).

echo "NOTE: Running environment validation..."
./check_env.sh

# ------------------------------------------------------------------------------
# Phase 1: Deploy Mini-AD infrastructure
# ------------------------------------------------------------------------------
# Initializes and applies Terraform configuration in 01-directory.

echo "NOTE: Deploying Mini-AD (01-directory)..."

cd 01-directory
terraform init
terraform apply -auto-approve
cd ..

# ------------------------------------------------------------------------------
# Phase 2: Deploy Mini-AD-connected servers
# ------------------------------------------------------------------------------
# Initializes and applies Terraform configuration in 02-servers.

echo "NOTE: Deploying Mini-AD-connected servers (02-servers)..."

cd 02-servers
terraform init
terraform apply -auto-approve
cd ..
