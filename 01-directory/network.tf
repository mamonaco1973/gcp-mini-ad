# This resource defines a **Custom Mode VPC** in Google Cloud.
# "Custom Mode" means you are responsible for explicitly defining all subnets — GCP will NOT auto-create default subnets for you.
# This is preferred for tightly controlled network architectures, like when setting up Active Directory or other enterprise systems.

resource "google_compute_network" "ad_vpc" {

  # The name of the VPC network being created.
  # This must be unique within the project and will be referenced by subnets, firewall rules, etc.

  name = "ad-vpc"

  # Disables automatic subnet creation.
  # In "auto mode" GCP would create one subnet per region, with pre-defined CIDR ranges.
  # We don't want that here — we want to explicitly define our own subnets (custom mode).
  
  auto_create_subnetworks = false
}

# This resource defines a **single subnet** inside the previously created VPC.
# In GCP, a subnet lives within exactly one region and is assigned a specific CIDR block.

resource "google_compute_subnetwork" "ad_subnet" {

  # Name of the subnet — this must be unique within the parent VPC.

  name = "ad-subnet"

  # The region where this subnet will exist.
  # This must match the region(s) where you plan to deploy resources like VMs or Managed AD.

  region = "us-central1"

  # This ties the subnet directly to the `ad_vpc` network defined above.
  # The `.id` returns the full self-link identifier for the VPC (projects/<project-id>/global/networks/ad-vpc).

  network = google_compute_network.ad_vpc.id

  # Defines the IPv4 address range for this subnet in standard CIDR notation.
  # This range must:
  # - Be within the overall range of the VPC (if it's restricted by an org policy or other means)
  # - NOT overlap with any other subnet in the VPC
  # - Be large enough to accommodate the resources you want to place in the subnet

  ip_cidr_range = "10.1.0.0/24"
}
