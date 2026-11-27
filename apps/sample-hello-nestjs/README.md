# sample-hello-nestjs

이 앱은 **iac-multicloud 배포 파이프라인 검증용 샘플**입니다. 실제 서비스 코드가 아니며,
`opentofu` → `ansible`(k3s+ArgoCD) → `helm` → `ArgoCD Application`으로 이어지는 배포 흐름이
각 환경(aws/gcp/azure/libvirt/proxmox)에서 정상 동작하는지 확인하는 목적으로만 존재합니다.

chart는 따로 없고 범용 chart(`charts/app`)에 `values.yaml`/`values-{env}.yaml`만 넘깁니다.
`argocd/apps/appset-{env}.yaml`(ApplicationSet)이 `values-{env}.yaml`을 보고 자동 배포합니다.

이 레포를 실제 프로젝트에 사용할 때는 이 디렉토리를 지우고, 같은 구조(`apps/{app}/values-{env}.yaml`)로
실제 애플리케이션을 추가하면 됩니다 (`docs/adding-an-app.md`).

> 실제 앱은 이 샘플처럼 소스를 이 저장소에 두지 말고 별도 레포로 분리하세요
> (`docs/adding-an-app.md` 6절, 재사용 workflow `build-app-image.yml`).
