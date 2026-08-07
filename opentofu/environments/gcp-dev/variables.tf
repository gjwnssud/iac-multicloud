variable "project" {
  description = "GCP 프로젝트 ID"
  type        = string
}

variable "region" {
  description = "리전"
  type        = string
  default     = "asia-northeast3"
}

variable "zone" {
  description = "인스턴스를 배치할 존"
  type        = string
  default     = "asia-northeast3-a"
}

variable "name" {
  description = "리소스 이름 접두사"
  type        = string
  default     = "iac-multicloud-gcp-dev"
}

variable "instance_type" {
  description = "머신 타입"
  type        = string
  default     = "e2-medium"
}

variable "image" {
  description = "부팅 이미지"
  type        = string
  default     = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
}

variable "allowed_ssh_cidrs" {
  description = "SSH 접근을 허용할 CIDR 목록"
  type        = list(string)
}

variable "ssh_username" {
  description = "SSH 접속 계정명"
  type        = string
}

variable "ssh_public_key" {
  description = "인스턴스에 등록할 SSH 공개키"
  type        = string
}
