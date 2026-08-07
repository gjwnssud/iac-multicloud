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
├── values-local-libvirt.yaml
├── values-local-mac.yaml
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

`local-mac` 또는 `local-libvirt`에 이미 k3s가 떠 있다면, 레지스트리 없이도
클러스터 노드 안에서 직접 이미지를 빌드해 넣고 확인할 수 있다:

```bash
# local-mac(Lima) 예시 - k3s의 containerd 네임스페이스로 바로 빌드
scp -r apps/<app-name> <node>:~/
ssh <node> "cd <app-name> && sudo nerdctl --namespace k8s.io \
  --address /run/k3s/containerd/containerd.sock build -t <app-name>:latest ."

helm upgrade --install <app-name> apps/<app-name>/chart \
  -f apps/<app-name>/chart/values.yaml \
  -f apps/<app-name>/chart/values-local-mac.yaml \
  --set image.pullPolicy=IfNotPresent \
  -n <app-name> --create-namespace
```

`sample-hello-nestjs`를 이 방식으로 검증한 절차와 동일하다.
