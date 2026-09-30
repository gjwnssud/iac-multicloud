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

  # 고정 IP를 쓰므로 qemu-guest-agent 없이도 IP를 알 수 있다. 템플릿에 agent가 없는 상태에서
  # enabled = true면 apply가 agent 응답을 기다리며 멈추므로 끈다.
  agent {
    enabled = false
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
      keys     = [var.ssh_public_key]
    }
  }
}
