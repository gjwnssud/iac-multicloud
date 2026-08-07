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
