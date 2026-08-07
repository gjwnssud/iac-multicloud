terraform {
  required_version = ">= 1.7.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }

  # 초기에는 local backend로 시작. GCS 버킷 프로비저닝(Phase 5) 이후 아래로 전환:
  # backend "gcs" {
  #   bucket = "iac-multicloud-tfstate"
  #   prefix = "gcp"
  # }
}
