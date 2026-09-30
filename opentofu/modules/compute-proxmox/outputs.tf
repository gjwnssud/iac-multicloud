output "instance_id" {
  description = "Proxmox VM ID"
  value       = proxmox_virtual_environment_vm.this.vm_id
}

output "instance_ip" {
  description = "고정 할당한 인스턴스 IP (CIDR 접미사 제거)"
  value       = split("/", var.ip_address)[0]
}
