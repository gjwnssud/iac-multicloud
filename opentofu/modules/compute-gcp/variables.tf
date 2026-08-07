variable "name" {
  description = "인스턴스 이름"
  type        = string
}

variable "project" {
  description = "GCP 프로젝트 ID"
  type        = string
}

variable "zone" {
  description = "인스턴스를 배치할 존"
  type        = string
}

variable "instance_type" {
  description = "머신 타입"
  type        = string
  default     = "e2-medium"
}

variable "image" {
  description = "부팅 이미지 (예: ubuntu-os-cloud/ubuntu-2404-lts-amd64)"
  type        = string
}

variable "root_volume_size_gb" {
  description = "부팅 디스크 크기 (GB). containerd 이미지 캐시 공간 확보용"
  type        = number
  default     = 20
}

variable "subnet_id" {
  description = "network 모듈 output.subnet_id"
  type        = string
}

variable "network_tag" {
  description = "network 모듈 output.network_tag (SSH 방화벽 규칙 적용 대상)"
  type        = string
}

variable "ssh_username" {
  description = "SSH 접속 계정명"
  type        = string
}

variable "ssh_public_key" {
  description = "인스턴스에 등록할 SSH 공개키 (OpenSSH 형식)"
  type        = string
}

variable "tags" {
  description = "공통 라벨"
  type        = map(string)
  default     = {}
}
