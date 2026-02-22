# ==============================================================================
# linux.tf
# ------------------------------------------------------------------------------
# Purpose:
#   - Provision a Linux admin VM for Managed AD / domain join operations
#   - Allow SSH access via a targeted VPC firewall rule (tag-based)
#   - Use the latest Ubuntu 24.04 LTS image via a data source lookup
#
# Notes:
#   - Firewall rule is intentionally open (0.0.0.0/0) for quick testing
#   - Tighten source_ranges for production use
#   - VM name includes a random suffix to avoid collisions
# ==============================================================================

# ==============================================================================
# RANDOM STRING: Unique suffix for resource names
# ------------------------------------------------------------------------------
# Generates a 6-character lowercase string. Appended to the VM name to ensure
# uniqueness across deployments.
# ==============================================================================

resource "random_string" "vm_suffix" {
  length  = 6     # Number of characters in the generated string.
  special = false # Exclude special chars (DNS-friendly resource names).
  upper   = false # Lowercase only for consistency and compatibility.
}

# ==============================================================================
# FIREWALL: Allow SSH (TCP/22) to tagged instances
# ------------------------------------------------------------------------------
# Opens TCP/22 from anywhere and targets instances with the "allow-ssh" tag.
# Restrict source_ranges in production.
# ==============================================================================

resource "google_compute_firewall" "allow_ssh" {

  name    = "allow-ssh" # Rule name (unique within the VPC).
  network = "ad-vpc"    # VPC network this rule applies to.

  # ----------------------------------------------------------------------------
  # Allow inbound SSH
  # ----------------------------------------------------------------------------
  allow {
    protocol = "tcp"  # Apply to TCP traffic.
    ports    = ["22"] # SSH port.
  }

  # ----------------------------------------------------------------------------
  # Target only instances with this network tag
  # ----------------------------------------------------------------------------
  target_tags = ["allow-ssh"]

  # ----------------------------------------------------------------------------
  # Source CIDR ranges allowed to connect
  # ----------------------------------------------------------------------------
  source_ranges = ["0.0.0.0/0"]
}

# ==============================================================================
# COMPUTE INSTANCE: Ubuntu 24.04 VM for AD setup / admin tasks
# ------------------------------------------------------------------------------
# Single VM with:
#   - Latest Ubuntu 24.04 LTS boot image (data source)
#   - NIC in ad-vpc / ad-subnet with ephemeral public IP (SSH access)
#   - Startup script to join the AD domain
#   - Service account with cloud-platform scope
# ==============================================================================

resource "google_compute_instance" "linux_ad_instance" {
  # VM name includes a random suffix for uniqueness.
  name         = "linux-ad-${random_string.vm_suffix.result}"

  # Machine type controls vCPU and memory sizing.
  machine_type = "e2-medium"

  # Zone where the VM is deployed (must align with subnet region).
  zone         = "us-central1-a"

  # ----------------------------------------------------------------------------
  # Boot disk: Ubuntu 24.04 LTS
  # ----------------------------------------------------------------------------
  boot_disk {
    initialize_params {
      # Latest Ubuntu 24.04 LTS image from the selected image family.
      image = data.google_compute_image.ubuntu_latest.self_link
    }
  }

  # ----------------------------------------------------------------------------
  # Network interface: VPC + subnet + ephemeral public IP
  # ----------------------------------------------------------------------------
  network_interface {
    network    = "mini-ad-vpc"
    subnetwork = "ad-subnet"

    # Enables an ephemeral public IP for direct SSH access.
    access_config {}
  }

  # ----------------------------------------------------------------------------
  # Instance metadata: OS Login + startup script (domain join)
  # ----------------------------------------------------------------------------
  metadata = {
    enable-oslogin = "TRUE"

    # Domain join script rendered from a template file.
    startup-script = templatefile("./scripts/ad_join.sh", {
      domain_fqdn   = "mcloud.mikecloud.com"
    })
  }

  # ----------------------------------------------------------------------------
  # Service account: VM identity + API access scope
  # ----------------------------------------------------------------------------
  service_account {
    email  = local.service_account_email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  # ----------------------------------------------------------------------------
  # Network tags: bind firewall rule(s) to this instance
  # ----------------------------------------------------------------------------
  tags = ["allow-ssh"]
}

# ==============================================================================
# DATA SOURCE: Latest Ubuntu 24.04 LTS image (GCE public image family)
# ------------------------------------------------------------------------------
# Pulls the newest image from the Ubuntu 24.04 LTS family so builds stay current
# without hard-coding a specific image version.
# ==============================================================================

data "google_compute_image" "ubuntu_latest" {
  family  = "ubuntu-2404-lts-amd64"
  project = "ubuntu-os-cloud"
}