# sample-hello-nestjs

이 앱은 **iac-multicloud 배포 파이프라인 검증용 샘플**입니다. 실제 서비스 코드가 아니며,
`opentofu` → `ansible`(k3s+ArgoCD) → `helm` → `ArgoCD Application`으로 이어지는 배포 흐름이
각 환경(aws/gcp/azure/local-libvirt/local-mac)에서 정상 동작하는지 확인하는 목적으로만 존재합니다.

이 레포를 실제 프로젝트에 사용할 때는 이 디렉토리와 `argocd/apps/sample-hello-nestjs-*.yaml`,
`argocd/bootstrap/root-*.yaml`의 `include` 대상에서 제거하고, 같은 구조(`apps/{app}/chart/`)로
실제 애플리케이션을 추가하면 됩니다.
