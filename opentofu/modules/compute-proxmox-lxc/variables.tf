variable "name" {
  description = "CT 호스트명 (Proxmox 이름 겸용)"
  type        = string
}

variable "node_name" {
  description = "CT를 만들 Proxmox 노드 이름 (예: pve)"
  type        = string
}

variable "template_vmid" {
  description = "clone할 CT 템플릿 ID (proxmox-lxc-template 롤이 만든 템플릿, 기본 9100)"
  type        = number
  default     = 9100
}

variable "datastore_id" {
  description = "rootfs를 만들 datastore"
  type        = string
  default     = "local-lvm"
}

variable "bridge" {
  description = "CT NIC를 붙일 Proxmox 브리지"
  type        = string
  default     = "vmbr0"
}

variable "ip_address" {
  description = "고정 IPv4 (CIDR 형식, 예: 10.77.0.111/24)"
  type        = string
}

variable "gateway" {
  description = "IPv4 게이트웨이"
  type        = string
}

variable "dns_servers" {
  description = "CT가 쓸 DNS 서버 목록. 비우면 gateway를 DNS로 사용"
  type        = list(string)
  default     = []
}

variable "vcpu" {
  description = "CPU 코어 수"
  type        = number
  default     = 1
}

variable "memory_mb" {
  description = "메모리 (MB)"
  type        = number
  default     = 1024
}

variable "swap_mb" {
  description = "스왑 (MB)"
  type        = number
  default     = 512
}

variable "disk_size_gb" {
  description = "rootfs 크기 (GB). 템플릿 rootfs(기본 8GB)보다 작으면 안 됨 (clone 시 늘리기만 가능)"
  type        = number
  default     = 16
}

variable "start_on_boot" {
  description = "Proxmox 호스트 부팅 시 CT 자동 시작 여부"
  type        = bool
  default     = true
}

variable "ssh_public_key" {
  description = "root 계정에 등록할 SSH 공개키 (OpenSSH 형식)"
  type        = string
}

variable "extra_ssh_public_keys" {
  description = "ssh_public_key 외에 root에 추가로 등록할 SSH 공개키 목록 (다른 장비에서 접속할 때)"
  type        = list(string)
  default     = []
}
