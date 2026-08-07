terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }

  # opentofu/bootstrap/azure를 먼저 apply해 Storage Account를 만든 뒤
  # partial config로 연결한다 (CI는 plan.yml/deploy.yml 참고):
  #   tofu init -backend-config="resource_group_name=<bootstrap output>" \
  #             -backend-config="storage_account_name=<bootstrap output>" \
  #             -backend-config="container_name=tfstate" \
  #             -backend-config="key=azure.terraform.tfstate"
  backend "azurerm" {}
}
