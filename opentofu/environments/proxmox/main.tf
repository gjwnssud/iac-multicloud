locals {
  nodes = merge(
    { for i, ip in var.server_ip_addresses : "server-${i}" => { role = "server", ip = ip } },
    { for i, ip in var.agent_ip_addresses : "agent-${i}" => { role = "agent", ip = ip } }
  )
  server_ips = [for k, v in local.nodes : module.compute[k].instance_ip if v.role == "server"]
  agent_ips  = [for k, v in local.nodes : module.compute[k].instance_ip if v.role == "agent"]
}

module "compute" {
  source   = "../../modules/compute-proxmox"
  for_each = local.nodes

  name           = "${var.name}-${each.key}"
  node_name      = var.node_name
  template_vmid  = var.template_vmid
  datastore_id   = var.datastore_id
  bridge         = var.bridge
  ip_address     = each.value.ip
  gateway        = var.gateway
  vcpu           = var.vcpu
  memory_mb      = var.memory_mb
  disk_size_gb   = var.disk_size_gb
  ssh_username   = var.ssh_username
  ssh_public_key = var.ssh_public_key
}

resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../../../ansible/inventories/proxmox/hosts.ini"
  content = templatefile("${path.module}/../../templates/inventory.tpl", {
    server_ips           = local.server_ips
    agent_ips            = local.agent_ips
    ssh_username         = var.ssh_username
    ssh_private_key_path = var.ssh_private_key_path
  })
}
