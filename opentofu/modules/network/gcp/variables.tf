variable "name" {
  description = "리소스 이름 접두사"
  type        = string
}

variable "project" {
  description = "GCP 프로젝트 ID"
  type        = string
}

variable "region" {
  description = "리전"
  type        = string
}

variable "subnet_cidr" {
  description = "서브넷 CIDR"
  type        = string
  default     = "10.0.1.0/24"
}

variable "allowed_ssh_cidrs" {
  description = "SSH(22/tcp) 접근을 허용할 CIDR 목록"
  type        = list(string)
}
