# career-hub Worker — 내 무료 백엔드 (데이터 저장 + AI 프록시)

`templates/hub.html`(개인 허브)이 동기화·AI에 쓰는 **사용자 소유** Cloudflare Worker. 무료 등급으로 충분.
**로그인/인가만 사용자가 하고, 나머지는 자동**에 가깝게 설계했다. 자격증명(TOKEN·AI 키)은 **Cloudflare 시크릿**으로만 존재 — 소스·리포지토리·브라우저에 키가 없다.

## 무엇을 하나
- `GET/PUT <base>/doc` — 허브 데이터(JSON 1문서)를 KV에 저장/로드.
- `POST <base>/ai` — **AI 프록시**. 본인 AI 키를 워커 시크릿에 넣으면, 허브(HTML)가 이 엔드포인트만 호출해 AI를 쓴다(키는 브라우저에 안 남고, CORS도 해결). 안 넣으면 AI는 꺼진 상태 — 정보 디벨롭은 Claude/Codex 스킬로.

## 배포 (A: 원클릭 — 로그인만)
1. **Deploy to Cloudflare** 버튼:
   [![Deploy to Cloudflare](https://deploy.workers.cloudflare.com/button)](https://deploy.workers.cloudflare.com/?url=https://github.com/Simon-YHKim/Career-manager-Skill/tree/main/worker)
2. Cloudflare 로그인/인가 → KV·워커가 **자동 생성·바인딩**된다.
3. 배포 후 **시크릿만** 설정(Worker → Settings → Variables and Secrets):
   - `TOKEN` — 아무 긴 랜덤 문자열(허브 '연결'에 같은 값 입력). **필수.**
   - `AI_KEY` — (선택) 본인 Anthropic/OpenAI API 키. 넣으면 인브라우저 AI 활성.
   - `AI_PROVIDER` — (선택) `anthropic`(기본) 또는 `openai`.

## 배포 (B: 수동 — 대시보드, 로그인 후 5클릭)
1. Cloudflare 대시보드 → **Workers & Pages → Create → Worker** → 이름 `career-hub` → Deploy.
2. **Edit code** → `src/index.js` 내용을 붙여넣고 저장/배포.
3. **KV**: Storage & Databases → KV → Create namespace `CAREER` → Worker → Settings → Bindings → **KV binding** `CAREER` 연결.
4. **Secrets**(위 A-3과 동일): `TOKEN` 필수, `AI_KEY`·`AI_PROVIDER` 선택.
> CLI 선호 시: `npx wrangler deploy` → `wrangler kv namespace create CAREER`(id를 wrangler.toml에) → `wrangler secret put TOKEN` / `wrangler secret put AI_KEY`.

## 허브에 연결
허브 → **설정·동기화** 탭 → "내 백엔드(Worker) 연결":
- **Worker URL** = 배포된 주소(예: `https://career-hub.<계정>.workers.dev`)
- **토큰** = 위 `TOKEN`
→ 저장하면 데이터 동기화가 켜지고, `AI_KEY`를 넣었다면 **AI 연결**도 자동 감지된다. 설정은 **브라우저 로컬에만** 저장.

## 보안
- 브라우저·허브·리포지토리에 **AI 키 없음**(워커 시크릿에만). 허브는 워커의 `/ai`만 호출.
- `TOKEN`은 접근 문지기. 유출 시 **본인 문서 1개 + 본인 AI 프록시** 범위 → 토큰 교체로 회수.
- 넣는 AI 키는 **본인 키**. 사용량·비용은 본인 계정. 워커 무료 등급 한도 내에서 운영.
- 네트워크는 사용자가 **동기화/AI 버튼을 누를 때만** 발생.

> 상세 계약·대안 백엔드(Supabase 등): `reference/hub-backend.md`.
