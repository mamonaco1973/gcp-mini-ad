# ==============================================================================
# Google Cloud Networking: Active Directory VPC Stack
# ------------------------------------------------------------------------------
# Purpose:
#   - Provisions a custom-mode VPC dedicated to the mini Active Directory
#     deployment.
#   - Defines an explicitly managed subnet with a controlled CIDR range.
#   - Configures Cloud Router + Cloud NAT to allow private instances outbound
#     internet access without assigning public IP addresses.
#
# Design Principles:
#   - Custom-mode networking for deterministic IP planning.
#   - No default subnets (avoids accidental regional sprawl).
#   - Private-only AD instances with secure outbound access via NAT.
# ==============================================================================

# ==============================================================================
# VPC Network (Custom Mode)
# ------------------------------------------------------------------------------
# Creates a custom-mode Virtual Private Cloud.
# - Custom mode requires you to define all subnets manually.
# - Preferred for enterprise workloads (e.g., AD, databases, controlled CIDR).
# - Prevents GCP from auto-creating one subnet per region.
# ==============================================================================

resource "google_compute_network" "ad_vpc" {

  # ---------------------------------------------------------------------------
  # VPC Name
  # ---------------------------------------------------------------------------
  # Must be unique within the project.
  # Referenced by subnets, routers, firewall rules, and VM NICs.
  name = var.vpc_name

  # ---------------------------------------------------------------------------
  # Disable Auto Subnets
  # ---------------------------------------------------------------------------
  # Ensures this is a custom-mode VPC.
  # No automatic regional subnet creation.
  auto_create_subnetworks = false
}

# ==============================================================================
# Subnet: Active Directory Subnet
# ------------------------------------------------------------------------------
# Defines a regional subnet inside the custom VPC.
# - Subnets are regional resources in GCP.
# - Each subnet has a unique CIDR block within the VPC.
# - All VM instances launched in this subnet draw IPs from this range.
# ==============================================================================

resource "google_compute_subnetwork" "ad_subnet" {

  # ---------------------------------------------------------------------------
  # Subnet Name
  # ---------------------------------------------------------------------------
  # Must be unique within the VPC.
  name = var.subnet_name

  # ---------------------------------------------------------------------------
  # Region
  # ---------------------------------------------------------------------------
  # Must match the region where AD VMs and related resources will run.
  region = "us-central1"

  # ---------------------------------------------------------------------------
  # Parent VPC Association
  # ---------------------------------------------------------------------------
  # Links this subnet to the custom AD VPC.
  # .id returns the fully qualified self-link.
  network = google_compute_network.ad_vpc.id

  # ---------------------------------------------------------------------------
  # IP Range (CIDR)
  # ---------------------------------------------------------------------------
  # Defines the IPv4 address space for this subnet.
  # Requirements:
  #   - Must not overlap with other subnets in the VPC.
  #   - Must be large enough for AD, supporting VMs, and growth.
  ip_cidr_range = "10.1.0.0/24"
}

# ==============================================================================
# Cloud Router
# ------------------------------------------------------------------------------
# Required for Cloud NAT.
# - Acts as the control-plane resource for dynamic routing.
# - Must exist in the same region as the subnet/NAT configuration.
# ==============================================================================

resource "google_compute_router" "ad_router" {

  # Router name (unique per region in the project)
  name = "ad-router"

  # Attach router to the AD VPC
  network = google_compute_network.ad_vpc.id

  # Region must match subnet region
  region = "us-central1"
}

# ==============================================================================
# Cloud NAT (Outbound Internet Without Public IPs)
# ------------------------------------------------------------------------------
# Enables instances in private subnets to access the internet:
#   - OS package updates
#   - External repositories
#   - API calls
# Without assigning public IP addresses to the VMs.
#
# This is ideal for:
#   - Domain Controllers
#   - Internal infrastructure services
#   - Secure enterprise deployments
# ==============================================================================

resource "google_compute_router_nat" "ad_nat" {

  # NAT resource name
  name = "ad-nat"

  # Associate NAT with the Cloud Router
  router = google_compute_router.ad_router.name

  # Must match router region
  region = google_compute_router.ad_router.region

  # ---------------------------------------------------------------------------
  # NAT IP Allocation
  # ---------------------------------------------------------------------------
  # AUTO_ONLY = GCP automatically allocates ephemeral external IPs for NAT.
  nat_ip_allocate_option = "AUTO_ONLY"

  # ---------------------------------------------------------------------------
  # Source Subnet Scope
  # ---------------------------------------------------------------------------
  # Applies NAT to all subnets and all IP ranges in this VPC.
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  # ---------------------------------------------------------------------------
  # Logging Configuration
  # ---------------------------------------------------------------------------
  # Enables NAT flow logging for troubleshooting and auditing.
  log_config {
    enable = true
    filter = "ALL"
  }
}