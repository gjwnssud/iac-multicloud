output "instance_id" {
  description = "libvirt 도메인 ID"
  value       = libvirt_domain.this.id
}

output "instance_ip" {
  description = "DHCP로 할당된 인스턴스 IP (부팅 후 리스 획득 시까지 대기)"
  value       = libvirt_domain.this.network_interface[0].addresses[0]
}
