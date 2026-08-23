#!/usr/bin/env python3
"""본문 글자 수를 센다. YAML 프론트매터는 제외한다.

사용법:
    python3 scripts/count.py posts/2026-08-23-slug.md
    python3 scripts/count.py posts/*.md
    python3 scripts/count.py --quiet posts/글.md   # 숫자만 출력

기준:
    - 공백 포함 글자 수가 정식 수치다 (하드 게이트 2000자, 목표 1400~1900자).
    - 프론트매터(--- ... ---)는 세지 않는다.
    - 문서 끝의 개행은 세지 않는다.
"""
import sys

LIMIT_HARD = 2000
TARGET_MIN = 1400
TARGET_MAX = 1900


def strip_frontmatter(text: str) -> str:
    """맨 앞의 --- ... --- 블록을 제거한다."""
    if not text.startswith("---"):
        return text
    lines = text.split("\n")
    if lines[0].strip() != "---":
        return text
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            return "\n".join(lines[i + 1:])
    return text  # 닫는 --- 이 없으면 원문 그대로


def count(path: str):
    with open(path, encoding="utf-8") as f:
        body = strip_frontmatter(f.read())
    body = body.strip()
    with_space = len(body)
    without_space = len("".join(body.split()))
    return with_space, without_space


def verdict(n: int) -> str:
    if n > LIMIT_HARD:
        return f"FAIL  상한 {LIMIT_HARD}자 초과 (+{n - LIMIT_HARD}) — 저장 금지"
    if n < TARGET_MIN:
        return f"WARN  목표 하한 미달 ({TARGET_MIN}자까지 {TARGET_MIN - n}자 부족)"
    if n > TARGET_MAX:
        return f"WARN  목표 상한 초과 ({TARGET_MAX}자보다 {n - TARGET_MAX}자 많음)"
    return f"OK    목표 구간 {TARGET_MIN}~{TARGET_MAX}자 안"


def main() -> int:
    args = sys.argv[1:]
    quiet = "--quiet" in args or "-q" in args
    paths = [a for a in args if not a.startswith("-")]

    if not paths:
        print("사용법: python3 scripts/count.py [--quiet] <파일.md> ...", file=sys.stderr)
        return 2

    worst = 0
    for path in paths:
        try:
            with_space, without_space = count(path)
        except FileNotFoundError:
            print(f"파일 없음: {path}", file=sys.stderr)
            worst = 2
            continue

        if quiet:
            print(with_space)
        else:
            v = verdict(with_space)
            print(f"{path}")
            print(f"  공백 포함 : {with_space:,}자")
            print(f"  공백 제외 : {without_space:,}자")
            print(f"  판정      : {v}")
        if with_space > LIMIT_HARD:
            worst = max(worst, 1)

    return worst


if __name__ == "__main__":
    sys.exit(main())
