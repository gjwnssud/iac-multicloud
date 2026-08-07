output "instance_id" {
  description = "VM ID"
  value       = azurerm_linux_virtual_machine.this.id
}

output "instance_ip" {
  description = "VM 퍼블릭 IP"
  value       = azurerm_public_ip.this.ip_address
}
