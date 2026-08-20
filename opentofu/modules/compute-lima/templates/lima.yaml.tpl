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
# Lima는 게스트 안에서 0.0.0.0으로 바인딩된 포트(예: k3s Traefik의 ServiceLB가 문
# 80/443)를 기본적으로 호스트에도 자동으로 포워딩한다. 호스트(Mac)에서 nginx 등
# 별도 서비스가 같은 포트를 쓰려면 이 포트들의 자동 포워딩을 꺼야 포트 충돌이
# 나지 않는다.
portForwards:
  - guestPort: 80
    ignore: true
  - guestPort: 443
    ignore: true
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
