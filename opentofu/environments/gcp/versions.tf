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

  # opentofu/bootstrap/gcp를 먼저 apply해 GCS 버킷을 만든 뒤
  # partial config로 연결한다 (CI는 plan.yml/deploy.yml 참고):
  #   tofu init -backend-config="bucket=<bootstrap output>" \
  #             -backend-config="prefix=gcp"
  backend "gcs" {}
}
