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

# 같은 서브넷에 속한 노드끼리 k3s 클러스터 트래픽 허용 (서버<->에이전트)
resource "google_compute_firewall" "allow_k3s_internal" {
  project       = var.project
  name          = "${var.name}-allow-k3s-internal"
  network       = google_compute_network.this.id
  direction     = "INGRESS"
  source_ranges = [var.subnet_cidr]
  target_tags   = [var.name]

  allow {
    protocol = "tcp"
    ports    = ["6443", "10250"]
  }

  allow {
    protocol = "udp"
    ports    = ["8472"]
  }
}
