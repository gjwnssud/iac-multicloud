# 노드 추가 절차

## 1. 기존 환경의 노드 수만 늘리기 (가장 흔한 경우)

모든 `environments/*`는 `server_count`/`agent_count` 변수로 k3s 노드 수를 정한다
(Phase 3에서 도입, `for_each`로 `compute-*` 모듈을 필요한 만큼 호출한다).

```bash
cd opentofu/environments/<env>
# terraform.tfvars 또는 -var로 조정
tofu apply -var 'server_count=1' -var 'agent_count=2'
```

`tofu apply`가 끝나면 `ansible/inventories/<env>/hosts.ini`가 새 노드 IP까지 포함해
자동으로 다시 생성된다. 그 뒤 Ansible을 다시 실행하면 신규 노드는 k3s에 조인되고,
기존 노드는 태스크가 대부분 `ok`(변경 없음)로 스킵된다:

```bash
cd ansible
ansible-playbook -i inventories/<env>/hosts.ini playbooks/site.yml
```

주의할 점:

- `server_count`를 2 이상으로 올리면 k3s는 embedded etcd로 컨트롤 플레인 이중화를 시도한다.
  단순히 워커를 늘리고 싶다면 `agent_count`만 올리는 편이 안전하다.
- 클라우드 환경(aws/gcp/azure)은 노드가 늘어난 만큼 비용이 늘어난다 — 실제 `apply` 전에
  `tofu plan`으로 몇 대가 추가되는지 반드시 확인한다.

## 2. 새로운 클라우드/로컬 환경을 처음부터 추가하기

기존 provider 중 하나를 골라 그대로 모사하면 된다. 예를 들어 AWS와 같은 계정에
리전이 다른 환경을 하나 더 만드는 경우:

1. `opentofu/environments/aws`를 복사해 `opentofu/environments/aws-<name>` 생성
2. `variables.tf`의 `name` 기본값과 `region` 기본값만 바꾸면 나머지는 그대로 재사용 가능
   (모듈 인터페이스가 `network_id`/`subnet_id`, `instance_id`/`instance_ip`로 통일되어 있기 때문)
3. `versions.tf`의 backend `key`를 새 환경 이름으로 변경
4. `opentofu/templates/inventory.tpl`을 가리키는 `local_file.ansible_inventory`의
   `filename`도 새 환경 이름으로 변경
5. 완전히 새로운 provider(예: Oracle Cloud, Hetzner)를 추가하는 경우엔
   `opentofu/modules/network/<provider>`, `opentofu/modules/compute-<provider>`를
   기존 모듈과 동일한 output 인터페이스(`network_id`/`subnet_id`, `instance_id`/`instance_ip`)로
   새로 작성해야 한다. `compute-lima`처럼 공식 Terraform 프로바이더가 없는 도구는
   `null_resource` + `local-exec`로 CLI를 구동하는 패턴을 참고한다.
6. `.github/workflows/plan.yml`, `deploy.yml`의 `matrix.environment` 목록에 추가
7. `argocd/apps/`, `argocd/bootstrap/`에 새 환경용 매니페스트 추가
   (자세한 절차는 [adding-an-app.md](./adding-an-app.md) 참고)

Ansible 롤(`common`/`k3s`/`argocd`)은 provider와 무관하게 그대로 재사용된다 —
`inventory.tpl`이 만들어내는 `hosts.ini`의 그룹 구조(`k3s_servers`/`k3s_agents`)만
동일하면 되기 때문이다.
