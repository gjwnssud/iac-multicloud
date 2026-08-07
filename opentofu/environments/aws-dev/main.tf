locals {
  nodes = merge(
    { for i in range(var.server_count) : "server-${i}" => { role = "server" } },
    { for i in range(var.agent_count) : "agent-${i}" => { role = "agent" } }
  )
  server_ips = [for k, v in local.nodes : module.compute[k].instance_ip if v.role == "server"]
  agent_ips  = [for k, v in local.nodes : module.compute[k].instance_ip if v.role == "agent"]
}

module "network" {
  source = "../../modules/network/aws"

  name              = var.name
  allowed_ssh_cidrs = var.allowed_ssh_cidrs
}

module "compute" {
  source   = "../../modules/compute-aws"
  for_each = local.nodes

  name              = "${var.name}-${each.key}"
  instance_type     = var.instance_type
  image             = var.image
  subnet_id         = module.network.subnet_id
  security_group_id = module.network.security_group_id
  ssh_public_key    = var.ssh_public_key
}

resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../../../ansible/inventories/aws-dev/hosts.ini"
  content = templatefile("${path.module}/../../templates/inventory.tpl", {
    server_ips           = local.server_ips
    agent_ips            = local.agent_ips
    ssh_username         = var.ssh_username
    ssh_private_key_path = var.ssh_private_key_path
  })
}
