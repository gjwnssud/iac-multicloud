# 노드 추가 절차

## 1. 기존 환경의 노드 늘리기

노드는 워커(agent)를 늘리는 방식으로 확장한다. 이 저장소의 k3s role에는 컨트롤 플레인 이중화(embedded etcd)가 구현돼 있지 않다.
서버 노드를 2대 이상으로 늘리면 각 서버가 독립 클러스터가 되므로, 서버는 1대로 두고 `agent`만 추가한다.

### aws / gcp / azure / libvirt: 개수로 지정

```bash
cd opentofu/environments/<env>
# terraform.tfvars 또는 -var로 조정
tofu apply -var 'server_count=1' -var 'agent_count=2'
```

클라우드 환경은 노드가 늘면 비용이 늘어난다. `tofu apply` 전에 `tofu plan`으로 몇 대가 추가되는지 확인한다.

### proxmox: 고정 IP 목록으로 지정

Proxmox VM은 고정 IP를 쓰므로 노드 수가 IP 목록의 길이다.

```hcl
# opentofu/environments/proxmox/terraform.tfvars
server_ip_addresses = ["10.77.0.122/24"]
agent_ip_addresses  = ["10.77.0.123/24"]   # 추가
```

IP는 CT 110번대, VM 120번대 규칙에 맞추고, 같은 노드의 다른 VM/CT가 쓰는 주소와 겹치지 않게 한다.

### 반영

`tofu apply`가 끝나면 `ansible/inventories/<env>/hosts.ini`가 새 노드까지 포함해 자동으로 다시 생성된다. 이어서 Ansible을 다시 실행한다.
신규 노드는 k3s에 조인되고 레지스트리 mirror 설정도 받는다. 기존 노드는 대부분 변경 없음(`ok`)으로 넘어간다.

```bash
cd ansible
ansible-playbook -i inventories/<env>/hosts.ini playbooks/site.yml
kubectl get nodes   # KUBECONFIG=ansible/fetched/<node-ip>-kubeconfig.yaml
```

proxmox 환경은 `deploy.yml`이 CI에서 `ansible-playbook`을 실행하지만 `tofu apply`는 사람이 직접 한다 (`.github/environments.json`의 `tofu_apply: false`).
CI는 클러스터에서 `k3s kubectl get nodes`로 노드 IP를 조회해 inventory를 만든다.

## 2. 새 환경(사이트, 계정, 리전) 추가

기존 환경을 복사해서 시작한다. 예를 들어 같은 AWS 계정의 다른 리전이라면 다음과 같다.

1. `opentofu/environments/aws`를 `opentofu/environments/aws-<name>`으로 복사한다.
2. `variables.tf`의 `name`과 `region` 기본값만 바꾸면 나머지는 그대로 쓸 수 있다. 모듈 인터페이스가 통일돼 있기 때문이다 (`network_id`/`subnet_id`, `instance_id`/`instance_ip`).
3. `versions.tf`의 backend `key`를 새 환경 이름으로 바꾼다.
4. `local_file.ansible_inventory`의 `filename`을 새 환경 이름으로 바꾼다 (`opentofu/templates/inventory.tpl` 사용).
5. 완전히 새로운 provider(Oracle Cloud, Hetzner 등)는 `opentofu/modules/network/<provider>`와 `opentofu/modules/compute-<provider>`를 같은 output 인터페이스로 새로 작성한다.
6. **CI 편입**: `.github/environments.json`에 항목(`provider`, `runs_on`, `plan`, `tofu_apply`, `inventory`)을 추가하고 리포지토리 변수 `CI_ENVIRONMENTS`에 이름을 넣는다. 기존 provider(aws/gcp/azure/local)를 쓰면 워크플로 수정은 필요 없다. 새 클라우드 provider일 때만 자격증명과 backend init 스텝을 추가한다. self-hosted runner 환경은 러너가 Idle인 것을 확인한 뒤에 지정한다.
7. **GitOps 매니페스트**: `argocd/bootstrap/root-<env>.yaml`과 `argocd/apps/appset-<env>.yaml`을 기존 환경 것에서 복사해 환경 이름(`<env>`, `values-<env>.yaml`, `include` 글롭)을 바꾼다. 앱 저장소는 `deploy/values-<env>.yaml`을 두면 이 환경에 배포된다 ([adding-an-app.md](./adding-an-app.md)).
8. 사설망 환경이면 `ansible/inventories/<env>/group_vars/all.yml`에 러너 라벨(`github_runner_labels`)과 아키텍처(`github_runner_arch`)를 둔다.

Ansible role(`common`, `k3s`, `registry`, `argocd`)은 provider와 무관하게 재사용된다. `inventory.tpl`이 만드는 `hosts.ini`의 그룹 구조(`k3s_servers`, `k3s_agents`)만 같으면 된다.

## 3. k3s 없이 서버만 추가

앱을 올릴 k3s 노드가 아니라 일반 서버(VM/CT)가 필요하면 `opentofu/environments/proxmox-servers`의 `vms`/`containers` map에 블록을 추가하고 `tofu apply` 한다.
절차는 [new-site-checklist.md](./new-site-checklist.md)의 "범용 서버" 절에 있다.
