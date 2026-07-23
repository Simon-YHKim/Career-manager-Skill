# career — 취업·이직 준비 스킬

취업·이직을 개인화 지원하는 **Claude Code 스킬(플러그인)**. `/career` 하나를 호출하면 대화로 의도를
파악해 **7개 태스크 중 하나를 자동 판별**하고, 태스크별 **고정 템플릿**으로 산출물(자체완결 HTML 리포트 /
A4 인쇄용 문서)을 만든다. 메뉴·페르소나·엔진 전환·라우터·상주 UX **없음** — 단일 목적 + 점진 공개 +
개인 컨텍스트 분리.

> Gemini 'Jobs Verstappen' 커리어 OS를 Opus 4.8 + Claude Code에 맞게 **재구축**(포팅 아님).
> 사양 원본(SSOT): [`BUILD_SPEC.md`](./BUILD_SPEC.md) · 빌드 트리거: [`GOAL_CONDITION.txt`](./GOAL_CONDITION.txt).

## 설치

**A) 플러그인으로 설치** (`.claude-plugin/` 매니페스트 포함 — Claude Code에서):
```
/plugin marketplace add Simon-YHKim/Career-manager-Skill
/plugin install career@career-manager
/career
```
> 단일 스킬 shortcut으로 `SKILL.md`가 플러그인 루트에 있습니다. 개인 컨텍스트(`.private/`,
> `reference/private/`)와 젬 원본은 gitignore되어 **플러그인에 번들되지 않습니다**.

**B) 스킬로 직접 사용** (설치 없이): 이 repo를 `~/.claude/skills/career/`(또는 프로젝트
`.claude/skills/career/`)에 두면 `~/.claude/skills/career/SKILL.md` → `/career`로 호출.

## 사용법

1. **호출:** `/career`
2. **말하기:** 하고 싶은 걸 자연어로. 스킬이 태스크를 자동 판별한다(메뉴 없음).
   - "이 JD에 내 이력 맞는지 봐줘" → ① JD↔포트폴리오 매칭
   - "자소서 첨삭해줘" / "영문 resume 써줘" → ② 문서 작성/첨삭
   - "1차 실무면접 예상질문" → ③ 면접 준비
   - "임원 모의면접 압박 강도로" → ④ 모의면접
   - "내 경쟁력 냉정하게 진단해줘" → ⑤ 메타인지 자가진단
   - "오퍼 받았는데 연봉협상" → ⑥ 연봉협상
   - "3/5/10년 로드맵" → ⑦ 커리어 로드맵
3. **개인 자료:** 프로필·이력서·포폴을 `.private/profile.md`·`reference/private/`에 두면 자동 활용
   (둘 다 gitignore — **커밋 안 됨**). 저장 위치는 실행 중 바꿀 수 있다(D-6).
4. **평가 강도:** 코칭 / 균형(기본) / 압박 중 실행 중 선택.
5. **산출물:** 분석·리포트는 HTML 보고서, 문서(이력서 등)는 A4 인쇄용 HTML. 브라우저에서 열고
   인쇄→PDF로 A4에 깔끔히 앉는다.

## 포트폴리오 빌더 = 기초 job (P0–P8)
이 스킬의 토대는 **마스터 경험 뱅크**(`.private/experience-bank.md`) — 모든 경험을 한 번 정리해 두면
지원마다 재입력 없이 맞춤 문서를 파생한다. 처음 쓰는 사람의 순서:

1. **입력 폼** — [`templates/intake-form.html`](./templates/intake-form.html)을 열어 인적사항·타임라인(년/월)·경력·
   대표 경험(C·R·A·R·I)을 채우고 **[데이터 복사]** → 스킬 대화창에 붙여넣기. (비워도 됨 — 대화로 채움)
2. **경험 분류** — 필살기/빌살기/밉살기 + 해시태그(레벨·카테고리·KPI버킷·Truth Tier), 연차별 필살기 상한.
3. **포트폴리오화** — C·R·A·R·I + KPI 5버킷(효율·품질·규모·재무·직무특화)+런타임 KPI명 + NCS 앵커.
4. **문체 게이트** — AI 티 제거·컨설턴트 문체([`reference/writing-voice.md`](./reference/writing-voice.md)), 진지문서 이모지 금지, (선택) 낭독 STT 가독성 루프.
5. **방어 시뮬** — 2단 채점 + 전문가 면접관 꼬리질문 + PR강도 Lv1–3(날조 금지).
6. **출력** — 작업용/제출용 토글로 A4 문서(에디토리얼)·HTML 리포트.
7. **지속** — 뱅크 갱신([T3]→[T1] 승격 리마인드) + **지원 히스토리**([`templates/application-tracker.html`](./templates/application-tracker.html): 전형단계·D-day·결과·제출 파생본).

상세 확정본: [`reference/portfolio-builder.md`](./reference/portfolio-builder.md).

## 7 Tasks (D-2) — 두 트랙
**취업 실행 트랙**(특정 지원 건): ① JD↔포트폴리오 매칭 → ② 문서 작성/첨삭(자소서·이력서KR·resume·cover·포폴) → ③ 면접 준비 → ④ 모의면접(실무→임원→연봉) → ⑥ 연봉협상.
**커리어 성장 트랙**(장기 방향): ⑤ 메타인지 자가진단 ↔ ⑦ 커리어 로드맵.
> ⑦ 로드맵은 면접의 하위 단계가 아니라 발전용 — 산출물만 자소서 포부·임원 답변으로 재활용. 두 트랙은 마스터 경험 뱅크를 공유한다.

## 평가 (D-3)
2단 — ① 냉정 진단(보수 채점·근거 없으면 상한) → ② 최대 PR(방어 가능·진실). 강도 런타임 선택.
상세 루브릭: [`reference/evaluation.md`](./reference/evaluation.md).

## 지식 (D-5)
Durable 방법론 내장([`reference/methodology.md`](./reference/methodology.md)). 시의성 데이터(채용시장·기업·
JD·연봉)는 런타임 **JD Browsing**으로 수집(로그인/페이월 정지·"인증 필요" 보고·자격증명 저장 금지),
Truth Tier + 조회일 인용.

## Repo layout
```
BUILD_SPEC.md            사양 원본 SSOT (D-0~D-10)
GOAL_CONDITION.txt       /goal 빌드 완료조건
SKILL.md                 스킬 정의 (name: career + description + 7태스크 본문)
reference/
  methodology.md         컨설턴트 방법론 모듈 (5-D Prism·Truth Tier·STAR-L·Tech-to-Biz + 6섹션)
  evaluation.md          2단 평가 엔진 + 채점 루브릭
  portfolio-builder.md   마스터 경험 뱅크 & 포폴 빌더 (P0–P8)
  writing-voice.md       문체 게이트(AI-tell 제거) + 컨설턴트 문체 + Action Verbs
  jd-browsing.md         내장 웹 리서치 모듈(공고 발굴·기업·연봉·인재상; 게이트=추론+직접확인)
  linkedin.md            LinkedIn 필드 카탈로그 + 반영 2모드(복사 / computer-use 자동입력·게이트)
  handoff.md             세션 핸드오프(simon-handoff 최적화·PII는 .private/로 라우팅)
  gems/techniques.md     엔진 체리픽 기법 + 포팅 금지 목록
  gems/*  [gitignore]    젬 시스템프롬프트 원본(로컬)
  private/  [gitignore]  포폴·이력서·타깃·소스 PDF (PRIVATE)
templates/
  report.html            HTML 보고 표준 (D-7a)
  a4-doc.html            A4 인쇄용 문서 (D-7b, 에디토리얼·사람/포폴)
  resume-ats.html        ATS-세이프 단일컬럼 resume EN (기계 제출용)
  cover-letter.html      자소서 (문항+답변+글자수 카운터)
  linkedin-export.html   LinkedIn 전 필드 (섹션 선택·글자수·복사 + Fill Plan[computer-use])
  intake-form.html       표준 입력 폼 (D-7d, 데이터 복사)
  jd-discovery.html      공고 발굴 보드 (순위·적합도 점수·한줄요약·링크·위시리스트)
  roadmap.html           다중 경로 로드맵 보드 (⑦ 경로 추천·적합도·연차별 목표·선택)
  application-tracker.html 지원 현황 대시보드 (P8, 일정관리)
samples/sample-resume.html   A4 렌더 샘플(제네릭·PII 없음)
scripts/
  check_a4.py            A4 인쇄 검증 (chromium print→PDF + PyMuPDF)
  smoke_check.sh         구조·수용기준 스모크 체크
.private/  [gitignore]   개인 컨텍스트: profile.md · experience-bank.md · applications/
.gitignore               .private/ · reference/private/ · .env
```

## 개발/검증
```bash
bash scripts/smoke_check.sh            # 구조·수용기준 스모크 체크
python3 scripts/check_a4.py samples/sample-resume.html   # A4 인쇄 검증
```
필요 도구: 헤드리스 Chromium(사전설치) + PyMuPDF(`fitz`).

## Privacy (D-6)
`.private/`, `reference/private/`, 젬 원본은 **gitignore**되어 커밋·번들되지 않는다. 개인 이력서·포트폴리오·
프로필·타깃은 스킬 번들에 포함하지 않으며, IP·영업비밀 소지 항목은 대외 산출물에 비IP·방어 가능 범위로만 축약.
