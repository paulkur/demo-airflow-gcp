module "network" {
  source = "terraform-google-modules/network/google"

  project_id   = var.project_id
  network_name = "network-${random_id.suffix.hex}"

  subnets = [
    {
      subnet_name           = "subnet"
      subnet_ip             = "10.6.0.0/20"
      subnet_region         = var.region
      subnet_private_access = false
    }
  ]

  secondary_ranges = {
    subnet = [
      {
        range_name    = "subnet-secondary-gke-pods"
        ip_cidr_range = "10.196.0.0/14"
      },
      {
        range_name    = "subnet-secondary-gke-services"
        ip_cidr_range = "10.200.0.0/20"
      }
    ]
  }
}

module "cloud_router" {
  source  = "terraform-google-modules/cloud-router/google"

  name    = "router-shared-host"
  project = var.project_id
  region = "europe-west1"
  #region = var.gcp_region
  network = module.network.network_name
  nats = [
    {
      name = "nat-shared-host"
    }
  ]
}

resource "google_compute_global_address" "private_ip_alloc" {
  project       = var.project_id
  name          = "airflow-db-ip"
  address_type  = "INTERNAL"
  purpose       = "VPC_PEERING"
  prefix_length = 16
  network       = module.network.network_id
  address       = "10.81.0.0"
}

resource "google_service_networking_connection" "vpc_connection" {
  network                 = module.network.network_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_alloc.name]
}