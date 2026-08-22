locals {
  nodes = merge(
    { for i in range(var.server_count) : "server-${i}" => { role = "server" } },
    { for i in range(var.agent_count) : "agent-${i}" => { role = "agent" } }
  )
  server_ips = [for k, v in local.nodes : module.compute[k].instance_ip if v.role == "server"]
  agent_ips  = [for k, v in local.nodes : module.compute[k].instance_ip if v.role == "agent"]
}

module "network" {
  source = "../../modules/network/libvirt"

  name = var.name
}

module "compute" {
  source   = "../../modules/compute-libvirt"
  for_each = local.nodes

  name           = "${var.name}-${each.key}"
  network_id     = module.network.network_id
  image          = var.image
  vcpu           = var.vcpu
  memory_mb      = var.memory_mb
  ssh_username   = var.ssh_username
  ssh_public_key = var.ssh_public_key
  domain_type    = var.domain_type
}

resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../../../ansible/inventories/local-libvirt/hosts.ini"
  content = templatefile("${path.module}/../../templates/inventory.tpl", {
    server_ips           = local.server_ips
    agent_ips            = local.agent_ips
    ssh_username         = var.ssh_username
    ssh_private_key_path = var.ssh_private_key_path
  })
}
