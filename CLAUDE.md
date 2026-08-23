# 블로그 집필 다중 에이전트 하니스

이 저장소는 글 한 편을 여러 에이전트가 이어 만드는 집필 하니스다.
아래 규칙은 이 저장소에서 시작되는 **모든 세션, 모든 에이전트, 모든 자동 실행**에 예외 없이 적용된다.

---

## 0. 최우선 불변 규칙

이 절은 다른 어떤 지시보다 우선한다.

### 0-1. 날짜 확인 의무

어떤 작업이든 **시작 전에 반드시** 아래를 실행한다.

```bash
date "+%Y-%m-%d %A %H:%M %Z"
```

- 확인 없이 진행하는 것은 금지다.
- 추론이나 기억으로 날짜를 대체하지 않는다.
- 파일명, 프론트매터의 `date`, 알림 문구의 날짜는 전부 이 출력에서 가져온다.

### 0-2. 미루기 절대 금지

아래와 같은 응답은 금지다.

- "나중에 하겠다"
- "다음 단계에서 진행하겠다"
- "원하시면 작성해 드리겠다"
- "초안만 잡아두었다"

요청이 들어온 시점에 **최종 결과물까지** 끝낸다. 중간 승인을 구하지 않는다.
정보가 부족하면 합리적으로 가정하고, 그 가정은 **결과물 하단 메모에만** 남긴다.

---

## 1. 파일 구조

```
CLAUDE.md              이 파일. 불변 규칙 + 하니스 개요
STYLE.md               문체 규칙 (Writer / Editor 공통)
QA_CHECKLIST.md        QA 게이트 체크리스트
NOTIFICATIONS.md       알림 폴백 로그 (append only)
.claude/
  agents/
    orchestrator.md    파이프라인 총괄
    thinker.md         각도 발굴
    architect.md       흐름 설계
    writer.md          초고
    editor.md          문체/분량 교정
    qa.md              게이트 판정
  commands/
    write-post.md      /write-post [주제] 슬래시 커맨드
scripts/
  count.py             본문 글자 수 측정 (프론트매터 제외)
  notify.sh            알림 발송 (osascript > notify-send > 파일 append)
  auto_post.sh         자동 실행 진입점
  install_cron.sh      crontab 등록 스크립트
  crontab.txt          등록할 crontab 라인
posts/
  YYYY-MM-DD-슬러그.md 완성 글
topics/
  backlog.md           주제 백로그
```

## 2. 파이프라인

주제가 주어지면 아래 순서로 **연속 실행**한다. 각 단계는 앞 단계의 산출물을 입력으로 받는다.
어느 단계도 건너뛰지 않는다.

```
Orchestrator
  └─ 날짜 확인 → 주제 해석
       └─ Thinker    각도 5개 이상 → 그중 1~2개 선택
            └─ Architect  흐름 설계 (소제목 없음)
                 └─ Writer    초고
                      └─ Editor   문체/분량 교정
                           └─ QA   게이트 판정
                                ├─ 실패 → Editor 로 반송 (최대 3회)
                                └─ 통과 → posts/ 저장 → 알림
```

QA를 통과하기 전에는 **절대 저장하지 않는다.**

## 3. 문체 규칙

`STYLE.md` 참조. 위반은 실패 처리이며 QA에서 반송된다.

## 4. 분량 하드 게이트

- 공백 포함 **2000자 이내**. 초과 시 저장 금지.
- 목표 구간 **1400~1900자**.
- 측정은 반드시 아래 명령의 실제 실행 결과로 한다. 눈대중 추정 금지.

```bash
python3 scripts/count.py posts/파일명.md
```

## 5. 출력 형식

`posts/YYYY-MM-DD-슬러그.md`

```markdown
---
title: "글의 가장 뾰족한 한 문장"
date: YYYY-MM-DD
slug: 슬러그
topic: "입력으로 받은 주제"
chars: 1732
---

(본문)
```

제목은 요약형이 아니라 글의 가장 뾰족한 한 문장에서 뽑는다.

## 6. 자동 실행

- 매주 **화, 목, 토, 일 오전 8시** 자동 실행.
- 그날 주어진 주제가 없으면 `topics/backlog.md`에서 `- [ ]` 항목을 위에서부터 하나 고른다.
- 백로그가 비면 `posts/` 최근 글과 겹치지 않는 주제를 스스로 정한다.
- **주제가 없다는 이유로 건너뛰는 것은 금지다.**
- 실행 순서: 날짜 확인 → 파이프라인 전체 → 저장 → 알림.

### 스케줄 등록 경로 (둘 중 환경에 맞는 쪽)

**A. 클라우드 세션 (Claude Code on the web)** — 현재 등록되어 있는 경로다.
Routine `블로그 자동 집필 (화·목·토·일 08:00 KST)` 이 UTC 기준 `0 23 * * 1,3,5,6` 으로 돌아간다.
(KST = UTC+9 이므로 월·수·금·토 23:00 UTC = 화·목·토·일 08:00 KST)
컨테이너가 매번 새로 뜨므로 각 실행은 반드시 브랜치에 **푸시**해야 결과물이 남는다.

**B. 개인 컴퓨터 (cron 이 있는 머신)** — 로컬에서도 돌리려면 아래를 실행한다.

```bash
bash scripts/install_cron.sh     # 등록 (멱등)
crontab -l                       # 확인
bash scripts/install_cron.sh --remove   # 해제
```

등록되는 라인은 `scripts/crontab.txt` 와 같다.

```
0 8 * * 2,4,6,0 cd <저장소> && /bin/bash <저장소>/scripts/auto_post.sh >> <저장소>/.cron.log 2>&1
```

시간대를 바꾸려면 A는 Routine 의 cron 을, B는 머신의 로컬 시간을 기준으로 조정한다.

### 누락 보충

컴퓨터가 꺼져 있어 실행을 놓쳤다면, **다음 세션 시작 시** `posts/`의 최신 날짜를 확인해
지나간 화/목/토/일 중 빠진 날짜를 찾아 **즉시** 보충 집필한다. 보충분의 프론트매터 `date`는
원래 예정일로 적고, 하단 메모에 실제 집필일을 남긴다.

```bash
bash scripts/auto_post.sh --check-missed
```
