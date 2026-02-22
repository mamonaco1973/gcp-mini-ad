# ==========================================================================================
# Mini Active Directory (mini-ad) Module Invocation
# ------------------------------------------------------------------------------------------
# Purpose:
#   - Invokes the reusable "mini-ad" module to deploy an Ubuntu-based Samba 4
#     Domain Controller (mini Active Directory) on Google Cloud.
#   - Supplies the module with VPC/subnet placement, DNS/realm identifiers, and
#     admin credentials.
#   - Passes a rendered JSON payload describing demo/test users so the VM
#     bootstrap can create accounts automatically during provisioning.
#
# Notes:
#   - The "users_json" input is produced via templatefile() below and includes
#     randomly generated passwords.
#   - depends_on enforces NAT/router readiness before the AD instance boots so
#     it can reach external package repositories and complete initialization.
# ==========================================================================================

module "mini_ad" {
  # ----------------------------------------------------------------------------------------
  # Module Source
  # ----------------------------------------------------------------------------------------
  # Relative path to the local mini-ad module implementation.
  source = "github.com/mamonaco1973/module-gcp-mini-ad"
  
  # ----------------------------------------------------------------------------------------
  # Domain / Identity Inputs
  # ----------------------------------------------------------------------------------------
  # NetBIOS short domain name used by AD clients (e.g., "MCLOUD").
  netbios = var.netbios

  # Kerberos realm, typically the DNS domain name in UPPERCASE (e.g., "MCLOUD.EXAMPLE.COM").
  realm = var.realm

  # DNS zone name to configure for AD-integrated DNS (e.g., "mcloud.mikecloud.com").
  dns_zone = var.dns_zone

  # Base Distinguished Name where user accounts will be created (e.g., "OU=Users,DC=...").
  user_base_dn = var.user_base_dn

  # Randomized AD administrator password used to secure the initial admin account.
  ad_admin_password = random_password.admin_password.result

  # ----------------------------------------------------------------------------------------
  # Networking Inputs
  # ----------------------------------------------------------------------------------------
  # Target VPC network where the Domain Controller instance will be deployed.
  network = google_compute_network.ad_vpc.id

  # Target subnet where the Domain Controller instance NIC will be attached.
  subnetwork = google_compute_subnetwork.ad_subnet.id

  # ----------------------------------------------------------------------------------------
  # Instance / Runtime Inputs
  # ----------------------------------------------------------------------------------------
  # Machine shape for the Domain Controller VM.
  machine_type = var.machine_type

  # Service account email used by the instance/module for API access as needed.
  email = local.service_account_email

  # ----------------------------------------------------------------------------------------
  # Bootstrap Payload Inputs
  # ----------------------------------------------------------------------------------------
  # JSON blob describing users/passwords, rendered from users.json.template below.
  # Consumed by the module's startup/bootstrap logic to create demo users.
  users_json = local.users_json

  # ----------------------------------------------------------------------------------------
  # Dependencies
  # ----------------------------------------------------------------------------------------
  # Ensure NAT + router resources are fully created before bootstrapping the AD VM.
  # This avoids first-boot failures due to inability to reach package repositories.
  depends_on = [
    google_compute_subnetwork.ad_subnet,
    google_compute_router.ad_router,
    google_compute_router_nat.ad_nat
  ]
}

# ==========================================================================================
# Local Variable: users_json
# ------------------------------------------------------------------------------------------
# Purpose:
#   - Renders ./scripts/users.json.template into a single JSON string via templatefile().
#   - Injects environment-specific directory parameters (DN, realm, DNS zone, NetBIOS).
#   - Injects per-user randomized passwords from random_password resources.
#   - The resulting JSON is passed into the mini-ad module so user creation is
#     automated during initial provisioning.
#
# Notes:
#   - Keep template variable names in sync with users.json.template placeholders.
#   - Passwords originate from Terraform random_password resources and will be
#     present in Terraform state; protect state storage appropriately.
# ==========================================================================================

locals {
  users_json = templatefile("./scripts/users.json.template", {
    # --------------------------------------------------------------------------------------
    # Directory / Naming Context
    # --------------------------------------------------------------------------------------
    USER_BASE_DN = var.user_base_dn # Base DN for placing new users in LDAP
    DNS_ZONE     = var.dns_zone     # AD-integrated DNS zone
    REALM        = var.realm        # Kerberos realm (FQDN in uppercase)
    NETBIOS      = var.netbios      # NetBIOS domain name

    # --------------------------------------------------------------------------------------
    # Demo User Passwords
    # --------------------------------------------------------------------------------------
    jsmith_password = random_password.jsmith_password.result # John Smith
    edavis_password = random_password.edavis_password.result # Emily Davis
    rpatel_password = random_password.rpatel_password.result # Raj Patel
    akumar_password = random_password.akumar_password.result # Amit Kumar
  })
}