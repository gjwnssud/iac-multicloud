module "network" {
  source = "../../modules/network/aws"

  name              = var.name
  allowed_ssh_cidrs = var.allowed_ssh_cidrs
}

module "compute" {
  source = "../../modules/compute-aws"

  name              = var.name
  instance_type     = var.instance_type
  image             = var.image
  subnet_id         = module.network.subnet_id
  security_group_id = module.network.security_group_id
  ssh_public_key    = var.ssh_public_key
}
