module "network" {
  source = "../../modules/network/gcp"

  name              = var.name
  project           = var.project
  region            = var.region
  allowed_ssh_cidrs = var.allowed_ssh_cidrs
}

module "compute" {
  source = "../../modules/compute-gcp"

  name           = var.name
  project        = var.project
  zone           = var.zone
  instance_type  = var.instance_type
  image          = var.image
  subnet_id      = module.network.subnet_id
  network_tag    = module.network.network_tag
  ssh_username   = var.ssh_username
  ssh_public_key = var.ssh_public_key
}

resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../../../ansible/inventories/gcp-dev/hosts.ini"
  content = templatefile("${path.module}/../../templates/inventory.tpl", {
    server_ips           = [module.compute.instance_ip]
    agent_ips            = []
    ssh_username         = var.ssh_username
    ssh_private_key_path = var.ssh_private_key_path
  })
}
