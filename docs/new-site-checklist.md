# 신규 사이트 추가 체크리스트

새 하이퍼바이저 호스트(사이트)나 클라우드 계정에 이 저장소로 IaC를 구축할 때 순서대로 따라가는 체크리스트다.
환경별 상세 준비물은 [onboarding.md](./onboarding.md), 노드/환경 코드 추가는 [adding-a-node.md](./adding-a-node.md) 참고.

## 무엇이 수동이고 무엇이 자동인가

| 항목 | 방식 | 빈도 |
|---|---|---|
| 호스트에 SSH 공개키 등록 (하이퍼바이저) | 수동 `ssh-copy-id` | 사이트당 1회 |
| 클라우드 계정 자격증명 등록 | 수동 | 계정당 1회 |
| Proxmox API 토큰 발급 | 수동 | 사이트당 1회 |
| 템플릿 VM 생성 (proxmox) | `proxmox-template` 플레이북 | 사이트당 1회 |
| `terraform.tfvars` 사이트별 값 | 수동 작성 | 사이트당 1회 |
| 신규 VM의 SSH 키 주입 | cloud-init 자동 | 매번 자동 |
| k3s + ArgoCD 설치 | Ansible | 매번 자동 |
| 앱 배포 | ArgoCD (`root-{env}.yaml` 1회 적용 후 자동. GitHub 토큰 Secret과 organization 러너도 1회) | 클러스터당 1회 |

## 체크리스트 (Proxmox 사이트 기준)

- [ ] **0. 사전 확인**: 호스트 주소, 노드명(`pve` 등), 사용할 IP 대역/게이트웨이, datastore 이름을 메모한다.
- [ ] **0. LAN 대역 선정**: 사이트 LAN은 공용 Wi-Fi와 충돌하지 않도록 `192.168.0.x`/`192.168.1.x` 같은 흔한 대역을 피하고, 흔치 않은 `10.x.y.0/24`(예: `10.77.0.0/24`)를 쓴다. 사이트끼리도 겹치지 않게 하고 WireGuard 터널 대역과도 분리한다.
- [ ] **1. SSH 키 준비**: 사이트용 키쌍을 정한다 (기존 `~/.ssh/iac_multicloud_local` 재사용 가능, 격리가 필요하면 사이트별 분리).
- [ ] **2. 호스트에 공개키 등록** (1회): `ssh-copy-id -i <키>.pub root@<호스트>` 후 `ssh -i <키> root@<호스트>`로 접속 확인.
- [ ] **3. 템플릿 VM 생성** (1회): `cd ansible && ansible-playbook -i "<호스트>," -u root playbooks/proxmox-template.yml`
  - 템플릿 이미지에 `qemu-guest-agent`를 미리 설치한다(`virt-customize`, 호스트에 `libguestfs-tools` 자동 설치). 이미 만든 구버전 템플릿(agent 없음)이면 템플릿을 `qm destroy`로 지우고 재생성하거나, tfvars에 `agent_enabled = false`를 둔다. 이미 만든 VM은 안에서 `apt install qemu-guest-agent` 후 완전 재시작.
  - root가 아닌 사용자(`-u <사용자> --private-key <키>`)는 호스트에서 sudo가 가능해야 한다 (`qm`에 root 필요). PVE 웹 UI의 admin 권한과 리눅스 sudo는 별개다.
  - datastore/브리지/VM ID가 다르면 `-e proxmox_template_datastore=<이름>` 식으로 덮어쓴다 (기본값 `local-lvm`). 디스크 이미지는 `local-lvm`(LVM-thin)에 두고, `local`(디렉토리)은 cloud image 파일 다운로드용이다. tfvars `datastore_id`도 같은 값으로 맞춘다.
- [ ] **4. API 토큰 발급** (1회): 전용 사용자(예: `terraform@pve`)와 토큰을 만들고 **Privilege Separation은 해제**한다. `export PROXMOX_VE_API_TOKEN='user@realm!id=secret'`
  - 새 사용자는 권한이 없으므로 아래 세 가지를 모두 부여해야 한다 (PVE 9의 `PVEVMAdmin`에는 `Datastore.*`, `SDN.Use`가 없다):
    ```bash
    pveum acl modify / --users terraform@pve --roles PVEVMAdmin
    pveum acl modify /storage/<datastore> --users terraform@pve --roles PVEDatastoreUser
    pveum acl modify /sdn/zones/localnetwork --users terraform@pve --roles PVESDNUser
    ```
  - 부족하면 `tofu apply`가 `403 Permission check failed (<경로>, <권한>)`으로 실패한다. 메시지의 경로/권한에 맞춰 추가한다.
- [ ] **5. 환경 디렉토리 준비**: 사이트가 하나면 `opentofu/environments/proxmox`를 그대로 쓰고, 둘 이상이면 복사해 이름을 구분한다.
  `terraform.tfvars.example` → `terraform.tfvars` 복사 후 `proxmox_endpoint`, `node_name`, `template_vmid`, `ssh_public_key`, `server_ip_addresses`, `gateway`를 입력한다. 이 중 `template_vmid`, `ssh_public_key`, `server_ip_addresses`, `gateway`는 기본값이 없는 필수 값이다. VM의 DNS는 기본으로 `gateway`를 쓰고, 다른 DNS가 필요하면 `dns_servers = ["..."]`로 지정한다 (Proxmox 호스트의 DNS 설정과 무관하게 VM에 직접 들어간다). 다른 장비에서도 VM에 접속해야 하면 `extra_ssh_public_keys = ["ssh-ed25519 ..."]`에 공개키를 추가한다 (Proxmox UI에서 직접 넣으면 tofu와 어긋나므로 tfvars로 관리).
- [ ] **6. `tofu apply`**: `cd opentofu/environments/proxmox && tofu init && tofu plan && tofu apply`. `ansible/inventories/proxmox/hosts.ini`가 자동 생성된다.
- [ ] **7. k3s + 레지스트리 + ArgoCD 설치**: `cd ansible && ansible-playbook -i inventories/proxmox/hosts.ini playbooks/site.yml`
- [ ] **8. 클러스터 확인**: `ansible/fetched/`의 kubeconfig로 `kubectl get nodes`.
- [ ] **9. GitOps 루프 시작** (클러스터당 1회): `kubectl apply -f argocd/bootstrap/root-proxmox.yaml` 후 ArgoCD UI에서 Sync 확인. 앱 배포를 쓰려면 이어서 [adding-an-app.md](./adding-an-app.md) 0절(GitHub 토큰 Secret, organization 러너)을 1회 수행한다. Secret이 없으면 ApplicationSet이 오류 상태가 된다.
- [ ] **10. CI 편입** (선택, 위 단계 검증 후):
  1. `.github/environments.json`에 환경 항목이 있는지 확인한다 (없으면 추가: `provider`, `runs_on`, `plan`, `tofu_apply`, `inventory`).
     - 사설망 + 로컬 tfstate 사이트는 `tofu_apply: false`, `plan: false`, `inventory: dynamic`(ansible만 CI, tofu는 사람이 실행)을 권장한다. 러너가 관리 대상 VM 안에서 돌아 로컬 state를 잃으면 VM을 재생성하려 하기 때문이다.
  2. 사설망이면 k3s 서버 노드에 self-hosted runner를 설치한다 (PAT는 채팅/커밋에 남기지 말 것). 라벨은 `runs_on`과 일치해야 한다. 이 저장소의 CI용 러너는 저장소 러너로 등록한다:
     ```bash
     cd ansible && ansible-playbook -i inventories/<env>/hosts.ini playbooks/site.yml --tags github-runner \
       -e github_runner_repo=<owner>/<repo> -e github_runner_pat=<PAT>
     ```
  - 앱 이미지 빌드용 러너는 **organization 러너**(`-e github_runner_repo=<org>`)로 따로 등록하고 환경의 `group_vars` 또는 `-e`로 `github_runner_build_tools_enabled: true`를 준다. 같은 호스트에 러너를 여러 개 띄울 수 있다 (등록 대상 이름으로 컨테이너와 유닛이 구분됨). 자세한 내용은 [adding-an-app.md](./adding-an-app.md) 0절에 있다.
  3. 시크릿 `SSH_PRIVATE_KEY`, 변수 `SSH_USERNAME`을 등록하고, GitHub Settings > Actions > Runners에서 러너가 Idle인지 확인한다.
  4. **러너가 Idle인 것을 확인한 뒤에** 변수 `CI_ENVIRONMENTS`에 환경을 추가한다 (러너 없이 지정하면 job이 24시간 대기하며 push를 막는다).

## 범용 서버(VM/CT) 찍어내기 — k3s와 무관 (Proxmox)

EC2처럼 필요할 때 서버를 하나씩 코드로 만든다. k3s/ArgoCD는 이 서버들 중 "k3s 노드" 용도일 뿐이고,
아래 환경(`opentofu/environments/proxmox-servers`)은 k3s `proxmox` 환경과 **state가 분리**돼 있다.

| 개념 | EC2 비유 | 이 저장소 |
|---|---|---|
| VM 템플릿 (9000) | AMI | `proxmox-template` 플레이북 (Ubuntu cloud image) |
| CT 템플릿 (9100) | AMI | `proxmox-lxc-template` 플레이북 (Ubuntu 26.04 + docker + compose + git) |
| CPU/RAM/디스크 | instance type | `terraform.tfvars`의 서버별 `vcpu`/`memory_mb`/`disk_size_gb` (템플릿 값은 최소값일 뿐) |
| 서버 생성 | launch instance | `vms`/`containers` map에 블록 추가 → `tofu apply` |

- [ ] **A. CT 템플릿 생성** (1회): `cd ansible && ansible-playbook -i "<호스트>," -u root playbooks/proxmox-lxc-template.yml` (root SSH가 막힌 호스트는 `-u <계정> -K --private-key <키>`: `-K`(대문자)는 sudo 비밀번호, `-k`(소문자)는 SSH 비밀번호)
  - 이미 9100이 있으면 건너뛴다(멱등). 템플릿을 새로 만들려면 `pct destroy 9100` 후 재실행.
  - CT 안에서 docker가 돌도록 템플릿은 unprivileged + `nesting=1,keyctl=1`로 만든다. nesting 외 feature는 root@pam만 바꿀 수 있어 API 토큰을 쓰는 tofu가 아니라 이 플레이북에서 박아두고 clone이 상속한다.
  - **CT의 root 접속용 공개키는 템플릿에 심긴다** (기본: 플레이북을 실행하는 머신의 `~/.ssh/iac_multicloud_local.pub`, 다른 키는 `-e '{"proxmox_lxc_template_authorized_keys":["ssh-ed25519 ..."]}'`). Proxmox가 clone한 CT에는 tofu의 `ssh-public-keys`를 적용하지 않기 때문이다(`pct create` 때만 적용). 키를 바꾸려면 템플릿을 다시 만들어야 하고, 이미 만든 CT에는 반영되지 않는다. tfvars의 `ssh_public_key`/`extra_ssh_public_keys`는 VM 전용이다.
  - 템플릿 안에서 sshd가 host key 없이 뜨는지 실제로 시험한다 (ssh.service의 `sshd -t`가 키 재생성보다 먼저 실패하는 문제 방지).
  - OS 템플릿 파일명이 바뀌었으면 `-e proxmox_lxc_template_ostemplate=<파일명>` (`pveam available --section system`으로 확인). 빌드 중 DHCP가 안 되면 `-e proxmox_lxc_template_build_ip=<CIDR> -e proxmox_lxc_template_build_gateway=<GW>`.
- [ ] **B. 서버 정의**: `cd opentofu/environments/proxmox-servers && cp terraform.tfvars.example terraform.tfvars` 후 `proxmox_endpoint`, `ssh_public_key`와 `vms`/`containers`를 채운다. IP 규칙은 CT 110번대, VM 120번대이며 수동 사용 중인 `.110`(NPM)/`.120`(Steam)/`.121`(k3s)은 피한다.
- [ ] **C. 생성**: `tofu init && tofu plan && tofu apply`. **CT는 처음 생성 때 `disk_size_gb`가 반영되지 않고 템플릿 크기(8GB)로 만들어진다** (생성 직후 `plan`에 `size = 8 -> N`이 보임). `tofu apply`를 한 번 더 실행하면 지정한 크기로 늘어난다. 출력의 `container_ips`/`vm_ips`로 접속한다 (CT는 `ssh root@IP`, VM은 `ssh ubuntu@IP`).
  - API 토큰에 CT 권한이 필요하다: `PVEVMAdmin`이 CT도 포함한다 (4번과 동일한 ACL).
- 서버 삭제는 map에서 블록을 지우고 `tofu apply`. 이미 수동으로 만든 서버(.110/.120)는 이 환경 대상이 아니다(import는 별도 작업).

## 클라우드(aws/gcp/azure) 사이트일 때 차이점

- 2~4번(호스트 키/템플릿/API 토큰) 대신 **계정 자격증명 등록**과 `opentofu/bootstrap/{cloud}` 원격 tfstate 생성이 선행된다 (실비용 발생, 사용자가 직접 실행).
- VM 접속 키는 cloud-init/메타데이터로 자동 주입되므로 호스트 등록 단계가 없다.
- 나머지(6~10번)는 동일하다.

## 진행 기록

신규 사이트를 붙일 때마다 아래에 날짜와 결과를 남긴다.

| 사이트 | 진행 단계 | 비고 |
|---|---|---|
| proxmox (10.77.0.100) | 1~10 전부 완료 (2026-10-18) | 템플릿 9000, VM `.122`(`.121`은 기존 사용 중), k3s v1.36.5 + ArgoCD + 샘플 앱 Healthy, 러너 등록·CI deploy job success 확인 |
