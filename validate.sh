#!/bin/bash
# ==============================================================================
# validate.sh - Mini-AD Quick Start Validation (GCP)
# ------------------------------------------------------------------------------
# Purpose:
#   - Prints external IP addresses for:
#       - Windows AD admin host (win-ad-*)
#       - Linux domain-joined host (linux-ad-*)
#   - Scoped only to instances attached to VPC: mini-ad-vpc
#
# Requirements:
#   - gcloud CLI installed and authenticated
#   - gcloud project set (gcloud config set project <PROJECT_ID>)
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------
PROJECT_ID="$(gcloud config get-value project 2>/dev/null)"
WIN_PREFIX="win-ad-"
LINUX_PREFIX="linux-ad-"
VPC_NAME="mini-ad-vpc"

# ------------------------------------------------------------------------------
# Pre-Checks
# ------------------------------------------------------------------------------
if [ -z "${PROJECT_ID}" ]; then
  echo "ERROR: No GCP project set."
  exit 1
fi

# ------------------------------------------------------------------------------
# Lookups (Scoped to VPC)
# ------------------------------------------------------------------------------
windows_ip="$(gcloud compute instances list \
  --filter="name~'^${WIN_PREFIX}.*' AND networkInterfaces.network:${VPC_NAME}" \
  --format="value(networkInterfaces[0].accessConfigs[0].natIP)" \
  --limit=1 2>/dev/null)"

linux_ip="$(gcloud compute instances list \
  --filter="name~'^${LINUX_PREFIX}.*' AND networkInterfaces.network:${VPC_NAME}" \
  --format="value(networkInterfaces[0].accessConfigs[0].natIP)" \
  --limit=1 2>/dev/null)"

# ------------------------------------------------------------------------------
# Quick Start Output
# ------------------------------------------------------------------------------
echo ""
echo "============================================================================"
echo "Mini-AD Quick Start - Validation Output (GCP)"
echo "============================================================================"
echo ""

printf "%-28s %s\n" "NOTE: Windows RDP Host:" "${windows_ip:-<not found>}"
printf "%-28s %s\n" "NOTE: Linux SSH Host:"   "${linux_ip:-<not found>}"

echo ""