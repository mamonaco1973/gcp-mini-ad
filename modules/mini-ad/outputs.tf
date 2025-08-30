
output "dns_server" {
  description = "DNS server IP address for the mini-ad deployment."
  value       = google_compute_instance.mini_ad_dc_instance.network_interface[0].network_ip
}
