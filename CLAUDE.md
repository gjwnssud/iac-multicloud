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
│   │   └── network/            # 공통 인터페이스 (VPC/subnet 추상화)
│   ├── environments/
│   │   ├── aws/
│   │   ├── gcp/
│   │   ├── azure/
│   │   ├── local-libvirt/      # 로컬 리눅스 서버/VM 환경
│   │   └── local-mac/          # 로컬 macOS 환경 (Lima)
│   ├── bootstrap/               # 원격 tfstate 저장소(S3/GCS/Storage Account) 1회성 생성
│   └── templates/
│       └── inventory.tpl       # tofu output → ansible inventory 자동 생성
├── ansible/
│   ├── inventories/
│   │   └── {env}/hosts.ini     # tofu가 자동 생성
│   ├── roles/
│   │   ├── common/             # 공통 base (방화벽, 유저, 타임존 등)
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
- 클라우드 확장 시 EKS/GKE/AKS(관리형) vs VM+k3s(직접 관리) 중 선택 필요 — 비용/운영 부담 비교 후 결정
- **인프라 변경(tofu apply, k3s 부트스트랩)은 여전히 push 기반**: GitHub 호스팅 러너는 로컬 사설망에 도달 불가하므로, 로컬 대상 인프라 작업은 self-hosted runner(로컬 네트워크 내부에 설치) 또는 로컬에서 직접 실행 필요. ArgoCD는 앱 배포 단계에만 적용되며 이 문제를 해결하지 않음
- ArgoCD sync 방식: 기본 polling(3분 간격) 사용, 즉시 반영이 필요하면 webhook 고려하되 로컬 환경은 인바운드 제약으로 webhook 적용 어려움 — 로컬은 polling 유지 권장
