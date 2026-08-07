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
  name      = var.name
  vcpu      = var.vcpu
  memory    = var.memory_mb
  cloudinit = libvirt_cloudinit_disk.this.id

  disk {
    volume_id = libvirt_volume.this.id
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
