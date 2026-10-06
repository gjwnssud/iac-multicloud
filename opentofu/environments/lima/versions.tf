terraform {
  required_version = ">= 1.7.0"

  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.0"
    }
  }

  # macOS 로컬 개발용 환경이라 원격 backend 없이 로컬 state를 그대로 사용
}
