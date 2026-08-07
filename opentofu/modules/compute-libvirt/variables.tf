variable "name" {
  description = "도메인(VM) 이름"
  type        = string
}

variable "network_id" {
  description = "network 모듈 output.network_id"
  type        = string
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
  description = "메모리 (MB). k3s server + ArgoCD 구동에는 최소 4096 권장"
  type        = number
  default     = 4096
}

variable "disk_size_gb" {
  description = "디스크 크기 (GB)"
  type        = number
  default     = 20
}

variable "ssh_username" {
  description = "cloud-init으로 생성할 접속 계정명"
  type        = string
  default     = "ubuntu"
}

variable "ssh_public_key" {
  description = "cloud-init에 등록할 SSH 공개키 (OpenSSH 형식)"
  type        = string
}

variable "pool" {
  description = "볼륨을 생성할 libvirt storage pool 이름"
  type        = string
  default     = "default"
}
