module "network" {
  source = "../../modules/network/azure"

  name              = var.name
  location          = var.location
  allowed_ssh_cidrs = var.allowed_ssh_cidrs
}

module "compute" {
  source = "../../modules/compute-azure"

  name                = var.name
  resource_group_name = module.network.resource_group_name
  location            = module.network.location
  instance_type       = var.instance_type
  subnet_id           = module.network.subnet_id
  ssh_username        = var.ssh_username
  ssh_public_key      = var.ssh_public_key
}

resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../../../ansible/inventories/azure-dev/hosts.ini"
  content = templatefile("${path.module}/../../templates/inventory.tpl", {
    server_ips           = [module.compute.instance_ip]
    agent_ips            = []
    ssh_username         = var.ssh_username
    ssh_private_key_path = var.ssh_private_key_path
  })
}
