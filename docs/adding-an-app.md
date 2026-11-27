# 신규 앱 추가 절차

**앱 저장소에 `deploy/values-<env>.yaml`만 두면 이 인프라 저장소를 수정하지 않고 배포된다.**
ArgoCD가 GitHub organization(`hznlabs`)에서 대상 저장소를 직접 찾고, 이 저장소의 범용 chart
`charts/app`으로 배포한다. 앱마다 chart를 만들 필요도 없다.

```
앱 저장소 (hznlabs/my-app, topic: hznlabs-app)        이 인프라 저장소 (iac-multicloud)
├── src/, Dockerfile                                 ├── charts/app/                 범용 chart
├── deploy/                                          └── argocd/apps/appset-<env>.yaml
│   ├── values.yaml            (선택, 공통)                  └─ organization을 조회해 앱 자동 발견
│   └── values-proxmox.yaml    (환경별, 이 파일이 배포 선언)
└── .github/workflows/deploy.yml   재사용 workflow 호출
```

## 0. 최초 1회: 클러스터 준비

앱을 처음 연결하기 전에 한 번만 한다.

1. **ArgoCD가 organization을 조회할 토큰**(fine-grained PAT, 해당 organization 저장소 읽기:
   Contents/Metadata read)을 Secret으로 등록한다.
   ```bash
   kubectl -n argocd create secret generic github-token --from-literal=token=<PAT>
   ```
2. **private 앱 저장소**를 쓰면 ArgoCD가 clone할 자격증명도 등록한다 (public이면 불필요).
   ```bash
   kubectl -n argocd create secret generic repo-creds-hznlabs \
     --from-literal=type=git --from-literal=url=https://github.com/hznlabs \
     --from-literal=username=x --from-literal=password=<PAT>
   kubectl -n argocd label secret repo-creds-hznlabs argocd.argoproj.io/secret-type=repo-creds
   ```
3. **organization 러너**를 k3s 노드에 설치한다 (조직의 모든 저장소가 하나를 공유).
   PAT 권한은 fine-grained 토큰이면 Organization permissions의 `Self-hosted runners`(Read and write), classic 토큰이면 `admin:org`다.
   ```bash
   ansible-playbook ... --tags github-runner \
     -e github_runner_repo=hznlabs -e github_runner_build_tools_enabled=true
   ```
   organization 설정의 Runner groups에서 이 러너 그룹이 대상 저장소(public 포함)를 허용하는지 확인한다.
   기본 그룹은 public 저장소를 허용하지 않는다.

## 1. 앱 저장소 만들기

`examples/sample-hello-nestjs`가 그대로 복사해 쓸 수 있는 시작점이다.

1. `hznlabs` 아래에 저장소를 만든다. **저장소 이름이 곧 앱 이름**이다 (이미지 이름, k8s namespace,
   release 이름). 소문자, 숫자, 하이픈만 쓴다.
2. 저장소에 topic **`hznlabs-app`** 을 붙인다 (About 옆 톱니바퀴).
3. `deploy/values-<env>.yaml`을 만든다 (배포할 환경마다 하나: `proxmox` 등). 이 파일이 있어야 그 환경에 배포된다.

```yaml
# deploy/values.yaml (공통, 선택)
service:
  targetPort: 3000          # 컨테이너 포트 (환경변수 PORT 로도 주입됨)
probes:
  path: /healthz            # 빈 값이면 probe 없음
env:
  LOG_LEVEL: info
ingress:
  enabled: true
  host: my-app.example.com
```

```yaml
# deploy/values-proxmox.yaml (환경별)
replicaCount: 1
# image.repository/tag 는 CI가 빌드 후 이 파일에 기록한다
```

사용할 수 있는 키 전체는 이 저장소의 `charts/app/values.yaml` 참고. 로컬 검증:

```bash
helm template <app> <인프라 저장소>/charts/app -f deploy/values.yaml -f deploy/values-proxmox.yaml \
  --set image.repository=x --set image.tag=y
```

## 2. 빌드 workflow 추가

앱 저장소에 `.github/workflows/deploy.yml`을 둔다 (`examples/sample-hello-nestjs/.github/workflows/deploy.yml`).

```yaml
on:
  push:
    branches: [main]
    paths-ignore: ["deploy/**"]
jobs:
  build:
    permissions:
      contents: write
    uses: gjwnssud/iac-multicloud/.github/workflows/build-app-image.yml@main
    with:
      environment: proxmox
      infra_repo: gjwnssud/iac-multicloud
```

별도 토큰은 필요 없다. push하면 organization 러너가 이미지를 빌드해
`<k3s서버IP>:5000/<앱이름>:<git sha>`로 로컬 레지스트리에 올리고, 앱 저장소 자신의
`deploy/values-<env>.yaml`에 이미지 태그를 커밋한다 (`.github/workflows/build-app-image.yml`,
`.github/scripts/build-one.sh`). `@main` 대신 태그(`@v1`)로 고정하면 workflow 변경의 영향을 통제할 수 있다.

## 3. 배포는 자동

ArgoCD ApplicationSet이 3분마다 organization을 조회한다 (`requeueAfterSeconds: 180`).
조건은 topic `hznlabs-app` + `deploy/values-<env>.yaml` 존재이고, 만족하면 Application
`<앱이름>-<env>`가 만들어져 배포된다. 앱 코드를 push하면 위 2단계가 새 태그를 커밋하고
ArgoCD가 롤아웃한다.

- **앱 내리기**: topic을 떼거나 `deploy/values-<env>.yaml`을 지우면 Application이 사라지고
  `resources-finalizer`로 워크로드도 함께 정리된다.
- **환경별 선택**: `deploy/values-<env>.yaml`을 둔 환경에만 배포된다.
- **인프라 저장소는 수정하지 않는다.** 환경 추가는 `argocd/apps/appset-<env>.yaml`(환경당 1개) 몫이다.

## 4. 로컬 클러스터로 실제 확인 (선택)

`ansible/roles/k3s`가 k3s 설치 시 `nerdctl`(+ `buildkitd`)을 함께 설치하고,
k3s의 containerd 소켓에 붙도록 `buildkit.service`를 구성해둔다. 별도로 Docker
Desktop이나 nerdctl을 수동 설치할 필요 없이, `proxmox`/`libvirt`에
k3s가 떠 있는 노드라면 바로 다음이 된다:

```bash
# proxmox 예시 - k3s의 containerd 네임스페이스로 바로 빌드
scp -r <앱 저장소 디렉터리> <node>:~/<app-name>
ssh <node> "cd <app-name> && sudo nerdctl --namespace k8s.io \
  --address /run/k3s/containerd/containerd.sock build -t <app-name>:latest ."

helm upgrade --install <app-name> charts/app \
  -f deploy/values.yaml \
  -f deploy/values-proxmox.yaml \
  --set image.pullPolicy=IfNotPresent \
  -n <app-name> --create-namespace
```

`examples/sample-hello-nestjs`를 이 방식으로 검증한 절차와 동일하다.

### 왜 nerdctl이 k3s의 containerd 소켓에 직접 붙는가

- **nerdctl은 daemon이 아니라 CLI다.** `docker` 명령이 `dockerd`에게 gRPC로
  요청을 보내는 것처럼, `nerdctl`도 containerd의 gRPC API에 요청을 보낼 뿐이다.
  즉 자기 소유의 런타임을 새로 띄우지 않고 `--address`로 지정한 *어떤*
  containerd 소켓에도 붙을 수 있다.
- **k3s는 자체 containerd를 별도 소켓/네임스페이스로 격리해서 띄운다.** 기본
  경로(`/run/containerd/containerd.sock`)가 아니라 `/run/k3s/containerd/containerd.sock`을
  쓰고, kubelet이 관리하는 이미지/컨테이너는 전부 `k8s.io` 네임스페이스 안에
  둔다. 호스트에 별도 Docker/containerd가 있어도 서로 충돌하지 않게 하기 위함이다.
  따라서 `--namespace k8s.io --address /run/k3s/containerd/containerd.sock`로
  붙어야 kubelet이 보는 것과 **동일한** 이미지 저장소에 쓰게 된다.
- **레지스트리 왕복이 필요 없다.** 다른 containerd/Docker에서 빌드하면 이미지가
  다른 저장소에 남기 때문에 k3s가 그 이미지를 못 찾아 `ImagePullBackOff`가
  난다. k3s의 소켓/네임스페이스에 직접 빌드해 넣으면 push/pull 없이 바로
  `imagePullPolicy: IfNotPresent`로 파드가 그 이미지를 쓸 수 있다.
- **containerd 자체엔 빌드 기능이 없다.** 이미지 빌드(Dockerfile 실행)는
  BuildKit의 역할이라, `buildkitd`를 `--containerd-worker-addr`로 같은 k3s
  소켓/네임스페이스를 보게 띄워두고 `nerdctl build`가 그 buildkitd를 호출하는
  구조다.

## 5. 범용 chart로 표현이 안 되는 앱

StatefulSet, CronJob 등은 앱 저장소에 자체 chart를 두고, 이 저장소 `argocd/apps/<app>-<env>.yaml`에
Application을 직접 쓴다 (`source.repoURL`/`path`를 앱 저장소로 지정, root Application이
`*-<env>.yaml` 글롭으로 인식). 이 경우만 이 저장소를 수정한다. private이면 0절 2번 자격증명이 필요하다.

## 6. 외부 접속

k3s 내장 Traefik이 노드의 80/443을 받는다. `deploy/values-<env>.yaml`에 `ingress.host`를 두고,
Nginx Proxy Manager(CT)에서 해당 도메인을 `<k3s노드IP>:80`으로 포워딩한다.
