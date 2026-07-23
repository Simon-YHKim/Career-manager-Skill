# Career-Prep Skill — Build Spec (v1)

> Claude Code가 **"취업·이직 준비 개인화 스킬"**을 빌드하기 위한 **단일 원천(SSOT)**.
> `GOAL_CONDITION.txt`의 `/goal` 완료조건이 이 파일의 구현 완료를 검증한다.
> **커맨드명은 빌드 중 사용자가 지정**한다.
> 대상: Claude Code + Opus 4.8. Gemini 'Jobs Verstappen' 커리어 OS의 **재구축**(포팅 아님).

---

## D-0. 목적

취업·이직 준비를 개인화 지원하는 Claude Code 스킬. 젬의 목발(멀티엔진·페르소나·상주 UX·렌더 안정성 프로토콜·퓨샷 과적재)은 버리고 → **단일 목적 + 점진 공개 + 개인 컨텍스트 분리**로 재설계.

## D-1. 실행 모델

스킬 호출 → **대화로 사용자 의도·목표 파악** → 부족한 자료는 스킬이 수집(JD Browsing)하거나 사용자에 요청 → **원하는 산출물 완성**. 단일 커맨드가 대화로 태스크를 자동 판별(메뉴·모드 스위칭 없음).

## D-2. 지원 태스크 (자동 판별 · 각 고정 출력 템플릿)

1. **JD ↔ 포트폴리오 매칭** — 5-D Prism 분해 + 매칭 매트릭스 + 갭·보강 액션
2. **문서 작성/첨삭** — 자기소개서 · 이력서(국문) · resume(영문) · cover letter(영문) · 포트폴리오 → **A4 인쇄용 HTML**(D-7b)
3. **면접 준비** — 예상질문 뱅크(Technical/Behavioral/Culture/Case) + 답변 프레임(두괄식→근거2→마무리, STAR-L)
4. **모의면접** — 실무/임원/HR, Training(턴별 채점) / Live(종료 후 리포트)
5. **메타인지 자가진단** — 냉정·근거우선 현 경쟁력 진단
6. **연봉협상** — 변수표 · BATNA · 전략 3안(강공/균형/안전) · 스크립트
7. **커리어 로드맵** — 3/5/10년, 현 진단 → 목표 → 스킬 → 증거 → 실행

## D-3. 평가 로직 (2단)

- **1단 냉정 진단(메타인지 강화)** — 실제 선발 경쟁 기준으로 보수 채점. 근거 없으면 점수 상한, 과장·팀성과 개인화·수치 없는 주장은 감점. "격려용 점수" 금지, 애매하면 낮게.
- **2단 최대 PR** — 그 진단 위에서 **방어 가능한 최대** 자기표현 산출물. 사실 왜곡 금지("임팩트 있되 진실"), 과장 요청은 거절하고 "진실하지만 강한" 리라이트 제시.
- **평가 강도(코칭 ↔ 압박·공격)는 실행 중 사용자 선택.**

## D-4. 방법론 모듈 / 프레임워크

`reference/gems/`(HR Process · Job&Process PDF, Jobs Verstappen 시스템프롬프트)에서 **채용 컨설턴트 방법론을 추출·압축** → `reference/methodology.md`. 원문 요약이 아니라 **실행 가능한 규칙 형태**로.

- 대상: 자기소개서 작성법 · 기업 면접 평가기준 · 이직 전문가 인사이트 · Resume Action Verbs · 영문 이력서 가이드 등.
- **프레임워크 체리픽만**: 5-D Prism(역량/의도/KPI/공격포인트/문화) · Truth Tier 태깅 · STAR-L · Tech-to-Biz.
- **넣지 말 것**: 페르소나(Loti/Ailey&Bailey/Ailey Debate) · 멀티엔진 · 라우터 · M/E 메뉴 · Command Center · 표/표현 안정성 프로토콜.
- 젬 시스템프롬프트의 **태스크 포맷(§11)·퓨샷(§13)은 출력 형식 일관성 소스로만** 참고 — 페르소나·엔진 UX는 제외.

## D-5. 지식·검색 (하이브리드)

- **durable 방법론**은 스킬에 내장.
- **시의성 데이터**(채용시장·기업·직무·평판·JD)는 프리즈 말고 런타임에 **JD Browsing**로 수집 — 공개 콘텐츠 Phase 0→3. **로그인/페이월에서 정지·"인증 필요" 보고, 자격증명 저장·전송 금지.**
- 내장 정적정보엔 **최신성 주석**(작성 시점) 부착, 빌드 시 A-Z 감사.

## D-6. 개인 컨텍스트 (스킬과 분리)

- 사용자 이력서·포트폴리오·이력·타깃은 **스킬 번들 금지**, 별도 저장소, 외부 비공개.
- **저장 위치는 실행 중 사용자 선택**: repo 내 private 폴더 + `.gitignore` / Claude Code 메모리 / 외부 파일.
- 스킬은 이를 read/write하며 **세션마다 개선**.
- IP·영업비밀성 자료는 저장소에 넣지 않음(사용자 판단).

## D-7. 출력 규격

**(a) 분석·진단·리포트·로드맵 → HTML 보고 표준**
자체완결 1파일 · KR/EN 토글 · easy/expert 토글 · 인라인 SVG · 점진 공개(`<details>`) · 워크플로우/알고리즘은 node-edge 다이어그램 · 색 3색 이내 · 라이트/다크 · 실제 KST 스탬프 · 외부 라이브러리/네트워크 금지.

**(b) 문서 산출물(이력서·resume·cover letter·자소서·포트폴리오) → A4 인쇄용 HTML**
- `@page { size: A4; margin: … }` + `@media print` CSS
- 블록 `page-break-inside: avoid`, 표/섹션 인쇄 잘림 방지
- 텍스트 밀림·오버플로·인쇄 잘림 방지(고정 폭·안전 여백)
- 인쇄 시 화면 전용 UI(토글/버튼) `display:none`
- **PDF로 인쇄하면 A4에 깔끔히 앉아야 함 — 샘플 생성 후 인쇄 점검 필수**

**(c)** 태스크별 출력 포맷은 **항상 동일 형식** — 태스크당 표준 템플릿 1벌 확정(젬 §11·§13 참고).

**(d) 입력 수집 → 표준 폼 HTML** (`templates/intake-form.html`)
- 사용자가 채워야 하는 값은 **동일한 양식**(HTML 폼)으로 제공해 작성을 용이하게 한다.
- 수집 항목: 타깃/모드 · 인적사항 · 타임라인(학력·병역, 년/월; 필요 시 일) · 경력 · 대표 경험(C·R·A·R·I·기여도·스택·증빙) · 자격/수상·스킬.
- **[데이터 복사]** → 구조화 텍스트를 스킬에 붙여넣어 마스터 경험 뱅크 구축. 자체완결, 외부 네트워크 금지.

**(e) 포트폴리오 빌더 = 기초 job** (`reference/portfolio-builder.md`, P0–P8)
- ②(문서 작성) 및 ①·④·⑤·⑦의 공통 근거인 **마스터 경험 뱅크**(`.private/experience-bank.md`)를 만들고 갱신한다.
- 작업용/제출용 토글, 문체 게이트(`reference/writing-voice.md`), KPI 5버킷+NCS, 방어 시뮬(2단 채점).
- **지원 히스토리**(`.private/applications/`) → 지원 현황 대시보드(`templates/application-tracker.html`, 자소설닷컴식 전형단계·D-day·결과·제출 파생본).

## D-8. 파일 구조

```
<repo>/
  BUILD_SPEC.md            ← 이 문서 (SSOT)
  GOAL_CONDITION.txt       ← /goal 완료조건
  SKILL.md                 ← name + description(≤50단어) + 본문
  reference/
    gems/                  ← 젬 시스템프롬프트 + 방법론 PDF
    private/               ← [gitignore] 실제 포트폴리오·이력서
    methodology.md         ← 추출·압축한 컨설턴트 방법론 모듈
    evaluation.md          ← 2단 평가 엔진 + 채점 루브릭
    portfolio-builder.md   ← 마스터 경험 뱅크 & 포폴 빌더 (P0–P8)
    writing-voice.md       ← 문체 게이트(AI-tell 제거) + 컨설턴트 문체
    jd-browsing.md         ← 내장 웹 리서치 모듈(구 insane-search 클론·개명)
  templates/
    report.html            ← HTML 보고 표준 템플릿
    a4-doc.html            ← A4 인쇄용 문서 템플릿(에디토리얼)
    resume-ats.html        ← ATS-세이프 단일컬럼 resume EN(기계 제출)
    intake-form.html       ← 표준 입력 폼 (데이터 복사)
    application-tracker.html ← 지원 현황 대시보드 (P8)
  .private/                ← [gitignore] 개인 컨텍스트
    profile.md             ←   보정 프로필
    experience-bank.md     ←   마스터 경험 뱅크 (SSOT)
    applications/          ←   지원 히스토리(건별 스냅샷)
  .gitignore               ← .private/ , reference/private/ , .env
  README.md
```

## D-9. 규율 · git · 보안

- 단일 목적·간결 유지. 잘못된 상호작용으로 방향 새지 않게.
- git/커밋/보안은 **사용자 전역 Claude Code 지침 준수**: Conventional Commits, 커밋 전 코드리뷰(버그·취약점), 시크릿 하드코딩 금지(`.env`/환경변수·gitignore), 파괴적 작업·force-push 전 확인.
- README·주석 최신화.

## D-10. 수용 기준 (= `GOAL_CONDITION.txt`와 일치)

D-8 파일 구조 + SKILL.md frontmatter 유효(name + description ≤50단어) + 7태스크 고정 템플릿 + 2단 평가(강도 런타임 선택) + 방법론 모듈 + 하이브리드 지식/JD Browsing + 개인 컨텍스트 분리(`.gitignore` 확인) + A4 인쇄 샘플 무오버플로 + 페르소나/라우터 없음 + README + 스모크 체크 통과 + Conventional Commits 푸시.

---

## 부록 A. 엔진 레퍼런스 체리픽 정책 (Claude 통합 시 유지 — 기존 BUILD_SPEC에서 이관)

- zip `04. 엔진 레퍼런스/`(Ailey&Bailey·Ailey Debate·Loti·Search Mode)는 **참고만**.
- **금지**: 페르소나·멀티엔진·라우터·메뉴·Command Center·안정성 프로토콜 이식.
- **허용**: 기법만 체리픽 — 예) 구조화된 반론/디베이트 기법 → 모의면접(D-2 #4) 압박 모드의 *기법*으로만(페르소나 없이); 검증·진실성 루프 → D-3 2단 평가. 상세·포팅 금지 목록: `reference/gems/techniques.md`.
- 구현 노트: 방법론 소스 PDF의 저장 위치(committed `reference/gems/` vs gitignored `reference/private/_sources/`)는 D-6(IP·영업비밀 저장소 배제)와의 정합을 위해 **사용자 결정 사항**(PRECHECK 참조).
