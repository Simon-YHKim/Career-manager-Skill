#!/usr/bin/env bash
# career skill — smoke check. Verifies structure, frontmatter, tasks, templates,
# privacy gitignore, no-persona, self-contained HTML, and A4 print fidelity.
# Exit 0 = all pass.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
pass=0; fail=0
ok(){ echo "  [PASS] $1"; pass=$((pass+1)); }
no(){ echo "  [FAIL] $1"; fail=$((fail+1)); }

# ── 사전 점검(비-집계) ─────────────────────────────────────────────────────────
# ★ 새로 클론한 컨테이너에서 A4 게이트 6건이 실패했는데 원인은 PyMuPDF 미설치였다(실측).
#   빨간 줄만 보면 코드 회귀로 오독된다 → 게이트를 돌리기 **전에** 원인을 먼저 알린다.
#   경고일 뿐 집계에 넣지 않는다. 게이트 자체는 그대로 실패시킨다(조용한 스킵 금지).
if ! python3 -c 'import fitz' 2>/dev/null; then
  echo "!! 의존성 없음: PyMuPDF — A4 인쇄 게이트가 실패합니다(코드 회귀 아님)."
  echo "   설치: pip install -r scripts/requirements.txt"
  echo
fi

echo "== files =="
for f in SKILL.md BUILD_SPEC.md GOAL_CONDITION.txt README.md .gitignore \
         reference/methodology.md reference/evaluation.md reference/gems/techniques.md \
         reference/portfolio-builder.md reference/writing-voice.md reference/polish-rulebook.md reference/jd-browsing.md \
         reference/handoff.md reference/linkedin.md reference/glossary.md reference/hub-backend.md reference/job-search-ops.md \
         worker/src/index.js worker/wrangler.toml worker/README.md \
         templates/report.html templates/a4-doc.html \
         templates/intake-form.html templates/application-tracker.html templates/resume-ats.html templates/jd-discovery.html \
         templates/cover-letter.html templates/linkedin-export.html templates/roadmap.html templates/interview-prep.html templates/hub.html; do
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
# ★ 정규식 주의: '/private/'는 '.private/'를 매치하지 못한다(앞에 슬래시가 없음).
# 실측(2026-07): 이 버그로 .private/experience-bank.md를 스테이징한 상태에서도 [PASS]가 찍혔다.
if git ls-files 2>/dev/null | grep -qiE '(^|/)\.?private/|profile\.md|\.pdf$'; then no "private file is git-tracked"; else ok "no private files tracked"; fi

# ── discover.py 승격 가드 (개인 저장소 → 스킬) ──────────────────────────────
# ★ 이 스크립트는 원래 개인 저장소에 있었고 현직·타깃 기업·직무명이 **기본값으로 박혀** 있었다.
#   승격의 전제가 "개인 값은 전부 필터 입력에서 온다"이므로, 그 전제를 선언이 아니라 **검사**한다.
#   기본값이 하나라도 되살아나면 남의 조건으로 발굴하고도 그런 줄 모르게 된다.
if [ -f scripts/discover.py ]; then
  # (a) 개인 값 하드코딩 금지 — 필터 키를 읽는 코드가 아니라 '값'이 박혀 있는지를 본다
  if python3 - <<'PY' 2>/dev/null
import re, sys
s = open('scripts/discover.py', encoding='utf-8').read()
# 리스트 리터럴 안의 한글 회사명/직무명이 기본값으로 쓰이는 패턴
bad = []
for m in re.finditer(r'(?:currentEmployerNames|targetCompanies|EXCLUDE_EMPLOYERS|TARGET_COMPANIES|ROLES)\s*=\s*([^\n]*)', s):
    line = m.group(1)
    if re.search(r'\[[^\]]*["\'][가-힣A-Za-z]', line):   # 비어있지 않은 리터럴 기본값
        bad.append(m.group(0)[:70])
sys.exit(1 if bad else 0)
PY
  then ok "discover.py: 개인 값 기본값 없음(현직·타깃기업·직무명)"; else no "discover.py에 개인 값 기본값이 박혀 있음"; fi
  # (b) 필터 없이 실행하면 **반드시 중단** — 기본값으로 조용히 도는 일이 없어야 한다
  if ! python3 scripts/discover.py >/dev/null 2>&1; then
    ok "discover.py: 필터 없이 실행 시 중단(무단 기본값 실행 차단)"; else no "discover.py가 필터 없이도 실행됨"; fi
  # (c) 스키마 고정 — jd-filter.html 출력과 계약이 어긋나면 조용히 빈 매트릭스가 된다
  grep -qF 'career/jd-filter@1' scripts/discover.py && grep -qF 'career/jd-filter@1' templates/jd-filter.html \
    && ok "discover.py ↔ jd-filter.html 스키마 계약 일치(career/jd-filter@1)" || no "필터 스키마 계약 불일치"
  # (d) 3-상태 기록 — '공고 0건'과 '취득 실패'를 뭉뚱그리면 다음 라운드에 같은 곳을 다시 판다
  grep -qF '공고 0건(정상 응답)' scripts/discover.py && grep -qF '취득 실패' scripts/discover.py \
    && grep -qF 'agent_todo' scripts/discover.py \
    && ok "discover.py: 3-상태 기록 + 에이전트 작업 목록 배출" || no "discover.py 3-상태/작업목록 누락"
else
  no "scripts/discover.py 없음"
fi

# ── hub.html 신뢰 경계: 외부 데이터는 normalize() 한 곳만 통과한다 ──────────
# ★ hub는 스킬에서 유일하게 **사용자가 파일로 가져오는** JSON을 받는다(붙여넣기·BYO 백엔드·localStorage).
#   경계가 여러 곳이면 새 경로가 생길 때마다 조용히 샌다 → DATA 대입 형태를 강제한다.
if python3 - <<'PY' 2>/dev/null
import re, sys
s = open('templates/hub.html', encoding='utf-8').read()
bad = []
# `DATA =`(속성 대입 DATA.x= 는 제외) 대입문마다 **문장 전체**를 보고 정규화 통과를 요구한다.
# ★ 첫 토큰만 보면 삼항(`DATA = r ? normalize(r) : sampleData()`)을 거짓 검출한다(실측).
for m in re.finditer(r'\bDATA\s*=(?!=)', s):
    stmt = s[m.end(): s.find(';', m.end())]
    if 'normalize(' in stmt or 'sampleData(' in stmt:
        continue
    bad.append(stmt.strip()[:60])
sys.exit(1 if bad else 0)
PY
then ok "hub: 외부 데이터가 normalize() 한 곳으로만 진입(대입문 전체 검사)"; else no "hub: normalize()를 우회하는 DATA 대입 존재"; fi

# ── 교차 저장소 경계 게이트 ──────────────────────────────────────────────────
# ★ 승격 세션에서 개인 워크스페이스의 사본을 회수하지 않아 로직이 두 벌이 됐다(실측).
#   문서·배너는 강제력이 없다 — 이 저장소는 강제력 없는 문서로 이미 한 번 실패했다.
#   그래서 워크스페이스를 자동 탐색해 검사하고 **그 결과를 이 집계에 편입**한다.
#   검사 못 한 경우를 '초록'과 구별한다 — 조용히 넘어가면 안 검사한 게 통과로 보인다.
WS="${CAREER_WORKSPACE:-}"
if [ -z "$WS" ]; then
  for c in ../Career ../career "$HOME/Career"; do
    [ -d "$c/.private" ] && { WS="$c"; break; }
  done
fi
if [ -n "$WS" ] && [ -d "$WS/.private" ]; then
  echo "== cross-repo workspace boundary =="
  if bash scripts/check_workspace.sh "$WS"; then
    ok "워크스페이스 경계 준수 ($WS)"
  else
    no "워크스페이스 경계 위반 ($WS) — 위 [FAIL] 참조"
  fi
else
  echo "== cross-repo workspace boundary =="
  echo "  !! cross-repo: NOT RUN — 개인 워크스페이스를 찾지 못했습니다(CAREER_WORKSPACE 로 지정 가능)."
  echo "     초록이지만 **교차 검사는 안 된 상태**입니다."
fi

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
# 추적되는 모든 HTML을 자동 대상화(하드코딩 목록이 새 파일을 놓치는 문제 제거 — samples/ 포함)
for h in $(git ls-files '*.html' 2>/dev/null || ls templates/*.html); do
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

# ── 윤문 룰북 (취업 특화 AI-tell 제거) ───────────────────────────────────────
# ★ 범용 윤문 지식은 모델 안에 이미 있어서, 지시하지 않으면 두괄식 해체·불릿 산문화가
#   되살아난다. 반전 목록이 문서에 실재하는지를 게이트로 고정한다.
grep -qF '문서유형' reference/polish-rulebook.md && grep -qE '판정을 보류|묻는다' reference/polish-rulebook.md \
  && ok "룰북: 축 판정이 템플릿이 아니라 문서유형 입력(모르면 보류)" || no "룰북 축 판정"
grep -qE '두괄식' reference/polish-rulebook.md && grep -qE '불릿 → 산문|불릿 산문' reference/polish-rulebook.md \
  && grep -qE '헤딩 제거' reference/polish-rulebook.md && grep -qE '조사 복원' reference/polish-rulebook.md \
  && ok "룰북 §3: 반전·비활성 목록 실재(두괄식·불릿·헤딩·조사)" || no "룰북 반전 목록"
grep -qE 'hedge' reference/polish-rulebook.md && grep -qE '역할 경계' reference/polish-rulebook.md \
  && grep -qE '수치 원자' reference/polish-rulebook.md \
  && ok "룰북 §2: 트림 불가침 명문화(수치·역할경계·hedge)" || no "룰북 불가침"
# 비중복 — 같은 토큰 목록이 두 파일에 있으면 세션마다 갈라진다
if grep -qF '~에 있어' reference/polish-rulebook.md && ! grep -qF '~에 있어' reference/writing-voice.md; then
  ok "티 토큰 비중복: 룰북에만 존재(writing-voice는 계약)"; else no "티 토큰이 두 파일에 중복"; fi
# 임계 SSOT 일치 — 문서와 코드가 각자 숫자를 적으면 어긋난다
if python3 - <<'PYEOF' 2>/dev/null
import re,sys
c=open('scripts/check_polish.py',encoding='utf-8').read()
d=open('reference/polish-rulebook.md',encoding='utf-8').read()
floor=re.search(r'LEN_FLOOR_RATIO\s*=\s*([\d.]+)',c).group(1)
warn=re.search(r'CHANGE_WARN\s*=\s*([\d.]+)',c).group(1)
end=re.search(r'ENDING_FLOOR\s*=\s*([\d.]+)',c).group(1)
sys.exit(0 if (floor in d and warn in d and end in d) else 1)
PYEOF
then ok "임계 SSOT 일치(룰북 §7 표 ↔ check_polish.py 상수)"; else no "임계값이 문서와 코드에서 어긋남"; fi
# 실행 검사 — 문자열이 아니라 동작
if [ "$(python3 scripts/check_polish.py --after /dev/null 2>/dev/null; echo $?)" = "3" ]; then
  ok "check_polish: 축 미지정 시 판정 보류(추정 금지)"; else no "check_polish 축 미지정 처리"; fi
# 폴백 축은 [일] — 규칙 많은 쪽이 아니라 오탐 비용 낮은 쪽
grep -qE '\[일\]' reference/polish-rulebook.md && grep -qF '"일반": "일"' scripts/check_polish.py \
  && ok "룰북 §1: 일반 산출 축[일] 존재(폴백이 자소서 규칙을 안 씀)" || no "일반 산출 축 누락"
# 하한 비율이 템플릿과 스크립트에서 같은 값인가
if python3 - <<'PYEOF' 2>/dev/null
import re,sys
c=re.search(r'LEN_FLOOR_RATIO\s*=\s*([\d.]+)',open('scripts/check_polish.py',encoding='utf-8').read()).group(1)
h=re.search(r'FLOOR_RATIO\s*=\s*([\d.]+)',open('templates/cover-letter.html',encoding='utf-8').read()).group(1)
sys.exit(0 if float(c)==float(h) else 1)
PYEOF
then ok "하한 비율 일치(check_polish ↔ cover-letter)"; else no "하한 비율이 스크립트와 템플릿에서 다름"; fi
# ATS 시트에 구분자 모호 문자가 없는가 — 기계가 읽는 제출본이다
if python3 -c "
import sys
s=open('templates/resume-ats.html',encoding='utf-8').read()
b=s[s.index('<div class=\"sheet\" id=\"sheet\">'):s.index('<script>')]
sys.exit(0 if not any(c in b for c in '—–·') else 1)" 2>/dev/null
then ok "resume-ats: 시트에 모호 구분자 0건(em/en dash·middot)"; else no "resume-ats 시트에 모호 구분자 잔존"; fi
# 폰트 고지 — 서브셋 내장은 원본 파일을 지우므로 고지가 증발한다
grep -qF 'SIL Open Font License' scripts/embed_fonts.py \
  && ok "embed_fonts: 폰트 라이선스 고지를 산출물에 배출" || no "embed_fonts 고지 누락"
# intake form + tracker have the required affordances
grep -qF "데이터 복사" templates/intake-form.html && ok "intake-form: 데이터 복사 button" || no "intake-form copy button"
grep -qiE '전형|D-day|dday' templates/application-tracker.html && ok "application-tracker: 전형/D-day" || no "application-tracker content"
grep -qiE '위시리스트|적합도|한줄|발전' templates/jd-discovery.html && grep -qiE '공고|link|href' templates/jd-discovery.html && ok "jd-discovery: 순위·점수·위시리스트·링크" || no "jd-discovery content"
grep -qiE '문항|글자수|counter' templates/cover-letter.html && grep -qiE '의도|q-intent' templates/cover-letter.html && ok "cover-letter: 문항·글자수 카운터 + 문항 의도" || no "cover-letter content"
# 입력 폼 프로젝트 필드(프로젝트명·기간·성과·역할·기술) + 면접대비 버전(항목별 예상질문 3개)
grep -qiE 'data-f="period"|기간 \(YYYY' templates/intake-form.html && grep -qiE 'data-f="stack"|기술' templates/intake-form.html && ok "intake-form: 프로젝트 기간·기술 필드 분리" || no "intake-form project fields"
grep -qiE '예상질문|면접 대비' templates/interview-prep.html && grep -qiE '검증|진위|심화' templates/interview-prep.html && grep -qiE '평가 의도|방어 포인트' templates/interview-prep.html && ok "interview-prep: 항목별 예상질문 3개 + 의도·방어·Truth Tier" || no "interview-prep content"
grep -qF "interview-prep.html" SKILL.md && ok "SKILL ③ wired to interview-prep.html" || no "SKILL interview-prep wiring"
# 개인 허브 (로컬-우선 + BYO 백엔드)
grep -qiE 'localStorage' templates/hub.html && grep -qiE '백엔드|동기화' templates/hub.html && grep -qiE '내보내기|가져오기' templates/hub.html && ok "hub: 로컬-우선 관리(localStorage·JSON 왕복·BYO 동기화)" || no "hub content"
grep -qiE 'BYO|사용자 소유|무료 백엔드' reference/hub-backend.md && grep -qiE 'Cloudflare|Supabase' reference/hub-backend.md && grep -qiE '계약|opt-in|service-role' reference/hub-backend.md && ok "hub-backend: 계약 + 무료 백엔드 레시피 + 보안" || no "hub-backend content"
grep -qF "hub.html" SKILL.md && grep -qF "hub-backend.md" SKILL.md && ok "SKILL wired to hub + hub-backend" || no "SKILL hub wiring"
# BYO 워커(데이터+AI 프록시) + 인브라우저 AI(opt-in)
grep -qiE 'CAREER|/doc' worker/src/index.js && grep -qiE '/ai|anthropic|openai' worker/src/index.js && grep -qiE 'TOKEN|AI_KEY' worker/src/index.js && ok "worker: 데이터 KV + AI 프록시(토큰·키 시크릿)" || no "worker content"
grep -qiE 'AI 다듬기|aiPolish|aiUrl' templates/hub.html && grep -qiE '프록시|AI_KEY|Worker' templates/hub.html && ok "hub: 인브라우저 AI(프록시·다듬기·opt-in)" || no "hub AI content"
grep -qiE '인브라우저 AI|AI 프록시|경로 A' reference/hub-backend.md && ok "hub-backend: AI 프록시 + 두 UX 경로" || no "hub-backend AI"
# 워커 파일에 하드코딩 자격증명 없음(시크릿만)
if grep -qiE 'sk-ant-|sk-[A-Za-z0-9]{20}|api[_-]?key\s*[:=]\s*["'"'"'][A-Za-z0-9]' worker/src/index.js worker/wrangler.toml 2>/dev/null; then no "worker has hardcoded credential"; else ok "worker: no hardcoded credentials (secrets only)"; fi
# 시크릿 스캔을 추적 파일 전체로 확대 + 패턴 보강(자기 자신은 탐지 정규식을 포함하므로 제외)
SECRET_RE='sk-ant-[A-Za-z0-9]|sk-proj-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{20,}|AIza[0-9A-Za-z_-]{30,}|-----BEGIN [A-Z ]*PRIVATE KEY-----'
hits=$(git ls-files -z | grep -zv '^scripts/smoke_check\.sh$' | xargs -0 grep -lE "$SECRET_RE" 2>/dev/null || true)
[ -z "$hits" ] && ok "추적 파일 전체 시크릿 스캔 0건" || no "secret-like string in: $hits"
# --- 동작 회귀 게이트 (문자열 존재가 아니라 '실제로 동작하는가' — 최종검증에서 발견된 결함 재발 방지) ---
# (a) XSS: 런타임 실증 — 악성 값을 데이터에 심고 실제로 렌더해 살아나는지 본다.
# ★ 옛 게이트는 esc() 정의만 격리 실행해 호출부를 다 지워도 통과했다. 정적 sink 스캔은 오탐이 많다.
#   그래서 chromium으로 실제 렌더 후 (i) onerror 발화 (ii) 엘리먼트 파싱 (iii) 위험 스킴 href를 검사한다.
node scripts/check_xss.js 2>/dev/null \
  && ok "XSS: 런타임 실증(페이로드 미실행·미파싱·위험스킴 href 없음)" || no "XSS: 페이로드가 살아있는 마크업/링크로 렌더됨"
# (b) worker provider: 클라이언트가 벤더를 절대 못 정하는가 (키 오전송 방지) — 문자열이 아니라 실제 로직 실행
# ★ 이전 게이트는 순수 grep이라 주석에 문자열만 남기고 우선순위를 뒤집어도 통과했다.
#   또한 AI_PROVIDER 미설정(기본 배포)이라는 핵심 케이스를 아예 검사하지 않았다.
if node -e "
const fs=require('fs');const s=fs.readFileSync('worker/src/index.js','utf8');
const m=s.match(/const provider = [^;]+;/); if(!m) process.exit(2);
const pick=(env,b)=>new Function('env','b','\"use strict\";'+m[0]+'return provider;')(env,b);
const t=[];
t.push(['시크릿 미설정+클라 openai → anthropic 유지', pick({},{provider:'openai'})==='anthropic']);
t.push(['시크릿 미설정+클라 미지정 → anthropic',      pick({},{})==='anthropic']);
t.push(['시크릿 openai → openai',                   pick({AI_PROVIDER:'openai'},{})==='openai']);
t.push(['시크릿 openai+클라 anthropic → openai 유지', pick({AI_PROVIDER:'openai'},{provider:'anthropic'})==='openai']);
const bad=t.filter(x=>!x[1]).map(x=>x[0]);
if(bad.length){ console.error('FAILED: '+bad.join(', ')); process.exit(1); }
" 2>/dev/null; then ok "worker: 벤더는 서버만 결정(미설정 기본 구성 포함) — 키 오전송 차단"; else no "worker: 클라이언트가 벤더를 정할 수 있음(키 오전송 위험)"; fi
# (c) report.html 토글 특이도 교정(한/영 중복 노출 방지)
grep -qE 'body:not\(\.lang-en\) \.en\{display:none\}' templates/report.html \
  && grep -qE 'body:not\(\.mode-easy\) \.easy\{display:none\}' templates/report.html \
  && ok "report.html: 언어·난이도 토글 특이도 교정(4상태 배타)" || no "report.html toggle specificity"
# (d) a4-doc 제출 안전: 인쇄 시 작업용 메모 은닉 이중 방어선 유지
grep -qE '\.work-only\{ *display:none *!important' templates/a4-doc.html \
  && grep -qi 'beforeprint' templates/a4-doc.html \
  && ok "a4-doc: 제출 인쇄 안전 이중 방어선(print CSS + beforeprint)" || no "a4-doc submission-safety guard"
# (e) 개인정보 커밋 방지가 '선언'이 아니라 '절차'로 존재하는가
grep -qiE 'is-inside-work-tree|워크트리' SKILL.md && grep -qF ".gitignore" SKILL.md \
  && ok "SKILL: .private/ gitignore 등록 절차(선언 아닌 이행)" || no "SKILL privacy procedure"
# (f) ⑤ 무데이터 가드(0/0 방지, 초보 낙담 방지)
grep -qiE '무데이터|분모가 0|N/A\(자료 없음\)' reference/evaluation.md \
  && ok "evaluation §5.5: 무데이터 선행 가드(N/A·0/0 금지)" || no "evaluation no-data guard"
# (h) 4분면 승격 가드가 '실제로' 라벨을 내리는가 — 만료/자사/확신낮음/하향이 최우선으로 새면 실사용에서 오판
if node -e "
const fs=require('fs');const s=fs.readFileSync('templates/jd-discovery.html','utf8');
const grab=(re)=>{const m=s.match(re); if(!m) throw new Error('not found: '+re); return m[0];};
const src=[/function daysTo\(d\)\{[^}]*\}/, /function dlOk\(j\)\{[^}]*\}/, /function quadrant\(fit, qual\)\{[\s\S]*?\n  \}/,
  /function delta\(j\)\{[\s\S]*?\n  \}/, /function expired\(j\)\{[^}]*\}/,
  /function guardReason\(j\)\{[\s\S]*?\n  \}/, /function quadLabel\(j\)\{[\s\S]*?\n  \}/].map(grab).join('\n');
const FIX='const TODAY='+JSON.stringify('2026-07-26')+';';
const base=(b)=>new Function('BASELINE','J','\"use strict\";'+FIX+src+'return quadLabel(J);');
const hi={score:90,quality:90,confidence:'높음',deadline:'2099-01-01',dlVerified:true};
const t=[];
t.push(['정상 최우선', base()(null,hi)==='최우선']);
t.push(['만료 차단',   base()(null,Object.assign({},hi,{deadline:'2000-01-01'}))!=='최우선']);
t.push(['자사 차단',   base()(null,Object.assign({},hi,{self:true}))!=='최우선']);
t.push(['확신낮음 차단',base()(null,Object.assign({},hi,{confidence:'낮음'}))!=='최우선']);
t.push(['하향(Δ<=-10) 차단', base()({quality:105},hi)!=='최우선']);
t.push(['보합(Δ=-3)은 통과 — 배지와 임계 일치', base()({quality:93},hi)==='최우선']);
t.push(['상향 통과',   base()({quality:60},hi)==='최우선']);
t.push(['기준선없음 Δ미적용', base()(null,hi)==='최우선']);
t.push(['다른분면 유지', base()(null,{score:40,quality:40,confidence:'높음',deadline:'2099-01-01',dlVerified:true})==='후순위']);
const bad=t.filter(x=>!x[1]).map(x=>x[0]);
if(bad.length){ console.error('FAILED: '+bad.join(', ')); process.exit(1); }
process.exit(0);
" 2>/dev/null; then ok "jd-discovery: 4분면 승격 가드 동작(만료·자사·확신낮음·하향 차단 / 상향 통과)"; else no "jd-discovery 승격 가드가 동작하지 않음"; fi
# (i) Δ는 기준선이 있을 때만 — 없는데 0으로 가정하면 무직 사용자에게 허위 판정
if node -e "
const fs=require('fs');const s=fs.readFileSync('templates/jd-discovery.html','utf8');
const m=s.match(/function delta\(j\)\{[\s\S]*?\n  \}/); if(!m) process.exit(2);
const f=new Function('BASELINE','j','\"use strict\";'+m[0]+'return delta(j);');
process.exit((f(null,{quality:50})===null && f({quality:70},{quality:50})===-20 && f({quality:70},{})===null) ? 0 : 1);
" 2>/dev/null; then ok "jd-discovery: Δ는 기준선 있을 때만(무직 0-가정 금지)"; else no "delta() 기준선 처리 오류"; fi
# (h13) PII 보호가 '선언'이 아니라 '결과 검증'인가 — 임시 저장소로 실제 유출을 재현해 확인
# ★ 실측: .gitignore에 줄을 적어도 경로가 이미 추적 중이면 무효인데, 스킬은 "등록했습니다"라고 보고했다.
if bash -c '
set -e
T=$(mktemp -d); cd "$T"
git init -q . && git config user.email t@t && git config user.name t
mkdir -p .private reference/private
echo secret > .private/profile.md
echo resume > reference/private/resume.pdf
git add -A -f >/dev/null && git commit -qm init          # 개인정보가 이미 추적 중인 상태
printf ".private/\nreference/private/\n" > .gitignore   # 규칙 ②만 이행
# 낡은 절차(텍스트 확인)는 여기서 "보호됨"이라 판정했다:
grep -q "^\.private/$" .gitignore || exit 9
# 새 절차(결과 검증)는 반드시 실패를 감지해야 한다:
if git check-ignore -q .private/profile.md; then exit 1; fi   # 추적 중이므로 무시 안 됨 → 감지 성공
git ls-files --error-unmatch .private/profile.md >/dev/null 2>&1 || exit 2
# 안내대로 조치하면 보호가 실제로 성립하는가
git rm --cached -r -q .private reference/private
git check-ignore -q .private/profile.md || exit 3
git check-ignore -q reference/private/resume.pdf || exit 4
cd /; rm -rf "$T"
' 2>/dev/null; then ok "PII: check-ignore 결과 검증(추적중 감지 + 조치 후 실제 보호)"; else no "PII 보호가 결과로 검증되지 않음"; fi
grep -qF 'git check-ignore' SKILL.md && grep -qF 'git rm --cached' SKILL.md \
  && grep -qF 'reference/private/' SKILL.md \
  && grep -qiE '선언은 보호가 아니다' SKILL.md \
  && ok "SKILL §2: PII 가드가 결과 검증 절차(두 경로·중단·재고지)" || no "SKILL PII 절차가 텍스트 확인에 머무름"
# (h12) 퍼널 병목 판정 — 서류에서 떨어지는 사람에게 "자소서 수정은 우선순위가 아니다"라고 하지 않는가
# ★ 실측 오진: 배타 if-else 사슬이라 서류통과 1건이면 docRate<=0.05를 빠져나가 '면접 전환' 병목으로 갔다.
#   서류통과 5%(19건 중 1건)인데 "서류는 통과하는데"라고 단정 — 리소스 배분을 정확히 반대로 돌린다.
if node -e "
const fs=require('fs');const s=fs.readFileSync('templates/application-tracker.html','utf8');
const g=(re)=>{const m=s.match(re); if(!m) throw new Error('miss'); return m[0];};
const src=[g(/const STAGES = \[[^\]]*\];/), g(/const STAGE_ALIAS = \{[\s\S]*?\};/), g(/function normStage\(a\)\{[\s\S]*?\n  \}/),
  g(/const MIN_SAMPLE = 10;/), g(/function reached\(app, idx\)\{[\s\S]*?\n  \}/)].join('\n');
const body=g(/    \/\/ ── 병목 판정[\s\S]*?\n    \}\n/);
function run(n,dp,itv,fin,off){
  const APPS=[];
  for(let k=0;k<n;k++){ let st='불합격',la='서류접수',re='fail';
    if(k<off){st='최종';la='최종';re='pass';} else if(k<fin){st='최종';la='최종';re='progress';}
    else if(k<itv){st='1차면접';la='1차면접';re='progress';} else if(k<dp){st='서류합격';la='서류합격';re='progress';}
    APPS.push({applied:'2026-01-01',stage:st,lastStage:la,result:re}); }
  const pre=src+'\nconst escHtml=x=>String(x);const applied=APPS.filter(a=>a.applied);'+
   'const iDoc=STAGES.indexOf(\"서류합격\"),i1=STAGES.indexOf(\"1차면접\"),iF=STAGES.indexOf(\"최종\");'+
   'const n=applied.length;const docPass=applied.filter(a=>reached(a,iDoc)).length;'+
   'const itv=applied.filter(a=>reached(a,i1)).length;const fin=applied.filter(a=>reached(a,iF)).length;'+
   'const offer=applied.filter(a=>a.result===\"pass\").length;';
  return new Function('APPS',pre+body+'return verdict;')(APPS);
}
const t=[];
t.push(['서류 5%는 문서 병목',   /문서·타겟팅/.test(run(19,1,0,0,0))]);
t.push(['서류 10%도 문서 병목',  /문서·타겟팅/.test(run(10,1,0,0,0))]);
t.push(['서류 0%도 문서 병목',   /문서·타겟팅/.test(run(10,0,0,0,0))]);
t.push(['서류 저조시 면접병목 아님', !/면접 전환/.test(run(19,1,0,0,0))]);
t.push(['분모 1로 임원병목 단정 금지', !/임원·컬처핏/.test(run(10,1,1,0,0))]);
t.push(['계산 근거 병기',        /근거:/.test(run(19,1,0,0,0))]);
t.push(['표본 부족은 보류',      /표본 부족/.test(run(5,0,0,0,0))]);
t.push(['건강한 퍼널은 병목 없음', !/병목:/.test(run(20,10,7,3,2))]);
const bad=t.filter(x=>!x[1]).map(x=>x[0]);
if(bad.length){ console.error('FAILED: '+bad.join(', ')); process.exit(1); }
" 2>/dev/null; then ok "tracker: 퍼널 병목 argmin 판정(서류 저조 오진 방지·분모 가드·근거 병기)"; else no "퍼널 병목 오진 — 서류 저조인데 면접/임원 병목으로 판정"; fi
# (h11) 총점 검산 — 총점과 축을 각각 손으로 적으면 어긋난다(실측: 실사용 보드 13건 중 6건 불일치)
if node -e "
const fs=require('fs');const s=fs.readFileSync('templates/jd-discovery.html','utf8');
const g=(re)=>{const m=s.match(re); if(!m) throw new Error('miss'); return m[0];};
const src=[g(/const FIT_W  = \{[^}]*\};/), g(/const QUAL_W = \{[^}]*\};/), g(/function wsum\(obj, W\)\{[\s\S]*?\n  \}/),
  g(/const calcFit[^\n]*\n/), g(/const calcQual[^\n]*\n/), g(/const TOL = \d+;[^\n]*\n/), g(/function mismatch\(j\)\{[\s\S]*?\n  \}/)].join('\n');
const M=(j)=>new Function('j',src+'return mismatch(j);')(j);
const S4=(v)=>({role:v,major:v,growth:v,weight:v}), S5=(v)=>({pay:v,grow:v,stable:v,culture:v,personal:v});
const t=[];
t.push(['일치는 통과',       M({score:80,sub:S4(80),quality:70,qsub:S5(70)}).length===0]);
t.push(['적합도 불일치 검출', M({score:70,sub:S4(85),quality:70,qsub:S5(70)}).length>0]);
t.push(['품질 불일치 검출',   M({score:80,sub:S4(80),quality:60,qsub:S5(80)}).length>0]);
t.push(['N/A 축 재정규화',    M({score:80,sub:S4(80),quality:80,qsub:{pay:80,grow:80,stable:80,personal:80}}).length===0]);
t.push(['하드필터 하향상한 허용', M({score:38,sub:S4(60),quality:70,qsub:S5(70),qualfit:'미달'}).length===0]);
t.push(['상한인데 상향은 오류',   M({score:90,sub:S4(60),quality:70,qsub:S5(70),qualfit:'미달'}).length>0]);
const bad=t.filter(x=>!x[1]).map(x=>x[0]);
if(bad.length){ console.error('FAILED: '+bad.join(', ')); process.exit(1); }
" 2>/dev/null; then ok "jd-discovery: 총점 검산(축 가중합 대조·N/A 재정규화·하드필터 상한 구분)"; else no "총점 검산이 동작하지 않음"; fi
# §5.9 오차 병기 강제 + N/A 명시 렌더
grep -qE 'class="noerr"' templates/jd-discovery.html \
  && grep -qiE '점수만 단독 제시 금지' templates/jd-discovery.html \
  && ok "jd-discovery §5.9: 오차 누락 시 화면 경고(±?)" || no "오차 없는 단독 점수가 조용히 렌더됨"
grep -qE 'subrow na' templates/jd-discovery.html && grep -qE ">N/A<" templates/jd-discovery.html \
  && ok "jd-discovery: N/A 축 명시 렌더(null 문자열·0점 취급 방지)" || no "N/A 축이 null/0으로 렌더됨"
# (h10) 자소서 = 면접 대본 (methodology §2-5.5) — 원칙이 아니라 산출물로 강제되는가
grep -qiE '면접 역산 설계' reference/methodology.md \
  && grep -qiE '내가 쓴 모든 문장이 곧 내가 받을 질문' reference/methodology.md \
  && grep -qiE '훅\(Hook\)|훅 유형' reference/methodology.md \
  && grep -qiE '지뢰 제거' reference/methodology.md \
  && grep -qiE '예상 꼬리질문 3개' reference/methodology.md \
  && ok "methodology §2-5.5: 면접 역산 설계(훅·지뢰제거·꼬리질문 산출)" || no "자소서 면접역산 절차 누락"
grep -qF 'q-drill' templates/cover-letter.html && grep -qF 'copyDrill' templates/cover-letter.html \
  && grep -qE '\.q-intent, \.q-drill\{ display:none !important' templates/cover-letter.html \
  && ok "cover-letter: 문항별 꼬리질문 필드 + 면접 문제은행 추출(제출본 미노출)" || no "꼬리질문 필드/추출 미구현"
# 통과 판정 기준에도 반영됐는가(체크리스트가 실행을 강제한다)
grep -qiE '훅이 1–2개 심겨' reference/methodology.md \
  && grep -qiE '답을 준비 못 한 문장이 남아' reference/methodology.md \
  && ok "methodology §2-6: 통과 판정에 면접역산 4항 반영" || no "통과 판정 미반영"
# (h9) 자소서 제출본: 답변이 실제로 인쇄되는가 + 본문 속 작업 마커가 제거되는가
# ★ 실측 2건: (i) textarea는 인쇄 시 잘려 답변이 통째로 누락됐다(PDF 25자)
#   (ii) 제출 게이트가 .work-only 블록만 봐서 답변 '본문 안에' 쓴 [T2 …]가 그대로 새어나갔다
if node -e "
const fs=require('fs');const s=fs.readFileSync('templates/cover-letter.html','utf8');
const g=(re)=>{const m=s.match(re); if(!m) throw new Error('miss'); return m[0];};
const f=new Function(g(/const WORK_MARK = [^;]+;/)+'\n'+g(/function stripWorkMarks\(text\)\{[\s\S]*?\n  \}/)+'return stripWorkMarks;')();
const t=[];
t.push(['마커 전용 줄 삭제', !/T2/.test(f('본문\n\n[T2 — 메모]\n\n계속'))]);
t.push(['문미 마커 제거',   f('문장입니다. [확인 필요]')==='문장입니다.']);
t.push(['T3도 제거',       !/T3/.test(f('a\n[T3 미검증]\nb'))]);
t.push(['본문 보존',       f('정상 문단\n\n둘째 문단')==='정상 문단\n\n둘째 문단']);
const bad=t.filter(x=>!x[1]).map(x=>x[0]);
if(bad.length){ console.error('FAILED: '+bad.join(', ')); process.exit(1); }
" 2>/dev/null; then ok "cover-letter: 제출 마커 스트리퍼 동작([T1-3]·확인 필요 제거)"; else no "제출본에 작업 마커가 남는다"; fi
grep -qE 'print-copy' templates/cover-letter.html && grep -qE 'textarea\{ display:none !important' templates/cover-letter.html \
  && grep -qF 'beforeprint' templates/cover-letter.html \
  && ok "cover-letter: 인쇄 미러(textarea 잘림 방지)" || no "cover-letter 인쇄 시 답변 누락"
# (h8) 난이도 밴드(쉬움/적정/도전)가 실제로 판정되는가 — 사용자가 "어디에 몇 개 넣을지"를 정하는 축
if node -e "
const fs=require('fs');const s=fs.readFileSync('templates/jd-discovery.html','utf8');
const g=(re)=>{const m=s.match(re); if(!m) throw new Error('miss'); return m[0];};
const src=[g(/function delta\(j\)\{[\s\S]*?\n  \}/), g(/const BAND_TARGET = \{[^}]*\};/), g(/function band\(j\)\{[\s\S]*?\n  \}/)].join('\n');
const B=(BL,j)=>new Function('BASELINE','j','\"use strict\";'+src+'return band(j);')(BL,j);
const t=[];
t.push(['80+ → 쉬움',       B(null,{score:88,quality:70,confidence:'높음'})==='쉬움']);
t.push(['60–79 → 적정',     B(null,{score:70,quality:60,confidence:'중간'})==='적정']);
t.push(['40–59 → 도전',     B(null,{score:45,quality:80,confidence:'중간'})==='도전']);
t.push(['<40 → 미달',       B(null,{score:35,quality:80,confidence:'중간'})==='미달']);
t.push(['확신낮음 보수화',   B(null,{score:88,quality:70,confidence:'낮음'})==='적정']);
t.push(['하드필터 미달 우선', B(null,{score:90,quality:80,confidence:'높음',qualfit:'미달'})==='미달']);
t.push(['재직자 하향은 안전카드 아님', B({quality:90},{score:88,quality:70,confidence:'높음'})==='적정']);
t.push(['재직자 보합은 안전카드 유지', B({quality:75},{score:88,quality:70,confidence:'높음'})==='쉬움']);
const bad=t.filter(x=>!x[1]).map(x=>x[0]);
if(bad.length){ console.error('FAILED: '+bad.join(', ')); process.exit(1); }
" 2>/dev/null; then ok "jd-discovery: 난이도 밴드 판정(확신 보수화·하드필터·재직자 특례)"; else no "난이도 밴드 판정이 동작하지 않음"; fi
grep -qiE '난이도 밴드' reference/evaluation.md && grep -qiE '권장 비중' reference/evaluation.md \
  && grep -qiE '한 밴드에만 몰아' reference/evaluation.md \
  && ok "evaluation §5.6-c: 난이도 밴드 + 지원 배분 규율" || no "evaluation 난이도 밴드 누락"
grep -qF "bandMixHTML" templates/jd-discovery.html && grep -qiE '몰아넣으면' templates/jd-discovery.html \
  && ok "jd-discovery: 배분 쏠림 경고 렌더" || no "배분 경고 미구현"
# (h6) TODAY 하드코딩 방지 — 치환 누락 시 브라우저 현재 날짜로 폴백하는가
# ★ 실측: 커밋된 템플릿의 TODAY가 이미 과거(2026-07-22/23)여서 D-day·만료가 조용히 틀렸다.
for T in templates/jd-discovery.html templates/application-tracker.html templates/roadmap.html; do
  if grep -qE "const TODAY = TODAY_PINNED \|\| new Date\(\)" "$T" && grep -qE "timeZone: 'Asia/Seoul'" "$T"; then
    ok "TODAY 자동 폴백: $(basename $T)"
  else no "TODAY가 하드코딩(치환 누락 시 과거 날짜로 계산): $(basename $T)"; fi
done
# (h7) 트래커도 마감일 검증·단계 정규화를 하는가 — 하류에서 무너지면 발굴보드 수정이 무의미
if node -e "
const fs=require('fs');const s=fs.readFileSync('templates/application-tracker.html','utf8');
const g=(re)=>{const m=s.match(re); if(!m) throw new Error('miss '+re); return m[0];};
const src=[/const STAGES = \[[^\]]*\];/, /function daysBetween\(a,b\)\{[^}]*\}/, /function dlOk\(a\)\{[^}]*\}/,
  /function ddayText\(a\)\{[\s\S]*?\n  \}/, /const STAGE_ALIAS = \{[\s\S]*?\};/,
  /function normStage\(a\)\{[\s\S]*?\n  \}/].map(g).join('\n');
const FIX='const TODAY='+JSON.stringify('2026-07-26')+';';
const R=(b)=>new Function('A','\"use strict\";'+FIX+src+b);
const dd=R('return ddayText(A);'), ns=R('return normStage(A);');
const t=[];
t.push(['미검증 마감 → D-day 금지', dd({deadline:'2099-01-01'}).unknown===true]);
t.push(['빈 마감 → NaN 금지', !/NaN/.test(dd({}).t)]);
t.push(['검증 마감 → D-day 계산', /^D-/.test(dd({deadline:'2099-01-01',dueVerified:true}).t)]);
t.push(['최종합격 → 최종 단계로 정규화', ns({stage:'최종합격'})==='최종']);
t.push(['불합격 → 직전 단계 유지', ns({stage:'불합격',lastStage:'서류합격'})==='서류합격']);
t.push(['정상 단계 보존', ns({stage:'1차면접'})==='1차면접']);
const bad=t.filter(x=>!x[1]).map(x=>x[0]);
if(bad.length){ console.error('FAILED: '+bad.join(', ')); process.exit(1); }
" 2>/dev/null; then ok "tracker: 마감 검증 + 전형단계 정규화(퍼널 붕괴 방지)"; else no "tracker: 마감 미검증/단계 어휘 불일치가 그대로 통과"; fi
# P8 문서 어휘가 트래커 STAGES와 어긋나지 않는가
if python3 - <<'PYEOF' 2>/dev/null
import re,sys,pathlib
tr=pathlib.Path('templates/application-tracker.html').read_text(encoding='utf-8')
st=set(re.findall(r"'([^']+)'", re.search(r"const STAGES = \[([^\]]*)\]", tr).group(1)))
doc=pathlib.Path('reference/portfolio-builder.md').read_text(encoding='utf-8')
m=re.search(r'전형 단계 파이프라인[^`]*`([^`]+)`', doc)
sys.exit(1 if not m else (0 if {x.strip() for x in m.group(1).split('→')} <= st else 1))
PYEOF
then ok "P8 전형단계 어휘 ⊆ 트래커 STAGES(퍼널 어휘 정합)"; else no "P8 전형단계 어휘가 트래커 STAGES에 없음"; fi
# (h4) 미검증 마감일이 D-day로 둔갑하지 않는가 — 실사용에서 11건 중 10건이 추정 날짜였다(날조 금지의 구멍)
if node -e "
const fs=require('fs');const s=fs.readFileSync('templates/jd-discovery.html','utf8');
const g=(re)=>{const m=s.match(re); if(!m) throw new Error('miss'); return m[0];};
const src=[/function daysTo\(d\)\{[^}]*\}/, /function dlOk\(j\)\{[^}]*\}/,
  /function dday\(j\)\{[\s\S]*?\n  \}/, /function expired\(j\)\{[^}]*\}/,
  /function delta\(j\)\{[\s\S]*?\n  \}/, /function guardReason\(j\)\{[\s\S]*?\n  \}/,
  /function quadrant\(fit, qual\)\{[\s\S]*?\n  \}/, /function quadLabel\(j\)\{[\s\S]*?\n  \}/].map(g).join('\n');
const FIX='const TODAY='+JSON.stringify('2026-07-26')+';';
const F=(body)=>new Function('BASELINE','J','\"use strict\";'+FIX+src+body);
const dd=(j)=>F('return dday(J);')(null,j);
const ex=(j)=>F('return expired(J);')(null,j);
const ql=(j)=>F('return quadLabel(J);')(null,j);
const t=[];
// 미검증 날짜: D-day 만들지 않고, 만료로도 단정하지 않는다
t.push(['미검증→D-day 금지', dd({deadline:'2099-01-01'}).unknown===true && !/^D-/.test(dd({deadline:'2099-01-01'}).t)]);
t.push(['미검증 과거날짜→만료 단정 금지', ex({deadline:'2000-01-01'})===false]);
t.push(['미검증→최우선 승격 차단', ql({score:90,quality:90,confidence:'높음',deadline:'2099-01-01'})!=='최우선']);
// 검증된 날짜는 정상 동작
t.push(['검증→D-day 계산', /^D-/.test(dd({deadline:'2099-01-01',dlVerified:true}).t)]);
t.push(['검증 과거→만료',   ex({deadline:'2000-01-01',dlVerified:true})===true]);
t.push(['검증→최우선 허용', ql({score:90,quality:90,confidence:'높음',deadline:'2099-01-01',dlVerified:true})==='최우선']);
// status:'만료'는 날짜 없이도 만료
t.push(['status 만료 존중', ex({status:'만료'})===true]);
const bad=t.filter(x=>!x[1]).map(x=>x[0]);
if(bad.length){ console.error('FAILED: '+bad.join(', ')); process.exit(1); }
" 2>/dev/null; then ok "jd-discovery: 미검증 마감일→D-day/만료 단정 금지(추정 날짜 차단)"; else no "미검증 마감일이 확정 날짜처럼 렌더됨"; fi
grep -qiE '마감일을 추정으로 채우지 않는다' reference/jd-browsing.md \
  && ok "jd-browsing §2-(2-c): 마감일 추정 금지 명문화" || no "마감일 추정 금지 규칙 누락"
# (h2) 커버리지 원장이 '미실행'을 실제로 노출하는가 — 조용한 누락 방지(규칙만으로는 두 번 실패했다)
if node -e "
const fs=require('fs');const s=fs.readFileSync('templates/jd-discovery.html','utf8');
const m=s.match(/function coverageHTML\(\)\{[\s\S]*?\n  \}/); if(!m) process.exit(2);
const esc=(x)=>String(x==null?'':x);
const run=(COVERAGE)=>{ let out=''; const el={set innerHTML(v){out=v;}};
  const f=new Function('COVERAGE','document','escHtml','escAttr','\"use strict\";'+m[0]+'coverageHTML();');
  f(COVERAGE,{getElementById:()=>el},esc,esc); return out; };
const miss=run([{axis:'ZZAXIS',detail:'d',ran:false,found:0}]);
// 경고 배너를 제거한 뒤에도 '칩 자체'가 미실행을 표시해야 한다(배너 하나로 두 검사를 통과시키지 않기 위함)
const chipOnly=miss.replace(/<span class=\"cvwarn\">[\s\S]*?<\/span>/g,'');
const t=[];
t.push(['미실행 칩 라벨', chipOnly.includes('ZZAXIS') && chipOnly.includes('미실행')]);
t.push(['미실행 칩 off클래스', chipOnly.includes('cv off')]);
t.push(['미실행 경고 배너',   miss.includes('완전하지 않')]);
t.push(['전부 실행시 경고없음', !run([{axis:'a',detail:'d',ran:true,found:3}]).includes('완전하지 않')]);
t.push(['실행 축은 건수 표시', run([{axis:'a',detail:'d',ran:true,found:3}]).includes('3건')]);
t.push(['원장 자체 부재도 경고', run([]).includes('커버리지 원장 없음')]);
const bad=t.filter(x=>!x[1]).map(x=>x[0]);
if(bad.length){ console.error('FAILED: '+bad.join(', ')); process.exit(1); }
" 2>/dev/null; then ok "jd-discovery: 커버리지 원장이 미실행 축을 노출(조용한 누락 방지)"; else no "커버리지 원장이 미실행을 숨김"; fi
# (h5) 헤더 조작 금지선 — SPA 데이터경로 조항이 우회의 빌미가 되지 않는가 (안전 회귀)
if grep -qiE '헤더 조작 금지선' reference/jd-browsing.md \
   && grep -qiE '차단당하면 (그것으로 )?종료' reference/jd-browsing.md \
   && grep -qiE 'X-Requested-With' reference/jd-browsing.md \
   && grep -qiE '위조방지 토큰|antiforgery|CSRF' reference/jd-browsing.md \
   && grep -qiE '레이트리밋을 (피하지|회피)' reference/jd-browsing.md \
   && grep -qiE '헤더 조작 금지선' SKILL.md; then
  ok "안전: 헤더 조작 금지선(차단 후 재시도 금지) — 문서·SKILL 양쪽 명시"
else no "SPA 데이터경로 조항에 우회 금지선이 없음(헤더 위조로 미끄러질 수 있음)"; fi
# 금지선이 §0 원칙에도 있어야 한다(문서 앞부분만 읽어도 새지 않게)
awk '/^## 0\. 원칙/,/^## 1\./' reference/jd-browsing.md | grep -qiE '차단당하면 종료' \
  && ok "안전: §0 원칙에도 차단-종료 규칙 존재" || no "§0 원칙에 차단-종료 규칙 없음"
# (h3) SPA 데이터 경로 폴백 + 첨부·분리된 직무목록 회수 + 직무명 사전
grep -qiE '데이터 경로 직접 조회' reference/jd-browsing.md \
  && grep -qiE 'POST form-urlencoded|form-urlencoded' reference/jd-browsing.md \
  && grep -qiE '우회가 아니다' reference/jd-browsing.md \
  && ok "jd-browsing §1-(2): SPA 데이터 경로 폴백(+우회 경계 명시)" || no "SPA 폴백 단계 누락"
grep -qiE 'addFiles|첨부파일 목록을 반드시' reference/jd-browsing.md \
  && grep -qiE '직무 목록이 별도 사이트' reference/jd-browsing.md \
  && ok "jd-browsing §1-(2-b): 첨부·분리 직무목록 회수 의무" || no "부속 데이터 회수 규칙 누락"
grep -qiE '직무명 사전' reference/jd-browsing.md && grep -qiE '설비기술' reference/jd-browsing.md \
  && grep -qiE '커버리지 원장' reference/jd-browsing.md \
  && ok "jd-browsing §2: 직무명 사전 + 커버리지 원장" || no "직무명 사전/원장 누락"
# (j) 취득 실패 taxonomy + 폴백 사다리 + 첨부 PDF 회수 경로
grep -qiE 'G 게이트' reference/jd-browsing.md && grep -qiE 'R 미렌더' reference/jd-browsing.md \
  && grep -qiE 'M 오조준' reference/jd-browsing.md && grep -qiE '폴백 사다리' reference/jd-browsing.md \
  && grep -qiE 'PyMuPDF|텍스트 레이어' reference/jd-browsing.md \
  && ok "jd-browsing §1: 취득실패 유형분류·폴백사다리·첨부PDF 회수" || no "jd-browsing 취득실패 구조"
# (k) 신선도 게이트 · 기준선 · 발굴 수율→채널전환
grep -qiE '신선도 게이트' reference/jd-browsing.md && grep -qiE '기준선' reference/jd-browsing.md \
  && grep -qiE '이 채널에 없다' reference/jd-browsing.md \
  && ok "jd-browsing §2: 신선도·기준선·수율 채널전환" || no "jd-browsing 발굴 규율"
grep -qiE '발굴 수율' reference/job-search-ops.md && grep -qiE '이 채널에 없다' reference/job-search-ops.md \
  && ok "job-search-ops §2-b: 지원 이전 단계 병목(발굴 수율)" || no "job-search-ops 발굴 수율"
grep -qiE '자격 정합' reference/evaluation.md && grep -qiE '오버스펙|오버' reference/evaluation.md \
  && grep -qiE '기준선 델타|Δ' reference/evaluation.md \
  && ok "evaluation §5.6-b·§5.8-c: 자격 정합 3상태 + 기준선 Δ" || no "evaluation 자격/기준선"
# (g) 무게중심 축이 직무군별로 보편화됐는가(비테크 40% 가중 축 부재 방지)
grep -qiE '직무군별 축 라이브러리' reference/methodology.md && grep -qiE '영업|디자인|금융' reference/methodology.md \
  && ok "methodology: 직무군별 무게중심 축 라이브러리(비테크 포함)" || no "methodology axis library"
# 좋은 곳 취업 — 직장 품질 2축 · 적신호 · 점수 정확도 · 퍼널/캘리브레이션
grep -qiE '직장 품질 루브릭' reference/evaluation.md && grep -qiE '적신호 스크리닝' reference/evaluation.md \
  && grep -qiE '2축 배치|4분면' reference/evaluation.md \
  && ok "evaluation §5.8: 직장 품질 5축 + 적신호 + 2축 배치(단일총점 금지)" || no "evaluation 5.8"
grep -qiE '점수 정확도 규율' reference/evaluation.md && grep -qiE '세분화 금지|허위 정밀도' reference/evaluation.md \
  && grep -qiE 'What-if|민감도' reference/evaluation.md \
  && ok "evaluation §5.9: 근거인용·오차/확신도·What-if(세분화 금지)" || no "evaluation 5.9"
grep -qiE '퍼널 병목 진단' reference/job-search-ops.md && grep -qiE '캘리브레이션' reference/job-search-ops.md \
  && grep -qiE '채널 믹스' reference/job-search-ops.md && grep -qiE '표본' reference/job-search-ops.md \
  && ok "job-search-ops: 퍼널 병목·채널믹스·캘리브레이션·표본 규율" || no "job-search-ops content"
grep -qF "job-search-ops.md" SKILL.md && grep -qiE '5\.8|직장 품질' SKILL.md \
  && ok "SKILL: 2축 판정 + 구직 운영 배선" || no "SKILL quality/ops wiring"
grep -qiE '직장 품질' templates/jd-discovery.html && grep -qiE '최우선|4분면|quadrant' templates/jd-discovery.html \
  && grep -qiE '적신호|flags' templates/jd-discovery.html \
  && ok "jd-discovery: 2축(적합도×품질)·4분면·적신호 배지" || no "jd-discovery 2-axis"
grep -qiE '퍼널 진단' templates/application-tracker.html && grep -qiE 'MIN_SAMPLE|표본 부족' templates/application-tracker.html \
  && grep -qiE '병목' templates/application-tracker.html \
  && ok "tracker: 퍼널 전환율 + 병목 판정 + 표본 규율" || no "tracker funnel"
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
# Phase D: 경력자 패스트레인 + 능동 트래커 + 연차 캘리브레이션
grep -qiE 'P0\.5|문서 인제스트' reference/portfolio-builder.md && ok "portfolio: P0.5 문서 인제스트(폼 건너뜀)" || no "portfolio P0.5"
grep -qiE '관심|적합도|마감임박' templates/application-tracker.html && grep -qiE 'urgent|미지원' templates/application-tracker.html && ok "tracker: 관심·적합도·마감임박 콕핏" || no "tracker cockpit"
grep -qiE '아키타입별 3종|매니지먼트/직급' SKILL.md && grep -qiE '아키타입별 3종|부업 수익화 서사' reference/methodology.md && ok "roadmap: Phase 아키타입 3종 분기" || no "roadmap archetype split"
grep -qiE '연차 캘리브레이션' reference/evaluation.md && ok "evaluation: 연차 캘리브레이션 밴드" || no "evaluation seniority"
grep -qiE '카운터오퍼|역제안' SKILL.md && ok "SKILL ⑥ 카운터오퍼 대응" || no "counter-offer"
# Phase E: 미션 완결 오버레이 (§6.1)
grep -qiE '조건부 오버레이|6\.1' SKILL.md && grep -qiE '전형 관문|콜드스타트' SKILL.md && grep -qiE '지원 제출|해외취업' SKILL.md && grep -qiE '탈락|리퍼럴' SKILL.md && ok "SKILL §6.1 완결성 오버레이(관문·직무탐색·공백기·리퍼럴·제출·해외·오퍼후·탈락)" || no "SKILL 6.1 overlays"
grep -qiE 'claim-audit|재-그라운딩' SKILL.md && grep -qF "session-state" SKILL.md && ok "SKILL: claim-audit + 세션 핸드오프 배선" || no "SKILL anti-drift/handoff"

echo "== A4 print fidelity =="
if python3 scripts/check_a4.py samples/sample-resume.html /tmp/_smoke_a4.pdf >/tmp/_smoke_a4.log 2>&1 && grep -q 'RESULT: PASS' /tmp/_smoke_a4.log; then
  ok "A4 sample prints clean (A4, no overflow)"; else no "A4 print check (sample)"; fi
if python3 scripts/check_a4.py templates/a4-doc.html /tmp/_smoke_a4b.pdf >/tmp/_smoke_a4b.log 2>&1 && grep -q 'RESULT: PASS' /tmp/_smoke_a4b.log; then
  ok "A4 editorial template prints clean (A4, no overflow)"; else no "A4 print check (a4-doc)"; fi
# 인쇄 버튼을 노출하는 나머지 템플릿도 A4 규격인지(US Letter로 나가지 않게)
for pt in templates/report.html templates/interview-prep.html templates/resume-ats.html templates/cover-letter.html; do
  if python3 scripts/check_a4.py "$pt" "/tmp/_smoke_$(basename "$pt" .html).pdf" >"/tmp/_smoke_$(basename "$pt" .html).log" 2>&1 \
     && grep -q 'RESULT: PASS' "/tmp/_smoke_$(basename "$pt" .html).log"; then
    ok "A4 print: $(basename "$pt")"; else no "A4 print: $(basename "$pt")"; fi
done
# 제출-안전 회귀: a4-doc을 work-mode 강제 ON으로 인쇄해도 작업용 메모가 PDF에 없어야 함
if command -v python3 >/dev/null && ls /opt/pw-browsers/chromium-*/chrome-linux/chrome >/dev/null 2>&1; then
  python3 - <<'PY' >/tmp/_smoke_safe.log 2>&1 && ok "제출 안전 회귀: work-mode 인쇄에도 작업메모 미노출" || no "제출 안전 회귀 실패(작업메모 유출)"
import glob,subprocess,tempfile,pathlib,sys
try: import fitz
except ImportError: sys.exit(0)   # PyMuPDF 없으면 스킵(다른 게이트가 커버)
ch=glob.glob('/opt/pw-browsers/chromium-*/chrome-linux/chrome')[0]
d=tempfile.mkdtemp(); s=pathlib.Path('templates/a4-doc.html').read_text()
h=pathlib.Path(d+'/w.html'); h.write_text(s.replace('</body>','<script>document.body.classList.add("work-mode")</script></body>'))
subprocess.run([ch,'--headless','--disable-gpu','--no-sandbox','--no-pdf-header-footer',
  f'--print-to-pdf={d}/w.pdf', f'file://{h}'], check=True, capture_output=True)
t=''.join(p.get_text() for p in fitz.open(d+'/w.pdf'))
sys.exit(1 if ('자기평가' in t or '평가 메모' in t or '면접 근거 메모' in t) else 0)
PY
fi

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
# 로드 가능성 실질 검증: marketplace의 source가 실제 스킬 정의(루트 SKILL.md 또는 skills/)를 가리키는가
python3 - <<'PY' 2>/dev/null && ok "plugin loadable: marketplace source → 실제 스킬 정의 존재" || no "plugin source가 스킬 정의를 못 가리킴"
import json, os, sys
mk=json.load(open('.claude-plugin/marketplace.json'))
p=[x for x in mk['plugins'] if x.get('name')=='career'][0]
src=p.get('source', './')
base=src if isinstance(src,str) else src.get('path','./')
base=os.path.normpath(os.path.join('.', base.lstrip('./') or '.'))
sys.exit(0 if (os.path.isfile(os.path.join(base,'SKILL.md')) or os.path.isdir(os.path.join(base,'skills'))) else 1)
PY
# single-skill shortcut: SKILL.md at plugin root
[ -f SKILL.md ] && ok "single-skill shortcut: SKILL.md at plugin root" || no "SKILL.md not at root"

echo ""
echo "== SUMMARY: $pass passed, $fail failed =="
[ "$fail" -eq 0 ] && { echo "SMOKE: PASS"; exit 0; } || { echo "SMOKE: FAIL"; exit 1; }
