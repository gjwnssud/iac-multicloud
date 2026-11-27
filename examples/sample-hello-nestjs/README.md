# sample-hello-nestjs

이 디렉터리는 **앱 저장소의 시작 템플릿**입니다. 배포 파이프라인 검증용 샘플 앱이며, 이 저장소에서는
배포되지 않습니다 (ArgoCD는 GitHub organization의 앱 저장소를 찾아 배포합니다).

사용법: 이 디렉터리 내용을 organization(`hznlabs`) 아래 새 저장소 루트로 복사하고, topic `hznlabs-app`을
붙인 뒤 `.github/workflows/deploy.yml`의 `<owner>/<infra-repo>`를 채우면 push로 자동 배포됩니다.
자세한 절차는 `docs/adding-an-app.md`를 참고하세요.

- `deploy/values.yaml`, `deploy/values-<env>.yaml`: 범용 chart(`charts/app`)에 넘기는 배포 설정
- `.github/workflows/deploy.yml`: 이미지 빌드와 태그 커밋을 맡는 재사용 workflow 호출
