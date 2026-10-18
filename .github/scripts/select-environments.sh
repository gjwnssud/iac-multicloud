#!/usr/bin/env bash
# 리포지토리 변수 CI_ENVIRONMENTS(JSON 배열)를 .github/environments.json 메타데이터와 대조해
# GITHUB_OUTPUT의 matrix(include 배열 JSON)로 내보낸다.
# 사용: select-environments.sh <plan|deploy|build>
#   plan   : 메타데이터에서 "plan": true 인 환경만 대상
#   deploy : 메타데이터에 있는 모든 환경이 대상
#   build  : 메타데이터에서 "build": true 인 환경만 대상 (앱 이미지를 그 환경 러너에서 빌드)
# 새 환경은 .github/environments.json에 항목만 추가하면 워크플로 수정 없이 지원된다.
set -euo pipefail

mode="${1:?usage: select-environments.sh <plan|deploy|build>}"
meta="$(dirname "$0")/../environments.json"
requested=$(jq -c 'unique' <<<"${CI_ENVIRONMENTS:-[]}")

unknown=$(jq -nc --argjson r "$requested" --slurpfile m "$meta" '$r - ($m[0] | keys)')
if [ "$unknown" != "[]" ]; then
  echo "::error::environments.json에 정의되지 않은 환경: $unknown (정의됨: $(jq -c 'keys' "$meta"))"
  exit 1
fi

matrix=$(jq -nc --argjson r "$requested" --slurpfile m "$meta" --arg mode "$mode" '
  [ $r[] as $e | $m[0][$e] as $c
    | select(($mode != "plan" or $c.plan) and ($mode != "build" or ($c.build // false)))
    | { environment: $e,
        provider: $c.provider,
        runs_on: ($c.runs_on | tojson),
        tofu_apply: $c.tofu_apply,
        inventory: $c.inventory } ]')

echo "대상 환경($mode): $(jq -c '[.[].environment]' <<<"$matrix")"
echo "matrix=$matrix" >> "${GITHUB_OUTPUT:-/dev/stdout}"
