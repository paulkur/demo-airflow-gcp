terraform {
  required_version = ">=0.13"

  required_providers {
    google = {
      source  = "hashicorp/google"
	  #version = ">= 4.58.0"
	  version = ">= 4.74.0"
      #version = "5.10.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
	  version = ">= 4.58.0"
      #version = ">= 4.74.0"
	  #version = "5.10.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.18.1"
	  #version = "2.24.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.4"
    }
    github = {
      source  = "integrations/github"
      version = ">= 5.36.0"
	  #version = "5.42.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.4.3"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.11.0"
	  #version = "2.12.1"
    }
  }
}

provider "google" {
  project = var.project_id
  credentials = file(var.gcp_auth_file)
}

provider "kubernetes" {
  host                   = module.gke_auth.host
  token                  = module.gke_auth.token
  cluster_ca_certificate = module.gke_auth.cluster_ca_certificate
}

provider "helm" {
  kubernetes {
    cluster_ca_certificate = module.gke_auth.cluster_ca_certificate
    host                   = module.gke_auth.host
    token                  = module.gke_auth.token
  }
}

provider "github" {
  owner = "paulkur"
  token = var.token
}