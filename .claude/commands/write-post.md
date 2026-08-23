---
description: 주제 하나로 집필 파이프라인을 완주해 posts/에 글 1편을 저장하고 알림까지 보낸다
argument-hint: [주제] (생략 시 topics/backlog.md에서 자동 선택)
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Agent
---

주제: $ARGUMENTS

`CLAUDE.md`의 0번 불변 규칙과 파이프라인을 그대로 따라 **끝까지** 실행한다.
중간 승인을 구하지 않는다. 미루지 않는다.

1. `date "+%Y-%m-%d %A %H:%M %Z"` 를 실행해 오늘 날짜를 확인한다. 건너뛰기 금지.
2. `posts/`의 최신 날짜를 확인한다. 지나간 화/목/토/일 중 빠진 날이 있으면 그 보충분부터 쓴다.
3. 주제가 비어 있으면 `topics/backlog.md`에서 `- [ ]` 첫 항목을 고른다.
   백로그가 비면 `posts/` 최근 글과 겹치지 않는 주제를 스스로 정한다. 건너뛰지 않는다.
4. Thinker → Architect → Writer → Editor → QA 순으로 실행한다.
   각 단계는 `.claude/agents/` 의 해당 정의를 따른다. 어느 단계도 생략하지 않는다.
5. QA는 `python3 scripts/count.py`를 **실제로 실행**해 분량을 실측한다.
   FAIL이면 Editor로 반송한다. 최대 3회. PASS 전에는 저장하지 않는다.
6. PASS 후 `posts/YYYY-MM-DD-슬러그.md`로 저장하고 프론트매터 `chars`를 실측치로 맞춘다.
7. 백로그에서 고른 주제였다면 해당 줄을 `- [x] ... (YYYY-MM-DD)` 로 바꾼다.
8. `bash scripts/notify.sh "<날짜>" "<제목>" "<글자수>" "<파일경로>"` 를 실행한다.
9. 글 전문과 **실측 글자 수**를 출력한다. 추정치 출력 금지.
