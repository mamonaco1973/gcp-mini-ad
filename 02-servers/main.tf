# Google Cloud Provider Configuration
# Configures the Google Cloud provider using project details and credentials from a JSON file.
provider "google" {
  project     = local.credentials.project_id             # Specifies the project ID extracted from the decoded credentials file.
  credentials = file("../credentials.json")               # Path to the credentials JSON file for Google Cloud authentication.
}

# Local Variables
# Reads and decodes the credentials JSON file to extract useful details like project ID and service account email.
locals {
  credentials            = jsondecode(file("../credentials.json")) # Decodes the JSON file into a map for easier access.
  service_account_email  = local.credentials.client_email          # Extracts the service account email from the decoded JSON map.
}


data "google_compute_network" "ad_vpc" {
  name = "ad-vpc"
}

data "google_compute_subnetwork" "ad_subnet" {
  name    = "ad-subnet"
  region  = "us-central1"  
}