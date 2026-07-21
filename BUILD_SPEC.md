# BUILD_SPEC — 취업·이직 스킬 플러그인

> 이 문서는 스킬의 **사양 원본(spec of record)**입니다. §D 스킬 스펙 전문 + §F /goal 완료조건을 담습니다.
> 프로젝트: 취업·이직 준비 개인화 Claude Code 스킬(플러그인). Gemini 'Jobs Verstappen' 커리어 OS를
> Opus 4.8 + Claude Code에 맞게 **재구축(포팅 아님)**. 젬 목발(멀티엔진·페르소나·상주 UX·렌더 안정성
> 프로토콜·퓨샷 과적재)은 버리고 **단일 목적 + 점진 공개 + 개인 컨텍스트 분리**로.
> 커맨드명은 빌드 중 사용자가 지정.
> 리포: github.com/Simon-YHKim/Career-manager-Skill

---

## §D 스킬 스펙 (BUILD_SPEC 전문)

### D-1 실행 모델
스킬 호출 → 대화로 의도·목표 파악 → 부족 자료는 스킬이 insane-search로 수집하거나 사용자에게 요청 →
산출물 완성. **단일 커맨드가 대화로 태스크를 자동 판별**(메뉴 없음).

### D-2 태스크 (자동 판별 · 각 고정 템플릿)
1. **JD ↔ 포트폴리오 매칭** — 5-D Prism + 매칭 매트릭스 + 갭·보강
2. **문서 작성/첨삭** — 자소서·이력서(국문)·resume(영문)·cover letter(영문)·포트폴리오
   → A4 인쇄용 HTML (D-7b)
3. **면접 준비** — 예상질문 뱅크 + 답변 프레임 STAR-L
4. **모의면접** — 실무/임원/HR (Training: 턴별 채점 / Live: 종료 리포트)
5. **메타인지 자가진단**
6. **연봉협상** — 변수표 + BATNA + 전략 3안 + 스크립트
7. **커리어 로드맵** — 3/5/10년

각 태스크당 **표준 출력 템플릿 1벌** 확정 (D-7c).

### D-3 평가 (2단)
1. **냉정 진단 (메타인지)** — 실제 선발 경쟁 기준으로 보수적 채점. 근거 없으면 점수 상한.
   과장·팀 성과 개인화·수치 없는 주장 감점. 애매하면 낮게.
2. **최대 PR** — 그 위에서 방어 가능한 최대 자기표현. 사실 왜곡 금지("임팩트 있되 진실").
   과장 요청 거절 → "진실하지만 강한" 리라이트.

평가 강도(코칭 ↔ 압박·공격)는 **실행 중 사용자가 선택**.

### D-4 방법론·프레임워크
HR/Job/엔진 PDF에서 컨설턴트 방법론 추출 → `reference/methodology.md`.
**체리픽만**: 5-D Prism(역량/의도/KPI/공격포인트/문화) · Truth Tier 태깅 · STAR-L · Tech-to-Biz.
**넣지 말 것**: 페르소나(Loti/Ailey&Bailey/Ailey Debate) · 멀티엔진 · 라우터 · 메뉴 ·
Command Center · 안정성 프로토콜.

### D-5 지식·검색 (하이브리드)
- **durable 방법론은 내장**.
- **시의성 데이터**(채용시장·기업·직무·평판·JD)는 프리즈하지 말고 **런타임에 insane-search로 수집**
  (공개 Phase 0→3, 로그인/페이월 정지 → "인증 필요" 보고, 자격증명 저장 금지).
- 내장 정적정보엔 **최신성 주석**, 빌드 시 A-Z 감사.

### D-6 개인 컨텍스트 (분리)
사용자의 이력서·포트폴리오·이력·타깃은 **스킬 번들 금지, 별도 저장소, 외부 비공개**.
저장 위치는 실행 중 사용자가 선택(repo private + gitignore / CC 메모리 / 외부 파일).
스킬은 read/write하며 세션마다 개선.

### D-7 출력
- **(a) 분석·진단·리포트·로드맵 → HTML 보고 표준**: 자체완결 1파일 · KR/EN · easy/expert 토글 ·
  인라인 SVG · 점진공개 details · 워크플로우는 node-edge · 색 3색 이내 · 라이트/다크 · 실제 KST 스탬프.
- **(b) 문서(이력서·resume·cover·자소서·포트폴리오) → A4 인쇄용 HTML**: `@page size:A4` + 여백 ·
  `@media print` · `page-break-inside:avoid` · 텍스트 밀림·오버플로·인쇄 잘림 방지 ·
  인쇄 시 화면 UI `display:none` · PDF 인쇄 시 A4에 깔끔히 앉게 (**샘플 생성 후 인쇄 점검 필수**).
- **(c) 태스크별 출력 포맷 항상 동일** — 태스크당 표준 템플릿 1벌 확정.

### D-8 파일 구조
```
<repo>/
  BUILD_SPEC.md
  SKILL.md                 # name + description(≤50단어) + 본문
  reference/
    gems/                  # 엔진 레퍼런스 기법 체리픽 (페르소나 이식 금지)
    private/               # [gitignore] 포폴·이력서 (PRIVATE)
    methodology.md         # 채용 컨설턴트 방법론 모듈
  templates/
    report.html            # HTML 보고 표준 (D-7a)
    a4-doc.html            # A4 인쇄용 문서 (D-7b)
  .private/                # [gitignore] profile.md
    profile.md
  .gitignore               # .private/ · reference/private/ · .env
  README.md
```

### D-9 수용 기준
D-8 구조 + SKILL.md frontmatter 유효 + 7태스크 고정 템플릿 + 2단 평가(강도 런타임) +
방법론 모듈 + 하이브리드 지식/insane-search + 개인 컨텍스트 분리(.gitignore 확인) +
A4 인쇄 샘플 무오버플로 + 페르소나/라우터 없음 + README + 스모크 체크 통과 +
Conventional Commits 푸시.

---

## §F /goal 완료조건 (§B 빌드 트리거)

`/goal` — BUILD_SPEC.md를 **동작하는 Claude Code 스킬로 완전히 구현**하고(커맨드명은 빌드 중 사용자 지정),
아래를 각각 이 대화에 **증거로 드러내** 검증한다:

1. SKILL.md 유효 frontmatter(name + description ≤50단어) — `cat SKILL.md` 표시.
2. D-2의 7태스크가 각 고정 출력 템플릿과 함께 구현 — 표시.
3. 2단 평가 구현 + 강도 실행 중 선택 — 표시.
4. `reference/methodology.md` 방법론 모듈 존재 — 표시.
5. 지식 하이브리드 + 런타임 insane-search(로그인/페이월 정지) + 내장 정적정보 최신성 주석 — 표시.
6. 개인 컨텍스트 .gitignore된 별도 저장소 read/write · 저장 위치 실행 중 선택 · 번들·커밋 안 함
   — `cat .gitignore` 표시.
7. 분석 = HTML 보고 표준; 문서 = A4 인쇄용 HTML, 샘플 1건 A4 인쇄 시 밀림·잘림 없이 앉고
   화면 UI 숨김 — 샘플·인쇄 점검 표시.
8. 페르소나·멀티엔진·라우터·메뉴·안정성 프로토콜 **없음**.
9. README 사용법; 스모크 체크 통과·결과 표시; Conventional Commits 커밋 후
   origin(github.com/Simon-YHKim/Career-manager-Skill) 푸시 · 시크릿 없음(.env gitignore)
   — `git log --oneline -5` · 푸시 확인 표시.

**제약**: 단일 목적·간결; git/보안/커밋은 전역 CC 지침 준수; force-push·파괴적 작업 전 확인.
30턴 내 미충족 시 중단·격차 보고.

---

## 부록: 엔진 레퍼런스 체리픽 정책 (zip `04. 엔진 레퍼런스/`)
- **참고만.** Ailey&Bailey · Ailey Debate · Loti · Search Mode.
- **금지**: 페르소나·멀티엔진 이식.
- **허용**: 기법만 체리픽 (예: 구조화된 반론/디베이트 기법 → 모의면접 압박 모드의 *기법*으로만,
  페르소나 없이).
