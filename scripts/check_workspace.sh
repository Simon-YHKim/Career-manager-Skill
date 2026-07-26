#!/usr/bin/env bash
# OWNER: skill
# 교차 저장소 경계 게이트 — 개인 워크스페이스를 **인자로 받아** 검사한다.
#
# 경계 원칙:
#   스킬 저장소는 **경로를 인자로 받는 로직**을 소유하고,
#   개인 저장소는 **그 경로가 가리키는 데이터**를 소유한다.
#   판별은 교체 시험 — 사용자 값을 남의 것으로 바꿔도 그대로여야 하면 로직(스킬),
#   내용이 달라져야 하면 데이터(개인).
#
# ★ 왜 이 파일이 스킬 저장소에 있나: P1은 "개인 워크스페이스에 실행 로직이 없어야 한다"를
#   검사한다. 검사기가 .private/ 안에 있으면 **검사기 자신이 P1을 위반한다.** 예외로 봉합하면
#   "게이트에는 예외가 있다"는 선례가 남는다. 검사기는 누구의 워크스페이스에도 동일하게
#   동작하므로 교체 시험을 통과하는 로직이고, 워크스페이스는 인자다.
#
# ★ 무엇이 이 게이트를 촉발했나(실측 2026-07): discover.py를 스킬로 승격했는데 개인 저장소
#   사본을 회수하지 않았다. 핵심 함수 7개가 양쪽에 존재했고, 승격 직후 스킬본에만 넣은
#   거짓 기각 수정(is_same_company)이 개인본에는 없어서 **사용자의 실동 발굴 도구가 진짜
#   본사 공고를 놓치는 상태**로 남았다. 같은 일이 jd-filter.html에서도 이미 벌어져 있었다.
#
# 사용: bash scripts/check_workspace.sh <workspace-dir>
# 종료: 0 = 통과 / 1 = 위반 / 2 = 검사 불가

set -uo pipefail
WS="${1:-}"
[ -z "$WS" ] && { echo "사용법: $0 <workspace-dir>"; exit 2; }
[ -d "$WS" ] && [ -d "$WS/.private" ] || { echo "검사 불가: $WS 에 .private/ 가 없음"; exit 2; }

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
pass=0; fail=0
ok(){ echo "    [PASS] $1"; pass=$((pass+1)); }
no(){ echo "    [FAIL] $1"; fail=$((fail+1)); }

echo "  -- 워크스페이스 경계 검사: $WS"

# ── P1. 개인 워크스페이스에 실행 로직이 없다 (래퍼는 허용) ────────────────────
# 래퍼 판별: 스킬 스크립트를 호출한다고 선언한 파일(WRAPPER 마커 + 스킬 경로 참조).
logic=0; wrapped=0; offenders=""
while IFS= read -r f; do
  [ -z "$f" ] && continue
  if head -12 "$f" | grep -q "WRAPPER -> skill:"; then
    wrapped=$((wrapped+1))
  else
    logic=$((logic+1)); offenders="$offenders $f"
  fi
done < <(find "$WS/.private" -type f \( -name '*.py' -o -name '*.sh' -o -name '*.js' \) 2>/dev/null)
if [ "$logic" -eq 0 ]; then
  ok "P1 실행 로직 0건 (래퍼 ${wrapped}건은 허용)"
else
  no "P1 개인 워크스페이스에 로직 존재 →$offenders  (스킬로 승격하고 래퍼로 교체할 것)"
fi

# ── P2. 래퍼는 실제로 스킬 구현을 가리킨다 (죽은 래퍼 금지) ───────────────────
bad=""
while IFS= read -r f; do
  [ -z "$f" ] && continue
  tgt=$(head -12 "$f" | sed -n 's/.*WRAPPER -> skill:\([^ ]*\).*/\1/p' | head -1)
  [ -z "$tgt" ] && continue
  [ -f "$SKILL_DIR/$tgt" ] || bad="$bad $f→$tgt"
done < <(find "$WS/.private" -type f \( -name '*.py' -o -name '*.sh' \) 2>/dev/null)
[ -z "$bad" ] && ok "P2 래퍼 대상 실존" || no "P2 래퍼가 없는 스킬 파일을 가리킴:$bad"

# ── P3. 스킬 템플릿의 포크본이 없다 ──────────────────────────────────────────
# ★ 포크는 개인화 때문에 생긴다. 원인(왕복 부재)은 제거했으므로 잔존 사본은 회수 대상이다.
forked=""
for t in "$SKILL_DIR"/templates/*.html; do
  b=$(basename "$t" .html)
  while IFS= read -r c; do
    [ -z "$c" ] && continue
    forked="$forked $(basename "$c")"
  done < <(find "$WS/.private" -type f -name "${b}*.html" 2>/dev/null)
done
[ -z "$forked" ] && ok "P3 템플릿 포크본 0건" \
  || no "P3 스킬 템플릿의 사본 존재 →$forked  (조건은 JSON으로 저장하고 템플릿의 [필터 불러오기]로 복원할 것)"

echo "  -- 워크스페이스: ${pass} passed, ${fail} failed"
[ "$fail" -eq 0 ] || exit 1
exit 0
