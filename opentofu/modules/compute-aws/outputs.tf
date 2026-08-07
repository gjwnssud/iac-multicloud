output "instance_id" {
  description = "인스턴스 ID"
  value       = aws_instance.this.id
}

output "instance_ip" {
  description = "인스턴스 퍼블릭 IP"
  value       = aws_instance.this.public_ip
}
