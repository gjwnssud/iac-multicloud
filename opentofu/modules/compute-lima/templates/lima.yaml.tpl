vmType: "vz"
arch: "aarch64"
images:
  - location: "${image_url}"
    arch: "aarch64"
cpus: ${vcpu}
memory: "${memory_gib}GiB"
disk: "${disk_gib}GiB"
mounts: []
# 기본 usermode(slirp) 네트워크는 호스트에서 직접 라우팅되지 않는 NAT 대역이라
# 다른 환경들과 동일하게 ansible_host=<ip>로 접속하려면 shared 모드가 필요하다.
# 최초 1회 `limactl sudoers | sudo tee /etc/sudoers.d/lima` 실행 필요 (socket_vmnet).
networks:
  - lima: shared
ssh:
  loadDotSSHPubKeys: false
provision:
  - mode: system
    script: |
      #!/bin/sh
      set -eux
      id -u ${ssh_username} >/dev/null 2>&1 || useradd -m -s /bin/bash ${ssh_username}
      usermod -aG sudo ${ssh_username} || true
      echo '${ssh_username} ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/90-${ssh_username}
      chmod 440 /etc/sudoers.d/90-${ssh_username}
      mkdir -p /home/${ssh_username}/.ssh
      echo '${ssh_public_key}' >> /home/${ssh_username}/.ssh/authorized_keys
      chmod 700 /home/${ssh_username}/.ssh
      chmod 600 /home/${ssh_username}/.ssh/authorized_keys
      chown -R ${ssh_username}:${ssh_username} /home/${ssh_username}/.ssh
