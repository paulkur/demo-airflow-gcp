# network.tf

locals {
  types  = ["public", "private"]
  subnets = {
    "01" = {
      ip          = element(var.ip_cidr_range, 0)
      region      = var.gcp_region
      description = "Subnet to be used in the D6 GKE cluster"
      secondary_ranges = {
        gke-pods     = element(var.ip_cidr_range_secondary, 0)
        gke-services = element(var.ip_cidr_range_secondary, 1)
      }
    }
  }
}


module "vpc_network" {
  source  = "terraform-google-modules/network/google"
  version = "~> 8.1"

  project_id        = var.project_id
  network_name      = "${var.gcp_app_name}-vpc"
  shared_vpc_host   = false
  routing_mode      = "GLOBAL"

  subnets = var.subnets

  secondary_ranges = { for unique_number, subnet in var.subnets :
    "subnet-${subnet.region}-${unique_number}" => [
      for range_name, range in subnet.secondary_ranges : {
        range_name    = range_name
        ip_cidr_range = range
      }
    ]
  }
}

module "cloud_router" {
  source  = "terraform-google-modules/cloud-router/google"
  version = "~> 6.0"

  name    = "router-shared-host"
  project = var.project_id
  region  = var.gcp_region
  network = module.vpc_network.network_name
  nats    = [
    {
      name = "nat-shared-host"
    }
  ]
}

resource "google_compute_global_address" "private_ip_alloc" {
  name          = "airflow-db-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = module.vpc_network.network_name
}

resource "google_service_networking_connection" "vpc_connection" {
  network                 = module.vpc_network.network_name
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_alloc.name]
}
