#!/usr/bin/env bash
# crontab 에 자동 집필 스케줄을 등록한다. 멱등하다 (여러 번 실행해도 중복되지 않는다).
#
#   bash scripts/install_cron.sh            등록
#   bash scripts/install_cron.sh --remove   해제

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MARKER="# blog-harness:auto_post"
LINE="0 8 * * 2,4,6,0 cd ${ROOT} && /bin/bash ${ROOT}/scripts/auto_post.sh >> ${ROOT}/.cron.log 2>&1 ${MARKER}"

if ! command -v crontab >/dev/null 2>&1; then
    echo "ERROR: 이 환경에는 crontab 이 없다."
    echo "       사용자 컴퓨터(cron 이 있는 머신)에서 이 스크립트를 실행하라."
    echo "       등록할 라인:"
    echo "       $LINE"
    exit 127
fi

CURRENT="$(crontab -l 2>/dev/null || true)"

if [ "${1:-}" = "--remove" ]; then
    echo "$CURRENT" | grep -v "$MARKER" | crontab -
    echo "해제 완료."
    crontab -l
    exit 0
fi

# 기존 하니스 라인을 지우고 새로 넣는다 (멱등)
{
    echo "$CURRENT" | grep -v "$MARKER" | sed '/^$/d'
    echo "$LINE"
} | crontab -

echo "등록 완료. 현재 crontab:"
echo "----------------------------------------"
crontab -l
echo "----------------------------------------"
