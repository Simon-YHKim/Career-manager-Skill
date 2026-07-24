// career-hub — 사용자 소유(BYO) Cloudflare Worker
// 두 역할: (1) 데이터 저장(KV, 단일 JSON 문서)  (2) AI 프록시(키는 서버측 시크릿, 브라우저 미노출)
// 엔드포인트: GET/PUT  <base>/doc   ·   POST <base>/ai
// 인증: Authorization: Bearer <TOKEN>   (TOKEN = 배포 시 사용자가 설정한 시크릿)
// AI: AI_KEY(시크릿) 있을 때만 활성. 제공자 = AI_PROVIDER(anthropic|openai, 기본 anthropic).
// 자격증명은 전부 Cloudflare 시크릿(env)로만 존재 — 소스·브라우저·리포지토리에 키 없음.

export default {
  async fetch(req, env) {
    const cors = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET,PUT,POST,OPTIONS',
      'Access-Control-Allow-Headers': 'authorization,content-type',
    };
    const J = (o, s = 200) =>
      new Response(JSON.stringify(o), { status: s, headers: { ...cors, 'content-type': 'application/json' } });

    if (req.method === 'OPTIONS') return new Response(null, { headers: cors });

    // 인증 — TOKEN 시크릿 필수(미설정이면 전부 거부: 실수로 공개되는 것 방지)
    if (!env.TOKEN || (req.headers.get('authorization') || '') !== 'Bearer ' + env.TOKEN)
      return J({ error: 'unauthorized' }, 401);

    const path = new URL(req.url).pathname;

    // (1) 데이터 문서 — 단일 사용자, 단일 문서
    if (path.endsWith('/doc')) {
      if (req.method === 'GET')
        return new Response((await env.CAREER.get('doc')) || '{}', {
          headers: { ...cors, 'content-type': 'application/json' },
        });
      if (req.method === 'PUT') {
        await env.CAREER.put('doc', await req.text());
        return J({ ok: true });
      }
    }

    // (2) AI 프록시 — 키는 여기(서버)에만. 브라우저는 이 엔드포인트만 부른다(CORS 해결).
    if (path.endsWith('/ai') && req.method === 'POST') {
      if (!env.AI_KEY) return J({ error: 'AI 미설정 — AI_KEY 시크릿을 추가하세요.' }, 400);
      const b = await req.json().catch(() => ({}));
      const provider = (b.provider || env.AI_PROVIDER || 'anthropic').toLowerCase();
      const prompt = String(b.prompt || '');
      const system = String(b.system || '');
      const max = Math.min(Number(b.max_tokens) || 1024, 4096);
      try {
        if (provider === 'openai') {
          const r = await fetch('https://api.openai.com/v1/chat/completions', {
            method: 'POST',
            headers: { 'content-type': 'application/json', authorization: 'Bearer ' + env.AI_KEY },
            body: JSON.stringify({
              model: b.model || env.AI_MODEL || 'gpt-4o-mini',
              max_tokens: max,
              messages: [...(system ? [{ role: 'system', content: system }] : []), { role: 'user', content: prompt }],
            }),
          });
          const d = await r.json();
          return J({ text: (d.choices && d.choices[0] && d.choices[0].message && d.choices[0].message.content) || '', error: d.error && d.error.message }, r.status);
        }
        // 기본: Anthropic
        const r = await fetch('https://api.anthropic.com/v1/messages', {
          method: 'POST',
          headers: { 'content-type': 'application/json', 'x-api-key': env.AI_KEY, 'anthropic-version': '2023-06-01' },
          body: JSON.stringify({
            model: b.model || env.AI_MODEL || 'claude-haiku-4-5-20251001',
            max_tokens: max,
            ...(system ? { system } : {}),
            messages: [{ role: 'user', content: prompt }],
          }),
        });
        const d = await r.json();
        const text = (d.content && d.content[0] && d.content[0].text) || '';
        return J({ text, error: d.error && d.error.message }, r.status);
      } catch (e) {
        return J({ error: String(e) }, 502);
      }
    }

    return J({ error: 'not found' }, 404);
  },
};
