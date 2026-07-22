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

## 7 Tasks (D-2)
① JD↔포트폴리오 매칭 · ② 문서 작성/첨삭(자소서·이력서KR·resume·cover·포폴) · ③ 면접 준비 ·
④ 모의면접(실무/임원/HR·Training/Live) · ⑤ 메타인지 자가진단 · ⑥ 연봉협상 · ⑦ 커리어 로드맵.

## 평가 (D-3)
2단 — ① 냉정 진단(보수 채점·근거 없으면 상한) → ② 최대 PR(방어 가능·진실). 강도 런타임 선택.
상세 루브릭: [`reference/evaluation.md`](./reference/evaluation.md).

## 지식 (D-5)
Durable 방법론 내장([`reference/methodology.md`](./reference/methodology.md)). 시의성 데이터(채용시장·기업·
JD·연봉)는 런타임 **insane-search**로 수집(로그인/페이월 정지·"인증 필요" 보고·자격증명 저장 금지),
Truth Tier + 조회일 인용.

## Repo layout
```
BUILD_SPEC.md            사양 원본 SSOT (D-0~D-10)
GOAL_CONDITION.txt       /goal 빌드 완료조건
SKILL.md                 스킬 정의 (name: career + description + 7태스크 본문)
reference/
  methodology.md         컨설턴트 방법론 모듈 (5-D Prism·Truth Tier·STAR-L·Tech-to-Biz + 6섹션)
  evaluation.md          2단 평가 엔진 + 채점 루브릭
  gems/techniques.md     엔진 체리픽 기법 + 포팅 금지 목록
  gems/*  [gitignore]    젬 시스템프롬프트 원본(로컬)
  private/  [gitignore]  포폴·이력서·타깃·소스 PDF (PRIVATE)
templates/
  report.html            HTML 보고 표준 (D-7a)
  a4-doc.html            A4 인쇄용 문서 (D-7b)
samples/sample-resume.html   A4 렌더 샘플(제네릭·PII 없음)
scripts/
  check_a4.py            A4 인쇄 검증 (chromium print→PDF + PyMuPDF)
  smoke_check.sh         구조·수용기준 스모크 체크
.private/  [gitignore]   개인 프로필(profile.md)
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
