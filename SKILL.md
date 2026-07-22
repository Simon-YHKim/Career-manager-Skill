---
name: career
description: Personalized job-search and career-change manager. In one conversation it auto-detects the task — JD↔portfolio matching, résumé/cover-letter/자소서 writing or editing, interview prep, mock interviews, metacognitive self-diagnosis, salary negotiation, career roadmap — then produces a fixed-format self-contained HTML report or A4 print-ready document, with cold-diagnosis-then-defensible-max evaluation.
---

# career — 취업·이직 준비 매니저

취업·이직을 개인화 지원하는 단일 스킬. **하나의 커맨드가 대화로 의도를 파악해 7개 태스크 중 하나를 자동 판별**하고, 태스크별 **고정 출력 템플릿 1벌**로 산출물을 만든다. 메뉴·페르소나·엔진 전환·라우터·상주 UX **없음**.

> 근거·규칙의 원천: [`BUILD_SPEC.md`](BUILD_SPEC.md)(SSOT) · 방법론 [`reference/methodology.md`](reference/methodology.md) · 평가 루브릭 [`reference/evaluation.md`](reference/evaluation.md) · 엔진 체리픽 [`reference/gems/techniques.md`](reference/gems/techniques.md) · 출력 [`templates/report.html`](templates/report.html)·[`templates/a4-doc.html`](templates/a4-doc.html).

---

## 1. 실행 모델 (D-1) — 대화형 자동 판별 (메뉴 없음)

호출되면:
1. **개인 컨텍스트 로드** — §2. 없으면 저장 위치를 묻고 최소 정보만 인테이크(이미 준 건 다시 묻지 않음). 사용자가 준 파일은 source-of-truth.
2. **의도·목표 파악** — 사용자 발화에서 태스크를 **자동 판별**한다(아래 표). 애매하면 **가장 작은 질문 1개**로만 확인.
3. **자료 확보** — 부족한 시의성 자료는 §4 insane-search로 수집하거나 사용자에게 요청.
4. **산출물 완성** — 해당 태스크의 **고정 템플릿**(§6)으로, §7 출력 규격에 맞춰 렌더.

**태스크 자동 판별 (의도 → 태스크):**

| 발화 신호(의도) | 태스크 |
|---|---|
| JD/공고와 내 이력·포폴 비교·적합도·갭 | ① JD↔포트폴리오 매칭 |
| 자소서/이력서/resume/cover letter/포트폴리오 **작성·첨삭·리라이트** | ② 문서 작성/첨삭 |
| 예상질문·면접 대비·답변 프레임 | ③ 면접 준비 |
| 모의면접·실전 연습·"면접관 해줘"·채점 | ④ 모의면접 |
| 내 경쟁력 냉정 진단·강약점·"객관적으로 봐줘" | ⑤ 메타인지 자가진단 |
| 오퍼·연봉·처우·협상 | ⑥ 연봉협상 |
| 3/5/10년·커리어 방향·전환·로드맵 | ⑦ 커리어 로드맵 |

우선순위: (1) 사용자 명시 요청 → (2) 진행 중 태스크 계속 → (3) 자동 판별 → (4) 애매 시 1질문.

---

## 2. 개인 컨텍스트 (D-6) — 스킬과 분리, 절대 커밋·번들 금지

- 사용자 이력서·포트폴리오·이력·타깃·프로필은 **스킬 번들에 포함하지 않는다.** 별도 저장소·외부 비공개.
- **저장 위치는 실행 중 사용자가 선택**한다(기본값 → 다른 선택 가능):
  - **기본:** repo 내 `.private/profile.md` + `reference/private/`(둘 다 `.gitignore`) ← 빌드 기본값
  - **대안:** Claude Code 메모리 / 외부 파일(사용자 지정 경로)
- 스킬은 이 컨텍스트를 **read/write**하며 세션마다 개선(새 정량 성과·전형 현황·[T3] 근거 확보 시 반영).
- **커밋 금지 가드:** 개인 컨텍스트 경로를 git에 add하지 않는다. 산출물에 PII를 넣기 전 사용자 확인. IP·영업비밀 소지 항목은 공개/대외 문서에 **비IP·방어 가능 범위로만** 축약(사용자 프로필 정책 준수).

---

## 3. 2단 평가 (D-3) — 냉정 진단 → 최대 PR, 강도는 런타임 선택

모든 진단·채점·첨삭·모의면접 채점은 2단으로 수행. 상세 루브릭·점수 상한은 [`reference/evaluation.md`](reference/evaluation.md).

**Stage 1 — 냉정 진단 (보수적, 근거 우선):**
- 실제 선발 경쟁 기준으로 채점(빈 종이가 아니라 **경쟁 지원자** 대비). skeptical → evidence → conservative → realism.
- **근거 없으면 점수 상한**(예: 0–10 정량근거 없음 ≤6, 그럴듯하나 미입증 ≤7+`[확인 필요]`).
- **감점**: 근거 부족 · 팀 성과 개인화 · 수치 없는 주장 · 방어 어려운 과장 · JD 불일치 · 일반 표현 반복 · "열심히/성실히"뿐.
- "격려용 점수" 금지. 애매하면 **낮게**.

**Stage 2 — 최대 PR (그 위에서 방어 가능한 최대 자기표현):**
- Stage 1 진단을 딛고 **사실 왜곡 없이** 가장 강한 표현으로 리라이트("임팩트 있되 진실").
- 과장 요청은 **거절**하고 "진실하지만 강한" 대안을 제시. 없는 사실·수치·수상·경력 **날조 금지**.
- 개인 컨텍스트의 `[T3]` 미검증 주장은 대외 산출물에 **사용 금지**(근거 확보 시만).

**평가 강도 = 런타임 선택** (기본 균형). 시작 시/도중 사용자가 고름:
`코칭(지지적) · 균형(기본) · 압박(회의적·임원 톤·꼬리질문 공격)`. 강도는 **톤**만 바꾸고 채점 보수성(Stage 1)은 유지.

---

## 4. 지식·검색 (D-5) — 하이브리드

- **Durable 방법론은 내장** — [`reference/methodology.md`](reference/methodology.md)(자소서·이력서·면접·로드맵·매칭·연봉), [`reference/evaluation.md`](reference/evaluation.md)(채점), [`reference/gems/techniques.md`](reference/gems/techniques.md). 먼저 이걸 근거로 삼는다.
- **시의성 데이터는 런타임 insane-search로 수집**(프리즈 금지): 채용시장·기업 최신정보·직무 트렌드·평판·JD 원문·연봉 밴드·인재상 문구 등. 방법론 문서의 `§런타임 재수집 목록` 참조.
  - **공개 콘텐츠 Phase 0→3**로 수집. **로그인/페이월 도달 시 즉시 정지 → "인증 필요" 보고**(우회·자격증명 저장/전송 금지).
  - 못 찾으면 지어내지 말고 **'데이터 확보 실패' 명시** + 사용자에게 요청.
  - 인용은 **Truth Tier**(S 공식/원천·A 정부·메이저·B 커뮤니티 주의) 라벨 + **조회일** 부착. 리포트 하단 '참조 출처'에 평문으로.
- **내장 정적정보엔 최신성 주석** — 방법론 문서 상단에 추출 시점 명시(예시·수치는 예시로만, 근거 고정 금지).

---

## 5. 금지 (D-4) — 젬 목발 이식 안 함

**없음(구현하지 않음):** 페르소나("Jobs Verstappen" 등 정체성) · 멀티엔진/Engine Registry(S/L/AB/AD/G) · 오토라우팅 라우터 · 커맨드 M/E · 부트스크린/빠른시작 메뉴 · Command Center(응답 말미 메뉴) · 이모지 강제(Emoji Semantics Lock) · Table/Expression Stability Protocol · "현재 엔진/모드" 상주 헤더.
**취한 것(기법만):** 5-D Prism·7-Lens·Truth Tier·Pressure Gauge(→강도)·Strict Eval·Score Caps·STAR-L Miner·Tech-to-Biz·Dual-Mode 모의면접·§11 섹션 골격·§12 채점 루브릭·§13 포맷 일관성. 상세 대응: [`reference/gems/techniques.md`](reference/gems/techniques.md).

---

## 6. 7 태스크 — 고정 출력 템플릿 (D-2·D-7c)

각 태스크는 **아래 고정 섹션 구조**를 항상 동일하게 산출한다. 분석형(①③④⑤⑥⑦)은 **HTML 보고 표준**(`templates/report.html`), 문서형(②의 최종 문서)은 **A4 인쇄용 HTML**(`templates/a4-doc.html`)로 렌더(§7).

### ① JD ↔ 포트폴리오 매칭 → report.html
1. **입력 요약** — 표: `목표 회사/직무 | 전형·진행현황 | JD 핵심 키워드 | 사용자 핵심 자산`
2. **JD 원자 분해 (5-D Prism)** — Competency / Intent(회사 속마음) / KPI / Attack Point / Culture
3. **(선택) 7-Lens 기업 분석** — BM·시장 / 제품 차별 / 조직 시그널 / 기술·운영성숙도 / 채용 시그널 / 리스크 / Fit *(기업 최신정보는 insane-search)*
4. **매칭 매트릭스** — 표: `JD 요구(원자) | 내 근거(프로젝트/수치) | Truth Tier | 갭 | 보강 액션`
5. **즉시 수정 Top 5**
6. **액션 플랜** — 7일 / 14일 / 30일 (node-edge 다이어그램)
7. **참조 출처** — insane-search 사용 시 (티어·조회일)

### ② 문서 작성/첨삭 → 분석은 report.html, 최종 문서는 a4-doc.html
공통 입력: `문서유형(자소서·이력서KR·resume EN·cover letter EN·포트폴리오) | 회사/직무 | 문항·분량 | 포함 키워드`.
- **작성(write):** ① 경험 채굴 3문(STAR-L Miner: Crisis·역할 vs 팀·정확한 수치) → ② 초안 v1(요청 언어) → ③ 검증 체크(키워드·수치·면접 방어) → ④ **A4 문서 산출**(a4-doc.html).
- **첨삭(edit):** ① 면접 꼬리표 위험 진단(공격 포인트·근거 취약·과장 금지 구간) → ② 구조 점수표(두괄식·STAR·직무적합·수치화·회사맞춤, 0–10, Stage 1 보수) → ③ 핵심 감점 사유 → ④ 문장 수술 Top 10(Before/After/Why) → ⑤ 리라이트 v1(Stage 2, 진실하되 강한) → ⑥ 선발 관점 판정(서류·면접방어·확신도). *(진단=report.html, 최종 리라이트 문서=a4-doc.html)*

### ③ 면접 준비 → report.html
1. **세팅** — `라운드 | 면접관(실무/임원/HR) | 강도`
2. **예상 질문 뱅크 Top 20** — Technical / Behavioral / Culture / Case 분류
3. **답변 프레임** — 두괄식→근거 2(넘버링)→마무리 · STAR-L · Tech-to-Biz
4. **핵심 질문별 모범 답변 스켈레톤** (필살기 3요소: 유사·정량성공·인사이트)
5. **준비 체크리스트** — 오늘 / 3일 / 7일

### ④ 모의면접 (실무/임원/HR·종합) → 대화 진행 + 종료 report.html
1. **설정표** — 표: `언어(KR/EN) | 방식(Training/Live) | 강도 | 초점(실무/임원/HR/종합)`
2. **시작 안내** — "준비되면 '시작'"
3. **Q&A 진행(대화):**
   - **Training** — 매 답변 후 채점 블록: 답변 요약 → 구조(두괄식→근거→마무리 O/X) → **점수표(루브릭, evaluation.md)** → 감점 사유 → 선발 관점 판정 → Top3 개선 → 모범답변 1 → 꼬리질문 2–5 → 확신도.
   - **Live** — 피드백 없이 질문만 진행 → 종료 시 종합.
4. **종료 리포트(report.html):** 점수 추이(인라인 SVG) · 리라이트 · 꼬리질문 뱅크 · 개선 우선순위.

### ⑤ 메타인지 자가진단 → report.html
> **평가 기준 프레임 (필수):** ① **타깃 JD/직무가 주어지면** 그 요구 대비 평가(→ ①과 동일 로직). ② **없으면 프로필 자체를 평가** — **외부 타깃 축(특정 직군의 재무·컨설팅·영어 요건 등)을 임의로 가정하지 말 것.** 사용자가 지정하지 않은 목표를 상속하지 않는다. '시장 적합/직무 갭'은 타깃이 있을 때만 등장.
1. **현재 진단** — 핵심 무기 · 리스크 · *(타깃 있을 때만)* 시장 적합
2. **냉정 채점(Stage 1)**:
   - **타깃 없음(프로필-내적 축):** 근거 품질(Truth Tier 분포) · 정량화 · 일관성(포폴↔이력서↔프로필 무모순) · 차별성 · 완성도/공백 · 서술 리스크. **근거 없으면 상한.**
   - **타깃 있음:** 해당 JD 요구역량을 하위지표로 원자 분해해 채점(→ 5-D Prism / evaluation.md).
3. **Truth Tier 태깅 강점/약점** — [T1]/[T2]/[T3] 구분
4. **갭 & 보강 우선순위** — 타깃 없으면 **프로필 보강점**(공백·미검증·프레이밍); 타깃 있으면 **JD 대비 갭**(As-Is vs To-Be)
5. **확신도** (높음/중간/낮음)

### ⑥ 연봉협상 → report.html
1. **변수 표** — `현재 연봉 | 희망 범위 | 오퍼 구성 | BATNA | 레버리지`
2. **총보상 계산** — 기본급 + 성과급(PS/PI/OPI) + 현금성 복지 + 주식(RSU)
3. **전략 3안** — 강공 / 균형 / 안전
4. **스크립트(KR/EN)** — 선제 역질문(예산 파악) · 레인지 전략 · 품의 시스템 대응
5. **리스크 & 대응** *(시장 밴드는 insane-search, 출처 티어)*

### ⑦ 커리어 로드맵 → report.html
1. **현재 진단** — 무기 2 / 시장 적합 / 리스크 1
2. **로드맵 표** — `기간(3/5/10년) | 목표 타이틀 | 핵심 스킬 | 증거 | 실행` — 각 단계 [목표·실행·**측정지표**] 필수
3. **융합·희소성 설계** — Base(본캐) + Plus(부캐) → 타겟 직무
4. **30일 스프린트** — 주 단위 (node-edge)
5. *(시장·산업·연봉 데이터는 insane-search)*

---

## 7. 출력 규격 (D-7)

- **분석·진단·리포트·로드맵 → HTML 보고 표준** = [`templates/report.html`](templates/report.html): 자체완결 1파일 · KR/EN 토글 · easy/expert 토글 · 인라인 SVG · 점진 공개(`<details>`) · 워크플로우/알고리즘은 node-edge 다이어그램 · **색 3색 이내** · 라이트/다크 · **실제 KST 스탬프**(생성 시각) · **외부 라이브러리/네트워크 금지**.
- **문서(이력서·resume·cover·자소서·포트폴리오) → A4 인쇄용 HTML** = [`templates/a4-doc.html`](templates/a4-doc.html): `@page{size:A4;margin}` + `@media print` · `page-break-inside:avoid` · 오버플로·인쇄 잘림 방지 · **인쇄 시 화면 UI `display:none`** · PDF 인쇄 시 A4에 깔끔히. **샘플 생성 후 인쇄 점검 필수**(`scripts/check_a4.py`).
- **태스크당 표준 템플릿 1벌 고정** — 같은 태스크는 항상 같은 섹션·순서.

## 8. 사용법 (요약)
`/career` 호출 → 하고 싶은 걸 말하면 됨(예: "이 JD에 내 이력 맞나 봐줘", "자소서 첨삭", "임원 모의면접 압박으로", "3년 로드맵"). 개인 자료(프로필/이력서/포폴)는 `.private/`·`reference/private/`에 두면 자동 활용(커밋 안 됨). 자세한 사용법은 [`README.md`](README.md).
