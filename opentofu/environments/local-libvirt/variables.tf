variable "libvirt_uri" {
  description = <<-EOT
    libvirt 연결 URI. 기본값(qemu:///system)은 tofu apply가 libvirtd가 있는 그 머신에서
    직접 실행될 때만 동작한다. github-runner 컨테이너(사설망 안 게스트 VM)에서 apply하려면
    물리 호스트로 되돌아가는 원격 URI가 필요하다:
      qemu+ssh://<host_user>@<하이퍼바이저_LAN_IP>/system?keyfile=/root/.ssh/id_ed25519&no_verify=1
    keyfile은 deploy.yml의 "SSH 개인키 준비" 단계가 러너 컨테이너 안에 이미 써둔 키를 재사용한다
    (해당 키가 하이퍼바이저 호스트 계정에도 등록돼 있어야 함).
  EOT
  type        = string
  default     = "qemu:///system"
}

variable "name" {
  description = "리소스 이름 접두사"
  type        = string
  default     = "iac-multicloud-local"
}

variable "image" {
  description = "베이스 이미지 경로 또는 URL (qcow2)"
  type        = string
}

variable "vcpu" {
  description = "vCPU 개수"
  type        = number
  default     = 2
}

variable "domain_type" {
  description = "libvirt 도메인 가상화 타입 (\"kvm\" 또는 \"qemu\"). KVM 가속이 없는 호스트는 \"qemu\"로 override"
  type        = string
  default     = "kvm"
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

variable "memory_mb" {
  description = "메모리 (MB). k3s server + ArgoCD 구동에는 최소 4096 권장"
  type        = number
  default     = 4096
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
