variable "name" {
  description = "Lima 인스턴스 이름"
  type        = string
}

variable "vcpu" {
  description = "vCPU 개수"
  type        = number
  default     = 2
}

variable "memory_gib" {
  description = "메모리 (GiB). k3s server + ArgoCD 구동에는 최소 4 권장"
  type        = number
  default     = 4
}

variable "disk_gib" {
  description = "디스크 크기 (GiB)"
  type        = number
  default     = 20
}

variable "image_url" {
  description = "Ubuntu 클라우드 이미지 URL (Apple Silicon용 arm64/aarch64 이미지)"
  type        = string
  default     = "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-arm64.img"
}

variable "ssh_username" {
  description = "생성할 접속 계정명"
  type        = string
  default     = "ubuntu"
}

variable "ssh_public_key" {
  description = "등록할 SSH 공개키 (OpenSSH 형식)"
  type        = string
}
