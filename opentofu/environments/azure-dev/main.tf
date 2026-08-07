locals {
  nodes = merge(
    { for i in range(var.server_count) : "server-${i}" => { role = "server" } },
    { for i in range(var.agent_count) : "agent-${i}" => { role = "agent" } }
  )
  server_ips = [for k, v in local.nodes : module.compute[k].instance_ip if v.role == "server"]
  agent_ips  = [for k, v in local.nodes : module.compute[k].instance_ip if v.role == "agent"]
}

module "network" {
  source = "../../modules/network/azure"

  name              = var.name
  location          = var.location
  allowed_ssh_cidrs = var.allowed_ssh_cidrs
}

module "compute" {
  source   = "../../modules/compute-azure"
  for_each = local.nodes

  name                = "${var.name}-${each.key}"
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
    server_ips           = local.server_ips
    agent_ips            = local.agent_ips
    ssh_username         = var.ssh_username
    ssh_private_key_path = var.ssh_private_key_path
  })
}
