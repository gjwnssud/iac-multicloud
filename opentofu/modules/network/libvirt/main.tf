# libvirt는 클라우드와 달리 network 리소스 자체가 서브넷(NAT + DHCP)을 겸한다.
# SSH 접근 제어는 클라우드 방화벽 대신 호스트 방화벽(libvirtd가 관리하는 iptables)이 담당하므로
# 이 모듈에는 aws/gcp/azure network 모듈에 있는 allowed_ssh_cidrs가 없다.
resource "libvirt_network" "this" {
  name      = var.name
  mode      = "nat"
  domain    = "${var.name}.local"
  addresses = [var.subnet_cidr]

  dhcp {
    enabled = true
  }

  autostart = true
}
