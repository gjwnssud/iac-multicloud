variable "name" {
  description = "리소스 이름 접두사"
  type        = string
}

variable "cidr_block" {
  description = "VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "퍼블릭 서브넷 CIDR"
  type        = string
  default     = "10.0.1.0/24"
}

variable "availability_zone" {
  description = "서브넷을 배치할 AZ. null이면 사용 가능한 첫 번째 AZ 사용"
  type        = string
  default     = null
}

variable "allowed_ssh_cidrs" {
  description = "SSH(22/tcp) 접근을 허용할 CIDR 목록"
  type        = list(string)
}

variable "tags" {
  description = "공통 태그"
  type        = map(string)
  default     = {}
}
