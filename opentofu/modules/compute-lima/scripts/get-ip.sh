#!/usr/bin/env bash
# Lima 게스트에 SSH로 접속해 shared 네트워크 IP를 조회한다.
# 192.168.5.0/24는 Lima 기본 usermode(slirp) NAT 대역이라 제외한다.
set -euo pipefail

NAME="$1"

IP=$(limactl shell "$NAME" -- sh -c \
  "ip -4 -o addr show scope global 2>/dev/null | awk '{print \$4}' | cut -d/ -f1 | grep -v '^192\.168\.5\.' | head -n1")

if [ -z "$IP" ]; then
  echo "lima VM '$NAME'의 shared network IP를 찾지 못했습니다" >&2
  exit 1
fi

printf '{"ip": "%s"}\n' "$IP"
