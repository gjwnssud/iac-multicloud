# iac-multicloud 구축 계획서

> 저장소: `iac-multicloud` (github.com/gjwnssud/iac-multicloud, 개인 계정 소유, public)
> Claude Code 세션 시작 시 이 문서를 참조해 작업을 이어간다. 최종 갱신: 2026-11-27.

## 1. 목표

서버(VM/CT)를 EC2처럼 코드로 찍어내고, 그 위에서 어떤 앱이든 **같은 방식으로 자동 배포**한다.
멀티클라우드(AWS/GCP/Azure)와 로컬(Proxmox 홈서버, libvirt)을 **동일한 코드 구조**로 다룬다.

- 지금 용도: 개인 앱을 개발해서 홈랩(Proxmox)에 자동 배포. 규모가 커져도 아키텍처 변경 없이 확장 가능해야 한다.
- 서버만 필요한 경우(k3s 없이)와 앱 배포(k3s + ArgoCD) 두 경로를 모두 지원한다.

## 2. 기술 스택

| 레이어 | 도구 | 비고 |
|---|---|---|
| 프로비저닝 | OpenTofu | VM/CT 생성. 클라우드는 원격 state, 로컬은 로컬 state |
| 클러스터 구성 | Ansible | k3s, 로컬 레지스트리, ArgoCD 설치 (`site.yml`). 관리형 K8s는 해당 없음 |
| 컨테이너 런타임 | k3s 내장 containerd | Docker 불필요. 이미지 빌드는 k3s 소켓에 붙는 nerdctl + buildkit |
| 이미지 보관 | 로컬 레지스트리 (k3s 서버 노드 :5000) | `registry` role. 모든 노드에 mirror 설정 |
| 앱 배포 표준 | 범용 Helm chart `charts/app` + 앱별 values | 앱마다 chart를 만들지 않는다. 범용 chart로 안 되는 앱만 별도 chart |
| 앱 배포 방식 | **ArgoCD (GitOps, pull)** + ApplicationSet(SCM Provider) | 클러스터마다 독립 설치. GitHub organization을 조회해 앱 저장소를 자동 발견 |
| CI/CD | GitHub Actions | 인프라(plan/apply, ansible)와 앱 이미지 빌드만. 클러스터에 배포를 push하지 않음 |
| 정책 검증 | OPA (Conftest) | PR에서 tofu plan 결과 검증 (인스턴스 타입 허용 목록, SSH 0.0.0.0/0 차단) |
| 시크릿 | 클라우드 네이티브 시크릿 매니저 + 로컬은 SOPS | Vault는 규모 확대 시 검토 (아직 미도입) |

## 3. 저장소 구조

```
iac-multicloud/
├── opentofu/
│   ├── modules/
│   │   ├── compute-{aws,gcp,azure,libvirt}/
│   │   ├── compute-proxmox/        # Proxmox VM (cloud-init 템플릿 clone, 고정 IP)
│   │   ├── compute-proxmox-lxc/    # Proxmox CT (CT 템플릿 clone, 고정 IP, docker용 nesting 상속)
│   │   └── network/{aws,gcp,azure,libvirt}/
│   ├── environments/
│   │   ├── aws/ gcp/ azure/ libvirt/
│   │   ├── proxmox/            # k3s 노드 VM (server_ip_addresses/agent_ip_addresses)
│   │   └── proxmox-servers/    # k3s 무관 범용 서버 (vms/containers map, state는 proxmox와 분리)
│   ├── bootstrap/{aws,gcp,azure}/   # 원격 tfstate 저장소 1회성 생성
│   └── templates/inventory.tpl      # tofu output -> ansible hosts.ini
├── ansible/
│   ├── inventories/{libvirt,proxmox}/group_vars/all.yml   # hosts.ini는 tofu가 생성(gitignore)
│   ├── playbooks/{site,proxmox-template,proxmox-lxc-template}.yml
│   └── roles/{common,k3s,registry,argocd,github-runner,proxmox-template,proxmox-lxc-template}/
├── charts/app/                  # 범용 앱 chart (image/service/env/probes/ingress/resources)
├── argocd/
│   ├── bootstrap/root-{env}.yaml   # 클러스터당 1회 적용하는 루트 Application (include "*-{env}.yaml")
│   └── apps/appset-{env}.yaml      # 환경당 ApplicationSet (organization에서 앱 저장소 자동 발견)
├── examples/sample-hello-nestjs/   # 앱 저장소 시작 템플릿 (배포 대상 아님)
├── scripts/set-repo-url.sh         # 포크/템플릿 사용 시 repoURL, organization 일괄 교체
├── policy/*.rego
├── docs/                           # architecture, tech-stack, onboarding, new-site-checklist, adding-a-node, adding-an-app
└── .github/
    ├── environments.json           # 환경별 메타데이터 (provider, runs_on, plan, tofu_apply, inventory)
    ├── scripts/{select-environments,build-one,set-image}.sh
    └── workflows/{plan,deploy,build-app-image}.yml
```

## 4. 단계별 실행 계획 (Phase 0~7 완료)

| Phase | 내용 | 상태 |
|---|---|---|
| 0. 초기화 | 레포, `.gitignore`, `versions.tf`, README 스캐폴딩 | 완료 |
| 1. 공통 모듈 | `network`, `compute-*` 모듈 (입출력 이름 통일) | 완료 |
| 2. k3s + ArgoCD 부트스트랩 | Ansible `common`, `k3s`, `argocd` + inventory 자동 생성 | 완료 |
| 3. 이중화 구성 | 서버 1 + 에이전트 1 조인 | 완료 (서버 2대 이상의 컨트롤 플레인 이중화는 미구현) |
| 4. 클라우드 확장 | AWS/GCP/Azure VM+k3s 모듈과 환경 | 코드 완료, 실제 apply는 안 함 |
| 5. CI/CD | plan/deploy 워크플로, OPA 게이트 | 완료 (proxmox에서 deploy job 검증) |
| 6. 검증 배포 | 샘플 앱을 ArgoCD로 배포 | 완료 (proxmox, 2026-10-18). 이후 배포 구조 개편으로 샘플은 `examples/`로 이동 |
| 7. 문서화 | README, docs 6종 | 완료. 2026-11-27 전체 재작성 |

## 5. 설계 원칙

- **Provider 추상화**: 모듈 입출력 이름을 통일해 `environments/`만 provider를 바꾼다.
- **앱 비의존성**: 새 앱을 추가해도 인프라 저장소를 수정하지 않는다. 앱 저장소의 `deploy/values-{env}.yaml`만으로 배포된다.
- **앱 소스는 이 저장소 밖**: 앱은 GitHub organization(`hznlabs`)의 별도 저장소. 이 저장소에는 chart와 환경 규칙만 둔다.
- **개인 환경값은 코드 밖**: IP, 노드명 등은 gitignore된 `terraform.tfvars`에만 둔다. 변수 기본값에 개인 LAN 값을 넣지 않는다 (`gateway`, `server_ip_addresses`는 필수).
- **컨테이너 런타임 통일**: k3s 내장 containerd. Docker는 쓰지 않는다.
- **State 격리**: 클라우드는 원격 backend, 로컬은 로컬 state. `proxmox`와 `proxmox-servers`는 state가 분리돼 있다.
- **Pull 기반 배포**: ArgoCD가 git/GitHub를 조회한다. CI가 클러스터로 push하지 않는다.
- **클러스터별 독립 ArgoCD**: hub-and-spoke 대신 클러스터마다 설치해 로컬 클러스터에 대한 외부 접근 요구를 없앤다.
- **샘플 네이밍**: 템플릿 저장소의 데모 코드는 `sample-`/`example-` 접두사를 쓴다.

## 6. 확장 경로

```
1단계(단일)    : VM 1대 + k3s 단일 노드
2단계(확장)    : 에이전트(워커) 노드 추가. 서버는 1대 유지
3단계(클라우드): 같은 chart/values 구조로 AWS/GCP/Azure 환경 추가.
                필요하면 관리형 K8s를 environments/{cloud}-eks처럼 공존 추가
```

## 7. 결정 사항 / 리스크

- **VM+k3s 유지, 관리형 K8s는 공존 추가**: 비용과 재사용 이유로 VM+k3s로 결정. 관리형이 필요하면 전환이 아니라 별도 환경으로 추가한다.
- **인프라 변경은 push 기반**: GitHub 호스팅 러너가 사설망에 닿지 못하므로 로컬 대상은 self-hosted runner 또는 사람이 직접 실행한다. proxmox는 러너가 관리 대상 VM 안에서 돌고 tfstate가 로컬이라 `tofu_apply: false`(CI는 ansible만)다.
- **앱 배포에 organization이 필요**: ArgoCD SCM Provider(GitHub)가 organization 단위로만 저장소를 조회하고 개인 계정은 지원하지 않는다. 앱 저장소는 `hznlabs`에 두고, 인프라 저장소는 개인 계정(`gjwnssud`)에 그대로 둔다.
- **ArgoCD 폴링**: 3분 간격. webhook은 로컬 환경의 인바운드 제약으로 쓰지 않는다.
- **시크릿**: ArgoCD의 GitHub 토큰(`github-token` Secret)은 클러스터에 직접 만든다. PAT는 채팅/커밋에 남기지 않는다.
- **전역 gitignore 충돌**: `~/.gitignore_global`이 `CLAUDE.md`, `docs/`를 제외하므로 이 저장소 `.gitignore`가 `!CLAUDE.md`, `!docs/**`로 다시 포함한다. 새 문서를 추가한 뒤 `git status`로 추적되는지 확인한다.
- **이전 방식 이력**: 저장소 안 `apps/<app>/values-{env}.yaml` 방식과 `build-images.yml`은 SCM Provider 방식으로 교체돼 삭제됐다 (git 이력에서 복구 가능).

## 8. 진행 상태 및 다음 할 일 (2026-11-27 기준)

### 검증 완료

- **Proxmox 홈서버(10.77.0.100)**: 템플릿 9000, k3s VM(.122, 노드명 `hzn`, datastore `local-lvm`), k3s + 레지스트리 + ArgoCD, `root-proxmox.yaml` 적용 후 샘플 앱 Healthy (2026-10-18). self-hosted runner 설치와 `CI_ENVIRONMENTS=["proxmox"]` deploy job(ansible) success, 이미지 빌드 자동화(2026-10-20)까지 확인했다. 단, 이미지 빌드 자동화는 지금은 교체된 이전 방식으로 검증한 것이다.
- **범용 서버(2026-11-26)**: CT 템플릿 9100(Ubuntu 26.04 + docker + compose + git, unprivileged + nesting/keyctl) 플레이북 실행 성공, `proxmox-servers`로 CT 1대(106) 생성, `tofu plan` No changes.
- 이 호스트는 root SSH 로그인을 막아 두어 플레이북은 `-u hzn -K`(sudo 비밀번호)로 실행한다.
- 과거 `lima`(macOS) 환경은 end-to-end 검증 후 Proxmox로 방향을 바꾸면서 2026-10-18에 코드·러너·VM을 모두 제거했다 (git 이력 `2c44deb` 이전에서 복구 가능).

### 2026-11-27 구조 개편 (아직 실환경 미검증)

- 앱 배포를 ApplicationSet(SCM Provider)으로 교체: `hznlabs` organization에서 topic `homelab-app` + `deploy/values-{env}.yaml`이 있는 저장소를 자동 발견.
- 범용 chart `charts/app`, 앱 저장소용 재사용 workflow `build-app-image.yml`(앱 저장소 자신에 이미지 태그 커밋, 별도 토큰 불필요), `build-one.sh` 분리.
- `github-runner` role이 organization 러너(`github_runner_repo=<org>`)를 지원.
- 샘플 앱을 `examples/sample-hello-nestjs`(앱 저장소 시작 템플릿)로 이동, `build-images.yml`과 `environments.json`의 `build` 키 제거.
- `proxmox`, `proxmox-servers`의 `gateway`, `server_ip_addresses` 기본값 제거(필수 변수화). `scripts/set-repo-url.sh` 추가.

### 다음 할 일

- [ ] **앱 배포 구조 실환경 검증**: (1) `argocd` 네임스페이스에 `github-token` Secret 생성 (2) `hznlabs` organization 러너 설치 (`admin:org` PAT, Runner group이 public 저장소를 허용하는지 확인) (3) `examples/sample-hello-nestjs`로 앱 저장소를 만들어 topic 부여 후 push → ArgoCD 배포 확인. 구 샘플 Application이 prune되면 finalizer가 없어 워크로드가 남을 수 있으므로 `kubectl delete ns sample-hello-nestjs`로 정리한다. 절차는 `docs/adding-an-app.md`.
- [ ] 범용 서버 안에서 `docker run hello-world` 확인 (사용자 확인 후 진행)
- [ ] `opentofu/bootstrap/{aws,gcp,azure}` 실제 apply (원격 tfstate 백엔드). 실비용과 전역 유일 이름이 걸려 있어 **사용자가 직접 실행**한다. Claude가 자동으로 apply하지 않는다.
- [ ] GitHub Actions 클라우드 자격증명 등록 (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `GCP_SERVICE_ACCOUNT_KEY`, `AZURE_CREDENTIALS`)과 vars(`ALLOWED_SSH_CIDRS`, `AWS_AMI_ID`, `GCP_PROJECT_ID`, `TF_STATE_*`). 이미 등록된 것은 `SSH_PRIVATE_KEY`, `SSH_USERNAME`이다. `CI_ENVIRONMENTS`는 러너가 준비된 환경만 지정한다.
- [ ] 클라우드 3곳 실제 apply와 ansible 부트스트랩 → ArgoCD 기동 확인. 사용자가 클라우드 사용을 나중으로 미뤄 보류 중이다.
- [ ] `libvirt`용 실제 Linux/libvirtd 호스트 확보. Apple Silicon의 Lima VM은 KVM이 없어 TCG로만 동작하고 부팅이 극도로 느려(30분+ IP 미할당) 검증이 비현실적이었다. `domain_type` 변수와 cloud-init scsi 버스 수정, AppArmor 원인 분석은 완료했다(`docs/onboarding.md`). 호스트를 확보하면 러너 설치 후 `CI_ENVIRONMENTS`에 추가한다.
- [ ] (선택) 원격 tfstate backend(MinIO/S3) 도입 시 proxmox의 `tofu_apply`/`plan`을 `true`로 전환
- [ ] (선택) 컨트롤 플레인 이중화(embedded etcd) 구현. 지금 k3s role은 서버 1대만 지원한다.
