# This resource block creates a Google Managed Active Directory domain within Google Cloud.

resource "google_active_directory_domain" "mikecloud_ad" {

  # The fully qualified domain name (FQDN) of the Active Directory domain being created.
  # This is the "root" of the AD namespace and must follow standard AD naming conventions (e.g., a subdomain of an existing DNS name you own).

  domain_name = "mcloud.mikecloud.com"

  # Specifies the Google Cloud regions where this AD domain will be deployed.
  # Managed AD requires at least one region, but can support multiple for redundancy.
  # In this case, we are deploying to `us-central1` — which is a common GCP region in the central United States.
  
  locations = ["us-central1"]

  # Defines a **/24** IP range that will be reserved exclusively for this AD domain within the VPC network.
  # GCP Managed AD requires a dedicated subnet that it manages — no other resources should use this CIDR block.
  # This range should not overlap with any other subnets in the VPC.
  
  reserved_ip_range = "192.168.255.0/24"

  # Associates this AD domain with a specific VPC network in GCP.
  # This network must already exist (created separately, probably via a `google_compute_network` resource).
  # The AD domain controllers (managed by GCP) will live inside this network.
  # Here, we're dynamically referencing the ID of the `ad_vpc` network, assumed to be defined elsewhere in your Terraform code.
  
  authorized_networks = [google_compute_network.ad_vpc.id]

  # Controls whether or not this AD domain is protected from accidental deletion.
  # Setting this to `false` means the domain can be deleted by Terraform without additional safety checks.
  # For production environments, this is usually `true` to prevent accidental destruction of critical infrastructure.
  
  deletion_protection = false
}
