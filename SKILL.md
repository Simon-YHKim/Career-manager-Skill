---
name: career-manager
description: Personalized job-search and career-change assistant. Auto-detects one of seven tasks from conversation — JD↔portfolio matching, doc drafting/editing, interview prep, mock interviews, metacognitive self-diagnosis, salary negotiation, career roadmap. Two-stage evaluation (cold diagnosis then defensible max-PR). Outputs self-contained HTML reports and A4 print-ready documents.
---

<!--
  ⚠️ SKELETON (A1). Full body is built in §B after preparation is approved.
  Command/skill name `career-manager` is a PLACEHOLDER — the user picks the final
  name during the build. Rename `name:` above and this file's directory accordingly.
  This skeleton exists so the repo structure + frontmatter validate now.
  Authoritative spec: ../BUILD_SPEC.md (§D). Do NOT add persona/router/menu (D-4, F-8).
-->

# Career Manager (skeleton)

## What this skill does
대화로 의도를 파악해 아래 7개 태스크 중 하나를 **자동 판별**하고, 고정 템플릿으로 산출물을 만든다.
메뉴 없음 · 페르소나 없음 · 라우터 없음 (단일 목적).

## Tasks (D-2) — TODO(§B): 각 태스크별 고정 출력 템플릿 확정
1. JD ↔ portfolio matching — 5-D Prism + match matrix + gap/보강
2. Document draft/edit — 자소서 · 이력서(KR) · resume(EN) · cover letter(EN) · portfolio → A4 HTML
3. Interview prep — question bank + STAR-L answer frame
4. Mock interview — 실무/임원/HR (Training: 턴별 채점 / Live: 종료 리포트)
5. Metacognitive self-diagnosis
6. Salary negotiation — 변수표 + BATNA + 전략 3안 + 스크립트
7. Career roadmap — 3/5/10년

## Evaluation (D-3) — TODO(§B)
- Stage 1 냉정 진단 (보수 채점, 근거 없으면 상한).
- Stage 2 최대 PR (방어 가능·진실, 왜곡 금지).
- 강도(코칭↔압박) 런타임 선택.

## Knowledge (D-5) — TODO(§B)
- Durable 방법론 내장 (reference/methodology.md).
- 시의성 데이터는 런타임 insane-search (로그인/페이월 정지·인증필요 보고·자격증명 저장 금지).
- 내장 정적정보엔 최신성 주석.

## Personal context (D-6) — TODO(§B)
- 개인 컨텍스트는 스킬 번들 금지 · 별도 저장소 · gitignore.
- 저장 위치 런타임 선택 (repo private+gitignore / CC 메모리 / 외부 파일).

## Output (D-7) — TODO(§B)
- 분석·리포트·로드맵 → templates/report.html (자체완결 HTML 보고 표준).
- 문서 → templates/a4-doc.html (A4 인쇄용, 인쇄 점검 필수).
