# 온보딩 가이드

이 저장소로 처음 작업할 때 필요한 준비물과 절차를 환경별로 정리한다. 새 Proxmox 사이트를 붙이는 순서는
[new-site-checklist.md](./new-site-checklist.md), 앱 배포는 [adding-an-app.md](./adding-an-app.md)를 본다.

## 공통 도구

```bash
brew install opentofu ansible ansible-lint helm conftest actionlint
```

Ansible 컬렉션(`community.general`)은 저장소 루트가 아니라 `ansible/` 안에서 설치한다.

```bash
cd ansible
ansible-galaxy collection install -r requirements.yml
```

변경 후 로컬에서 확인하는 명령은 다음과 같다.

```bash
# OpenTofu: 환경 디렉터리에서
tofu init -backend=false && tofu validate
# 범용 chart 렌더링
helm lint charts/app && helm template x charts/app --set image.repository=x
# 워크플로 문법
actionlint
# 정책 (plan.json이 있을 때)
conftest test --policy policy plan.json
```

## 환경별 준비물

### aws / gcp / azure (클라우드 VM + k3s)

1. 해당 클라우드 자격증명을 로컬에 설정한다 (`aws configure`, `gcloud auth application-default login`, `az login` 등).
2. **원격 state 백엔드를 먼저 만든다** (1회성, 실비용 발생, 사용자가 직접 실행).

   ```bash
   cd opentofu/bootstrap/aws   # gcp, azure도 같은 방식
   cp terraform.tfvars.example terraform.tfvars   # 버킷 이름 등 채우기 (전역 유일해야 함)
   tofu init && tofu apply
   ```

   이 단계를 건너뛰고 `environments/{aws,gcp,azure}`에서 바로 `tofu init`을 실행하면 `backend "s3" {}`(partial config)가 필수 값을 요구해서 실패한다. 의도된 안전장치다.
   로컬 state를 쓰면 CI의 일회용 러너가 매번 state를 잃어 리소스가 중복 생성되기 때문이다.
3. bootstrap output(버킷 이름 등)을 `-backend-config`로 넘겨 init한다.

   ```bash
   cd opentofu/environments/aws
   tofu init \
     -backend-config="bucket=<bootstrap output: bucket_name>" \
     -backend-config="key=aws/terraform.tfstate" \
     -backend-config="region=ap-northeast-2" \
     -backend-config="dynamodb_table=<bootstrap output: lock_table_name>"
   ```

필수 변수는 환경마다 다르다. `aws`는 `image`(AMI), `allowed_ssh_cidrs`, `ssh_public_key`, `gcp`는 `project`, `allowed_ssh_cidrs`, `ssh_username`, `ssh_public_key`, `azure`는 `allowed_ssh_cidrs`, `ssh_username`, `ssh_public_key`가 필수다. `terraform.tfvars.example`을 따른다.
노드 수는 `server_count`/`agent_count`로 정한다.

### 베이스 이미지

| 환경 | 준비 방법 |
|---|---|
| aws / gcp / azure | 공개 이미지(AMI, image family 등)를 변수로 지정. 별도 준비 불필요 |
| libvirt | cloud image qcow2를 호스트에 받아 경로를 tfvars `image`에 지정 (수동) |
| proxmox | `playbooks/proxmox-template.yml`로 cloud-init 템플릿 VM(9000) 생성 |
| proxmox (CT) | `playbooks/proxmox-lxc-template.yml`로 CT 템플릿(9100) 생성 |

### libvirt (Linux 호스트 + KVM)

Linux 머신(베어메탈 또는 VM)에 `libvirt`, `qemu-kvm`이 설치돼 있고 `libvirtd`가 실행 중이어야 한다.
macOS에서는 KVM이 없어 사용할 수 없다.

```bash
sudo apt install libvirt-daemon-system qemu-kvm   # Debian/Ubuntu 예시
```

`libvirt_uri`를 `qemu+ssh://user@호스트IP/system`으로 주면 다른 머신(예: 게스트 VM 안의 러너)에서도 원격으로 VM을 만들 수 있다.

### proxmox (Proxmox VE 홈서버)

`bpg/proxmox` provider로 Proxmox API를 호출해 템플릿 VM을 clone한다. 사전 준비는 다음과 같다.

1. cloud-init 템플릿 VM을 만든다 (1회, 기본 VM ID 9000). root SSH가 막힌 호스트는 sudo 가능한 계정으로 실행한다.
   ```bash
   cd ansible
   ansible-playbook -i "<호스트IP>," -u root playbooks/proxmox-template.yml
   # root 로그인이 막힌 경우: -u <계정> -K --private-key ~/.ssh/iac_multicloud_local  (-K는 sudo 비밀번호)
   ```
   이미지 URL, VM ID, datastore는 `roles/proxmox-template/defaults/main.yml` 변수로 바꾼다. 이미 있으면 건너뛴다.
2. Datacenter > Permissions > API Tokens에서 토큰을 발급하고 `export PROXMOX_VE_API_TOKEN='user@realm!id=secret'`로 전달한다. 필요한 권한은 [new-site-checklist.md](./new-site-checklist.md) 4번에 있다.
3. `opentofu/environments/proxmox/terraform.tfvars.example`을 복사해 채운다. **`template_vmid`, `gateway`, `server_ip_addresses`, `ssh_public_key`는 기본값이 없는 필수 값**이다.
   IP는 고정이고 규칙은 CT 110번대, VM 120번대다.

## 최초 apply부터 ArgoCD 확인까지

저장소 루트에서 시작한다.

```bash
# 1) 인프라 생성 (환경별 terraform.tfvars를 채운 뒤)
cd opentofu/environments/<env>
tofu apply

# 2) k3s + 레지스트리 + ArgoCD 설치
cd ../../../ansible
ansible-playbook -i inventories/<env>/hosts.ini playbooks/site.yml

# 3) kubeconfig로 확인 (2번이 ansible/fetched/에 생성)
export KUBECONFIG=fetched/<node-ip>-kubeconfig.yaml
kubectl get nodes
kubectl get pods -n argocd

# 4) GitOps 시작 (클러스터당 1회)
kubectl apply -f ../argocd/bootstrap/root-<env>.yaml

# 5) ArgoCD UI (초기 admin 비밀번호는 2번 로그 마지막 줄에 출력됨)
kubectl port-forward svc/argocd-server -n argocd 8080:443
# https://localhost:8080
```

앱을 배포하려면 이어서 [adding-an-app.md](./adding-an-app.md) 0절(GitHub 토큰 Secret, organization 러너)을 한 번 수행한다.
이 Secret이 없으면 ApplicationSet이 오류 상태가 되어 앱이 하나도 배포되지 않는다.

## GitHub Actions 시크릿/변수 (인프라 CI)

`plan.yml`/`deploy.yml`이 참조하는 값이다. 등록하지 않으면 해당 환경 job은 자격증명 단계에서 바로 실패한다.
값은 클라우드 콘솔이나 CLI에서 직접 발급하고, **로컬 터미널에서 직접** 등록한다 (`gh` CLI, repo 관리자 권한). 값을 채팅 등에 붙여 넣지 않는다.

**`SSH_PRIVATE_KEY`/`SSH_USERNAME`은 클라우드 전용이 아니다.** proxmox/libvirt의 ansible 단계(self-hosted runner가 실행)도 이 값으로 노드에 접속한다.
비어 있으면 `ansible_user=`가 빈 값으로 렌더링되어 `Load key "...": error in libcrypto`로 접속이 실패한다.
값은 `environments/*`의 `ssh_public_key`와 짝인 키여야 한다.

```bash
# secrets
gh secret set AWS_ACCESS_KEY_ID --body "<...>"
gh secret set AWS_SECRET_ACCESS_KEY --body "<...>"
gh secret set GCP_SERVICE_ACCOUNT_KEY < service-account.json
gh secret set AZURE_CREDENTIALS < azure-credentials.json
gh secret set SSH_PRIVATE_KEY < ~/.ssh/iac_multicloud_local

# vars
gh variable set CI_ENVIRONMENTS --body '["proxmox"]'   # 자동 실행할 환경. 비우면 아무것도 실행 안 함
gh variable set ALLOWED_SSH_CIDRS --body '["<내 공인 IP>/32"]'
gh variable set SSH_PUBLIC_KEY --body "$(cat ~/.ssh/iac_multicloud_local.pub)"
gh variable set SSH_USERNAME --body "ubuntu"
gh variable set AWS_AMI_ID --body "<...>"
gh variable set GCP_PROJECT_ID --body "<...>"
gh variable set TF_STATE_BUCKET_AWS --body "<bootstrap/aws output>"
gh variable set TF_STATE_LOCK_TABLE_AWS --body "<bootstrap/aws output>"
gh variable set TF_STATE_BUCKET_GCP --body "<bootstrap/gcp output>"
gh variable set TF_STATE_RG_AZURE --body "<bootstrap/azure output>"
gh variable set TF_STATE_ACCOUNT_AZURE --body "<bootstrap/azure output>"
```

`TF_STATE_*`는 `opentofu/bootstrap/{aws,gcp,azure}`를 apply해야 나온다. 등록 후 `gh secret list`, `gh variable list`로 확인한다.
앱 배포용 토큰(`github-token`)은 GitHub가 아니라 **클러스터의 Secret**이다. 위 목록과 별개다.

## 자주 막히는 지점

- **필수 변수 누락**: `proxmox`, `proxmox-servers`의 `gateway`와 `proxmox`의 `server_ip_addresses`는 기본값이 없다. 개인 LAN 값을 코드에 두지 않기 위해서다. `tofu plan`이 값을 물으면 tfvars에 넣는다.
- **GCP/Azure 자격증명 없이 `tofu plan`**: provider 인증 단계에서 실패한다. 서비스 계정/앱 등록 후 CLI로 로그인하면 해결된다.
- **libvirt에서 `Unsupported argument`류 에러**: `dmacvicar/libvirt` provider가 `0.9.x`가 되면 스키마가 완전히 바뀐다. 모듈은 `~> 0.8.3`으로 고정돼 있으니 버전 제약을 건드리지 않는다.
- **Ansible이 로컬에서 sudo 비밀번호를 요구**: `delegate_to: localhost` 태스크에는 `become: false`를 명시한다. play 레벨 `become: true`가 상속되기 때문이다.
- **libvirt `tofu apply`에서 qemu가 디스크 이미지를 `Permission denied`로 못 엶**: 소유자와 모드가 멀쩡한데도 발생하면 AppArmor가 원인일 수 있다. `virsh pool-define-as`로 storage pool을 CLI에서 직접 만들면 libvirt가 VM마다 만드는 AppArmor 화이트리스트(`/etc/apparmor.d/libvirt/libvirt-<uuid>.files`)에 그 pool의 볼륨 경로가 빠진다. 파일에 경로가 없는지 확인하고, 없다면 `qemu.conf`에 `security_driver = "none"`을 추가하거나 pool을 virt-manager/`virt-install`로 다시 만든다. `efi-virtio.rom` 누락은 `ipxe-qemu` 패키지로 해결된다.
- **Proxmox VM 재부팅/cloud-init 변경 후 SSH가 안 됨**: 보통 키가 아니라 클라이언트 쪽 문제다.
  (1) `REMOTE HOST IDENTIFICATION HAS CHANGED`: cloud-init이 다시 실행되면 호스트 키가 재생성되어 `known_hosts`의 옛 키와 충돌한다. 원인이 이것이 맞을 때만 `ssh-keygen -R <IP>`로 지운다.
  (2) `Permission denied (publickey)`: `ssh ubuntu@<IP>`는 `~/.ssh/id_ed25519` 같은 기본 이름의 키만 제시한다. `iac_multicloud_local`처럼 다른 이름은 `-i`로 지정하거나 `~/.ssh/config`에 `IdentityFile`(+`IdentitiesOnly yes`)로 등록한다. 접속 계정은 cloud-init 사용자(`ubuntu`)다.
  (3) 다른 장비를 추가하려면 tfvars의 `extra_ssh_public_keys`에 넣는다. Proxmox UI에서 cloud-init 키를 바꾸면 tofu가 관리하는 값이라 다음 apply에서 되돌려진다.
- **Proxmox CT는 `ssh ubuntu@`가 아니라 `ssh root@`로 접속**한다. root 공개키는 CT 템플릿에 심겨 있고 tfvars의 SSH 키는 VM에만 적용된다. 자세한 내용은 [new-site-checklist.md](./new-site-checklist.md)의 범용 서버 절에 있다.
- **ApplicationSet이 오류 상태**: `argocd` 네임스페이스에 `github-token` Secret이 없거나 토큰 권한이 부족하다. `kubectl -n argocd describe applicationset apps-<env>`로 확인한다.
- **러너 job이 끊김**: k3s를 재시작하면 러너 컨테이너가 같이 내려간다(`Requires=k3s.service`). 재시작 후 러너가 다시 Idle이 되는지 확인한다. 러너를 다시 적용한 직후 첫 job이 이전 세션에 걸려 queued로 멈추면 취소하고 재실행한다.
