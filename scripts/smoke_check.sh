#!/usr/bin/env bash
# career skill — smoke check. Verifies structure, frontmatter, tasks, templates,
# privacy gitignore, no-persona, self-contained HTML, and A4 print fidelity.
# Exit 0 = all pass.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
pass=0; fail=0
ok(){ echo "  [PASS] $1"; pass=$((pass+1)); }
no(){ echo "  [FAIL] $1"; fail=$((fail+1)); }

echo "== files =="
for f in SKILL.md BUILD_SPEC.md GOAL_CONDITION.txt README.md .gitignore \
         reference/methodology.md reference/evaluation.md reference/gems/techniques.md \
         templates/report.html templates/a4-doc.html; do
  [ -f "$f" ] && ok "exists: $f" || no "missing: $f"
done

echo "== SKILL.md frontmatter =="
name=$(awk '/^name:/{print $2; exit}' SKILL.md)
[ "$name" = "career" ] && ok "name: career" || no "name != career ($name)"
desc=$(awk '/^description:/{sub(/^description: /,""); print; exit}' SKILL.md)
wc_desc=$(printf '%s' "$desc" | wc -w | tr -d ' ')
[ "$wc_desc" -le 50 ] && [ "$wc_desc" -gt 0 ] && ok "description words=$wc_desc (<=50)" || no "description words=$wc_desc"

echo "== 7 task templates present =="
for t in "JD ↔ 포트폴리오" "문서 작성/첨삭" "면접 준비" "모의면접" "메타인지 자가진단" "연봉협상" "커리어 로드맵"; do
  grep -qF "$t" SKILL.md && ok "task: $t" || no "task missing: $t"
done

echo "== 2-stage evaluation + runtime strength =="
grep -qF "Stage 1" SKILL.md && grep -qF "Stage 2" SKILL.md && ok "2-stage eval present" || no "2-stage eval"
grep -qF "강도" SKILL.md && grep -qiE "런타임|실행 중|선택" SKILL.md && ok "runtime strength select" || no "runtime strength"

echo "== hybrid knowledge + insane-search =="
grep -qF "insane-search" SKILL.md && grep -qiE "로그인/페이월|인증 필요" SKILL.md && ok "insane-search + login/paywall stop" || no "insane-search"

echo "== personal context privacy (D-6) =="
grep -qE '^\.private/' .gitignore && grep -qE '^reference/private/' .gitignore && grep -qE '^\.env' .gitignore && ok ".gitignore excludes .private/ reference/private/ .env" || no ".gitignore privacy"
if git ls-files 2>/dev/null | grep -qiE 'profile\.md|/private/|\.pdf$'; then no "private file is git-tracked"; else ok "no private files tracked"; fi

echo "== no persona/router in SKILL.md (D-4) =="
# Must DECLARE absence (§5) and must NOT implement active menu/engine/command-center signatures.
# (Mentions inside the "금지/do-not-port" list are expected and OK.)
if grep -qF "없음(구현하지 않음)" SKILL.md \
   && ! grep -qE '현재 엔진:|빠른 시작\(번호만\)|엔진을 바꾸려면|엔진 변경: E|\[Jobs Verstappen Command Center\]|When user inputs "' SKILL.md; then
  ok "no persona/router implemented (declared absent; no active menu/engine/command-center)"
else
  no "persona/router artifact in SKILL.md"
fi

echo "== self-contained HTML (no external network) =="
for h in templates/report.html templates/a4-doc.html; do
  if grep -qiE 'https?://|src=|<link|@import|integrity=' "$h"; then no "external ref in $h"; else ok "self-contained: $h"; fi
done

echo "== A4 print fidelity =="
if python3 scripts/check_a4.py samples/sample-resume.html /tmp/_smoke_a4.pdf >/tmp/_smoke_a4.log 2>&1 && grep -q 'RESULT: PASS' /tmp/_smoke_a4.log; then
  ok "A4 sample prints clean (A4, no overflow)"; else no "A4 print check"; fi

echo ""
echo "== SUMMARY: $pass passed, $fail failed =="
[ "$fail" -eq 0 ] && { echo "SMOKE: PASS"; exit 0; } || { echo "SMOKE: FAIL"; exit 1; }
