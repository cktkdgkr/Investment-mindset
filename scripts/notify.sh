#!/usr/bin/env bash
# 집필 완료 알림.
#   macOS  -> osascript display notification
#   Linux  -> notify-send
#   둘 다 실패 -> NOTIFICATIONS.md 에 타임스탬프와 함께 append
#
# 사용법:
#   bash scripts/notify.sh "<날짜>" "<제목>" "<글자수>" "<파일경로>"

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="$ROOT/NOTIFICATIONS.md"

DATE="${1:-$(date '+%Y-%m-%d')}"
TITLE="${2:-(제목 없음)}"
CHARS="${3:-?}"
PATH_MD="${4:-(경로 없음)}"

STAMP="$(date '+%Y-%m-%d %H:%M:%S %Z')"

NOTIF_TITLE="블로그 집필 완료 · ${DATE}"
NOTIF_BODY="${TITLE} · ${CHARS}자 · ${PATH_MD}"

escape_applescript() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

sent=""

case "$(uname -s)" in
    Darwin)
        if command -v osascript >/dev/null 2>&1; then
            if osascript -e "display notification \"$(escape_applescript "$NOTIF_BODY")\" with title \"$(escape_applescript "$NOTIF_TITLE")\"" >/dev/null 2>&1; then
                sent="osascript"
            fi
        fi
        ;;
    *)
        if command -v notify-send >/dev/null 2>&1; then
            if notify-send "$NOTIF_TITLE" "$NOTIF_BODY" >/dev/null 2>&1; then
                sent="notify-send"
            fi
        fi
        ;;
esac

# 반대 플랫폼 도구가 있을 수도 있으니 한 번 더 시도한다.
if [ -z "$sent" ] && command -v notify-send >/dev/null 2>&1; then
    notify-send "$NOTIF_TITLE" "$NOTIF_BODY" >/dev/null 2>&1 && sent="notify-send"
fi
if [ -z "$sent" ] && command -v osascript >/dev/null 2>&1; then
    osascript -e "display notification \"$(escape_applescript "$NOTIF_BODY")\" with title \"$(escape_applescript "$NOTIF_TITLE")\"" >/dev/null 2>&1 && sent="osascript"
fi

if [ -n "$sent" ]; then
    echo "[notify] 전송 완료 ($sent): ${NOTIF_TITLE} — ${NOTIF_BODY}"
    exit 0
fi

# 폴백: 파일 append
if [ ! -f "$LOG" ]; then
    {
        echo "# 알림 로그"
        echo
        echo "데스크톱 알림(osascript / notify-send)이 불가능한 환경에서 여기에 쌓인다."
        echo
    } > "$LOG"
fi

{
    echo "- \`${STAMP}\` — **${DATE}** · ${TITLE} · ${CHARS}자 · \`${PATH_MD}\`"
} >> "$LOG"

echo "[notify] 데스크톱 알림 불가 → NOTIFICATIONS.md 에 기록했다."
echo "[notify] ${STAMP} — ${DATE} · ${TITLE} · ${CHARS}자 · ${PATH_MD}"
exit 0
