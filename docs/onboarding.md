# 온보딩 가이드

이 저장소로 처음 작업을 시작할 때 필요한 준비물과 절차를 환경별로 정리한다.

## 공통 도구

```bash
brew install opentofu ansible ansible-lint helm conftest actionlint
```

Ansible 컬렉션(`community.general` 등)은 저장소 루트가 아니라 `ansible/` 안에서 설치한다:

```bash
cd ansible
ansible-galaxy collection install -r requirements.yml
```

## 환경별 준비물

### aws / gcp / azure (클라우드 VM + k3s)

1. 해당 클라우드 자격증명을 로컬에 설정한다 (`aws configure`, `gcloud auth application-default login`,
   `az login` 등). CLI 없이 진행한 경우에도 provider가 요구하는 환경변수/파일만 있으면 된다.
2. **원격 state 백엔드를 먼저 부트스트랩한다** (클라우드 환경 공통, 1회성):

   ```bash
   cd opentofu/bootstrap/aws   # gcp, azure도 동일한 패턴
   cp terraform.tfvars.example terraform.tfvars   # 버킷 이름 등 채우기
   tofu init && tofu apply
   ```

   이 단계를 건너뛰고 `environments/{aws,gcp,azure}`에서 바로 `tofu init`을 실행하면
   `backend "s3" {}`(partial config)가 필수 값을 요구해서 실패한다 — 의도된 안전장치다.
   기본 backend가 로컬 상태였다면 CI의 ephemeral 러너가 매번 state를 잃어버려
   리소스가 중복 생성됐을 것이기 때문에, 클라우드 환경은 반드시 원격 backend로 시작한다.

3. `environments/{env}`에서 bootstrap output(버킷 이름 등)을 `-backend-config`로 넘겨 init한다:

   ```bash
   cd opentofu/environments/aws
   tofu init \
     -backend-config="bucket=<bootstrap output: bucket_name>" \
     -backend-config="key=aws/terraform.tfstate" \
     -backend-config="region=ap-northeast-2" \
     -backend-config="dynamodb_table=<bootstrap output: lock_table_name>"
   ```

### local-libvirt (리눅스 호스트 + KVM)

리눅스 머신(베어메탈 또는 VM)에 `libvirt`, `qemu-kvm`이 설치되어 있고 `libvirtd`가 실행 중이어야 한다.
macOS에는 해당하지 않는다 — KVM은 리눅스 커널 전용 기능이라 macOS에서는 동작하지 않는다.

```bash
sudo apt install libvirt-daemon-system qemu-kvm   # Debian/Ubuntu 계열 예시
```

### local-mac (macOS/Apple Silicon + Lima)

```bash
brew install lima socket_vmnet
```

`socket_vmnet`은 root 소유의 고정 경로(`/opt/socket_vmnet`)에 있어야 하는 보안 요구사항이 있어
Homebrew keg 경로를 그대로 쓸 수 없다. **최초 1회**만 아래를 직접 실행한다 (sudo 필요):

```bash
sudo mkdir -p /opt/socket_vmnet/bin
sudo cp "$(brew --prefix socket_vmnet)/bin/socket_vmnet" /opt/socket_vmnet/bin/socket_vmnet
sudo chown -R root:wheel /opt/socket_vmnet
limactl sudoers | sudo tee /etc/sudoers.d/lima
```

이후로는 `tofu apply`만으로 Lima VM이 shared 네트워크(실제 라우팅되는 IP)로 뜬다.

## 최초 apply ~ ArgoCD 확인까지

아래 명령은 저장소 루트에서 시작한다고 가정한다.

```bash
# 1) 인프라 provisioning (환경별 terraform.tfvars 채운 뒤)
cd opentofu/environments/<env>
tofu apply

# 2) k3s + ArgoCD 부트스트랩
cd ../../../ansible
ansible-playbook -i inventories/<env>/hosts.ini playbooks/site.yml

# 3) kubeconfig로 클러스터 확인 (2번 단계가 ansible/fetched/에 생성)
export KUBECONFIG=fetched/<node-ip>-kubeconfig.yaml
kubectl get nodes
kubectl get pods -n argocd

# 4) ArgoCD app-of-apps 최초 등록 (클러스터당 1회)
kubectl apply -f ../argocd/bootstrap/root-<env>.yaml

# 5) ArgoCD UI 접근 (초기 admin 비밀번호는 2번 단계 로그 마지막 줄에 출력됨)
kubectl port-forward svc/argocd-server -n argocd 8080:443
# https://localhost:8080
```

## 자주 막히는 지점

- **GCP/Azure 자격증명 없이 `tofu plan`**: provider 인증 단계에서 실패한다. 클라우드 콘솔에서
  서비스 계정/앱 등록 후 CLI로 로그인하면 해결된다.
- **local-mac에서 `Unsupported argument`류 에러**: `dmacvicar/libvirt` provider 버전이 `0.9.x`로
  올라가면 스키마가 완전히 바뀐다. `opentofu/modules/*/libvirt`는 `~> 0.8.3`으로 고정되어 있으니
  버전 제약을 건드리지 않는다.
- **Ansible이 로컬(제어 노드)에서 sudo 비밀번호를 요구**: `delegate_to: localhost`가 붙은 태스크는
  반드시 `become: false`를 명시해야 한다. play 레벨 `become: true`가 기본적으로 상속되기 때문이다.
