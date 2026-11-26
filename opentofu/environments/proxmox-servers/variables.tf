variable "proxmox_endpoint" {
  description = "Proxmox API 주소 (예: https://10.77.0.100:8006/)"
  type        = string
}

variable "proxmox_api_token" {
  description = "API 토큰 (형식: user@realm!tokenid=secret). null이면 PROXMOX_VE_API_TOKEN 환경변수 사용"
  type        = string
  sensitive   = true
  default     = null
}

variable "proxmox_insecure" {
  description = "자체 서명 인증서 검증 생략. Proxmox 기본 인증서를 그대로 쓰면 true 필요"
  type        = bool
  default     = true
}

variable "node_name" {
  description = "서버를 만들 Proxmox 노드 이름"
  type        = string
  default     = "pve"
}

variable "vm_template_vmid" {
  description = "clone할 cloud-init VM 템플릿 ID (proxmox-template 롤이 만든 템플릿)"
  type        = number
  default     = 9000
}

variable "ct_template_vmid" {
  description = "clone할 CT(LXC) 템플릿 ID (proxmox-lxc-template 롤이 만든 템플릿)"
  type        = number
  default     = 9100
}

variable "datastore_id" {
  description = "디스크를 만들 datastore"
  type        = string
  default     = "local-lvm"
}

variable "bridge" {
  description = "NIC를 붙일 Proxmox 브리지"
  type        = string
  default     = "vmbr0"
}

variable "gateway" {
  description = "LAN 게이트웨이"
  type        = string
  default     = "10.77.0.1"
}

variable "dns_servers" {
  description = "서버가 쓸 DNS 서버 목록. 비우면 gateway를 DNS로 사용"
  type        = list(string)
  default     = []
}

# 서버 추가 = 아래 map에 한 블록 추가 후 tofu apply (EC2 launch에 해당). 크기 필드는 생략하면 기본값.
# IP 규칙: CT는 110번대, VM은 120번대. 이미 수동으로 쓰는 IP(.110 NPM, .120 Steam, .121 k3s)는 피한다.
variable "vms" {
  description = "찍어낼 일반 VM. key가 VM 이름. ip는 CIDR"
  type = map(object({
    ip           = string
    vcpu         = optional(number, 2)
    memory_mb    = optional(number, 2048)
    disk_size_gb = optional(number, 20)
  }))
  default = {}
}

variable "containers" {
  description = "찍어낼 CT(LXC). key가 호스트명. ip는 CIDR. docker 사용 가능(nesting)"
  type = map(object({
    ip           = string
    vcpu         = optional(number, 1)
    memory_mb    = optional(number, 1024)
    swap_mb      = optional(number, 512)
    disk_size_gb = optional(number, 16)
  }))
  default = {}
}

variable "ssh_username" {
  description = "VM cloud-init으로 생성할 접속 계정명 (CT는 root)"
  type        = string
  default     = "ubuntu"
}

variable "ssh_public_key" {
  description = "VM cloud-init에 등록할 SSH 공개키. CT는 해당 없음(공개키는 CT 템플릿에 심겨 있음)"
  type        = string
}

variable "extra_ssh_public_keys" {
  description = "ssh_public_key 외에 VM cloud-init에 추가 등록할 SSH 공개키 목록. CT는 해당 없음"
  type        = list(string)
  default     = []
}

variable "agent_enabled" {
  description = "VM의 qemu-guest-agent 사용 여부. 구버전 템플릿(agent 미설치)이면 false"
  type        = bool
  default     = true
}
