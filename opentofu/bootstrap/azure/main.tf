# tofu state를 저장할 Storage Account + Container를 만드는 1회성 부트스트랩.
# 이 스택 자체는 local state로 관리한다 (chicken-and-egg 문제).
# environments/azure는 이 리소스가 생성된 뒤 partial backend config로 연결한다.

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "tfstate" {
  name     = "${var.name_prefix}-rg"
  location = var.location
}

resource "azurerm_storage_account" "tfstate" {
  name                     = replace(var.name_prefix, "-", "")
  resource_group_name      = azurerm_resource_group.tfstate.name
  location                 = azurerm_resource_group.tfstate.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  blob_properties {
    versioning_enabled = true
  }
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.tfstate.name
  container_access_type = "private"
}
