output "network_id" {
  description = "libvirt 네트워크 ID"
  value       = libvirt_network.this.id
}

output "subnet_cidr" {
  description = "네트워크 CIDR"
  value       = var.subnet_cidr
}
