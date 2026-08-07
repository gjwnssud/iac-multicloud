variable "name" {
  description = "리소스 이름 접두사"
  type        = string
  default     = "iac-multicloud-local-mac"
}

variable "vcpu" {
  description = "vCPU 개수"
  type        = number
  default     = 2
}

variable "memory_gib" {
  description = "메모리 (GiB). k3s server + ArgoCD 구동에는 최소 4 권장"
  type        = number
  default     = 4
}

variable "disk_gib" {
  description = "디스크 크기 (GiB)"
  type        = number
  default     = 20
}

variable "server_count" {
  description = "k3s 서버(control-plane) 노드 수"
  type        = number
  default     = 1
}

variable "agent_count" {
  description = "k3s 에이전트(worker) 노드 수. 로컬 환경은 이중화 검증을 위해 기본 1"
  type        = number
  default     = 1
}

variable "ssh_username" {
  description = "생성할 접속 계정명"
  type        = string
  default     = "ubuntu"
}

variable "ssh_public_key" {
  description = "등록할 SSH 공개키"
  type        = string
}

variable "ssh_private_key_path" {
  description = "ssh_public_key에 대응하는 로컬 개인키 경로. 비워두면 ansible inventory에 명시하지 않음"
  type        = string
  default     = ""
}
