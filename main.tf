# demo-airflow-gcp # main.tf
module "airflow" {
  source = "github.com/paulkur/terraform-astrafy-gcp-airflow-module//?ref=paulk-dev-branch"

  project_id = var.project_id
  region     = "europe-west1"
  #region = var.gcp_region
  #gcp_region = var.gcp_region

  sql_private_network   = module.network.network_id
  dags_repository       = "test-airflow-dags"
  k8s_airflow_namespace = "airflow"

  #airflow_version		= "1.11.0"
  #deploy_cloud_sql		= true
  #deploy_github_keys	= true
  #create_redis_secrets	= true
  #airflow_logs_bucket_name = "airflow-logs"
  #sql_delete_protection	= false
  #airflow_logs_sa		= "paul@hpdafund.com"

  deploy_airflow = true

  airflow_values_filepath = "${path.module}/values.yaml"

  depends_on = [google_service_networking_connection.vpc_connection, kubernetes_namespace.namespaces]
}

