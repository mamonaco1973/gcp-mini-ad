# ==================================================================================================
# Active Directory naming inputs
# --------------------------------------------------------------------------------------------------
# dns_zone : The fully qualified DNS name of your AD domain (e.g., mcloud.mikecloud.com).
#            This defines the namespace for users, groups, and service records.
#
# realm    : The Kerberos realm name (conventionally the DNS zone in UPPERCASE).
#            Kerberos requires uppercase for ticket validation.
#
# netbios  : The short pre-Windows 2000 domain name (<= 15 chars, uppercase).
#            Still used by some SMB clients, legacy apps, and NetBIOS lookups.
# ==================================================================================================

# --------------------------------------------------------------------------------
# DNS zone / AD domain
# Example: "mcloud.mikecloud.com"
# This becomes the root domain of your Samba AD environment.
# Users will have logins like user@mcloud.mikecloud.com.
# --------------------------------------------------------------------------------
variable "dns_zone" {
  description = "AD DNS zone / domain (e.g., mcloud.mikecloud.com)"
  type        = string
  default     = "mcloud.mikecloud.com"
}

# --------------------------------------------------------------------------------
# Kerberos realm
# Example: "MCLOUD.MIKECLOUD.COM"
# Always set to the uppercase version of dns_zone.
# Kerberos authentication (kinit, tickets, etc.) is realm-sensitive and
# will fail if this is lowercase or mismatched.
# --------------------------------------------------------------------------------
variable "realm" {
  description = "Kerberos realm (usually DNS zone in UPPERCASE, e.g., MCLOUD.MIKECLOUD.COM)"
  type        = string
  default     = "MCLOUD.MIKECLOUD.COM"
}

# --------------------------------------------------------------------------------
# NetBIOS domain name
# Example: "MCLOUD"
# Used by legacy systems and SMB/CIFS clients.
# Must be <= 15 characters, uppercase, and alphanumeric only.
# This name shows up in old-style logons (DOMAIN\user).
# --------------------------------------------------------------------------------
variable "netbios" {
  description = "NetBIOS short domain name (e.g., MCLOUD)"
  type        = string
  default     = "MCLOUD"
}

# --------------------------------------------------------------------------------
# User base Distinguished Name (DN)
# Example: "CN=Users,DC=mcloud,DC=mikecloud,DC=com"
# This is the LDAP subtree where new users will be created by default.
# If omitted, Samba defaults to CN=Users in your domain partition.
# --------------------------------------------------------------------------------
variable "user_base_dn" {
  description = "User base DN for LDAP (e.g., CN=Users,DC=mcloud,DC=mikecloud,DC=com)"
  type        = string
  default     = "CN=Users,DC=mcloud,DC=mikecloud,DC=com"
}

# --------------------------------------------------------------------------------
# GCP zone for VM deployment
# Example: "us-central1-a"
# This determines the physical availability zone where the AD VM will be created.
# --------------------------------------------------------------------------------
variable "zone" {
  description = "GCP zone for deployment (e.g., us-central1-a)"
  type        = string
  default     = "us-central1-a"
}

# --------------------------------------------------------------------------------
# Machine type
# Example: "e2-small"
# Defines CPU and memory allocated to the VM.
# e2-small (2 vCPU, 2 GB RAM) is a reasonable minimum for a lightweight DC,
# but you can scale up (e2-medium, n2-standard-2, etc.) for higher performance
# --------------------------------------------------------------------------------
variable "machine_type" {
  description = "Machine type for mini AD instance (minimum is e2-small)"
  type        = string
  default     = "e2-medium"
}

# --------------------------------------------------------------------------------
# Network
# Example: "ad-vpc"
# The VPC network in GCP where the AD VM will be deployed.
# AD requires low-latency networking for replication, so place in the correct VPC.
# --------------------------------------------------------------------------------
variable "network" {
  description = "Network for mini AD instance (e.g., ad-vpc)"
  type        = string
  default     = "ad-vpc"
}

# --------------------------------------------------------------------------------
# Subnetwork
# Example: "ad-subnet"
# The subnet inside the chosen VPC where the VM will live.
# Ensure that DNS and LDAP ports are open in firewall rules for clients to join.
# --------------------------------------------------------------------------------
variable "subnetwork" {
  description = "Sub-network for mini AD instance (e.g., ad-subnet)"
  type        = string
  default     = "ad-subnet"
}

# --------------------------------------------------------------------------------
# Users JSON
# Example: JSON string with user/group definitions.
# Passed to the VM at bootstrap to seed users and groups in AD automatically.
# Typically rendered from users.json.template with Terraform templatefile().
# --------------------------------------------------------------------------------
variable "users_json" {
  description = "Pre-rendered JSON string containing user account definitions (from users.json.template)."
  type        = string
  default     = ""
}

# --------------------------------------------------------------------------------
# AD Administrator password
# This password is applied to both:
#   - The built-in 'Administrator' account
#   - A bootstrap 'Admin' account (Domain Admins member)
# Must meet Samba/Kerberos complexity (>= 8 chars, mixed case, numbers/symbols).
# Marked sensitive so Terraform does not log or display it.
# --------------------------------------------------------------------------------
variable "ad_admin_password" {
  description = "Password for the AD Administrator and Admin account used in Samba bootstrap."
  type        = string
  sensitive   = true
}

# --------------------------------------------------------------------------------
# Email
# Example: "admin@mikecloud.com"
# A generic email input you can use for ownership, labels, or security scopes.
# Can also be used to configure alerts or IAM bindings in GCP if extended.
# --------------------------------------------------------------------------------
variable "email" {
  description = "Email for security scope"
  type        = string
}
