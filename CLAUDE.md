# iac-multicloud 구축 계획서

> 저장소명: `iac-multicloud` (github.com/gjwnssud/iac-multicloud)
> Claude Code 세션 시작 시 이 문서를 참조하여 순서대로 작업을 진행한다.

## 1. 목표

멀티클라우드(AWS/GCP/Azure) + 로컬(온프레미스/베어메탈) 인프라를 **동일한 코드 구조**로 프로비저닝하고, 애플리케이션 종류(Java/Spring Boot, NestJS 등)에 무관하게 **k3s + Helm 기반 배포**로 통일한다.

- 시작 규모: 단일 노드 또는 이중화(2노드)
- 목표: 노드/워크로드 추가 시 아키텍처 변경 없이 확장 가능

## 2. 기술 스택

| 레이어 | 도구 | 비고 |
|---|---|---|
| 프로비저닝 | OpenTofu | VM 또는 관리형 K8s 클러스터 생성 |
| 클러스터 구성 | Ansible | 로컬/온프렘 VM에 k3s 설치·부트스트랩 전용 (관리형 K8s는 클라우드가 컨트롤 플레인 관리) |
| 컨테이너 런타임 | k3s 내장 containerd | 별도 Docker 설치 불필요. Docker는 CI 빌드 단계에서만 사용 |
| 앱 배포 표준 | Helm chart | `docker-compose.yml` 대신 앱마다 Helm chart 하나 |
| 앱 배포 방식 | **ArgoCD (GitOps, pull 기반)** | 클러스터가 git 저장소를 직접 polling, push 방향 아님 → 로컬/클라우드 네트워크 도달성 문제 원천 해결 |
| CI/CD | GitHub Actions | **인프라(tofu plan/apply, k3s+ArgoCD 부트스트랩)까지만 담당**. 앱 배포는 트리거하지 않음 |
| 정책 검증 | OPA (Conftest) | PR 단계에서 tofu plan 결과 검증 |
| 시크릿 | 클라우드 네이티브 시크릿 매니저(AWS/GCP/Azure) + 로컬은 SOPS | Vault는 규모 확대 시 도입 검토 |

## 3. 저장소 구조

```
iac-multicloud/
├── opentofu/
│   ├── modules/
│   │   ├── compute-aws/        # EC2 (또는 EKS)
│   │   ├── compute-gcp/        # Compute Engine (또는 GKE)
│   │   ├── compute-azure/      # Azure VM (또는 AKS)
│   │   ├── compute-libvirt/    # 로컬 KVM/QEMU VM (리눅스 호스트 전용)
│   │   ├── compute-lima/       # 로컬 Lima VM (macOS 호스트 전용, limactl 구동)
│   │   ├── compute-proxmox/    # Proxmox VM (cloud-init 템플릿 clone, 고정 IP)
│   │   └── network/            # 공통 인터페이스 (VPC/subnet 추상화)
│   ├── environments/
│   │   ├── aws/
│   │   ├── gcp/
│   │   ├── azure/
│   │   ├── libvirt/      # 로컬 리눅스 서버/VM 환경
│   │   ├── lima/          # 로컬 macOS 환경 (Lima)
│   │   └── proxmox/      # Proxmox 홈서버 (bpg/proxmox, cloud-init 템플릿 clone)
│   ├── bootstrap/               # 원격 tfstate 저장소(S3/GCS/Storage Account) 1회성 생성
│   └── templates/
│       └── inventory.tpl       # tofu output → ansible inventory 자동 생성
├── ansible/
│   ├── inventories/
│   │   └── {env}/hosts.ini     # tofu가 자동 생성
│   ├── roles/
│   │   ├── common/             # 공통 base (방화벽, 유저, 타임존 등)
│   │   ├── proxmox-template/   # Proxmox 호스트에 cloud-init 템플릿 VM 1회 생성 (playbooks/proxmox-template.yml)
│   │   ├── k3s/                # k3s 설치 + 클러스터 조인 (server/agent)
│   │   └── argocd/             # ArgoCD 설치 (Helm 기반, 클러스터별 독립 설치)
│   └── playbooks/
│       └── site.yml
├── argocd/
│   ├── bootstrap/               # app-of-apps 패턴 root Application (클러스터당 1회 적용)
│   └── apps/
│       ├── {app}-local.yaml     # ArgoCD Application 매니페스트 (환경별)
│       ├── {app}-aws.yaml
│       └── ...
├── apps/
│   └── {app-name}/
│       └── chart/                # 앱별 Helm chart (인프라 코드와 완전 분리)
│           ├── values.yaml        # 공통 값
│           └── values-{env}.yaml  # 환경별 오버라이드 (ArgoCD Application에서 참조)
├── policy/
│   └── *.rego                    # OPA 정책
└── .github/workflows/
    ├── plan.yml                  # PR 시 tofu plan + OPA 검증
    └── deploy.yml                # merge 시 tofu apply + ansible-playbook (k3s+ArgoCD 부트스트랩만 담당, 앱 배포는 트리거 안 함)
```

## 4. 단계별 실행 계획

| Phase | 내용 | 완료 기준 |
|---|---|---|
| 0. 초기화 | `iac-multicloud` 레포 생성, `.gitignore`, `versions.tf`, README 스캐폴딩 | 디렉토리 구조 생성 완료 |
| 1. 공통 모듈 | `network`, `compute-*` 모듈 작성 (provider별 input/output 변수명 통일: `instance_ip`, `instance_id` 등) | 각 provider에서 `tofu plan` 통과 |
| 2. k3s + ArgoCD 부트스트랩 | Ansible `common`, `k3s`, `argocd` 롤 작성 + inventory 자동 생성 템플릿 | 로컬 VM 1대에서 k3s 단일 노드 + ArgoCD 정상 기동, UI/CLI 접근 확인 |
| 3. 이중화 구성 | k3s 서버 노드 2대 구성 (또는 서버 1 + 에이전트 1) | 노드 2대 클러스터 조인 확인, `kubectl get nodes` 정상 |
| 4. 클라우드 확장 | AWS/GCP/Azure 관리형 K8s(EKS/GKE/AKS) 모듈 또는 VM+k3s 모듈 완성, 클러스터별 ArgoCD 설치 | 3개 클라우드 + 로컬 각 클러스터에 독립 ArgoCD 기동 확인 |
| 5. CI/CD (인프라 전용) | GitHub Actions로 tofu plan/apply + ansible-playbook 파이프라인, OPA 정책 게이트 추가. 로컬 대상 apply는 self-hosted runner 필요 | PR에서 자동 plan 코멘트, main merge 시 인프라 자동 apply (앱 배포는 포함 안 함) |
| 6. 검증 배포 | 샘플 앱(NestJS 또는 Spring Boot) Helm chart 작성 + `argocd/apps/`에 Application 등록 → git push로 각 클러스터 ArgoCD가 자동 동기화하는지 확인 | 모든 타겟 환경에서 push만으로 앱 자동 배포 및 서비스 접근 확인 |
| 7. 문서화 | README, 아키텍처 다이어그램, 온보딩 가이드, 노드 추가 절차 문서화 | 신규 환경/앱 추가 절차 문서화 완료 |

## 5. 설계 원칙

- **Provider 추상화**: OpenTofu 모듈 입출력 변수명을 클라우드 간 통일 → `environments/` 레이어만 provider 교체
- **앱 비의존성**: Ansible은 k3s 설치까지만 책임, 앱 배포 로직은 `apps/{app}/chart/`에 격리 → 새 애플리케이션 추가 시 인프라 코드 변경 불필요
- **컨테이너 런타임 통일**: 모든 환경에서 k3s 내장 containerd 사용, Docker는 CI 빌드 단계 전용
- **State 격리**: 클라우드별 원격 backend(S3/GCS/AzureRM), 로컬은 로컬 state 또는 MinIO
- **점진적 확장**: 단일 노드 → 이중화 → 워커 노드 추가 → 클라우드 관리형 이관까지 Helm chart는 변경 없이 재사용
- **Pull 기반 배포**: 앱 배포는 각 클러스터의 ArgoCD가 git 저장소를 직접 polling하여 처리 → CI가 클러스터로 push할 필요 없음, 로컬/사설망 인바운드 문제 원천 해결
- **클러스터별 독립 ArgoCD**: hub-and-spoke(중앙 ArgoCD가 여러 클러스터 관리) 대신 클러스터마다 ArgoCD를 독립 설치 → 로컬 클러스터에 대한 외부 접근성 요구 자체가 없어짐

## 6. 확장 경로 (참고)

```
1단계(단일)   : VM 1대 + k3s 단일 노드
2단계(이중화) : VM 2대, k3s 서버 이중화 또는 서버+에이전트
3단계(확장)   : 워커 노드 추가, 또는 클라우드 관리형 K8s(EKS/GKE/AKS)로 이관
              → Helm chart는 그대로 재사용, Ansible k3s 롤만 클라우드에서는 불필요해짐
```

## 7. 리스크 / 추후 결정 사항

- 시크릿 관리: 초기엔 클라우드 네이티브+SOPS로 시작, 팀/규모 커지면 Vault 도입 검토
- ~~클라우드 확장 시 EKS/GKE/AKS(관리형) vs VM+k3s(직접 관리) 중 선택 필요~~ → **결정 완료**: VM+k3s
  유지 (비용/재사용 이유). 관리형 K8s가 필요해지면 전환이 아니라 `environments/{cloud}-eks` 같은
  형태로 **공존** 추가. 로컬은 `libvirt`(리눅스 호스트)와 `lima`(macOS/Lima)으로 분리
- **인프라 변경(tofu apply, k3s 부트스트랩)은 여전히 push 기반**: GitHub 호스팅 러너는 로컬 사설망에 도달 불가하므로, 로컬 대상 인프라 작업은 self-hosted runner(로컬 네트워크 내부에 설치) 또는 로컬에서 직접 실행 필요. ArgoCD는 앱 배포 단계에만 적용되며 이 문제를 해결하지 않음
- ArgoCD sync 방식: 기본 polling(3분 간격) 사용, 즉시 반영이 필요하면 webhook 고려하되 로컬 환경은 인바운드 제약으로 webhook 적용 어려움 — 로컬은 polling 유지 권장

## 8. 진행 상태 및 다음 할 일 (2026-09-01 기준)

Phase 0~7 전체 완료. GitHub 원격 저장소 생성 및 push 완료
(https://github.com/gjwnssud/iac-multicloud, public).

`lima`은 실제로 end-to-end 검증됨(tofu apply → ansible k3s+argocd → 이미지 빌드 →
helm install → curl 응답 확인). 실제로 `main` push로 Actions를 실행해본 이력(run 32325148355)이
있는데, aws/gcp/azure는 자격증명 미등록으로 즉시 실패, `libvirt`는 매칭되는 self-hosted
runner가 없어 24시간 대기 후 타임아웃 — 아래 TODO들이 그 원인이다.

**lima vs libvirt self-hosted runner 설계가 다르다** (자세한 내용은
[docs/architecture.md](./docs/architecture.md) 3절): `limactl`은 daemon/원격 프로토콜이 없는 순수
로컬 CLI라 게스트 VM 안 러너 컨테이너가 `tofu apply`를 대신할 수 없다 (ansible만 자동화, tofu는 Mac에서
수동 유지). 반면 `libvirt`는 daemon+원격 클라이언트 구조라 `libvirt_uri`를 `qemu+ssh://...`로 주면
게스트 VM 안 러너 컨테이너가 `tofu apply`부터 `ansible-playbook`까지 전부 처리할 수 있다 — 이 방향으로
`opentofu/environments/libvirt/variables.tf`(`libvirt_uri` 원격 URI 설명),
`terraform.tfvars.example`, `ansible/roles/github-runner`(`github_runner_extra_packages` 변수),
`ansible/inventories/libvirt/group_vars/all.yml`(`libvirt-clients` 설치, 라벨/arch 오버라이드)까지
코드는 반영해뒀다.

**실제 Linux/libvirtd 호스트 대신 Lima VM(`iac-multicloud-libvirt-devbox`)으로 시험 apply를 시도함**
(Apple Silicon이라 KVM 가속 없음, TCG로만 동작). 이 과정에서 실제 버그 2개를 발견해 고쳤고 커밋됨
(KVM 미지원 호스트에서도, 실제 KVM 호스트에서도 안전한 변경):
- `libvirt_domain`이 항상 `type="kvm"`으로 고정 → `domain_type` 변수 추가 (기본값 `kvm` 유지, override 가능)
- `cloudinit` top-level 속성이 항상 IDE bus cdrom으로 붙는데 aarch64 `virt` machine은 IDE 자체를
  지원 안 함 → 일반 disk + `scsi=true`로 변경 (모든 아키텍처에서 동작)

`tofu apply`가 qemu 프로세스의 backing 파일(`*-base.qcow2`) open에서 `Permission denied`로 막혔던
문제는 **원인을 찾았다**: AppArmor. `virsh pool-define-as`로 storage pool을 CLI에서 직접 만들면,
libvirt가 VM마다 자동 생성하는 AppArmor 화이트리스트(`/etc/apparmor.d/libvirt/libvirt-<uuid>.files`)에
그 pool 볼륨 경로가 누락된다(virt-aa-helper가 pool 기반 볼륨 경로를 못 채움). devbox에서는
`qemu.conf`에 `security_driver = "none"` 추가로 우회 — **이건 devbox 환경 설정일 뿐 모듈 코드 문제가
아니라서 코드 변경은 없음** (자세한 내용/재현 조건은 `docs/onboarding.md` "자주 막히는 지점" 참고,
실제 서버에서도 pool을 CLI로 만들면 동일하게 재현될 수 있음).

이 수정 후 `tofu apply`로 domain 생성·기동까지는 성공했다(`efi-virtio.rom` 누락 문제도 `ipxe-qemu`
설치로 해결). 다만 KVM 가속이 없어 TCG 소프트웨어 에뮬레이션으로 부팅해야 해서 30분 넘게 기다려도
DHCP IP를 못 받을 만큼 느렸다 — devbox 자체의 근본적 한계(Apple Silicon은 중첩 가상화 미지원)라 여기서
검증을 중단했다. **실제 KVM 지원 호스트라면 이 부팅 지연 자체가 없을 것으로 예상된다.**

**`github-runner` role이 lima에서 실제로 검증됐다**: fine-grained PAT(Administration:RW,
저장소 한정)로 `ansible-playbook --tags github-runner`를 실행해 lima server VM 안 컨테이너
러너가 GitHub에 실제 등록됨(`Connected to GitHub` / `Runner successfully added`, GitHub Runners
페이지에 `lima` 라벨로 표시). 과정에서 실제 버그를 하나 더 고쳤다: `ubuntu:24.04` 베이스 이미지에
actions-runner(.NET 기반)가 요구하는 `libicu` 등이 없어 계속 crash-loop했는데, 러너에 내장된
`bin/installdependencies.sh`가 24.04(noble)를 인식 못 하고 오래된 패키지명(`libicu52`)을 시도해서
실패하던 것 — 최신 패키지명(`libicu74` 등)을 직접 설치하도록 수정, 커밋 완료.

**`lima`을 `deploy.yml`에 편입 완료** (2026-10-06부터 매트릭스 고정 대신 `CI_ENVIRONMENTS` 변수로 선택, Lima VM/러너는 제거된 상태): ansible 단계(k3s+ArgoCD 재적용)만 이 러너가 자동
실행하도록 매트릭스에 추가했고(tofu는 여전히 Mac에서 수동), lima VM에서 직접 동작 검증까지
마쳤다. 과정에서 두 가지를 더 고쳤다: (1) `hosts.ini`가 커밋 안 되므로(gitignore) CI가 `k3s kubectl
get nodes`로 클러스터에서 직접 노드 IP를 조회해 인벤토리를 동적 생성하도록 워크플로 스텝 추가 (2) 이를
위해 러너 컨테이너에 `k3s.yaml`/`k3s` 바이너리를 읽기 전용 마운트했는데, k3s.yaml의 API 서버 주소가
127.0.0.1이라 컨테이너 자체 네트워크 네임스페이스에서 연결이 안 돼 `--net host`로 전환. `plan.yml`은
tofu plan 자체가 Mac 전용이라 편입하지 않음(lima 지원 대상 아님).

**Proxmox 홈서버(192.168.0.100) 편입 (2026-09-30)**: `compute-proxmox` 모듈과 `proxmox` 환경을
추가했다(`bpg/proxmox`, cloud-init 템플릿 clone + 고정 IP). `tofu validate`까지만 통과했고 실제 apply는
미검증. 같은 노드에 Steam VM(.120)/NPM CT(.110)가 있어 k3s VM은 IP 규칙(CT 110번대, VM 120번대)에 따라 기본 단일 노드(.121)로 시작한다. 이에
따라 macOS 로컬 배포는 불필요해져 Lima VM 3개, `lima`/`socket_vmnet` brew 패키지, GitHub runner
`lima` 등록을 제거했다 — `compute-lima`/`lima` 코드는 참고용으로 남겨뒀다.

다음 세션에서 필요할 때 진행할 것:

- [ ] `proxmox` 실제 apply: `proxmox-template` 플레이북으로 템플릿 VM 준비(미실행) → API 토큰 발급 → `tofu apply` →
      `ansible-playbook` → `argocd/bootstrap/root-proxmox.yaml` 적용. 이후 CI 편입(`select-environments.sh` 지원 목록 + 환경별 스텝 + `CI_ENVIRONMENTS`)
      (하드코딩된 환경별 `if` 분기를 `environments.yaml` 메타데이터 기반으로 정리하는 리팩터링 포함 검토)

- [ ] `opentofu/bootstrap/{aws,gcp,azure}` 실제 apply — 원격 tfstate 백엔드(S3+DynamoDB/GCS/Storage
      Account) 생성. 실비용 발생, 버킷/스토리지 계정 이름은 전역 유일해야 함
      (`terraform.tfvars.example` 참고). **실제 실행은 사용자가 직접** — 클라우드 비용/자격증명이
      걸려 있어 Claude가 자동으로 apply하지 않는다
- [x] GitHub 저장소에 Actions 시크릿/변수 등록 — `SSH_PRIVATE_KEY`(lima이 쓰는
      `~/.ssh/iac_multicloud_local`과 동일 키)/`SSH_USERNAME`("ubuntu") 등록 완료.
      **`lima`의 `deploy.yml` job이 실제로 success로 끝까지 통과함** (run 33501442246,
      2026-09-01). aws/gcp/azure 자격증명은 아직 미등록 — 클라우드 진행 여부 결정 후 등록
  - secrets 남은 것: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `GCP_SERVICE_ACCOUNT_KEY`,
    `AZURE_CREDENTIALS`
  - vars 남은 것: `CI_ENVIRONMENTS`(자동 plan/apply 대상, 미설정이면 CI는 아무 환경도 실행하지 않음), `ALLOWED_SSH_CIDRS`, `AWS_AMI_ID`, `GCP_PROJECT_ID`, `TF_STATE_BUCKET_AWS`,
    `TF_STATE_LOCK_TABLE_AWS`, `TF_STATE_BUCKET_GCP`, `TF_STATE_RG_AZURE`, `TF_STATE_ACCOUNT_AZURE`
- [ ] `libvirt`용 실제 Linux/libvirtd 호스트 확보 — 현재 범위 밖. macOS(Lima devbox)로는
      TCG 소프트웨어 에뮬레이션이라 부팅이 극도로 느려 완전한 검증이 비현실적임을 확인함
      (docs/architecture.md 5절). 확보되면 (1) `ansible-playbook ... --tags github-runner`로 러너
      설치·검증 (2) 리포지토리 변수 `CI_ENVIRONMENTS`에 `libvirt` 추가 (러너 없이 지정하면
      concurrency 그룹 대기로 push가 막히므로 러너 준비 후에만)
- [ ] 클라우드 3곳(aws/gcp/azure)에 실제 apply/ansible 부트스트랩 → ArgoCD 기동 확인. 현재 보류
      (사용자가 클라우드 사용을 나중으로 미룸)
- [ ] 위 항목들 완료 후 각 신규 클러스터에 `argocd/bootstrap/root-{env}.yaml` 1회 적용해 GitOps
      루프 실제 동작 확인 (`docs/onboarding.md` 참고). lima은 이미 예전에 적용·검증됨
