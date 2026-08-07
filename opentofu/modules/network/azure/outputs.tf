output "network_id" {
  description = "VNet ID"
  value       = azurerm_virtual_network.this.id
}

output "subnet_id" {
  description = "서브넷 ID"
  value       = azurerm_subnet.this.id
}

output "resource_group_name" {
  description = "리소스 그룹 이름. compute-azure 모듈에서 재사용"
  value       = azurerm_resource_group.this.name
}

output "location" {
  description = "리소스 그룹 리전. compute-azure 모듈에서 재사용"
  value       = azurerm_resource_group.this.location
}
