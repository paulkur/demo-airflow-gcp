
module "gke" {
  source            = "terraform-google-modules/kubernetes-engine/google//modules/beta-public-cluster"
  project_id        = module.network.project_id
  name              = "gke-cluster-${random_id.suffix.hex}"
  region            = var.region
  zones             = [var.zone]
  network           = module.network.network_name
  subnetwork        = module.network.subnets_names[0]
  ip_range_pods     = "subnet-secondary-gke-pods"
  ip_range_services = "subnet-secondary-gke-services"

  node_pools = [
    {
      name               = "default-node-pool"
      machine_type       = var.cluster_machine_type
      node_locations     = var.zone
      min_count          = 1
      max_count          = 2
      disk_size_gb       = 30
      disk_type          = "pd-standard"
      image_type         = "COS_CONTAINERD"
      initial_node_count = 1
    }
  ]
}