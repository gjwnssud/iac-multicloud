#!/usr/bin/env bash
# 이 저장소의 apps/<app>/ 에 Dockerfile이 있는 앱 중 변경된 것을 빌드한다 (실제 빌드는 build-one.sh).
# apps/<app>/values-<env>.yaml 의 image.repository/tag 가 갱신된다 (커밋은 호출 측이 한다).
# 사용: build-images.sh <environment> <before-sha> <sha>
# 외부 앱 저장소의 앱은 이 스크립트가 아니라 재사용 workflow(build-app-image.yml)가 build-one.sh를 호출한다.
set -euo pipefail

env_name="${1:?environment}"; before="${2:-}"; sha="${3:?sha}"

# 변경된 앱 목록 (첫 push이거나 before 커밋을 못 찾으면 전체)
if [[ -z "$before" || "$before" =~ ^0+$ ]] || ! git cat-file -e "$before^{commit}" 2>/dev/null; then
  changed=$(ls apps)
else
  changed=$(git diff --name-only "$before" "$sha" -- apps | cut -d/ -f2 | sort -u)
fi

built=0
for app in $changed; do
  [ -f "apps/$app/Dockerfile" ] || continue
  values="apps/$app/values-$env_name.yaml"
  [ -f "$values" ] || { echo "skip $app: $values 없음"; continue; }
  "$(dirname "$0")/build-one.sh" "$app" "apps/$app" "$values" "$sha"
  built=$((built + 1))
done

echo "빌드한 앱: $built"
