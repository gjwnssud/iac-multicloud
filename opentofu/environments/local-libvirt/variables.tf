variable "libvirt_uri" {
  description = "libvirt 연결 URI"
  type        = string
  default     = "qemu:///system"
}

variable "name" {
  description = "리소스 이름 접두사"
  type        = string
  default     = "iac-multicloud-local"
}

variable "image" {
  description = "베이스 이미지 경로 또는 URL (qcow2)"
  type        = string
}

variable "vcpu" {
  description = "vCPU 개수"
  type        = number
  default     = 2
}

variable "memory_mb" {
  description = "메모리 (MB)"
  type        = number
  default     = 2048
}

variable "ssh_username" {
  description = "cloud-init으로 생성할 접속 계정명"
  type        = string
  default     = "ubuntu"
}

variable "ssh_public_key" {
  description = "cloud-init에 등록할 SSH 공개키"
  type        = string
}

variable "ssh_private_key_path" {
  description = "ssh_public_key에 대응하는 로컬 개인키 경로. 비워두면 ansible inventory에 명시하지 않음"
  type        = string
  default     = ""
}
