variable "name" {
  description = "인스턴스 이름"
  type        = string
}

variable "resource_group_name" {
  description = "network 모듈 output.resource_group_name"
  type        = string
}

variable "location" {
  description = "network 모듈 output.location"
  type        = string
}

variable "instance_type" {
  description = "VM 크기"
  type        = string
  default     = "Standard_B1s"
}

variable "image" {
  description = "VM 이미지 참조"
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  default = {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}

variable "subnet_id" {
  description = "network 모듈 output.subnet_id"
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
  description = "공통 태그"
  type        = map(string)
  default     = {}
}
