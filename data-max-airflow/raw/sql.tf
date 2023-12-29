module "private-service-access" {
  source = "GoogleCloudPlatform/sql-db/google//modules/private_service_access"

  project_id  = var.project_id
  vpc_network = module.network.network_name
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