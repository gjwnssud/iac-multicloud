variable "name" {
  description = "libvirt 네트워크 이름"
  type        = string
}

variable "subnet_cidr" {
  description = "NAT 네트워크 CIDR (DHCP 범위 포함)"
  type        = string
  default     = "10.17.0.0/24"
}
