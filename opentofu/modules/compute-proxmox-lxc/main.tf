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

    # SSH 키(user_account.keys)는 두지 않는다: Proxmox는 clone한 CT에 ssh-public-keys를 적용하지 않는다
    # (pct create 때만 적용). root 접속용 공개키는 템플릿(proxmox-lxc-template 롤)에 미리 심어 둔다.
  }

  # 예전 버전이 user_account.keys를 넣어 만든 CT는 state에 그 블록이 남아 있고, provider는 이 블록의
  # 변경을 "교체 필요"로 처리한다. 이미 만든 CT가 삭제·재생성되지 않도록 변경을 무시한다.
  lifecycle {
    ignore_changes = [initialization[0].user_account]
  }
}
