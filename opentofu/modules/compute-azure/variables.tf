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
  description = "VM 크기. k3s server + ArgoCD 구동에는 최소 4GB RAM 권장 (B1s/B1ms는 OOM 위험)"
  type        = string
  default     = "Standard_B2s"
}

variable "root_volume_size_gb" {
  description = "OS 디스크 크기 (GB). containerd 이미지 캐시 공간 확보용"
  type        = number
  default     = 20
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
