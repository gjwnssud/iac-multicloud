output "network_id" {
  description = "VPC 네트워크 ID"
  value       = google_compute_network.this.id
}

output "subnet_id" {
  description = "서브넷 ID"
  value       = google_compute_subnetwork.this.id
}

output "network_tag" {
  description = "SSH 방화벽 규칙이 적용되는 대상 태그. compute 인스턴스의 tags에 포함시켜야 함"
  value       = var.name
}
