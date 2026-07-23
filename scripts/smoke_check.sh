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
         reference/portfolio-builder.md reference/writing-voice.md reference/jd-browsing.md \
         reference/handoff.md reference/linkedin.md reference/glossary.md \
         templates/report.html templates/a4-doc.html \
         templates/intake-form.html templates/application-tracker.html templates/resume-ats.html templates/jd-discovery.html \
         templates/cover-letter.html templates/linkedin-export.html templates/roadmap.html; do
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

echo "== hybrid knowledge + JD Browsing =="
grep -qF "JD Browsing" SKILL.md && grep -qiE "로그인/페이월|인증 필요" SKILL.md && ok "JD Browsing + login/paywall stop" || no "JD Browsing"
[ -f reference/jd-browsing.md ] && grep -qiE "게이트|추론|직접 확인" reference/jd-browsing.md && ok "jd-browsing.md: embedded module + gated-inference" || no "jd-browsing.md module"
if git ls-files 2>/dev/null | grep -qF "insane-search" || grep -rqF "insane-search" SKILL.md reference/methodology.md reference/portfolio-builder.md 2>/dev/null; then no "stale 'insane-search' token remains in operational files"; else ok "renamed insane-search → JD Browsing (no stale token)"; fi

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
for h in templates/report.html templates/a4-doc.html templates/intake-form.html templates/application-tracker.html templates/resume-ats.html templates/jd-discovery.html templates/cover-letter.html templates/linkedin-export.html templates/roadmap.html; do
  if grep -qiE 'https?://|src=|<link|@import|integrity=' "$h"; then no "external ref in $h"; else ok "self-contained: $h"; fi
done

echo "== portfolio builder (P0-P8) + wiring =="
if grep -qE 'P0' reference/portfolio-builder.md && grep -qE 'P8' reference/portfolio-builder.md \
   && grep -qF "experience-bank" reference/portfolio-builder.md; then
  ok "portfolio-builder covers P0-P8 + master bank"; else no "portfolio-builder P0-P8/bank"; fi
grep -qF "portfolio-builder.md" SKILL.md && grep -qF "experience-bank" SKILL.md \
  && ok "SKILL ② wired to portfolio builder + bank" || no "SKILL not wired to portfolio builder"
grep -qiE 'AI-tell|AI 티' reference/writing-voice.md && grep -qiE '이모지' reference/writing-voice.md \
  && ok "writing-voice: AI-tell blacklist + 진지문서 규칙" || no "writing-voice content"
# intake form + tracker have the required affordances
grep -qF "데이터 복사" templates/intake-form.html && ok "intake-form: 데이터 복사 button" || no "intake-form copy button"
grep -qiE '전형|D-day|dday' templates/application-tracker.html && ok "application-tracker: 전형/D-day" || no "application-tracker content"
grep -qiE '위시리스트|적합도|한줄|발전' templates/jd-discovery.html && grep -qiE '공고|link|href' templates/jd-discovery.html && ok "jd-discovery: 순위·점수·위시리스트·링크" || no "jd-discovery content"
grep -qiE '문항|글자수|counter' templates/cover-letter.html && ok "cover-letter: 문항·글자수 카운터" || no "cover-letter content"
# linkedin-export: all fields + user-selectable activation + copy + Fill Plan(computer-use) + ToS/API + credential guard
grep -qiE '복사|copy' templates/linkedin-export.html && grep -qiE 'ToS|API' templates/linkedin-export.html \
  && grep -qiE 'Fill Plan|computer-use' templates/linkedin-export.html && grep -qiE '활성화|섹션 선택' templates/linkedin-export.html \
  && grep -qiE '자격증명' templates/linkedin-export.html \
  && ok "linkedin-export: 전체 필드·섹션 선택·복사·Fill Plan(computer-use)·자격증명 미취급" || no "linkedin-export content"
grep -qiE 'computer-use|자동 입력|Fill Plan' reference/linkedin.md && grep -qiE 'ToS|자격증명' reference/linkedin.md \
  && ok "linkedin.md: 필드 카탈로그 + A/B 모드 + 안전 프로토콜" || no "linkedin.md content"
# roadmap: multi-path recommender board (다중 경로·적합도·연차별 목표·선택)
grep -qiE '다중 경로|경로 추천|적합도' templates/roadmap.html && grep -qiE '연차|측정지표|타임라인' templates/roadmap.html \
  && grep -qiE '직급|승진|라더|인터뷰' templates/roadmap.html \
  && ok "roadmap: 직무 경로 + 직급 승진(라더·인터뷰) 두 축 보드" || no "roadmap content"
grep -qiE '다중 경로 추천|Path Recommender' reference/methodology.md && grep -qiE '직급 로드맵|Rank Ladder|직급 라더' reference/methodology.md \
  && ok "methodology: roadmap §4.5 직무 경로 + §4.6 직급 라더" || no "methodology recommender"
grep -qiE 'Path Recommender|다중 경로' SKILL.md && grep -qF "roadmap.html" SKILL.md && ok "SKILL ⑦ wired to Path Recommender + roadmap.html" || no "SKILL ⑦ recommender wiring"
# handoff.md: session-state PII routing + prepend discipline
grep -qF "session-state" reference/handoff.md && grep -qiE 'prepend|덮어쓰지' reference/handoff.md && grep -qF ".private" reference/handoff.md \
  && ok "handoff.md: 세션 핸드오프 + PII 라우팅(.private/session-state)" || no "handoff.md content"
grep -qF "handoff.md" SKILL.md && ok "SKILL wired to reference/handoff.md" || no "SKILL handoff wiring"
# 초보 진입 스캐폴딩 + 미션 명문화 (Phase B)
grep -qiE '필살기|무게중심|Truth Tier' reference/glossary.md && ok "glossary: 초보 용어집" || no "glossary content"
grep -qiE '콜드스타트|초보' SKILL.md && grep -qiE 'easy 기본|verdict-first' SKILL.md && grep -qF "glossary.md" SKILL.md && ok "SKILL: 초보 콜드스타트 + easy/verdict-first + 용어집 배선" || no "SKILL beginner scaffolding"
grep -qiE '취린이|초보' BUILD_SPEC.md && grep -qiE '미션' BUILD_SPEC.md && ok "BUILD_SPEC: 초보-포함 미션 명문화(D-0)" || no "BUILD_SPEC mission"
grep -qF "5.6" reference/evaluation.md && grep -qiE 'claim-audit|재-그라운딩|재그라운딩' reference/evaluation.md && grep -qiE '축별 4단|객관 기준|객관 산정' reference/evaluation.md && ok "evaluation: §5.6 적합도 루브릭(객관 밴드) + §8 claim-audit" || no "evaluation 5.6/8"
# Phase C: 시장 위치 레이어 + 최대 PR 엔진
grep -qiE '시장 위치 레이어' reference/evaluation.md && grep -qiE '최대 PR 엔진' reference/evaluation.md && grep -qiE '동일 사실|PR강도 3버전' reference/evaluation.md && ok "evaluation: §5.7 시장 위치 + §9 최대 PR 엔진(3버전·Before/After)" || no "evaluation 5.7/9"
grep -qiE '시장 위치 레이어|5\.7' SKILL.md && grep -qiE '최대 PR 엔진|§9' SKILL.md && ok "SKILL: 시장 위치 + PR 엔진 배선" || no "SKILL positioning/PR wiring"
grep -qiE 'claim-audit|재-그라운딩' SKILL.md && grep -qF "session-state" SKILL.md && ok "SKILL: claim-audit + 세션 핸드오프 배선" || no "SKILL anti-drift/handoff"

echo "== A4 print fidelity =="
if python3 scripts/check_a4.py samples/sample-resume.html /tmp/_smoke_a4.pdf >/tmp/_smoke_a4.log 2>&1 && grep -q 'RESULT: PASS' /tmp/_smoke_a4.log; then
  ok "A4 sample prints clean (A4, no overflow)"; else no "A4 print check (sample)"; fi
if python3 scripts/check_a4.py templates/a4-doc.html /tmp/_smoke_a4b.pdf >/tmp/_smoke_a4b.log 2>&1 && grep -q 'RESULT: PASS' /tmp/_smoke_a4b.log; then
  ok "A4 editorial template prints clean (A4, no overflow)"; else no "A4 print check (a4-doc)"; fi

echo "== plugin packaging =="
for f in .claude-plugin/plugin.json .claude-plugin/marketplace.json; do
  [ -f "$f" ] && ok "exists: $f" || no "missing: $f"
done
python3 -c "import json; d=json.load(open('.claude-plugin/plugin.json')); assert d['name']=='career'" 2>/dev/null \
  && ok "plugin.json valid JSON (name=career)" || no "plugin.json invalid"
python3 -c "import json; d=json.load(open('.claude-plugin/marketplace.json')); assert any(p['name']=='career' for p in d['plugins'])" 2>/dev/null \
  && ok "marketplace.json valid JSON (lists plugin career)" || no "marketplace.json invalid"
extra=$(ls .claude-plugin | grep -vE '^(plugin|marketplace)\.json$' || true)
[ -z "$extra" ] && ok ".claude-plugin holds only manifests" || no ".claude-plugin has extra files: $extra"
# single-skill shortcut: SKILL.md at plugin root
[ -f SKILL.md ] && ok "single-skill shortcut: SKILL.md at plugin root" || no "SKILL.md not at root"

echo ""
echo "== SUMMARY: $pass passed, $fail failed =="
[ "$fail" -eq 0 ] && { echo "SMOKE: PASS"; exit 0; } || { echo "SMOKE: FAIL"; exit 1; }
