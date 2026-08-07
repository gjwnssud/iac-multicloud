terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }

  # 초기에는 local backend로 시작. S3 버킷 프로비저닝(Phase 5) 이후 아래로 전환:
  # backend "s3" {
  #   bucket = "iac-multicloud-tfstate"
  #   key    = "aws/terraform.tfstate"
  #   region = "ap-northeast-2"
  # }
}
