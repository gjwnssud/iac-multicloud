#!/usr/bin/env bash
# ArgoCD 매니페스트(argocd/bootstrap, argocd/apps)의 repoURL을 한 번에 바꾼다.
# 포크/템플릿으로 새 저장소를 만든 직후 1회 실행한다.
# 사용: scripts/set-repo-url.sh https://github.com/<owner>/<repo>.git
set -euo pipefail

new="${1:?사용: $0 <git repo URL> (예: https://github.com/me/my-infra.git)}"
cd "$(dirname "$0")/.."

files=$(grep -rl "repoURL: " argocd/bootstrap argocd/apps)
# 현재 URL은 파일에서 추출 (여러 종류가 섞여 있으면 중단)
current=$(grep -rh "repoURL: " $files | sed 's/.*repoURL: *//' | sort -u)
[ "$(echo "$current" | wc -l)" -eq 1 ] || { echo "repoURL이 여러 종류입니다:"; echo "$current"; exit 1; }

if [ "$current" = "$new" ]; then echo "이미 $new 입니다"; exit 0; fi
for f in $files; do
  sed -i.bak "s#repoURL: .*#repoURL: $new#" "$f" && rm -f "$f.bak"
done
echo "repoURL: $current -> $new ($(echo "$files" | wc -w)개 파일)"
echo "github-runner 사용 시 ansible의 github_runner_repo 도 확인하세요."
