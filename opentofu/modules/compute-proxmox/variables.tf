variable "name" {
  description = "VM 이름"
  type        = string
}

variable "node_name" {
  description = "VM을 만들 Proxmox 노드 이름 (예: pve)"
  type        = string
}

variable "template_vmid" {
  description = "clone할 cloud-init 템플릿 VM ID (Ubuntu cloud image 기반 템플릿)"
  type        = number
}

variable "datastore_id" {
  description = "디스크와 cloud-init 드라이브를 만들 datastore"
  type        = string
  default     = "local-lvm"
}

variable "bridge" {
  description = "VM NIC를 붙일 Proxmox 브리지"
  type        = string
  default     = "vmbr0"
}

variable "ip_address" {
  description = "고정 IPv4 (CIDR 형식, 예: 192.168.0.130/24)"
  type        = string
}

variable "gateway" {
  description = "IPv4 게이트웨이"
  type        = string
}

variable "vcpu" {
  description = "vCPU 개수"
  type        = number
  default     = 2
}

variable "memory_mb" {
  description = "메모리 (MB). k3s server + ArgoCD 구동에는 최소 4096 권장"
  type        = number
  default     = 4096
}

variable "disk_size_gb" {
  description = "디스크 크기 (GB). 템플릿 디스크보다 작으면 안 됨"
  type        = number
  default     = 20
}

variable "ssh_username" {
  description = "접속 계정명. sudo NOPASSWD는 cloud image 기본 계정(ubuntu)만 보장되므로 기본값 유지 권장"
  type        = string
  default     = "ubuntu"
}

variable "ssh_public_key" {
  description = "cloud-init에 등록할 SSH 공개키 (OpenSSH 형식)"
  type        = string
}
