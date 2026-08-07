module "network" {
  source = "../../modules/network/libvirt"

  name = var.name
}

module "compute" {
  source = "../../modules/compute-libvirt"

  name           = var.name
  network_id     = module.network.network_id
  image          = var.image
  vcpu           = var.vcpu
  memory_mb      = var.memory_mb
  ssh_username   = var.ssh_username
  ssh_public_key = var.ssh_public_key
}
