# 신규 앱 추가 절차

인프라 코드는 건드릴 필요가 없다 (설계 원칙 5: 앱 비의존성). 앱마다 chart를 만들 필요도 없다 —
범용 chart `charts/app`이 이미지/포트/env/ingress를 values로 받아 Deployment·Service·Ingress를 만든다.
`apps/sample-hello-nestjs`를 실제 예시로 두고 따라 하면 된다.

## 1. values 작성

```
apps/<app-name>/
├── Dockerfile / src/ ...    # (선택) 소스. 별도 레포로 분리하려면 6절 참고
├── values.yaml              # 앱 공통 값 (선택)
└── values-<env>.yaml        # 배포할 환경마다 하나 (aws/gcp/azure/libvirt/proxmox)
```

```yaml
# values.yaml 예시
image:
  repository: my-app        # build-images.yml이 values-<env>.yaml 에 <노드IP>:5000/my-app + sha 태그를 자동 기입
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

사용할 수 있는 키 전체는 `charts/app/values.yaml` 참고. 로컬 검증:

```bash
helm lint charts/app -f apps/<app>/values.yaml -f apps/<app>/values-<env>.yaml
helm template <app> charts/app -f apps/<app>/values.yaml -f apps/<app>/values-<env>.yaml
```

범용 chart로 표현이 안 되는 앱(StatefulSet, CronJob 등)은 5/6절처럼 별도 chart를 두고
`argocd/apps/<app>-<env>.yaml`에 Application을 직접 작성하면 된다 (`directory.include` 글롭이 인식).

## 2. 등록은 자동 (ApplicationSet)

`argocd/apps/appset-<env>.yaml`(환경당 1개)의 git files generator가 `apps/*/values-<env>.yaml`을
찾아 앱마다 Application(`<app>-<env>`, namespace `<app>`)을 만든다. **`values-<env>.yaml` 파일을
추가해 push하면 끝**이고, Application 매니페스트는 쓰지 않는다. 앱을 내리려면 그 파일을 지운다
(`prune`으로 정리됨).

## 3. bootstrap은 수정 불필요

`argocd/bootstrap/root-<env>.yaml`은 `directory.include: "*-<env>.yaml"` 글롭으로
`argocd/apps/` 안의 `appset-<env>.yaml`(과 직접 작성한 Application)을 가져온다.
클러스터당 1회 적용한 뒤로는 수정할 일이 없다. 다음 git polling 주기(기본 3분)에 새 앱을 인식한다.

## 4. 컨테이너 이미지

이 저장소의 인프라 CI(`plan.yml`/`deploy.yml`)는 이미지 빌드를 하지 않는다. 대신 `apps/<app>/`에
`Dockerfile`이 있으면 `.github/workflows/build-images.yml`이 소스 변경(chart 제외) push 때
`.github/environments.json`에서 `"build": true`인 환경의 self-hosted runner에서 이미지를 빌드한다.

1. 러너가 nerdctl/buildkit으로 이미지를 빌드해 그 노드의 로컬 레지스트리(`localhost:5000`)에 `<git sha 7자리>` 태그로 push
2. `apps/<app>/values-<env>.yaml`의 `image.repository`(`<노드IP>:5000/<app>`)/`image.tag`를 갱신해 커밋
3. ArgoCD가 git을 polling해서 새 태그를 배포 (CI는 클러스터에 접근하지 않음)

조건: 환경에 `values-<env>.yaml`이 있어야 하고, 러너가 `github_runner_build_tools_enabled: true`로
설치돼 있어야 한다. 앱을 별도 저장소로 분리하는 경우에는 그 저장소 CI에서 같은 방식으로 빌드·push하면 된다.

## 5. 로컬 클러스터로 실제 확인 (선택)

`ansible/roles/k3s`가 k3s 설치 시 `nerdctl`(+ `buildkitd`)을 함께 설치하고,
k3s의 containerd 소켓에 붙도록 `buildkit.service`를 구성해둔다. 별도로 Docker
Desktop이나 nerdctl을 수동 설치할 필요 없이, `proxmox`/`libvirt`에
k3s가 떠 있는 노드라면 바로 다음이 된다:

```bash
# proxmox 예시 - k3s의 containerd 네임스페이스로 바로 빌드
scp -r apps/<app-name> <node>:~/
ssh <node> "cd <app-name> && sudo nerdctl --namespace k8s.io \
  --address /run/k3s/containerd/containerd.sock build -t <app-name>:latest ."

helm upgrade --install <app-name> charts/app \
  -f apps/<app-name>/values.yaml \
  -f apps/<app-name>/values-proxmox.yaml \
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

## 6. 앱 소스를 별도 레포에 두는 경우 (권장)

실서비스 앱은 이 저장소(인프라) 안에 두지 않는다. **앱 레포는 소스와 Dockerfile만**, 이 저장소는
`apps/<app>/values-<env>.yaml`(배포 설정) 한 파일만 갖는다. chart는 범용 `charts/app`을 그대로 쓴다.

```
앱 레포 (my-web-app)                          인프라 저장소 (iac-multicloud)
├── src/, Dockerfile                         └── apps/my-web-app/
└── .github/workflows/deploy.yml  ──CI──▶        └── values-proxmox.yaml   (image.tag는 CI가 갱신)
     (재사용 workflow 호출)
```

1. **인프라 저장소에 배포 선언**: `apps/<app>/values-<env>.yaml`을 만든다(포트, env, ingress 등. 1절 참고).
   이 파일이 있어야 ApplicationSet이 배포하고, 이미지 태그 갱신 대상이 된다. `image`는 CI가 채운다.
2. **앱 레포용 러너**: k3s 노드에 앱 레포용 self-hosted runner를 설치한다
   (`ansible-playbook ... --tags github-runner -e github_runner_repo=<owner>/<app> -e github_runner_build_tools_enabled=true`).
3. **토큰**: 인프라 저장소에 push할 수 있는 fine-grained PAT(Contents: write)를 앱 레포 secret
   `INFRA_REPO_TOKEN`으로 등록한다.
4. **앱 레포 workflow**:

```yaml
# 앱 레포 .github/workflows/deploy.yml
on:
  push:
    branches: [main]
jobs:
  build:
    uses: <owner>/<infra-repo>/.github/workflows/build-app-image.yml@main
    with:
      app: my-web-app            # = apps/<app>/ 디렉토리명 = 이미지 이름
      environment: proxmox
      infra_repo: <owner>/<infra-repo>
    secrets:
      infra_token: ${{ secrets.INFRA_REPO_TOKEN }}
```

push하면 앱 레포 러너가 이미지를 빌드해 `<k3s서버IP>:5000/<app>:<git sha>`로 로컬 레지스트리에 push하고,
인프라 저장소 `values-<env>.yaml`의 `image.repository/tag`를 커밋한다. 이후는 ArgoCD가 polling으로 롤아웃한다
(`.github/workflows/build-app-image.yml`, `.github/scripts/build-one.sh`).

5. **외부 접속**: k3s 내장 Traefik이 노드의 80/443을 받는다. `values-<env>.yaml`에 `ingress.host`를 두고,
   Nginx Proxy Manager(CT)에서 해당 도메인을 `<k3s노드IP>:80`으로 포워딩한다.

> 범용 chart로 표현이 안 되는 앱(StatefulSet, CronJob 등)만 앱 레포에 자체 chart를 두고
> `argocd/apps/<app>-<env>.yaml`에 Application을 직접 쓴다 (`source.repoURL`/`path`를 앱 레포로 지정,
> private이면 ArgoCD에 저장소 자격증명 등록). 이 경우 이미지 태그 갱신은 앱 레포 CI가 자체 values를 커밋한다.

> 이 저장소 안 `apps/<app>/`에 소스(Dockerfile)를 두는 방식(`sample-hello-nestjs`)은 파이프라인 검증과
> 아주 작은 앱용이다. 4절의 `build-images.yml`이 처리한다.
