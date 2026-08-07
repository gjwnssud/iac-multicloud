locals {
  nodes = merge(
    { for i in range(var.server_count) : "server-${i}" => { role = "server" } },
    { for i in range(var.agent_count) : "agent-${i}" => { role = "agent" } }
  )
  server_ips = [for k, v in local.nodes : module.compute[k].instance_ip if v.role == "server"]
  agent_ips  = [for k, v in local.nodes : module.compute[k].instance_ip if v.role == "agent"]
}

# Lima는 VM별로 독립된 usermode/shared 네트워크를 스스로 관리해서
# 다른 환경들의 network 모듈 같은 공유 VPC/방화벽 추상화가 필요 없다.
module "compute" {
  source   = "../../modules/compute-lima"
  for_each = local.nodes

  name           = "${var.name}-${each.key}"
  vcpu           = var.vcpu
  memory_gib     = var.memory_gib
  disk_gib       = var.disk_gib
  ssh_username   = var.ssh_username
  ssh_public_key = var.ssh_public_key
}

resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../../../ansible/inventories/local-mac/hosts.ini"
  content = templatefile("${path.module}/../../templates/inventory.tpl", {
    server_ips           = local.server_ips
    agent_ips            = local.agent_ips
    ssh_username         = var.ssh_username
    ssh_private_key_path = var.ssh_private_key_path
  })
}
