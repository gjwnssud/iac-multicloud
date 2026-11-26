resource "proxmox_virtual_environment_container" "this" {
  node_name = var.node_name

  # 템플릿(proxmox-lxc-template 롤)이 unprivileged + nesting/keyctl(docker용)로 만들어져 있다.
  # unprivileged는 생성 후 변경할 수 없어 템플릿과 값이 다르면 replace가 발생하므로 true로 고정한다.
  # features는 root@pam만 변경 가능해 API 토큰으로는 건드리지 않고 clone 상속에 맡긴다.
  unprivileged  = true
  start_on_boot = var.start_on_boot
  started       = true

  clone {
    vm_id        = var.template_vmid
    datastore_id = var.datastore_id
  }

  cpu {
    cores = var.vcpu
  }

  memory {
    dedicated = var.memory_mb
    swap      = var.swap_mb
  }

  disk {
    datastore_id = var.datastore_id
    size         = var.disk_size_gb
  }

  network_interface {
    name   = "eth0"
    bridge = var.bridge
  }

  initialization {
    hostname = var.name

    ip_config {
      ipv4 {
        address = var.ip_address
        gateway = var.gateway
      }
    }

    # 생략하면 Proxmox가 호스트의 /etc/resolv.conf를 복사한다. 호스트 DNS가 어긋나면 CT도 같이
    # 깨지므로 명시한다. 비워 두면 게이트웨이를 DNS로 쓴다.
    dns {
      servers = length(var.dns_servers) > 0 ? var.dns_servers : [var.gateway]
    }

    user_account {
      keys = concat([var.ssh_public_key], var.extra_ssh_public_keys)
    }
  }
}
