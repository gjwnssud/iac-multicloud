resource "local_file" "lima_config" {
  filename = "${path.root}/.lima/${var.name}.yaml"
  content = templatefile("${path.module}/templates/lima.yaml.tpl", {
    image_url      = var.image_url
    vcpu           = var.vcpu
    memory_gib     = var.memory_gib
    disk_gib       = var.disk_gib
    ssh_username   = var.ssh_username
    ssh_public_key = var.ssh_public_key
  })
}

# 공식 Lima Terraform 프로바이더가 없어 limactl CLI를 local-exec로 구동한다.
# config_hash가 바뀌면(스펙 변경 등) destroy 후 재생성되며, in-place 업데이트는 지원하지 않는다.
resource "null_resource" "lima_vm" {
  triggers = {
    name        = var.name
    config_hash = local_file.lima_config.content_md5
  }

  provisioner "local-exec" {
    command = "limactl start --name=${var.name} --tty=false ${local_file.lima_config.filename}"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "limactl delete --force ${self.triggers.name}"
  }

  depends_on = [local_file.lima_config]
}

data "external" "lima_ip" {
  program    = ["bash", "${path.module}/scripts/get-ip.sh", var.name]
  depends_on = [null_resource.lima_vm]
}
