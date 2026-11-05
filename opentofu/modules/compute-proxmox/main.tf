resource "proxmox_virtual_environment_vm" "this" {
  name      = var.name
  node_name = var.node_name

  clone {
    vm_id        = var.template_vmid
    datastore_id = var.datastore_id
    full         = true
  }

  cpu {
    cores = var.vcpu
    type  = "host"
  }

  memory {
    dedicated = var.memory_mb
  }

  disk {
    datastore_id = var.datastore_id
    interface    = "scsi0"
    size         = var.disk_size_gb
  }

  network_device {
    bridge = var.bridge
  }

  # 템플릿에 qemu-guest-agent가 설치돼 있어야 한다 (proxmox-template 롤이 설치).
  # 구버전 템플릿이면 apply가 agent 응답을 기다리며 멈추므로 agent_enabled=false로 끈다.
  agent {
    enabled = var.agent_enabled
  }

  initialization {
    datastore_id = var.datastore_id

    ip_config {
      ipv4 {
        address = var.ip_address
        gateway = var.gateway
      }
    }

    user_account {
      username = var.ssh_username
      keys     = concat([var.ssh_public_key], var.extra_ssh_public_keys)
    }
  }
}
