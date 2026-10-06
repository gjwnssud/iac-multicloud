#!/usr/bin/env bash
# 리포지토리 변수 CI_ENVIRONMENTS(JSON 배열)를 검증해 GITHUB_OUTPUT의 environments로 내보낸다.
# 사용: select-environments.sh '<이 워크플로가 지원하는 환경의 JSON 배열>'
set -euo pipefail

supported="$1"
requested=$(jq -c 'unique' <<<"${CI_ENVIRONMENTS:-[]}")
unknown=$(jq -nc --argjson r "$requested" --argjson s "$supported" '$r - $s')

if [ "$unknown" != "[]" ]; then
  echo "::error::이 워크플로가 지원하지 않는 환경: $unknown (지원: $supported)"
  exit 1
fi

echo "대상 환경: $requested"
echo "environments=$requested" >> "$GITHUB_OUTPUT"
