output "instance_id" {
  description = "인스턴스 ID"
  value       = google_compute_instance.this.instance_id
}

output "instance_ip" {
  description = "인스턴스 외부 IP"
  value       = google_compute_instance.this.network_interface[0].access_config[0].nat_ip
}
