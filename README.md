# iac-multicloud

멀티클라우드(AWS/GCP/Azure) + 로컬 인프라를 동일한 코드 구조로 프로비저닝하고,
k3s + Helm + ArgoCD(GitOps) 기반으로 애플리케이션 배포를 통일하는 IaC 저장소.

전체 계획과 단계별 진행 상황은 [CLAUDE.md](./CLAUDE.md) 참고.

## 디렉토리 구조

- `opentofu/` — 인프라 프로비저닝 (modules, environments)
- `ansible/` — k3s + ArgoCD 부트스트랩
- `argocd/` — GitOps Application 매니페스트
- `apps/` — 애플리케이션별 Helm chart
- `policy/` — OPA(Conftest) 정책
- `.github/workflows/` — 인프라 전용 CI/CD (앱 배포는 트리거하지 않음)
