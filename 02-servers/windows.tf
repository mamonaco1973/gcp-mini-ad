# -------------------------------------------------
# FIREWALL RULE: Allow RDP (Remote Desktop Protocol)
# -------------------------------------------------
# This rule allows remote desktop access (port 3389) to Windows instances in the VPC.
# ⚠️ WARNING: This opens RDP to the entire internet (0.0.0.0/0) — very insecure for production!

resource "google_compute_firewall" "allow_rdp" {
  
  name    = "allow-rdp"    # Name of the rule (must be unique within the VPC)
  network = "ad-vpc"       # Target VPC network where this rule applies (must already exist)

  # --------- ALLOW BLOCK: Defines allowed traffic ---------
  
  allow {
    protocol = "tcp"        # RDP uses TCP
    ports    = ["3389"]     # Port 3389 is the standard RDP port
  }

  # --------- TARGET TAGS: Which VMs get this rule? ---------
  # This rule only applies to instances explicitly tagged with "allow-rdp"
  # Firewall rules in GCP are tag-based (unlike AWS security groups which bind directly to instances).
  
  target_tags = ["allow-rdp"]

  # --------- SOURCE RANGE: Who can connect ---------
  # This allows RDP from **anywhere on the internet**.
  # 🔥 This is dangerous in production — lock it down to your office IP if possible.
  
  source_ranges = ["0.0.0.0/0"]
}

# --------------------------------------------------------
# WINDOWS AD MANAGEMENT VM: Windows Server 2022 Instance
# --------------------------------------------------------
# This creates a Windows Server VM to act as a domain management or utility machine.
# Typically used to administer Active Directory, run PowerShell scripts, or install management tools.
resource "google_compute_instance" "windows_ad_instance" {

  # VM name includes a randomly generated suffix for uniqueness across deployments.
  # This avoids collisions if running multiple environments.
  
  name         = "win-ad-${random_string.vm_suffix.result}"

  # Machine type defines CPU, RAM, and performance.
  # Windows requires more resources than Linux (especially for AD tools), so we use `e2-standard-2`.
  
  machine_type = "e2-standard-2"

  # Placement zone — must be in the same region as the VPC subnet it's connecting to.
  
  zone         = "us-central1-a"

  # --------- BOOT DISK: Operating System ---------
  
  boot_disk {
    initialize_params {
      # Reference the latest Windows Server 2022 image.
      # This is dynamically pulled using the `data` block below.
      image = data.google_compute_image.windows_2022.self_link
    }
  }

  # --------- NETWORK INTERFACE: Connect VM to network ---------
  
  network_interface {
    network    = "ad-vpc"    # Attach to the custom `ad-vpc` network
    subnetwork = "ad-subnet" # Place the VM into `ad-subnet`

    # Assign a public IP so you can RDP directly into the instance.
    # This is required since the firewall allows RDP traffic from external sources.
    access_config {}  # Without this, the VM would only have an internal IP.
  }

  # --------- SERVICE ACCOUNT: What permissions does this VM have? ---------
  # Attaches a service account to the VM so it can interact with GCP APIs (e.g., AD joining process).
  
  service_account {
    email  = local.service_account_email  # Service account email (usually created separately)
    scopes = ["https://www.googleapis.com/auth/cloud-platform"] # Full API access (broad permissions)
  }

  # --------- STARTUP SCRIPT: Domain Join Automation ---------
  # This script automatically runs **once** when the VM boots for the first time.
  # It handles joining the Windows Server to your Managed AD domain.
  # Windows uses `windows-startup-script-ps1`, which is a PowerShell script.
  
  metadata = {
    windows-startup-script-ps1 = templatefile("./scripts/ad_join.ps1", {
      # Pass domain name and OU path as variables into the PowerShell script.
      domain_fqdn  = "mcloud.mikecloud.com"
      computers_ou = "OU=Computers,OU=Cloud,DC=mcloud,DC=mikecloud,DC=com"
    })
  }

  # --------- FIREWALL TAGS: Apply Firewall Rules ---------
  # This tag ensures the "allow-rdp" firewall rule applies to this VM.
  
  tags = ["allow-rdp"]
}

# ------------------------------------------------------
# DATA SOURCE: Fetch Latest Windows Server 2022 Image
# ------------------------------------------------------
# This data source dynamically fetches the latest Windows Server 2022 image from the official `windows-cloud` project.
# Using a data source ensures your deployment always gets the latest patched image, rather than hard-coding a specific version.
data "google_compute_image" "windows_2022" {
  family  = "windows-2022"  # Official GCP family for Windows Server 2022 images.
  project = "windows-cloud" # This is the GCP project hosting official Microsoft images.
}
