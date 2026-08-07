resource "google_compute_network" "this" {
  project                 = var.project
  name                    = var.name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "this" {
  project       = var.project
  name          = "${var.name}-subnet"
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.this.id
}

resource "google_compute_firewall" "allow_ssh" {
  project       = var.project
  name          = "${var.name}-allow-ssh"
  network       = google_compute_network.this.id
  direction     = "INGRESS"
  source_ranges = var.allowed_ssh_cidrs
  target_tags   = [var.name]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}
