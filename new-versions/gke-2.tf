# gke.tf
resource "kubernetes_namespace" "namespaces" {
  for_each = toset(["airflow"])
  metadata {
    annotations = {
      name = each.value
    }
    labels = {
      istio-injection = "enabled"
    }
    name = each.value
  }
  depends_on = [module.kubernetes-engine_private-cluster-update-variant]
}

module "kubernetes-engine_private-cluster-update-variant" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/private-cluster-update-variant"
  version = "29.0.0"

  project_id = var.project_id
  name       = "${var.gcp_app_name}-gke-test"

  network_project_id = var.project_id
  network            = module.network.network_name
  subnetwork         = module.network.subnets["europe-west1/subnet-europe-west1-01"].name

  ip_range_pods     = "gke-pods"
  ip_range_services = "gke-services"

  region = var.gcp_region
  zones  = var.gcp_zones

  grant_registry_access = true
  registry_project_ids  = [var.project_id]

  default_max_pods_per_node = 55
  remove_default_node_pool  = true

  enable_private_nodes = true

  master_ipv4_cidr_block = "192.168.0.0/28" # default value
  master_authorized_networks = [
    {
      cidr_block   = "0.0.0.0/0"
      display_name = "all"
    },
  ]

  enable_vertical_pod_autoscaling = true
  cluster_autoscaling = {
    enabled             = true
    autoscaling_profile = "OPTIMIZE_UTILIZATION"
    min_cpu_cores       = 1
    max_cpu_cores       = 200
    min_memory_gb       = 1
    max_memory_gb       = 200
    auto_repair         = true
    auto_upgrade        = true
    gpu_resources       = []
  }
}

module "gke_auth" {
  source               = "terraform-google-modules/kubernetes-engine/google//modules/auth"
  version              = "29.0.0"
  project_id           = var.project_id
  cluster_name         = module.kubernetes-engine_private-cluster-update-variant.name
  location             = module.kubernetes-engine_private-cluster-update-variant.location
}