resource "google_secret_manager_secret" "db_user_pass" {
  secret_id = "db-user-pass-${random_id.suffix.hex}"

  replication {
    automatic = true
  }

  depends_on = [module.services.enabled_api_identities]
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