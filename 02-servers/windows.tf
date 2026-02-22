# ==============================================================================
# windows.tf
# ------------------------------------------------------------------------------
# Purpose:
#   - Generate and store Windows admin credentials (SysAdmin) in Secret Manager
#   - Open RDP access via a tag-targeted VPC firewall rule (TCP/3389)
#   - Provision a Windows Server 2022 VM used for AD administration tasks
#   - Bootstrap the VM with a PowerShell startup script to domain-join
#
# Notes:
#   - RDP is open to 0.0.0.0/0 for quick testing; restrict in production
#   - VM name uses random_string.vm_suffix from another file/module
#   - Assumes the VPC ("ad-vpc") and subnet ("ad-subnet") already exist
#   - Service account email is sourced from local.service_account_email
# ==============================================================================

# ==============================================================================
# Credentials: SysAdmin random password
# ------------------------------------------------------------------------------
# Generates a strong random password for the Windows local/admin account that
# will be used for RDP login and (optionally) domain join operations.
# ==============================================================================

resource "random_password" "sysadmin_password" {
  length           = 24   # Strong password length.
  special          = true # Include special characters.
  override_special = "-_." # Limit special chars to Windows-friendly set.
}

# ==============================================================================
# Secret Manager: Store SysAdmin credentials
# ------------------------------------------------------------------------------
# Creates a Secret Manager secret and stores the SysAdmin username/password as
# a JSON payload in a secret version.
# ==============================================================================

resource "google_secret_manager_secret" "sysadmin_secret" {
  secret_id = "sysadmin-ad-credentials-mini" # Secret name (unique in project).

  replication {
    auto {} # Automatic replication (Google-managed).
  }
}

resource "google_secret_manager_secret_version" "admin_secret_version" {
  secret = google_secret_manager_secret.sysadmin_secret.id

  # Store credentials as JSON for easy retrieval/consumption by scripts/tools.
  secret_data = jsonencode({
    username = "sysadmin"
    password = random_password.sysadmin_password.result
  })
}

# ==============================================================================
# Firewall: Allow RDP (TCP/3389) to tagged instances
# ------------------------------------------------------------------------------
# Opens TCP/3389 from anywhere and targets instances with the "allow-rdp" tag.
# Restrict source_ranges in production environments.
# ==============================================================================

resource "google_compute_firewall" "allow_rdp" {

  name    = "allow-rdp" # Rule name (unique within the VPC).
  network = "mini-ad-vpc"    # VPC network this rule applies to.

  # ----------------------------------------------------------------------------
  # Allow inbound RDP
  # ----------------------------------------------------------------------------
  allow {
    protocol = "tcp"    # RDP uses TCP.
    ports    = ["3389"] # Standard RDP port.
  }

  # ----------------------------------------------------------------------------
  # Target only instances with this network tag
  # ----------------------------------------------------------------------------
  target_tags = ["allow-rdp"]

  # ----------------------------------------------------------------------------
  # Source CIDR ranges allowed to connect
  # ----------------------------------------------------------------------------
  source_ranges = ["0.0.0.0/0"]
}

# ==============================================================================
# Compute Instance: Windows Server 2022 (AD management / utility VM)
# ------------------------------------------------------------------------------
# Provisions a Windows Server 2022 VM with:
#   - Latest image from the windows-2022 family (data source)
#   - NIC in ad-vpc / ad-subnet with ephemeral public IP (RDP access)
#   - Service account attached for GCP API access
#   - PowerShell startup script to domain-join
#   - Metadata for admin username/password
# ==============================================================================

resource "google_compute_instance" "windows_ad_instance" {

  # VM name includes a random suffix for uniqueness across deployments.
  name         = "win-ad-${random_string.vm_suffix.result}"

  # Windows admin tooling benefits from additional CPU/RAM.
  machine_type = "e2-standard-2"

  # Zone where the VM is deployed (must align with subnet region).
  zone         = "us-central1-a"

  # ----------------------------------------------------------------------------
  # Boot disk: Windows Server 2022
  # ----------------------------------------------------------------------------
  boot_disk {
    initialize_params {
      # Latest Windows Server 2022 image from the selected image family.
      image = data.google_compute_image.windows_2022.self_link
    }
  }

  # ----------------------------------------------------------------------------
  # Network interface: VPC + subnet + ephemeral public IP
  # ----------------------------------------------------------------------------
  network_interface {
    network    = "mini-ad-vpc"
    subnetwork = "ad-subnet"

    # Enables an ephemeral public IP for direct RDP access.
    access_config {}
  }

  # ----------------------------------------------------------------------------
  # Service account: VM identity + API access scope
  # ----------------------------------------------------------------------------
  service_account {
    email  = local.service_account_email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  # ----------------------------------------------------------------------------
  # Instance metadata: startup script + admin credentials
  # ----------------------------------------------------------------------------
  metadata = {
    # PowerShell startup script executed on first boot.
    windows-startup-script-ps1 = templatefile("./scripts/ad_join.ps1", {
      domain_fqdn = "mcloud.mikecloud.com"
    })

    # Expose initial admin creds via instance metadata (use with care).
    admin_username = "sysadmin"
    admin_password = random_password.sysadmin_password.result
  }

  # ----------------------------------------------------------------------------
  # Network tags: bind firewall rule(s) to this instance
  # ----------------------------------------------------------------------------
  tags = ["allow-rdp"]
}

# ==============================================================================
# Data Source: Latest Windows Server 2022 image (GCE public image family)
# ------------------------------------------------------------------------------
# Pulls the newest image from the Windows Server 2022 family so deployments
# stay current without hard-coding a specific image version.
# ==============================================================================

data "google_compute_image" "windows_2022" {
  family  = "windows-2022"
  project = "windows-cloud"
}