
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