#!/usr/bin/env bash
# ArgoCD 매니페스트(argocd/bootstrap, argocd/apps)의 인프라 저장소 repoURL을 한 번에 바꾼다.
# 포크/템플릿으로 새 저장소를 만든 직후 1회 실행한다. 앱을 찾아올 GitHub organization도 함께 바꿀 수 있다.
# 사용: scripts/set-repo-url.sh <인프라 저장소 URL> [앱 저장소를 찾을 GitHub organization]
#   예: scripts/set-repo-url.sh https://github.com/me/my-infra.git my-apps-org
set -euo pipefail

new="${1:?사용: $0 <git repo URL> [organization]}"
org="${2:-}"
cd "$(dirname "$0")/.."

files=$(grep -rlE "repoURL: https?://" argocd/bootstrap argocd/apps)
# 현재 URL은 파일에서 추출 (고정 URL만. '{{ .url }}' 같은 템플릿 값은 제외). 여러 종류면 중단
current=$(grep -rhE "repoURL: https?://" $files | sed 's/.*repoURL: *//' | sort -u)
[ "$(echo "$current" | wc -l)" -eq 1 ] || { echo "repoURL이 여러 종류입니다:"; echo "$current"; exit 1; }

if [ "$current" != "$new" ]; then
  for f in $files; do
    sed -i.bak -E "s#(repoURL: )https?://.*#\1$new#" "$f" && rm -f "$f.bak"
  done
  echo "repoURL: $current -> $new ($(echo "$files" | wc -w)개 파일)"
else
  echo "repoURL은 이미 $new 입니다"
fi

if [ -n "$org" ]; then
  for f in argocd/apps/appset-*.yaml; do
    sed -i.bak -E "s#(organization: ).*#\1$org#" "$f" && rm -f "$f.bak"
  done
  echo "scmProvider organization -> $org"
fi
echo "github-runner 사용 시 ansible의 github_runner_repo 도 확인하세요."
