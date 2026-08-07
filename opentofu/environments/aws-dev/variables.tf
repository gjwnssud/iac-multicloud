variable "region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "name" {
  description = "리소스 이름 접두사"
  type        = string
  default     = "iac-multicloud-aws-dev"
}

variable "instance_type" {
  description = "EC2 인스턴스 타입"
  type        = string
  default     = "t3.micro"
}

variable "image" {
  description = "AMI ID"
  type        = string
}

variable "allowed_ssh_cidrs" {
  description = "SSH 접근을 허용할 CIDR 목록"
  type        = list(string)
}

variable "ssh_public_key" {
  description = "인스턴스에 등록할 SSH 공개키"
  type        = string
}

variable "ssh_username" {
  description = "SSH 접속 계정명 (AMI 기본 사용자, 예: ubuntu)"
  type        = string
  default     = "ubuntu"
}

variable "ssh_private_key_path" {
  description = "ssh_public_key에 대응하는 로컬 개인키 경로. 비워두면 ansible inventory에 명시하지 않음"
  type        = string
  default     = ""
}
