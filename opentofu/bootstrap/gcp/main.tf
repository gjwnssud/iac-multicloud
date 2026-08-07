# tofu state를 저장할 GCS 버킷을 만드는 1회성 부트스트랩.
# 이 스택 자체는 local state로 관리한다 (chicken-and-egg 문제).
# environments/gcp는 이 리소스가 생성된 뒤 partial backend config로 연결한다.

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = var.project
  region  = var.region
}

resource "google_storage_bucket" "tfstate" {
  name                        = var.bucket_name
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = false

  versioning {
    enabled = true
  }
}
