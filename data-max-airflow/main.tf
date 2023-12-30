module "cloudresourcemanager_service" {
  source = "terraform-google-modules/project-factory/google//modules/project_services"

  project_id                  = var.project_id
  enable_apis                 = var.enable_apis
  disable_services_on_destroy = var.disable_services_on_destroy
  disable_dependent_services  = var.disable_dependent_services

  activate_apis = [
    "cloudresourcemanager.googleapis.com",
  ]
}

module "services" {
  source = "terraform-google-modules/project-factory/google//modules/project_services"

  project_id                  = module.cloudresourcemanager_service.project_id
  enable_apis                 = var.enable_apis
  disable_services_on_destroy = var.disable_services_on_destroy
  disable_dependent_services  = var.disable_dependent_services

  activate_apis = [
    "compute.googleapis.com",
    "iam.googleapis.com",
    "container.googleapis.com",
    "sqladmin.googleapis.com",
    "servicenetworking.googleapis.com",
    "secretmanager.googleapis.com"
  ]
}
module "private-service-access" {
  source = "GoogleCloudPlatform/sql-db/google//modules/private_service_access"

  project_id  = var.project_id
  vpc_network = module.network.network_name
}

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

  deletion_protection = false

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

module "sql-db" {
  source = "GoogleCloudPlatform/sql-db/google//modules/postgresql"

  name                 = "db-${random_id.suffix.hex}"
  random_instance_name = false
  database_version     = "POSTGRES_14"
  project_id           = var.project_id
  zone                 = var.zone
  region               = var.region
  tier                 = var.db_tier

  deletion_protection = false

  additional_databases = [
    {
      name      = "airflow-db"
      charset   = "UTF8"
      collation = "en_US.UTF8"
    },
    {
      name      = "metabase-db"
      charset   = "UTF8"
      collation = "en_US.UTF8"
    }
  ]

  additional_users = [
    {
      name     = "postgres0"
      password = data.google_secret_manager_secret_version.db_user_pass.secret_data
      host     = "localhost"
      random_password = false  # Add this line to generate a random password
    }
  ]

  ip_configuration = {
    ipv4_enabled        = false
    private_network     = module.network.network_self_link
    require_ssl         = false
    allocated_ip_range  = module.private-service-access.google_compute_global_address_name
    authorized_networks = []
  }

  module_depends_on = [module.private-service-access.peering_completed]
}

resource "helm_release" "airflow" {
  name             = "airflow"
  repository       = "https://airflow.apache.org"
  chart            = "airflow"
  namespace        = "airflow"
  version          = var.airflow_helm_version
  create_namespace = true
  wait             = false

  set {
    name  = "defaultAirflowTag"
    value = var.airflow_default_tag
  }

  set {
    name  = "airflowVersion"
    value = var.airflow_version
  }

  set {
    name  = "executor"
    value = "KubernetesExecutor"
  }

  set {
    name  = "webserver.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "dags.gitSync.enabled"
    value = true
  }

  set {
    name  = "dags.gitSync.repo"
    value = var.airflow_dag_repo
  }

  set {
    name  = "dags.gitSync.branch"
    value = var.airflow_dag_branch
  }

  set {
    name  = "dags.gitSync.subPath"
    value = var.airflow_dag_dir
  }

  set {
    name  = "dags.gitSync.sshKeySecret"
    value = "airflow-ssh-secret"
  }

  set {
    name  = "extraSecrets.airflow-ssh-secret.data"
    value = "gitSshKey: ${var.airflow_gitSshKey}"
  }

  set {
    name  = "data.metadataConnection.user"
    value = "postgres0"
  }

  set {
    name  = "data.metadataConnection.pass"
    value = data.google_secret_manager_secret_version.db_user_pass.secret_data
  }

  set {
    name  = "data.metadataConnection.host"
    value = module.sql-db.private_ip_address
  }

  set {
    name  = "data.metadataConnection.db"
    value = "airflow-db"
  }

  set {
    name  = "postgresql.enabled"
    value = false
  }

  depends_on = [module.gke.endpoint]

}

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
  depends_on = [module.gke]
}

module "gke_auth" {
  source = "terraform-google-modules/kubernetes-engine/google//modules/auth"

  project_id = var.project_id
  cluster_name = module.gke.name
  location = module.gke.location
}

resource "random_id" "suffix" {
  byte_length = 4
}
resource "random_id" "gke_cluster_suffix" {
  byte_length = 4
}
resource "random_id" "sql_db_suffix" {
  byte_length = 4
}
resource "random_id" "db_user_pass" {
  byte_length = 8
}
resource "google_secret_manager_secret_version" "db_user_pass" {
  secret      = google_secret_manager_secret.db_user_pass.id
  secret_data = random_id.db_user_pass.hex
}
data "google_secret_manager_secret_version" "db_user_pass" {
  secret  = google_secret_manager_secret.db_user_pass.secret_id
  version = "latest"

  depends_on = [google_secret_manager_secret_version.db_user_pass]
}
resource "google_secret_manager_secret" "db_user_pass" {
  secret_id = "db-user-pass-${random_id.suffix.hex}"

  replication {
    auto {}
  }

  depends_on = [module.services.enabled_api_identities]
}