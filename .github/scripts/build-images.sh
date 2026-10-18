#!/usr/bin/env bash
# 변경된 앱의 컨테이너 이미지를 이 러너 노드의 k3s containerd로 빌드해 로컬 레지스트리에 push하고,
# apps/<app>/chart/values-<env>.yaml 의 image.repository/tag 를 갱신한다 (커밋은 호출 측이 한다).
# 사용: build-images.sh <environment> <before-sha> <sha>
# 전제: 러너 컨테이너에 nerdctl/buildctl/containerd·buildkit 소켓/k3s가 마운트되어 있고
#       (github_runner_build_tools_enabled), 같은 노드에 로컬 레지스트리(registry 롤)가 떠 있다.
set -euo pipefail

env_name="${1:?environment}"; before="${2:-}"; sha="${3:?sha}"
port="${REGISTRY_PORT:-5000}"
tag="${sha:0:7}"
ctr=(nerdctl --namespace k8s.io --address /run/k3s/containerd/containerd.sock)

# 푸시는 localhost(비TLS 허용), 파드가 pull하는 주소는 노드 IP — registries.yaml mirror가 이 주소를 가리킨다.
node_ip=$(/usr/local/bin/k3s kubectl get nodes -l node-role.kubernetes.io/control-plane \
  -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

# 변경된 앱 목록 (첫 push이거나 before 커밋을 못 찾으면 전체)
if [[ -z "$before" || "$before" =~ ^0+$ ]] || ! git cat-file -e "$before^{commit}" 2>/dev/null; then
  changed=$(ls apps)
else
  changed=$(git diff --name-only "$before" "$sha" -- apps | cut -d/ -f2 | sort -u)
fi

built=0
for app in $changed; do
  [ -f "apps/$app/Dockerfile" ] || continue
  values="apps/$app/chart/values-$env_name.yaml"
  [ -f "$values" ] || { echo "skip $app: $values 없음"; continue; }

  echo "== build $app:$tag"
  "${ctr[@]}" build -t "localhost:$port/$app:$tag" "apps/$app"
  "${ctr[@]}" push "localhost:$port/$app:$tag"
  "$(dirname "$0")/set-image.sh" "$values" "$node_ip:$port/$app" "$tag"
  built=$((built + 1))
done

echo "빌드한 앱: $built"
