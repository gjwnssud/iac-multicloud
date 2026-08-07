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

resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../../../ansible/inventories/local-libvirt/hosts.ini"
  content = templatefile("${path.module}/../../templates/inventory.tpl", {
    server_ips           = [module.compute.instance_ip]
    agent_ips            = []
    ssh_username         = var.ssh_username
    ssh_private_key_path = var.ssh_private_key_path
  })
}
