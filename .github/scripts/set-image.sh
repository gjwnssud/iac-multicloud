#!/usr/bin/env bash
# Helm values 파일의 최상위 image: 블록을 repository/tag로 교체(없으면 추가)한다.
# 사용: set-image.sh <values-file> <repository> <tag>
set -euo pipefail

file="${1:?values file}"; repo="${2:?repository}"; tag="${3:?tag}"
tmp=$(mktemp)

# 기존 image: 블록(들여쓴 하위 줄 포함)을 제거
awk '/^image:/{skip=1; next} skip && /^[[:space:]]/{next} {skip=0; print}' "$file" > "$tmp"
printf 'image:\n  repository: %s\n  tag: "%s"\n' "$repo" "$tag" >> "$tmp"
mv "$tmp" "$file"
