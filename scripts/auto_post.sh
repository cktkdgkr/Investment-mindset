#!/usr/bin/env bash
# 자동 집필 진입점. crontab 이 이 스크립트를 호출한다.
#
#   bash scripts/auto_post.sh                 오늘자 1편 집필
#   bash scripts/auto_post.sh "주제 문장"      주제를 지정해 집필
#   bash scripts/auto_post.sh --check-missed  누락분 확인 후 보충 집필
#
# 동작: 날짜 확인 -> 파이프라인 전체 -> 저장 -> 알림.
# 주제가 없다는 이유로 건너뛰지 않는다.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

RUNLOG="$ROOT/.auto_post.log"

# cron 환경은 PATH 가 빈약하다. 흔한 설치 경로를 미리 붙인다.
export PATH="$HOME/.local/bin:$HOME/.claude/local:/opt/homebrew/bin:/usr/local/bin:$PATH"

log() { echo "[auto_post $(date '+%Y-%m-%d %H:%M:%S %Z')] $*" | tee -a "$RUNLOG"; }

# --- 0. 날짜 확인 (불변 규칙) ---
TODAY_FULL="$(date '+%Y-%m-%d %A %H:%M %Z')"
TODAY="$(date '+%Y-%m-%d')"
DOW="$(date '+%u')"   # 1=월 ... 7=일
log "날짜 확인: $TODAY_FULL"

MODE="today"
TOPIC=""
DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --check-missed) MODE="missed" ;;
        --dry-run)      DRY_RUN=1 ;;
        --*)            log "알 수 없는 옵션: $arg" ;;
        *)              TOPIC="$arg" ;;
    esac
done

# --- 누락분 탐지 ---
# 기준점은 posts/ 의 최신 글 날짜다. 그 다음날부터 어제까지의 화/목/토/일 중
# 글이 없는 날짜만 누락으로 본다.
# posts/ 가 비어 있으면 = 하니스를 막 설치한 상태이므로 소급 보충하지 않는다.
missed_dates() {
    local latest anchor d wd i span
    latest="$(ls -1 "$ROOT"/posts/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-*.md 2>/dev/null \
              | sed 's#.*/##; s/^\([0-9-]\{10\}\).*/\1/' | sort | tail -n1)"
    [ -z "$latest" ] && return 0

    if date -v-1d >/dev/null 2>&1; then
        anchor=$(( ( $(date -j -f '%Y-%m-%d' "$latest" '+%s' 2>/dev/null || echo 0) ) ))
        span=$(( ( $(date '+%s') - anchor ) / 86400 ))
    else
        anchor=$(date -d "$latest" '+%s')
        span=$(( ( $(date '+%s') - anchor ) / 86400 ))
    fi
    [ "$span" -lt 1 ] && return 0
    [ "$span" -gt 60 ] && span=60

    for i in $(seq $(( span - 1 )) -1 1); do
        if date -v-1d >/dev/null 2>&1; then
            d="$(date -v-"${i}"d '+%Y-%m-%d')"        # BSD / macOS
            wd="$(date -v-"${i}"d '+%u')"
        else
            d="$(date -d "-${i} days" '+%Y-%m-%d')"   # GNU / Linux
            wd="$(date -d "-${i} days" '+%u')"
        fi
        case "$wd" in
            2|4|6|7)
                ls "$ROOT/posts/${d}-"*.md >/dev/null 2>&1 || echo "$d"
                ;;
        esac
    done
}

if [ "$MODE" = "missed" ]; then
    MISSING="$(missed_dates)"
    if [ -z "$MISSING" ]; then
        log "누락분 없음."
        exit 0
    fi
    log "누락분 발견:"
    echo "$MISSING" | while read -r d; do log "  - $d"; done
fi

# --- 프롬프트 조립 ---
if [ "$MODE" = "missed" ]; then
    PROMPT="오늘은 ${TODAY_FULL} 이다.
posts/ 를 확인한 결과 아래 날짜의 글이 누락되었다. 오래된 날짜부터 순서대로 전부 보충 집필한다.
$(missed_dates | sed 's/^/  - /')

각 편마다 CLAUDE.md 의 파이프라인(Thinker→Architect→Writer→Editor→QA)을 완주한다.
보충분의 프론트매터 date 는 원래 예정일로 적고, 하단 메모에 실제 집필일이 ${TODAY} 임을 남긴다.
미루지 말고 지금 전부 끝낸다."
elif [ -n "$TOPIC" ]; then
    PROMPT="오늘은 ${TODAY_FULL} 이다.
주제: ${TOPIC}
CLAUDE.md 의 파이프라인을 완주해 posts/${TODAY}-슬러그.md 로 저장하고 scripts/notify.sh 까지 실행한다."
else
    PROMPT="오늘은 ${TODAY_FULL} 이다.
오늘 주어진 주제가 없다. topics/backlog.md 에서 아직 안 쓴 '- [ ]' 항목 중 첫 번째를 고른다.
백로그가 비었으면 posts/ 최근 글과 겹치지 않는 주제를 스스로 정한다.
주제가 없다는 이유로 건너뛰는 것은 금지다.
CLAUDE.md 의 파이프라인(Thinker→Architect→Writer→Editor→QA)을 완주해
posts/${TODAY}-슬러그.md 로 저장하고, 백로그 항목을 '- [x] ... (${TODAY})' 로 바꾸고,
scripts/notify.sh 를 실행한다. 미루지 말고 지금 끝낸다."
fi

log "모드=${MODE} 요일=${DOW}"

if [ "$DRY_RUN" = "1" ]; then
    log "--dry-run: claude 를 호출하지 않고 프롬프트만 출력한다."
    echo "----- PROMPT -----"
    echo "$PROMPT"
    echo "------------------"
    exit 0
fi

# --- 실행 ---
if ! command -v claude >/dev/null 2>&1; then
    log "ERROR: claude CLI 를 찾을 수 없다. PATH=$PATH"
    bash "$ROOT/scripts/notify.sh" "$TODAY" "자동 집필 실패 — claude CLI 없음" "0" "-"
    exit 127
fi

claude -p "$PROMPT" \
    --permission-mode acceptEdits \
    --allowedTools "Bash,Read,Write,Edit,Glob,Grep,Agent" \
    2>&1 | tee -a "$RUNLOG"
STATUS=${PIPESTATUS[0]}

# --- 결과 확인 및 알림 폴백 ---
LATEST="$(ls -1 "$ROOT/posts/${TODAY}-"*.md 2>/dev/null | head -n1)"

if [ -n "$LATEST" ]; then
    CHARS="$(python3 "$ROOT/scripts/count.py" --quiet "$LATEST" 2>/dev/null || echo '?')"
    TITLE="$(sed -n 's/^title: *"\{0,1\}\(.*\)/\1/p' "$LATEST" | head -n1 | sed 's/"$//')"
    log "저장 확인: $LATEST (${CHARS}자)"
    # 파이프라인이 알림을 이미 보냈더라도 누락 대비로 한 번 더 확인 기록을 남긴다.
    if ! grep -q "$(basename "$LATEST")" "$ROOT/NOTIFICATIONS.md" 2>/dev/null; then
        bash "$ROOT/scripts/notify.sh" "$TODAY" "${TITLE:-제목미상}" "$CHARS" "${LATEST#"$ROOT/"}"
    fi
else
    log "ERROR: ${TODAY} 자 글이 저장되지 않았다 (claude exit=$STATUS)"
    bash "$ROOT/scripts/notify.sh" "$TODAY" "자동 집필 실패 — 저장물 없음" "0" "-"
    exit 1
fi

log "완료."
exit 0
