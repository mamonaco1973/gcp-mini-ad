# ==============================================================================
# variables.tf - Mini Active Directory Configuration Inputs
# ------------------------------------------------------------------------------
# Purpose:
#   - Defines configurable inputs for the mini Active Directory deployment.
#   - Controls domain naming, LDAP structure, compute sizing, and placement.
#   - Provides safe defaults for a lab / demo environment.
#
# Notes:
#   - Defaults are suitable for development/testing.
#   - Override via terraform.tfvars or CLI for production environments.
# ==============================================================================

# ==============================================================================
# Active Directory Naming Inputs
# ------------------------------------------------------------------------------
# These variables define the logical identity of the AD domain.
# They must remain consistent across Samba configuration, Kerberos, DNS,
# and any client systems joining the domain.
# ==============================================================================

# ------------------------------------------------------------------------------
# dns_zone
# ------------------------------------------------------------------------------
# Fully Qualified Domain Name (FQDN) of the AD domain.
# Used for:
#   - AD DNS namespace
#   - Domain identity
#   - Kerberos principal construction
# Example: mcloud.mikecloud.com
# ------------------------------------------------------------------------------
variable "dns_zone" {
  description = "AD DNS zone / domain (e.g., mcloud.mikecloud.com)"
  type        = string
  default     = "mcloud.mikecloud.com"
}

# ------------------------------------------------------------------------------
# realm
# ------------------------------------------------------------------------------
# Kerberos realm name.
# Convention:
#   - Same value as dns_zone
#   - Entirely UPPERCASE
# Required by Kerberos and Samba AD configuration.
# Example: MCLOUD.MIKECLOUD.COM
# ------------------------------------------------------------------------------
variable "realm" {
  description = "Kerberos realm (usually DNS zone in UPPERCASE, e.g., MCLOUD.MIKECLOUD.COM)"
  type        = string
  default     = "MCLOUD.MIKECLOUD.COM"
}

# ------------------------------------------------------------------------------
# netbios
# ------------------------------------------------------------------------------
# Short (pre-Windows 2000) domain name.
# Constraints:
#   - Typically <= 15 characters
#   - Uppercase alphanumeric
# Used by:
#   - Legacy Windows systems
#   - SMB authentication flows
#   - DOMAIN\username logon format
# Example: MCLOUD
# ------------------------------------------------------------------------------
variable "netbios" {
  description = "NetBIOS short domain name (e.g., MCLOUD)"
  type        = string
  default     = "MCLOUD"
}

# ==============================================================================
# LDAP Structure
# ==============================================================================

# ------------------------------------------------------------------------------
# user_base_dn
# ------------------------------------------------------------------------------
# Base Distinguished Name (DN) where user objects will be created.
# Determines LDAP placement of new accounts.
# Example:
#   CN=Users,DC=mcloud,DC=mikecloud,DC=com
# ------------------------------------------------------------------------------
variable "user_base_dn" {
  description = "User base DN for LDAP (e.g., CN=Users,DC=mcloud,DC=mikecloud,DC=com)"
  type        = string
  default     = "CN=Users,DC=mcloud,DC=mikecloud,DC=com"
}

# ==============================================================================
# Compute & Placement Configuration
# ==============================================================================

# ------------------------------------------------------------------------------
# zone
# ------------------------------------------------------------------------------
# Specific GCP availability zone where the mini AD VM will be deployed.
# Must align with:
#   - The subnet region
#   - Any regional networking constraints
# Example: us-central1-a
# ------------------------------------------------------------------------------
variable "zone" {
  description = "GCP zone for deployment (e.g., us-central1-a)"
  type        = string
  default     = "us-central1-a"
}

# ------------------------------------------------------------------------------
# machine_type
# ------------------------------------------------------------------------------
# GCP machine type used for the mini AD instance.
# Minimum recommendation: e2-small
# Default (e2-medium) provides additional headroom for:
#   - Samba AD services
#   - DNS
#   - Authentication load
# ------------------------------------------------------------------------------
variable "machine_type" {
  description = "Machine type for mini AD instance (minimum is e2-small)"
  type        = string
  default     = "e2-small"
}

# ==============================================================================
# Networking Inputs
# ==============================================================================

# ------------------------------------------------------------------------------
# vpc_name
# ------------------------------------------------------------------------------
# Name of the VPC network where the mini AD instance will be deployed.
# Should match an existing google_compute_network resource.
# Example: ad-vpc
# ------------------------------------------------------------------------------
variable "vpc_name" {
  description = "Network for mini AD instance (e.g., ad-vpc)"
  type        = string
  default     = "mini-ad-vpc"
}

# ------------------------------------------------------------------------------
# subnet_name
# ------------------------------------------------------------------------------
# Name of the subnet within the VPC where the mini AD VM will attach.
# Must exist in the same region as the selected zone.
# Example: ad-subnet
# ------------------------------------------------------------------------------
variable "subnet_name" {
  description = "Sub-network for mini AD instance (e.g., ad-subnet)"
  type        = string
  default     = "mini-ad-subnet"
}