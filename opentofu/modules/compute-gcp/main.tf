resource "google_compute_instance" "this" {
  project      = var.project
  name         = var.name
  zone         = var.zone
  machine_type = var.instance_type
  tags         = [var.network_tag]
  labels       = var.tags

  boot_disk {
    initialize_params {
      image = var.image
      size  = var.root_volume_size_gb
    }
  }

  network_interface {
    subnetwork = var.subnet_id
    access_config {}
  }

  metadata = {
    ssh-keys = "${var.ssh_username}:${var.ssh_public_key}"
  }
}
