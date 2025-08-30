# # -------------------------------------------------
# # FIREWALL RULE: Allow AD DC Ports
# # -------------------------------------------------
# # This firewall rule opens the ports required for
# # a Samba-based Active Directory Domain Controller.
# # WARNING: Source range 0.0.0.0/0 is insecure —
# # restrict to trusted IPs in production.
# # -------------------------------------------------

# resource "google_compute_firewall" "ad_ports" {
#   name    = "ad-ports"
#   network = google_compute_network.ad_vpc.id   # Reference VPC by id, not string

#   # Allow blocks for each AD service
#   allow {
#     protocol = "tcp"
#     ports    = ["22","53","88","135","389","445","443","464","636","3268","3269"]
#   }

#   allow {
#     protocol = "udp"
#     ports    = ["53","88","389","464","123"]
#   }

#   # Ephemeral RPC high ports
#   allow {
#     protocol = "tcp"
#     ports    = ["49152-65535"]
#   }

#   # Outbound: allow all (default in GCP VPCs anyway)
#   # No need to explicitly add unless you have custom deny rules.

#   source_ranges = ["0.0.0.0/0"]   # ← tighten in production
#   target_tags   = ["ad-dc"]       # Apply only to DC instances
# }

# # ----------------------------------------------------
# # VIRTUAL MACHINE: Ubuntu 24.04 instance for mini-AD
# # ----------------------------------------------------

# resource "google_compute_instance" "mini_ad_dc_instance" {

#   name         = "mini-ad-dc-${lower(var.netbios)}"

#   # Machine type defines CPU, memory, and price class.
#   # `e2-micro` is small and cheap — perfect for testing.

#   machine_type = var.machine_type

#   # Zone specifies the physical location where this VM lives.
#   # Must match your network/subnet region.

#   zone         = var.zone

#   # --------- BOOT DISK: OS and root filesystem ---------

#   boot_disk {
#     initialize_params {
#       # Fetches the latest Ubuntu 24.04 LTS image dynamically.
#       image = data.google_compute_image.ubuntu_latest.self_link
#     }
#   }

#   # --------- NETWORK INTERFACE: Connect to VPC ---------

#   network_interface {
#     network    = var.network   # Attach to the `ad-vpc` network.
#     subnetwork = var.subnetwork # Specifically attach to `ad-subnet` (in `us-central1`).
#   }

#   # --------- METADATA: Custom data passed to the VM ---------
#   # Metadata can be read by the VM and used during startup.
#   # This is often used to pass config values or trigger startup scripts.

#   metadata = {
#     enable-oslogin = "TRUE"  # Enable OS Login for secure SSH access.

#     # Inject a domain join script to configure the VM to join your AD domain at boot.
#     # `templatefile()` allows you to pass variables into the script, like domain name and OU path.

#     startup-script = templatefile("./scripts/mini-ad.sh.template", {
#       HOSTNAME_DC        = "ad1"
#       DNS_ZONE           = var.dns_zone
#       REALM              = var.realm
#       NETBIOS            = var.netbios
#       ADMINISTRATOR_PASS = random_password.admin_password.result
#       ADMIN_USER_PASS    = random_password.admin_password.result
#       USERS_JSON         = local.users_json
#     })
#   }

#   # --------- SERVICE ACCOUNT: What permissions does the VM have? ---------
#   # This attaches a service account to the VM to allow it to interact with GCP services.
#   # The service account should have appropriate permissions (like joining domains).

#   service_account {
#     email  = local.service_account_email  # Email address of the service account to use.
#     scopes = ["https://www.googleapis.com/auth/cloud-platform"] # Full access to GCP APIs.
#   }

#   # --------- FIREWALL TAGS: Apply firewall rules ---------
#   # This applies the "ad-dc" firewall rule we created above.

#   tags = ["ad-dc"]

#   depends_on = [ google_compute_subnetwork.ad_subnet,
#                  google_compute_router.ad_router,
#                  google_compute_router_nat.ad_nat]
# }

# # -----------------------------------------------------
# # DATA SOURCE: Lookup latest Ubuntu image dynamically
# # -----------------------------------------------------
# # This data source fetches the latest Ubuntu 24.04 LTS image from GCP's public Ubuntu image family.
# # Using `data` instead of hard-coding the image ensures your VM always uses the newest version.
# data "google_compute_image" "ubuntu_latest" {
#   family  = "ubuntu-2404-lts-amd64" # Specifies the image family (Ubuntu 24.04 LTS).
#   project = "ubuntu-os-cloud"       # This is the official GCP project hosting Ubuntu images.
# }

# # ==========================================================================================
# # Local Variable: users_json
# # ------------------------------------------------------------------------------------------
# # - Renders a JSON file (`users.json.template`) into a single JSON blob
# # - Injects unique random passwords for test/demo users
# # - Template variables are replaced with real values at runtime
# # - Passed into the VM bootstrap so users are created automatically
# # ==========================================================================================

# locals {
#   users_json = templatefile("./scripts/users.json.template", {
#     USER_BASE_DN    = var.user_base_dn                       # Base DN for placing new users in LDAP
#     DNS_ZONE        = var.dns_zone                           # AD-integrated DNS zone
#     REALM           = var.realm                              # Kerberos realm (FQDN in uppercase)
#     NETBIOS         = var.netbios                            # NetBIOS domain name
#     jsmith_password = random_password.jsmith_password.result # Random password for John Smith
#     edavis_password = random_password.edavis_password.result # Random password for Emily Davis
#     rpatel_password = random_password.rpatel_password.result # Random password for Raj Patel
#     akumar_password = random_password.akumar_password.result # Random password for Amit Kumar
#   })
# }


# # Wait for AD DC provisioning (Samba/DNS startup)
# # Conservative 240s delay → adjust if bootstrap time differs.
# resource "time_sleep" "wait_for_mini_ad" {
#   depends_on      = [ google_compute_instance.mini_ad_dc_instance ]
#   create_duration = "240s"
# }

# resource "google_dns_managed_zone" "ad_forward_zone" {
#   name        = "${lower(var.netbios)}-forward-zone"
#   dns_name    = "${lower(var.dns_zone)}."
#   description = "Forward zone for ${var.netbios}."
#   visibility  = "private"

#   forwarding_config {
#     target_name_servers {
#       ipv4_address = google_compute_instance.mini_ad_dc_instance.network_interface[0].network_ip
#     }
#   }

#   private_visibility_config {
#     networks {
#       network_url = google_compute_network.ad_vpc.id
#     }
#   }

#   depends_on = [time_sleep.wait_for_mini_ad]
# }
