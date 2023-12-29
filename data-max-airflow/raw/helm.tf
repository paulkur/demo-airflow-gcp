resource "helm_release" "metabase" {
  name             = "metabase"
  repository       = "https://pmint93.github.io/helm-charts"
  chart            = "metabase"
  namespace        = "metabase"
  version          = var.metabase_helm_version
  create_namespace = true
  wait             = false

  set {
    name  = "database.type"
    value = "postgres"
  }

  set {
    name  = "database.host"
    value = module.sql-db.private_ip_address
  }

  set {
    name  = "database.port"
    value = "5432"
  }

  set {
    name  = "database.dbname"
    value = "metabase-db"
  }

  set {
    name  = "database.username"
    value = "postgres0"
  }

  set {
    name  = "database.password"
    value = data.google_secret_manager_secret_version.db_user_pass.secret_data
  }

  set {
    name  = "service.type"
    value = "LoadBalancer"
  }

  depends_on = [module.gke.endpoint]
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