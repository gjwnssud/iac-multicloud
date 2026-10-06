# 신규 앱 추가 절차

인프라 코드는 건드릴 필요가 없다 (설계 원칙 5: 앱 비의존성). `apps/sample-hello-nestjs`를
실제 예시로 두고 그대로 따라 하면 된다.

## 1. Helm chart 작성

```
apps/<app-name>/chart/
├── Chart.yaml
├── values.yaml              # 공통 기본값
├── values-aws.yaml           # 환경별 오버라이드 (필요한 환경만 작성하면 됨)
├── values-gcp.yaml
├── values-azure.yaml
├── values-libvirt.yaml
├── values-lima.yaml
├── values-proxmox.yaml
└── templates/
    ├── deployment.yaml
    └── service.yaml
```

로컬에서 먼저 검증한다:

```bash
cd apps/<app-name>/chart
helm lint . -f values.yaml -f values-<env>.yaml
helm template test . -f values.yaml -f values-<env>.yaml
```

## 2. ArgoCD Application 매니페스트 등록

배포하려는 환경마다 `argocd/apps/<app-name>-<env>.yaml`을 추가한다
(`apps/sample-hello-nestjs-*.yaml` 참고):

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: <app-name>-<env>
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/gjwnssud/iac-multicloud.git
    targetRevision: main
    path: apps/<app-name>/chart
    helm:
      valueFiles:
        - values.yaml
        - values-<env>.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: <app-name>
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

## 3. bootstrap은 수정 불필요

`argocd/bootstrap/root-<env>.yaml`은 `directory.include: "*-<env>.yaml"` 글롭으로
`argocd/apps/` 안의 파일을 골라온다. 파일명을 `<app-name>-<env>.yaml` 규칙대로만 지으면
루트 Application이 다음 git polling 주기(기본 3분)에 자동으로 새 앱을 인식해서 동기화한다 —
**bootstrap 파일을 수정할 필요가 없다.**

## 4. 컨테이너 이미지

이 저장소의 CI(`plan.yml`/`deploy.yml`)는 이미지 빌드를 하지 않는다 (인프라 전용).
앱 저장소의 자체 CI에서 이미지를 빌드해 레지스트리에 푸시하고, `values-<env>.yaml`의
`image.repository`/`image.tag`가 그 이미지를 가리키도록 하면 된다.

## 5. 로컬 클러스터로 실제 확인 (선택)

`ansible/roles/k3s`가 k3s 설치 시 `nerdctl`(+ `buildkitd`)을 함께 설치하고,
k3s의 containerd 소켓에 붙도록 `buildkit.service`를 구성해둔다. 별도로 Docker
Desktop이나 nerdctl을 수동 설치할 필요 없이, `lima`/`libvirt`에
k3s가 떠 있는 노드라면 바로 다음이 된다:

```bash
# lima(Lima) 예시 - k3s의 containerd 네임스페이스로 바로 빌드
scp -r apps/<app-name> <node>:~/
ssh <node> "cd <app-name> && sudo nerdctl --namespace k8s.io \
  --address /run/k3s/containerd/containerd.sock build -t <app-name>:latest ."

helm upgrade --install <app-name> apps/<app-name>/chart \
  -f apps/<app-name>/chart/values.yaml \
  -f apps/<app-name>/chart/values-lima.yaml \
  --set image.pullPolicy=IfNotPresent \
  -n <app-name> --create-namespace
```

`sample-hello-nestjs`를 이 방식으로 검증한 절차와 동일하다.

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

## 6. 별도 레포의 웹 애플리케이션 배포 (fork 운영 권장)

실서비스 앱은 이 저장소(인프라) 안에 두지 않고 **앱 레포가 chart와 이미지까지 소유**하게 하는 구성을 권장한다.
인프라 fork는 "어떤 앱을 어느 클러스터에 띄울지"를 가리키는 Application 매니페스트만 갖는다.

```
앱 레포 (my-web-app)                         인프라 fork (iac-multicloud)
├── src/, Dockerfile                        └── argocd/apps/my-web-app-proxmox.yaml
├── deploy/chart/  (Chart, values*.yaml)         └── source.repoURL: 앱 레포, path: deploy/chart
└── .github/workflows/build.yml
```

1. **앱 레포**: `Dockerfile`과 `deploy/chart/`(Deployment, Service, Ingress, `values-proxmox.yaml`)를 둔다.
2. **이미지 빌드**: 앱 레포용 self-hosted runner를 k3s 노드에 설치한다
   (`ansible-playbook ... --tags github-runner -e github_runner_repo=<owner>/<app> -e github_runner_build_tools_enabled=true`).
   CI에서 `nerdctl build` 후 `<k3s서버IP>:5000/<app>:<git sha>`로 로컬 레지스트리에 push한다
   (`registry` 롤이 모든 노드에 mirror 설정을 해둔다).
3. **배포 트리거**: CI가 `values-proxmox.yaml`의 `image.tag`를 새 sha로 바꿔 앱 레포에 커밋한다
   (무한 루프 방지를 위해 `[skip ci]`). ArgoCD가 polling으로 변경을 감지해 롤아웃한다.
4. **인프라 fork에 Application 등록**: `argocd/apps/<app>-proxmox.yaml`의 `repoURL`/`path`를 앱 레포로
   지정하고 push한다 (root Application이 글롭으로 자동 인식). 앱 레포가 private이면 ArgoCD에 저장소
   자격증명(`argocd repo add` 또는 repository Secret)을 먼저 등록한다.
5. **외부 접속**: k3s 내장 Traefik이 노드의 80/443을 받는다. chart에 Ingress(host 규칙)를 두고,
   Nginx Proxy Manager(CT)에서 해당 도메인을 `<k3s노드IP>:80`으로 포워딩한다.
