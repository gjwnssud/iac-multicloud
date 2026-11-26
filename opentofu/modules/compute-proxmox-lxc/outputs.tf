output "instance_id" {
  description = "Proxmox CT ID"
  value       = proxmox_virtual_environment_container.this.vm_id
}

output "instance_ip" {
  description = "고정 할당한 인스턴스 IP (CIDR 접미사 제거)"
  value       = split("/", var.ip_address)[0]
}
