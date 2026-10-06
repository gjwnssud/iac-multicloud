variable "proxmox_endpoint" {
  description = "Proxmox API 주소 (예: https://192.168.0.100:8006/)"
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
  description = "VM을 만들 Proxmox 노드 이름"
  type        = string
  default     = "pve"
}

variable "template_vmid" {
  description = "clone할 cloud-init 템플릿 VM ID"
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

variable "gateway" {
  description = "LAN 게이트웨이"
  type        = string
  default     = "192.168.0.1"
}

variable "name" {
  description = "리소스 이름 접두사"
  type        = string
  default     = "iac-multicloud-local"
}

variable "server_ip_addresses" {
  description = "k3s 서버(control-plane) 노드의 고정 IP 목록 (CIDR). 길이가 서버 노드 수. VM은 120번대(.120은 Steam VM), CT는 110번대 규칙에 맞춰 지정"
  type        = list(string)
  default     = ["192.168.0.121/24"]
}

variable "agent_ip_addresses" {
  description = "k3s 에이전트(worker) 노드의 고정 IP 목록 (CIDR). 길이가 에이전트 노드 수. 기본은 단일 노드"
  type        = list(string)
  default     = []
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
  description = "디스크 크기 (GB)"
  type        = number
  default     = 20
}

variable "ssh_username" {
  description = "cloud-init으로 생성할 접속 계정명"
  type        = string
  default     = "ubuntu"
}

variable "ssh_public_key" {
  description = "cloud-init에 등록할 SSH 공개키"
  type        = string
}

variable "ssh_private_key_path" {
  description = "ssh_public_key에 대응하는 로컬 개인키 경로. 비워두면 ansible inventory에 명시하지 않음"
  type        = string
  default     = ""
}
