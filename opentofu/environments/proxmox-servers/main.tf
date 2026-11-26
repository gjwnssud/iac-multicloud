module "vm" {
  source   = "../../modules/compute-proxmox"
  for_each = var.vms

  name                  = each.key
  node_name             = var.node_name
  template_vmid         = var.vm_template_vmid
  datastore_id          = var.datastore_id
  bridge                = var.bridge
  ip_address            = each.value.ip
  gateway               = var.gateway
  dns_servers           = var.dns_servers
  vcpu                  = each.value.vcpu
  memory_mb             = each.value.memory_mb
  disk_size_gb          = each.value.disk_size_gb
  ssh_username          = var.ssh_username
  ssh_public_key        = var.ssh_public_key
  extra_ssh_public_keys = var.extra_ssh_public_keys
  agent_enabled         = var.agent_enabled
}

module "container" {
  source   = "../../modules/compute-proxmox-lxc"
  for_each = var.containers

  name                  = each.key
  node_name             = var.node_name
  template_vmid         = var.ct_template_vmid
  datastore_id          = var.datastore_id
  bridge                = var.bridge
  ip_address            = each.value.ip
  gateway               = var.gateway
  dns_servers           = var.dns_servers
  vcpu                  = each.value.vcpu
  memory_mb             = each.value.memory_mb
  swap_mb               = each.value.swap_mb
  disk_size_gb          = each.value.disk_size_gb
  ssh_public_key        = var.ssh_public_key
  extra_ssh_public_keys = var.extra_ssh_public_keys
}
