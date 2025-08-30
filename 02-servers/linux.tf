# -------------------------------------------------------------------
# RANDOM STRING GENERATOR: Create a unique suffix for resource names
# -------------------------------------------------------------------
# This `random_string` resource generates a 6-character lowercase string.
# It will be appended to the VM name to ensure uniqueness across deployments.

resource "random_string" "vm_suffix" {
  length  = 6     # Number of characters in the generated string.
  special = false # Exclude special characters to keep names simple and DNS-friendly.
  upper   = false # Use only lowercase characters for compatibility and aesthetics.
}

# -------------------------------------------------
# FIREWALL RULE: Allow SSH from anywhere (0.0.0.0/0)
# -------------------------------------------------
# This firewall rule opens port 22 (SSH) to the entire internet.
# This is useful for initial setup, but should be restricted in production.

resource "google_compute_firewall" "allow_ssh" {

  name    = "allow-ssh"    # Friendly name for the rule (must be unique within the VPC).
  network = "ad-vpc"       # Applies this rule to the `ad-vpc` network (must exist beforehand).

  # --------- ALLOW BLOCK: Defines what traffic is allowed ---------

  allow {
    protocol = "tcp"       # This rule applies to TCP traffic.
    ports    = ["22"]      # Specifically, it allows port 22 (the default port for SSH).
  }

  # --------- TARGET TAGS: What instances get this rule ---------
  # This rule will only apply to instances tagged with "allow-ssh."
  # In GCP, firewall rules don't apply to the whole network by default — you have to target specific resources.

  target_tags = ["allow-ssh"]

  # --------- SOURCE RANGE: Who can connect ---------
  # This allows SSH traffic from **anywhere** — very open!
  # Consider locking this down to trusted IPs if you're not testing.

  source_ranges = ["0.0.0.0/0"]
}

# ----------------------------------------------------
# VIRTUAL MACHINE: Ubuntu 24.04 instance for AD setup
# ----------------------------------------------------
# This resource defines a single Compute Engine VM running Ubuntu.
# It will be used to join the Managed AD domain and handle admin tasks.

resource "google_compute_instance" "linux_ad_instance" {
  # VM name includes a random suffix for uniqueness.
  
  name         = "linux-ad-${random_string.vm_suffix.result}"

  # Machine type defines CPU, memory, and price class.
  # `e2-micro` is small and cheap — perfect for testing.
  
  machine_type = "e2-micro"

  # Zone specifies the physical location where this VM lives.
  # Must match your network/subnet region.
  
  zone         = "us-central1-a"

  # --------- BOOT DISK: OS and root filesystem ---------
  
  boot_disk {
    initialize_params {
      # Fetches the latest Ubuntu 24.04 LTS image dynamically.
      image = data.google_compute_image.ubuntu_latest.self_link
    }
  }

  # --------- NETWORK INTERFACE: Connect to VPC ---------
  
  network_interface {
    network    = "ad-vpc"   # Attach to the `ad-vpc` network.
    subnetwork = "ad-subnet" # Specifically attach to `ad-subnet` (in `us-central1`).

    # Attach an ephemeral public IP so you can SSH into the VM directly.
    access_config {}  # Without this, the VM will only have internal (private) IP.
  }

  # --------- METADATA: Custom data passed to the VM ---------
  # Metadata can be read by the VM and used during startup.
  # This is often used to pass config values or trigger startup scripts.
  
  metadata = {
    enable-oslogin = "TRUE"  # Enable OS Login for secure SSH access.

    # Inject a domain join script to configure the VM to join your AD domain at boot.
    # `templatefile()` allows you to pass variables into the script, like domain name and OU path.
  
    startup-script = templatefile("./scripts/ad_join.sh", {
      domain_fqdn   = "mcloud.mikecloud.com"
      computers_ou  = "OU=Computers,OU=Cloud,DC=mcloud,DC=mikecloud,DC=com"
    })
  }

  # --------- SERVICE ACCOUNT: What permissions does the VM have? ---------
  # This attaches a service account to the VM to allow it to interact with GCP services.
  # The service account should have appropriate permissions (like joining domains).
  
  service_account {
    email  = local.service_account_email  # Email address of the service account to use.
    scopes = ["https://www.googleapis.com/auth/cloud-platform"] # Full access to GCP APIs.
  }

  # --------- FIREWALL TAGS: Apply firewall rules ---------
  # This applies the "allow-ssh" firewall rule we created above.

  tags = ["allow-ssh"]
}

# -----------------------------------------------------
# DATA SOURCE: Lookup latest Ubuntu image dynamically
# -----------------------------------------------------
# This data source fetches the latest Ubuntu 24.04 LTS image from GCP's public Ubuntu image family.
# Using `data` instead of hard-coding the image ensures your VM always uses the newest version.
data "google_compute_image" "ubuntu_latest" {
  family  = "ubuntu-2404-lts-amd64" # Specifies the image family (Ubuntu 24.04 LTS).
  project = "ubuntu-os-cloud"       # This is the official GCP project hosting Ubuntu images.
}
