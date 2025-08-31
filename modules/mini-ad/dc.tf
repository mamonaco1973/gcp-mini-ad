# ==========================================================================================
# FIREWALL RULE: Active Directory Domain Controller Ports
# ==========================================================================================
# This firewall rule enables the network ports required by a Samba-based AD DC.
# Notes:
#   - Includes standard LDAP, Kerberos, DNS, SMB, and replication ports.
#   - Ephemeral RPC ports (49152–65535) are also required for AD RPC operations.
#   - Source range is currently set to 0.0.0.0/0 (world-open) for demo/testing only.
#     In production, restrict source_ranges to trusted networks or peered VPCs.
# ==========================================================================================

resource "google_compute_firewall" "ad_ports" {
  name    = "ad-ports"
  network = var.network

  # Core TCP ports for AD services
  allow {
    protocol = "tcp"
    ports    = ["22", "53", "88", "135", "389", "445", "443", "464", "636", "3268", "3269"]
  }

  # Core UDP ports for AD services
  allow {
    protocol = "udp"
    ports    = ["53", "88", "389", "464", "123"] # NTP (123) is critical for Kerberos
  }

  # High dynamic port range for RPC
  allow {
    protocol = "tcp"
    ports    = ["49152-65535"]
  }

  # Scope: currently world-open; restrict in production environments
  source_ranges = ["0.0.0.0/0"]

  # Apply rule only to AD DC instances (by tag)
  target_tags = ["ad-dc"]
}

# ==========================================================================================
# VIRTUAL MACHINE: Mini Active Directory Domain Controller
# ==========================================================================================
# Creates a lightweight Ubuntu VM configured as a Samba AD DC.
#   - Machine sizing is controlled by var.machine_type (default: e2-small).
#   - Bootstraps automatically using a startup script template.
#   - Service account attached for optional GCP API interactions.
# ==========================================================================================

resource "google_compute_instance" "mini_ad_dc_instance" {
  name         = "mini-ad-dc-${lower(var.netbios)}"
  machine_type = var.machine_type
  zone         = var.zone

  # -----------------------------------------------------------------
  # Boot disk
  # Ubuntu 24.04 LTS is pulled dynamically from the GCP Ubuntu image family.
  # -----------------------------------------------------------------
  boot_disk {
    initialize_params {
      image = data.google_compute_image.ubuntu_latest.self_link
    }
  }

  # -----------------------------------------------------------------
  # Network configuration
  # Attaches the instance to the specified VPC and subnet.
  # -----------------------------------------------------------------
  network_interface {
    network    = var.network
    subnetwork = var.subnetwork
  }

  # -----------------------------------------------------------------
  # Metadata injection
  # Passes variables into a startup script that provisions Samba AD DC.
  # Includes domain identity values and seeded user definitions.
  # -----------------------------------------------------------------
  metadata = {
    enable-oslogin = "TRUE" # Enforce GCP OS Login for SSH access.

    startup-script = templatefile("${path.module}/scripts/mini-ad.sh.template", {
      HOSTNAME_DC        = "ad1"
      DNS_ZONE           = var.dns_zone
      REALM              = var.realm
      NETBIOS            = var.netbios
      ADMINISTRATOR_PASS = var.ad_admin_password
      ADMIN_USER_PASS    = var.ad_admin_password
      USERS_JSON         = local.effective_users_json
    })
  }

  # -----------------------------------------------------------------
  # Service account
  # Grants VM permissions to interact with GCP APIs.
  # Typically limited scope; here granted full cloud-platform for lab/demo simplicity.
  # -----------------------------------------------------------------
  service_account {
    email  = var.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  # -----------------------------------------------------------------
  # Firewall tags
  # Ensures the AD DC firewall rule applies to this VM.
  # -----------------------------------------------------------------
  tags = ["ad-dc"]
}

# ==========================================================================================
# DATA SOURCE: Ubuntu Image
# ==========================================================================================
# Always pulls the latest Ubuntu 24.04 LTS image from GCP’s official Ubuntu image project.
# Using a family reference avoids stale image references over time.
# ==========================================================================================

data "google_compute_image" "ubuntu_latest" {
  family  = "ubuntu-2404-lts-amd64"
  project = "ubuntu-os-cloud"
}

# ==========================================================================================
# PROVISIONING DELAY: Wait for Samba bootstrap
# ==========================================================================================
# Gives the startup script time to configure Samba AD DC before DNS forwarding zone creation.
# Default delay is 180s (tune based on observed bootstrap time).
# ==========================================================================================

resource "time_sleep" "wait_for_mini_ad" {
  depends_on      = [google_compute_instance.mini_ad_dc_instance]
  create_duration = "180s"
}

# ==========================================================================================
# MANAGED PRIVATE DNS ZONE: AD Forward Zone
# ==========================================================================================
# Creates a private Cloud DNS zone forwarding to the Samba AD DC.
# Ensures GCP resources in the VPC can resolve AD-integrated DNS queries.
# ==========================================================================================

resource "google_dns_managed_zone" "ad_forward_zone" {
  name        = "${lower(var.netbios)}-forward-zone"
  dns_name    = "${lower(var.dns_zone)}."
  description = "Forward zone for ${var.netbios}."
  visibility  = "private"

  forwarding_config {
    target_name_servers {
      ipv4_address = google_compute_instance.mini_ad_dc_instance.network_interface[0].network_ip
    }
  }

  private_visibility_config {
    networks {
      network_url = var.network
    }
  }

  depends_on = [time_sleep.wait_for_mini_ad]
}

# ==========================================================================================
# LOCALS: User Definitions
# ==========================================================================================
# local.default_users_json
#   - Renders the users.json.template with AD-specific values (DNs, realm, netbios).
#   - Injects admin password for bootstrap user accounts.
#
# local.effective_users_json
#   - Chooses between user-provided var.users_json or the generated default.
#   - Ensures VM always has a valid JSON blob to seed AD users/groups.
# ==========================================================================================

locals {
  default_users_json = templatefile("${path.module}/scripts/users.json.template", {
    USER_BASE_DN      = var.user_base_dn
    DNS_ZONE          = var.dns_zone
    REALM             = var.realm
    NETBIOS           = var.netbios
    sysadmin_password = var.ad_admin_password
  })

  effective_users_json = coalesce(var.users_json, local.default_users_json)
}
