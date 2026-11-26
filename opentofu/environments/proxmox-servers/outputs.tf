output "vm_ips" {
  description = "VM 이름 → IP (ssh <ssh_username>@IP)"
  value       = { for k, m in module.vm : k => m.instance_ip }
}

output "vm_ids" {
  value = { for k, m in module.vm : k => m.instance_id }
}

output "container_ips" {
  description = "CT 이름 → IP (ssh root@IP)"
  value       = { for k, m in module.container : k => m.instance_ip }
}

output "container_ids" {
  value = { for k, m in module.container : k => m.instance_id }
}
