#!/usr/bin/env bash
# 앱 하나의 이미지를 이 러너 노드의 k3s containerd로 빌드해 로컬 레지스트리에 push하고,
# 지정한 values 파일의 image.repository/tag 를 갱신한다 (커밋은 호출 측이 한다).
# 사용: build-one.sh <app> <build-context-dir> <values-file> <sha>
# 전제: 러너에 nerdctl/buildctl/containerd·buildkit 소켓/k3s가 마운트되어 있고(github_runner_build_tools_enabled),
#       같은 노드에 로컬 레지스트리(registry 롤)가 떠 있다. values 파일은 미리 존재해야 한다(= 배포 대상 선언).
# 앱 저장소가 호출하는 재사용 workflow(build-app-image.yml)에서 사용한다.
set -euo pipefail

app="${1:?app}"; context="${2:?build context}"; values="${3:?values file}"; sha="${4:?sha}"
port="${REGISTRY_PORT:-5000}"
tag="${sha:0:7}"
k3s_bin="${K3S_BIN:-/usr/local/bin/k3s}"
ctr=(nerdctl --namespace k8s.io --address /run/k3s/containerd/containerd.sock)

[ -f "$context/Dockerfile" ] || { echo "Dockerfile 없음: $context" >&2; exit 1; }
[ -f "$values" ] || { echo "values 파일 없음: $values (배포할 환경마다 먼저 만들어야 함)" >&2; exit 1; }

# 푸시는 localhost(비TLS 허용), 파드가 pull하는 주소는 노드 IP — registries.yaml mirror가 이 주소를 가리킨다.
node_ip=$("$k3s_bin" kubectl get nodes -l node-role.kubernetes.io/control-plane \
  -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

echo "== build $app:$tag"
"${ctr[@]}" build -t "localhost:$port/$app:$tag" "$context"
"${ctr[@]}" push "localhost:$port/$app:$tag"
"$(dirname "$0")/set-image.sh" "$values" "$node_ip:$port/$app" "$tag"
