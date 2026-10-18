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
| 앱 배포 | ArgoCD (`root-{env}.yaml` 1회 적용 후 자동) | 클러스터당 1회 |

## 체크리스트 (Proxmox 사이트 기준)

- [ ] **0. 사전 확인**: 호스트 주소, 노드명(`pve` 등), 사용할 IP 대역/게이트웨이, datastore 이름을 메모한다.
- [ ] **1. SSH 키 준비**: 사이트용 키쌍을 정한다 (기존 `~/.ssh/iac_multicloud_local` 재사용 가능, 격리가 필요하면 사이트별 분리).
- [ ] **2. 호스트에 공개키 등록** (1회): `ssh-copy-id -i <키>.pub root@<호스트>` 후 `ssh -i <키> root@<호스트>`로 접속 확인.
- [ ] **3. 템플릿 VM 생성** (1회): `cd ansible && ansible-playbook -i "<호스트>," -u root playbooks/proxmox-template.yml`
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
  `terraform.tfvars.example` → `terraform.tfvars` 복사 후 `proxmox_endpoint`, `node_name`, `template_vmid`, `ssh_public_key`, `server_ip_addresses`, `gateway` 입력.
- [ ] **6. `tofu apply`**: `cd opentofu/environments/proxmox && tofu init && tofu plan && tofu apply`. `hosts.ini`가 자동 생성된다.
- [ ] **7. k3s + ArgoCD 부트스트랩**: `cd ansible && ansible-playbook -i inventories/proxmox/hosts.ini playbooks/site.yml`
- [ ] **8. 클러스터 확인**: `ansible/fetched/`의 kubeconfig로 `kubectl get nodes`.
- [ ] **9. GitOps 루프 시작** (클러스터당 1회): `kubectl apply -f argocd/bootstrap/root-proxmox.yaml` 후 ArgoCD UI에서 Sync 확인.
- [ ] **10. CI 편입** (선택, 위 단계 검증 후):
  1. `.github/environments.json`에 환경 항목이 있는지 확인한다 (없으면 추가: `provider`, `runs_on`, `plan`, `tofu_apply`, `inventory`).
     - 사설망 + 로컬 tfstate 사이트는 `tofu_apply: false`, `plan: false`, `inventory: dynamic`(ansible만 CI, tofu는 사람이 실행)을 권장한다. 러너가 관리 대상 VM 안에서 돌아 로컬 state를 잃으면 VM을 재생성하려 하기 때문이다.
  2. 사설망이면 k3s 서버 노드에 self-hosted runner를 설치한다 (PAT는 채팅/커밋에 남기지 말 것). 라벨은 `runs_on`과 일치해야 한다:
     ```bash
     cd ansible && ansible-playbook -i inventories/<env>/hosts.ini playbooks/site.yml --tags github-runner \
       -e github_runner_repo=<owner>/<repo> -e github_runner_pat=<PAT>
     ```
  - 앱 이미지 빌드를 CI에서 하려면 환경의 `group_vars`에 `github_runner_build_tools_enabled: true`를 두고 `environments.json`에 `"build": true`를 설정한다 (k3s 롤이 nerdctl/buildkit을 이미 설치한 노드 전제).
  3. 시크릿 `SSH_PRIVATE_KEY`, 변수 `SSH_USERNAME`을 등록하고, GitHub Settings > Actions > Runners에서 러너가 Idle인지 확인한다.
  4. **러너가 Idle인 것을 확인한 뒤에** 변수 `CI_ENVIRONMENTS`에 환경을 추가한다 (러너 없이 지정하면 job이 24시간 대기하며 push를 막는다).

## 클라우드(aws/gcp/azure) 사이트일 때 차이점

- 2~4번(호스트 키/템플릿/API 토큰) 대신 **계정 자격증명 등록**과 `opentofu/bootstrap/{cloud}` 원격 tfstate 생성이 선행된다 (실비용 발생, 사용자가 직접 실행).
- VM 접속 키는 cloud-init/메타데이터로 자동 주입되므로 호스트 등록 단계가 없다.
- 나머지(6~10번)는 동일하다.

## 진행 기록

신규 사이트를 붙일 때마다 아래에 날짜와 결과를 남긴다.

| 사이트 | 진행 단계 | 비고 |
|---|---|---|
| proxmox (192.168.0.100) | 1~10 전부 완료 (2026-10-18) | 템플릿 9000, VM `.122`(`.121`은 기존 사용 중), k3s v1.36.5 + ArgoCD + 샘플 앱 Healthy, 러너 등록·CI deploy job success 확인 |
