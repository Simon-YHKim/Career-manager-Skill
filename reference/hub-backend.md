# reference/hub-backend.md — 개인 허브 백엔드 (BYO · 사용자 소유 무료 서버)

> `templates/hub.html`(로컬-우선 개인 관리 허브)의 **선택적 동기화** 규율. 핵심 원칙:
> **우리는 서버를 운영하지 않는다.** 각 사용자가 **자기 소유 무료 백엔드**를 만들어 연결하고,
> 데이터는 **그 사용자 서버로만** 간다(스킬 제작자·타인에게 안 감). 미설정 시 허브는 **완전 오프라인**
> (localStorage + JSON 내보내기/가져오기)으로 동작 = 자체완결(D-7) 유지. 동기화는 **opt-in 예외**.

## 0. 원칙 (privacy-first)
- **로컬-우선 기본.** 백엔드 없이도 허브는 완전 동작(localStorage 자동저장 + JSON 왕복). 백엔드는 **지속성·기기 간 동기화 편의**를 위한 선택.
- **사용자 소유.** 백엔드는 사용자가 만든 **자기 무료 계정/서버**. 스킬·제작자는 그 서버·데이터에 접근 없음.
- **자격증명 로컬.** 연결 설정(URL·키)은 **사용자 브라우저 localStorage에만** 저장. **커밋되는 파일엔 자격증명 0**(허브의 기본 config는 비어 있음).
- **네트워크는 동기화 시에만.** 사용자가 백엔드를 설정하고 "동기화"를 누를 때만 요청 발생. 그 외 모든 기능은 오프라인.
- **최소 권한 키만.** 브라우저에 넣는 키는 **공개-가능/제한 키**(Supabase anon+RLS 등)여야 한다. **service-role·admin·전체 PAT 금지**(유출 시 전체 계정 위험).

## 1. 백엔드 계약 (최소 — 아무 무료 서버나 만족시키면 됨)
허브는 **JSON 문서 1개**를 사용자 서버와 주고받는다. 사용자 서버는 아래만 제공하면 된다:
- **불러오기(GET):** 저장된 JSON 문서를 반환(없으면 빈 객체/404 → 신규로 간주).
- **저장(PUT 또는 POST):** 보낸 JSON 문서로 덮어쓰기(단일 문서 upsert).
- **엔드포인트 1개 + (선택) 인증 헤더 1개.** 허브 설정에 `URL` + `Authorization`(또는 커스텀 헤더) + 메서드만 넣는다.
- CORS: 브라우저에서 부르므로 서버가 **CORS 허용**해야 한다(레시피에 포함).

> 허브는 이 계약만 알면 되므로, 아래 어떤 무료 백엔드로도 연결된다. 문서 스키마(뱅크·지원·자소서…)는 허브의 export JSON과 동일 → `.private/` 뱅크와 왕복(스킬이 파싱/생성).

## 2. 무료 백엔드 레시피 (사용자가 자기 것 하나 선택)

### (a) Cloudflare Worker + KV — 권장(무료·최소·사용자 소유)
1. Cloudflare 무료 계정 → Workers & Pages → KV 네임스페이스 1개 생성(예: `CAREER`).
2. Worker 1개 배포(아래 코드). KV 바인딩 `CAREER`, 시크릿 `TOKEN`(임의 문자열) 설정.
3. 허브 설정에 `URL = https://<worker>.workers.dev/doc`, 헤더 `Authorization: Bearer <TOKEN>`.
```js
// Cloudflare Worker (free) — 사용자 본인 소유. GET=불러오기 / PUT=저장. 단일 문서.
export default {
  async fetch(req, env) {
    const cors = { 'Access-Control-Allow-Origin':'*', 'Access-Control-Allow-Methods':'GET,PUT,OPTIONS',
      'Access-Control-Allow-Headers':'authorization,content-type' };
    if (req.method === 'OPTIONS') return new Response(null, { headers: cors });
    if ((req.headers.get('authorization')||'') !== 'Bearer ' + env.TOKEN)
      return new Response('unauthorized', { status: 401, headers: cors });
    if (req.method === 'GET') {
      const v = await env.CAREER.get('doc');
      return new Response(v || '{}', { headers: { ...cors, 'content-type':'application/json' } });
    }
    if (req.method === 'PUT') {
      await env.CAREER.put('doc', await req.text());
      return new Response('{"ok":true}', { headers: { ...cors, 'content-type':'application/json' } });
    }
    return new Response('method', { status: 405, headers: cors });
  }
}
```
> TOKEN은 사용자가 정한 비밀값(자기 브라우저에만 입력). 유출돼도 **본인 문서 1개** 범위.

### (b) Supabase — 무료 Postgres + REST + 행 수준 보안(RLS)
1. Supabase 무료 프로젝트 → 테이블 `career_doc(id text primary key, data jsonb)` 생성.
2. **RLS 켜고** 본인만 read/write 정책(로그인 사용 시) 또는 단일 행 + anon 제한 정책.
3. 허브 설정: `URL = https://<ref>.supabase.co/rest/v1/career_doc?id=eq.me`, 헤더 `apikey: <anon>` + `Authorization: Bearer <anon>` + `Prefer: resolution=merge-duplicates`. **anon 키만**(service_role 금지).

### (c) GitHub Gist / 개인 private repo — git-native
- 사용자의 **비공개 Gist** 1개를 문서 저장소로. 브라우저에서 GitHub API 호출 시 **fine-grained PAT(해당 gist만, 최소 권한)** 필요 → 토큰 유출 위험이 있으니 **범위를 그 gist로만** 좁힐 것. (권한 넓은 클래식 PAT 금지.)
- 또는 사용자가 작은 프록시(Worker)를 두어 토큰을 서버측에 숨기는 방식 권장.

### (d) 기타
JSONBin·Deta·Fly.io 초소형 서버·본인 홈서버 등 §1 계약(GET/PUT + CORS)만 만족하면 연결 가능.

## 3. 동기화 동작 (허브)
- **수동 우선:** "지금 동기화"(불러오기/저장) 버튼. 자동 폴링·백그라운드 전송 없음(예측 가능·데이터 절약).
- **충돌:** 단순 last-write-wins + **저장 전 원격본 미리보기/확인**(실수 덮어쓰기 방지). 고급 병합은 하지 않음(단일 사용자 전제).
- **오프라인 폴백:** 네트워크 실패 시 localStorage는 그대로 유지 + 사용자에 알림. 데이터 손실 없음.
- **durable SSOT는 여전히 `.private/`** — 백엔드는 편의 계층. 중요한 건 JSON 내보내기로 `.private/`(private repo/CC 메모리)에도 보관 권장.

## 4. 스킬 연계 (왕복)
- 허브 export JSON ↔ `.private/experience-bank.md`·`applications/`: 스킬이 **가져오기**(export JSON 붙여넣기 → 뱅크 갱신) / **내보내기**(뱅크 → 허브 import용 JSON) 지원(§6.0 #1·P8).
- 허브는 **structured 데이터 관리**(뱅크 원자·지원 건·프로필), 문서 산출물(자소서·이력서·로드맵…)은 기존 템플릿이 그 데이터로 렌더.
- **보안 승계:** [T3]·미검증은 대외 렌더 배제(§6.0 #7), PII는 사용자 소유 저장소에만.

> 요약: **로컬-우선 + 사용자 소유 무료 백엔드(선택).** 우리는 아무 데이터도 보관·중계하지 않는다. 네트워크는 사용자가 자기 서버를 붙이고 동기화할 때만.
