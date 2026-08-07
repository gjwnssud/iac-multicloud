output "instance_ids" {
  value = { for k, m in module.compute : k => m.instance_id }
}

output "instance_ips" {
  value = { for k, m in module.compute : k => m.instance_ip }
}
