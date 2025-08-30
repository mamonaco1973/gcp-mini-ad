# ==========================================================================================
# OUTPUT: dns_server
# ==========================================================================================
# Purpose:
#   - Exposes the internal IP address of the AD DC instance.
#   - This IP is used as the primary DNS server for clients that need to
#     resolve Active Directory–integrated records (e.g., _ldap._tcp, _kerberos._tcp).
#
# Usage:
#   - Terraform will print this value after `apply`.
#   - You can reference it in other modules, or inject into VM configs / resolv.conf.
#
# Notes:
#   - Value is the NIC’s private IP (not public), ensuring clients in the same
#     VPC/subnet can query the DC directly.
# ==========================================================================================

output "dns_server" {
  description = "DNS server IP address for the mini-ad deployment."
  value       = google_compute_instance.mini_ad_dc_instance.network_interface[0].network_ip
}
