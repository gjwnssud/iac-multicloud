variable "name" {
  description = "인스턴스 이름"
  type        = string
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

variable "subnet_id" {
  description = "network 모듈 output.subnet_id"
  type        = string
}

variable "security_group_id" {
  description = "network 모듈 output.security_group_id"
  type        = string
}

variable "ssh_public_key" {
  description = "인스턴스에 등록할 SSH 공개키 (OpenSSH 형식)"
  type        = string
}

variable "tags" {
  description = "공통 태그"
  type        = map(string)
  default     = {}
}
