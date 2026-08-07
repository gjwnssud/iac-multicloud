terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  # 초기에는 local backend로 시작. Storage Account 프로비저닝(Phase 5) 이후 아래로 전환:
  # backend "azurerm" {
  #   resource_group_name  = "iac-multicloud-tfstate-rg"
  #   storage_account_name = "iacmulticloudtfstate"
  #   container_name       = "tfstate"
  #   key                  = "azure-dev.terraform.tfstate"
  # }
}
