# reference/handoff.md — 세션 핸드오프 (career 최적화 내재화)

> `simon-handoff`(SimonK-stack)의 **"영속 + 재개 보장"** 규율을 career에 맞게 최적화·내재화.
> 트리거: "핸드오프", "인수인계", "다음 세션 준비", "이어서 하게 저장". SKILL §2가 참조.
> **핵심 최적화(원본과의 차이):** career 세션 상태엔 **개인정보**(작성 중 자소서·위시리스트 실공고·
> 프로필 파생 문맥)가 있다. 원본은 `docs/HANDOFF.md`를 **main에 머지**하지만, career는 그러면
> D-6 위반이므로 **PII는 gitignore된 `.private/`로 라우팅하고 절대 커밋하지 않는다.**

## 두 갈래 (무엇을 이어받나로 결정)

### A. 개인 세션 핸드오프 (기본 — 취업 준비 세션)
사용자 취업 준비 상태를 이어받는다. **PII 포함 → `.private/session-state.md` (gitignore, 커밋 금지).**
- **영속:** `.private/`는 D-6대로 사용자가 durable하게 보관(repo private+gitignore / CC 메모리 / 외부 파일). 그 저장소가 유지되면 새 세션이 읽어 재개.
- **정직한 한계:** `.private/`는 gitignore라 **`git pull`로는 안 옴**. 임시 컨테이너가 폐기되면 사용자가 `.private/`를 다시 제공해야 함(또는 durable 저장 선택 시 유지). main 머지로 크로스-컨테이너 자동 재개는 **PII 때문에 불가** — 이게 원본과 다른 지점.
- **뱅크는 이미 durable** — 재입력 불필요분(경험 원자)은 `experience-bank.md`가 담당. 핸드오프는 **휘발 상태만**: 진행 태스크·진행률·활성 다이얼·작성 중 초안·위시리스트·미결 질문.

### B. 스킬 개발 핸드오프 (비-PII — 이 스킬을 빌드/개선하는 세션)
개발 상태엔 PII가 없다 → 원본 `simon-handoff` 그대로: `docs/HANDOFF.md`에 **prepend + main 머지** → 새 세션이 `git pull origin main`로 이어받음.

## 실행 절차 (공통 규율)

**1) 상태 수집** — git 상태(HEAD·머지된 PR·working tree) + 대화에서: 이번 세션 성과, 다음 작업 큐, 사용자가 명시한 영구 정책, 핵심 파일 위치.

**2) prepend (덮어쓰지 않음)** — 파일 맨 위에 새 `## Latest — YYYY-MM-DD / 요약` 블록 추가. **직전 블록의 `## Latest —`는 평문 `## <date>`로 강등**(Latest 마커는 항상 최신 1개만). 이전 블록 본문은 보존.

**블록 템플릿:**
```markdown
## Latest — YYYY-MM-DD / <한 줄 요약>

### 어디까지 왔나
- 진행 태스크: <태스크·단계> · 진행률: <…>
- 활성 다이얼: 출력모드/언어/평가강도/PR강도/전문용어
- 작성 중 초안: <문서유형·회사·문항 위치>
- 위시리스트: <공고 N개(회사·마감)>

### 다음 작업 큐
| # | 작업 | 크기 | 권장 |
|---|---|---|---|
| A | <…> | small/med/large | ⭐ <이유> |

### 미결 질문 / 사용자 결정 대기
- <…>

### 적용 중인 정책 (영구)
- <예: [T3] 대외 미사용, 원천징수=민감 PII, 국내 발굴 시 도메인 스코프 등>

### 다음 세션 재개
- (A) `.private/session-state.md` 로드 → 진행 태스크부터
- (B, 개발) `git fetch origin main && git pull && cat docs/HANDOFF.md`
```

**3) 영속 처리**
- **A(개인):** `.private/session-state.md`에 저장. **커밋 금지**(gitignore 확인). durable 보관 안내.
- **B(개발):** `docs/HANDOFF.md` prepend → 브랜치 `handoff/<date>` → commit·push·PR → **CI 없으면(또는 green) main 머지**. PR 본문에 Latest 블록 인라인(fallback).

**4) 재개 안내** — 사용자에게 복붙 블록 1개 + fallback:
- A: "다음 세션에서 `.private/session-state.md` 열고 '이어서'라고 하세요."
- B: `git fetch origin main && git pull origin main && cat docs/HANDOFF.md` + PR URL·raw URL·branch fallback.

## 자동 제안 타이밍
① 컨텍스트 압박(긴 세션) · ② "나중에/이어서" 발화 · ③ 태스크 경계 · ④ 산출물 완성 직후.

## 성공 기준
- A: `.private/session-state.md` 최상단이 오늘 날짜 Latest 블록 · gitignore 확인 · 커밋 안 됨.
- B: `git show origin/main:docs/HANDOFF.md` 최상단이 오늘 날짜 · (CI green 또는 무CI) · 재개 명령 동작 · fallback 2개 이상.

## 금지 (원본 안티패턴 + career 추가)
- ❌ `.private/`(PII)를 커밋/main 머지 — **D-6 위반**.
- ❌ `/tmp`·`/root` 등 임시 경로에 핸드오프 저장.
- ❌ 개인 세션 상태를 `docs/HANDOFF.md`(공개)에 기록.
- ❌ 업데이트만 하고 저장/영속 처리 안 함.

## 완료 보고 (선택)
길거나 산출물이 많은 세션은 자체완결 HTML 완료 보고서(report.html 표준: 심플 요약 + `<details>` 상세)로 마무리 가능.
