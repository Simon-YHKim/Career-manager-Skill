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
# (a) hub esc()가 진짜 이스케이프하는가 (no-op이면 저장형 XSS → 워커 토큰 유출)
if node -e "
const fs=require('fs');const s=fs.readFileSync('templates/hub.html','utf8');
const m=s.match(/function esc\(s\)\{[\s\S]*?\}/); if(!m){process.exit(2);}
const esc=new Function('return ('+m[0].replace('function esc','function')+')')();
process.exit(esc('<img src=x>').includes('&lt;') ? 0 : 1);
" 2>/dev/null; then ok "hub esc(): 실제 이스케이프(XSS 회귀 게이트)"; else no "hub esc() is a no-op → XSS 위험"; fi
# (b) worker provider: 서버 시크릿(env.AI_PROVIDER)이 클라이언트 body보다 우선하는가 (키 오전송 방지)
grep -qE 'env\.AI_PROVIDER\s*\|\|\s*b\.provider' worker/src/index.js \
  && ok "worker: provider 서버 시크릿 우선(키 오전송 방지)" || no "worker: client provider가 서버 시크릿을 이김"
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
const src=[/const TODAY = '[^']*';/, /function daysTo\(d\)\{[^}]*\}/, /function quadrant\(fit, qual\)\{[\s\S]*?\n  \}/,
  /function delta\(j\)\{[\s\S]*?\n  \}/, /function expired\(j\)\{[^}]*\}/,
  /function guardReason\(j\)\{[\s\S]*?\n  \}/, /function quadLabel\(j\)\{[\s\S]*?\n  \}/].map(grab).join('\n');
const base=(b)=>new Function('BASELINE','J','\"use strict\";'+src+'return quadLabel(J);');
const hi={score:90,quality:90,confidence:'높음',deadline:'2099-01-01'};
const t=[];
t.push(['정상 최우선', base()(null,hi)==='최우선']);
t.push(['만료 차단',   base()(null,Object.assign({},hi,{deadline:'2000-01-01'}))!=='최우선']);
t.push(['자사 차단',   base()(null,Object.assign({},hi,{self:true}))!=='최우선']);
t.push(['확신낮음 차단',base()(null,Object.assign({},hi,{confidence:'낮음'}))!=='최우선']);
t.push(['하향 차단',   base()({quality:95},hi)!=='최우선']);
t.push(['상향 통과',   base()({quality:60},hi)==='최우선']);
t.push(['기준선없음 Δ미적용', base()(null,hi)==='최우선']);
t.push(['다른분면 유지', base()(null,{score:40,quality:40,confidence:'높음',deadline:'2099-01-01'})==='후순위']);
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
