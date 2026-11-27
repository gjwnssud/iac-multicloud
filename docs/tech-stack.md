# 기술 스택 한눈에 보기 (인프라 입문자용)

이 저장소에 나오는 도구가 각각 무슨 일을 하는지 백엔드 개발자 관점에서 정리한다.
전체 구조는 [architecture.md](./architecture.md), 실습 절차는 [onboarding.md](./onboarding.md)를 본다.

택배 배송 시스템에 비유해서 순서대로 설명한다.

## 1. 서버를 만드는 도구: OpenTofu

VM 같은 서버를 코드로 선언해서 만든다. `tofu plan`은 실제로 바꾸지 않고 무엇이 바뀔지 보여주고(dry-run), `tofu apply`가 실제로 반영한다.
DB 마이그레이션처럼 현재 상태와 원하는 상태의 차이만 적용한다. 만든 결과는 state 파일에 기록한다.

> 비유: 건물을 지을 땅을 사고 골조를 세우는 사람. "2코어 4GB 서버 한 대"라고 코드로 써 두면 그대로 만들어진다.

이 저장소는 Proxmox, libvirt, AWS, GCP, Azure를 같은 구조로 다룬다. 개인 환경 값(IP, 노드 이름)은 git에 올라가지 않는 `terraform.tfvars`에만 둔다.

## 2. 서버에 소프트웨어를 설치하는 도구: Ansible

OpenTofu가 만든 빈 서버에 SSH로 들어가 설치하고 설정한다. 같은 명령을 여러 번 실행해도 결과가 같게 작성돼 있다.

> 비유: 골조만 세워진 건물에 전기, 수도, 인테리어를 설치하는 사람.

이 저장소에서 설치하는 것은 기본 설정(`common`), k3s, 로컬 레지스트리(`registry`), ArgoCD이고, 선택으로 CI 러너(`github-runner`)가 있다.

## 3. 컨테이너를 실행하는 시스템: k3s

Kubernetes를 가볍게 만든 버전이다. 컨테이너 이미지로 앱을 실행하고, 죽으면 다시 살리고, 원하는 개수를 유지한다.
`containerd`가 내장돼 있어 Docker를 따로 설치하지 않는다. 이미지 빌드도 k3s의 containerd 소켓에 붙는 `nerdctl`과 `buildkit`으로 한다.

자주 보는 Kubernetes 용어는 다음과 같다.

| 용어 | 뜻 |
|---|---|
| Pod | 실행 중인 컨테이너의 최소 단위. 앱 프로세스 하나 |
| Deployment | "이 이미지로 Pod를 N개 유지하라"는 선언. 새 버전은 하나씩 교체(롤링 업데이트) |
| Service | 여러 Pod 앞에 붙는 고정 내부 주소와 로드밸런서 |
| Ingress | 도메인과 경로를 보고 알맞은 Service로 보내는 규칙. k3s는 Traefik이 기본 내장 |
| Namespace | 클러스터 안에서 앱별로 나누는 구획 |

> 비유: 건물의 운영 시스템(엘리베이터, 전력 관리). 입주자(앱)가 들어오고 나가는 것을 관리한다.

## 4. 이미지 보관소: 로컬 레지스트리

빌드한 이미지를 저장하고 내려받는 곳이다. Maven 저장소의 이미지 버전이라고 보면 된다.
이 저장소는 k3s 서버 노드에 레지스트리(:5000)를 띄우고, 모든 노드가 그 주소를 쓰도록 설정한다. 외부 레지스트리를 쓰지 않아도 된다.

## 5. 앱 설정 템플릿: Helm과 범용 chart

Helm은 Kubernetes YAML을 값만 바꿔 재사용하게 해 주는 템플릿 도구다. 템플릿이 chart, 입력값이 values다.
이 저장소는 범용 chart 하나(`charts/app`)를 두고, 앱마다 이미지, 포트, 환경변수, 도메인만 values 파일로 넘긴다. 앱마다 chart를 새로 만들지 않는다.

> 비유: 표준 규격 상자. 어떤 앱이든 이 상자에 값만 채우면 k3s가 알아서 처리한다.

## 6. 자동 배포: ArgoCD와 GitOps

ArgoCD는 클러스터 안에서 git을 3분마다 직접 들여다보고, 바뀐 것이 있으면 클러스터에 반영한다.
CI가 클러스터로 밀어 넣지 않고 ArgoCD가 git을 당겨 온다. 그래서 집 공유기 안쪽처럼 외부에서 들어갈 문이 없는 곳에서도 동작한다.
git에 적힌 상태가 정답이라, 배포는 커밋이고 롤백은 `git revert`다. 클러스터에서 손으로 바꾼 것도 git 상태로 되돌려진다.

> 비유: 창고(git)에 새 상품이 들어오면 매장 직원(ArgoCD)이 스스로 창고를 확인해서 진열한다. 창고가 매장에 트럭을 보낼 필요가 없다.

### ApplicationSet과 organization

ApplicationSet은 ArgoCD에게 "어떤 앱을 배포할지"를 규칙으로 알려 준다. 이 저장소의 규칙은 이렇다.

> GitHub organization 안에서 topic이 `hznlabs-app`이고 `deploy/values-<env>.yaml`이 있는 저장소를 전부 배포한다.

- **topic**: GitHub 저장소에 붙이는 태그다. 여기서는 "이 저장소는 배포 대상"이라는 표시로 쓴다.
- **organization**: 여러 저장소를 묶는 GitHub 조직이다. ArgoCD가 개인 계정의 저장소는 조회하지 못해서 필요하다.

그래서 새 앱을 추가하려면 앱 저장소에 topic과 values 파일만 두면 되고, 이 인프라 저장소는 수정하지 않는다.

## 7. 빌드 자동화: GitHub Actions와 self-hosted runner

GitHub Actions는 push가 일어나면 정해 둔 작업을 실행한다. 이 저장소에서는 세 가지 일을 한다.

- 앱 이미지를 빌드해서 로컬 레지스트리에 올리고 이미지 태그를 커밋한다.
- PR에서 `tofu plan`을 실행하고 정책(OPA)으로 검사한다.
- main에 인프라 변경이 들어가면 `tofu apply`와 Ansible을 실행한다.

그런데 GitHub의 클라우드 러너는 집 사설망 안으로 들어올 수 없다. 그래서 **self-hosted runner**를 사설망 안의 서버에 설치한다.
러너가 GitHub으로 job을 가져오러 나가는 방식이라 포트를 열 필요가 없다.

> 비유: 현장에 상주하는 직원. 본사(GitHub)의 지시를 현장에서 대신 실행한다.

배포(ArgoCD)와 빌드(Actions)는 따로 돌아간다. Actions는 이미지를 만들고 태그를 커밋하는 데까지만 하고, 클러스터에는 접근하지 않는다.

## 8. 도면 검사: OPA / Conftest

PR에서 `tofu plan` 결과를 규칙으로 검사한다. 이 저장소는 허용하지 않은 인스턴스 타입(비용 통제)과 SSH(22)를 0.0.0.0/0에 여는 설정을 막는다.

> 비유: 착공 전에 도면을 심사하는 사람. 문제가 있으면 착공(merge)을 막는다.

## 9. 서버를 돌리는 곳: Proxmox와 libvirt

클라우드 대신 내 장비에서 가상 서버를 만드는 소프트웨어다. 홈서버는 Proxmox, 일반 Linux 서버는 libvirt를 쓴다.
OpenTofu가 쓰는 실행 수단일 뿐이고, 역할은 AWS/GCP/Azure와 같다. Proxmox에는 두 종류가 있다.

| 종류 | 설명 | 용도 |
|---|---|---|
| VM | OS 전체를 가진 가상 컴퓨터 | k3s 노드, 일반 서버 (EC2에 해당) |
| CT (LXC) | 호스트 커널을 공유하는 가벼운 격리 환경. 서버처럼 접속해서 쓴다 | docker를 돌리는 가벼운 서버 |

k3s 없이 서버만 필요하면 `opentofu/environments/proxmox-servers`의 map에 한 줄을 추가하면 된다.
템플릿(VM 9000, CT 9100)이 AMI 역할이다.

## 전체 흐름 요약

OpenTofu가 서버를 만들고, Ansible이 k3s와 ArgoCD를 설치한다. 개발자가 앱 저장소에 push하면 러너가 이미지를 빌드해 레지스트리에 올리고 태그를 커밋한다.
ArgoCD가 그 커밋을 발견해서 범용 chart로 클러스터에 반영한다. OPA는 인프라 변경이 나가기 전에 실수를 막는다.
