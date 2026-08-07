output "instance_id" {
  description = "Lima 인스턴스 이름"
  value       = var.name
}

output "instance_ip" {
  description = "Lima shared 네트워크 IP"
  value       = data.external.lima_ip.result.ip
}
