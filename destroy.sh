#!/bin/bash
# ==============================================================================
# destroy.sh
# ------------------------------------------------------------------------------
# Purpose:
#   - Tear down infrastructure in reverse deployment order
#   - Destroy Mini-AD-connected servers first (02-servers)
#   - Destroy Mini-AD core infrastructure second (01-directory)
#
# Notes:
#   - Destruction order matters to avoid dependency conflicts
#   - Assumes Terraform backend configuration is already defined
#   - Uses -auto-approve to avoid interactive confirmation
# ==============================================================================

# ------------------------------------------------------------------------------
# Phase 1: Destroy Mini-AD-connected servers
# ------------------------------------------------------------------------------
# Servers depend on Mini-AD resources, so they must be destroyed first.

echo "NOTE: Destroying Mini-AD-connected servers (02-servers)..."

cd 02-servers
terraform init
terraform destroy -auto-approve
cd ..

# ------------------------------------------------------------------------------
# Phase 2: Destroy Mini-AD core infrastructure
# ------------------------------------------------------------------------------
# After dependent servers are removed, destroy the directory layer.

echo "NOTE: Destroying Mini-AD core infrastructure (01-directory)..."

cd 01-directory
terraform init
terraform destroy -auto-approve
cd ..
