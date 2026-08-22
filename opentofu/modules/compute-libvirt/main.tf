resource "libvirt_volume" "base" {
  name   = "${var.name}-base.qcow2"
  pool   = var.pool
  source = var.image
  format = "qcow2"
}

resource "libvirt_volume" "this" {
  name           = "${var.name}.qcow2"
  pool           = var.pool
  base_volume_id = libvirt_volume.base.id
  size           = var.disk_size_gb * 1024 * 1024 * 1024
}

resource "libvirt_cloudinit_disk" "this" {
  name = "${var.name}-cloudinit.iso"
  pool = var.pool
  user_data = templatefile("${path.module}/cloud_init.cfg.tpl", {
    ssh_username   = var.ssh_username
    ssh_public_key = var.ssh_public_key
  })
}

resource "libvirt_domain" "this" {
  name   = var.name
  type   = var.domain_type
  vcpu   = var.vcpu
  memory = var.memory_mb

  # cloudinit 속성(top-level)은 provider가 항상 IDE bus의 cdrom으로 붙이는데, aarch64
  # "virt" machine type은 IDE 컨트롤러 자체를 지원하지 않아 domain 생성이 실패한다.
  # 대신 일반 disk로 붙이고 scsi(virtio-scsi)를 명시해서 모든 아키텍처에서 동작하게 한다.
  # split(";", ...)[0]로 libvirt_cloudinit_disk.this.id(형식: "경로;uuid")에서 경로만 뗀다.
  disk {
    volume_id = libvirt_volume.this.id
    scsi      = true
  }

  disk {
    volume_id = split(";", libvirt_cloudinit_disk.this.id)[0]
    scsi      = true
  }

  network_interface {
    network_id     = var.network_id
    wait_for_lease = true
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }
}
