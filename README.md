# Career Manager Skill

취업·이직 준비 개인화 **Claude Code 스킬(플러그인)**. 하나의 스킬을 호출하면 대화로 의도를 파악해
아래 7개 태스크 중 하나를 **자동 판별**하고, 태스크별 고정 템플릿으로 산출물(자체완결 HTML 리포트 /
A4 인쇄용 문서)을 만든다. 메뉴·페르소나·라우터 없음 — **단일 목적 + 점진 공개 + 개인 컨텍스트 분리**.

> Gemini 'Jobs Verstappen' 커리어 OS를 Opus 4.8 + Claude Code에 맞게 **재구축**(포팅 아님).
> 사양 원본(SSOT): [`BUILD_SPEC.md`](./BUILD_SPEC.md) · 빌드 트리거: [`GOAL_CONDITION.txt`](./GOAL_CONDITION.txt).

## Status

🚧 **준비 단계(§A) 완료 — 빌드(§B)는 사용자 승인 대기.** 스킬 본체(SKILL.md 본문)는 아직 스켈레톤.

| 준비 단계 | 상태 |
|---|---|
| A1 리포 스캐폴딩 (BUILD_SPEC · SKILL 스켈레톤 · 디렉터리 · .gitignore) | ✅ 완료 |
| A2 zip 추출·배치 (31 PDF → 방법론 소스 / 포폴·이력서·타깃은 gitignore) | ✅ 완료 |
| A3 개인 프로필 보정 (`.private/profile.md`, gitignore·로컬) | ✅ 완료 (사용자 리뷰 대기) |
| A4 방법론 모듈 추출 (`reference/methodology.md` + `gems/techniques.md`) | ✅ 완료 |
| A5 준비 완료 보고 → 정지 | ▶ 진행 (사용자 승인 게이트) |
| §B 빌드 | ⏳ 승인 후 |

## 7 Tasks (D-2)
1. JD ↔ 포트폴리오 매칭 (5-D Prism + 매칭 매트릭스 + 갭·보강)
2. 문서 작성/첨삭 (자소서 · 이력서 KR · resume EN · cover letter EN · 포트폴리오 → A4 HTML)
3. 면접 준비 (예상질문 뱅크 + STAR-L)
4. 모의면접 (실무/임원/HR · Training 턴별 채점 / Live 종료 리포트)
5. 메타인지 자가진단
6. 연봉협상 (변수표 + BATNA + 전략 3안 + 스크립트)
7. 커리어 로드맵 (3/5/10년)

## Evaluation (D-3)
2단 평가 — ① 냉정 진단(보수 채점) → ② 최대 PR(방어 가능·진실). 강도(코칭↔압박)는 실행 중 선택.

## Repo layout (D-8)
```
BUILD_SPEC.md            사양 원본 SSOT (D-0~D-10)
GOAL_CONDITION.txt       /goal 빌드 완료조건
SKILL.md                 스킬 정의 (name + description + 본문)   ← 현재 스켈레톤(§B에서 완성)
reference/
  gems/techniques.md     엔진 레퍼런스 체리픽 기법 + 포팅 금지 목록 (페르소나 이식 없음)
  private/    [gitignore] 포폴·이력서·타깃·소스 PDF·텍스트 캐시 (PRIVATE)
  methodology.md         채용 컨설턴트 방법론 모듈 (5-D Prism·Truth Tier·STAR-L·Tech-to-Biz + 6 섹션)
templates/
  report.html            HTML 보고 표준 (D-7a)                  ← 빌드 대기
  a4-doc.html            A4 인쇄용 문서 (D-7b)                  ← 빌드 대기
.private/     [gitignore] profile.md (개인 프로필)
.gitignore               .private/ · reference/private/ · .env
README.md
```

## Privacy (D-6)
`.private/`, `reference/private/`는 **gitignore**되어 커밋·번들되지 않는다. 개인 이력서·포트폴리오·
프로필·타깃 리서치는 스킬 번들에 포함하지 않으며, 저장 위치는 실행 중 선택(repo private+gitignore /
CC 메모리 / 외부 파일).

## Usage
> 스킬 빌드(§B) 완료 후 작성 예정. 커맨드명은 빌드 중 사용자가 지정.
