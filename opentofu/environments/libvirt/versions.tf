terraform {
  required_version = ">= 1.7.0"

  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.8.3"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }

  # 로컬 환경은 원격 backend 대신 로컬 state를 그대로 사용 (설계 원칙 5.State 격리 참고)
}
