output "network_id" {
  description = "VPC ID"
  value       = aws_vpc.this.id
}

output "subnet_id" {
  description = "서브넷 ID"
  value       = aws_subnet.this.id
}

output "security_group_id" {
  description = "SSH 허용 보안 그룹 ID"
  value       = aws_security_group.this.id
}
