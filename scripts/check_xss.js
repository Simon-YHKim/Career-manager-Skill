#!/usr/bin/env node
/**
 * check_xss.js — 템플릿 XSS 회귀 게이트 (런타임 실증)
 *
 * 왜 런타임인가: 이전 게이트는 esc() **정의만** 격리 실행해서, 정의를 남긴 채 호출부(sink)를
 * 전부 지워도 통과했다(실측 재현). 정적 분석으로 sink를 훑는 방식은 반대로 오탐이 쏟아진다.
 * 그래서 **실제로 악성 값을 데이터에 심고 렌더해서, 그 값이 살아있는 마크업이 되는지** 본다.
 *
 * 검사 대상은 **외부 JSON을 받아들이는 템플릿**이다 — 스킬이 생성하거나 사용자가 임포트한
 * 데이터가 그대로 화면에 들어가므로 신뢰할 수 없다.
 *
 * 판정
 *   - 페이로드가 <img>·<svg> 등 **엘리먼트로 파싱되면** 실패 (이스케이프 뚫림)
 *   - href가 javascript:/data: 스킴으로 **살아있으면** 실패 (safeUrl 미적용)
 *   - 텍스트로만 남으면 통과
 *
 * 종료코드 0=통과, 1=결함, 2=검사 불가(fail-closed — 브라우저 없음 등)
 */
const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');

const CHROME = ['/opt/pw-browsers/chromium', '/usr/bin/chromium', '/usr/bin/chromium-browser']
  .find((p) => fs.existsSync(p));
if (!CHROME) { console.error('검사 불가: chromium 없음 (fail-closed)'); process.exit(2); }

const PAY = '<img src=x onerror="window.__XSS=1">';
const URL_PAY = 'javascript:window.__XSS=1';

/** 각 템플릿의 데이터 전역을 오염된 값으로 갈아끼우는 주입 스크립트 */
const CASES = [
  {
    file: 'templates/jd-discovery.html',
    // JOBS는 스킬이 생성 → 외부 입력. 문자열 필드와 링크를 모두 오염시킨다.
    inject: `
      JOBS.length = 0;
      JOBS.push({ co:P, mono:P, title:P, region:P, summary:P,
        score:70, grade:'중', confidence:'높음', sub:{role:70,major:70,growth:70,weight:70},
        err:5, quality:70, qsub:{pay:70,grow:70,stable:70,culture:70,personal:70}, qconf:'중간',
        flags:[P], whatif:[P], reqs:[P,{t:P,flag:true}],
        deadline:'2099-01-01', dlVerified:true, link:U });
      GATED.length = 0; GATED.push(P);
      COVERAGE.length = 0; COVERAGE.push({ axis:P, detail:P, ran:false, found:0 });
      PROFILE.role = P; PROFILE.langs = P; PROFILE.region = P; PROFILE.level = P;
      render();
    `,
  },
  {
    file: 'templates/application-tracker.html',
    inject: `
      APPS.length = 0;
      APPS.push({ co:P, title:P, stage:'서류접수', channel:P, memo:P, link:U,
        due:'2099-01-01', score:70, result:'', docs:[{label:P, href:U}] });
      render();
    `,
  },
];

const problems = [];
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'xsschk-'));

for (const c of CASES) {
  if (!fs.existsSync(c.file)) { console.error(`검사 불가: ${c.file} 없음`); process.exit(2); }
  let html = fs.readFileSync(c.file, 'utf8');

  const probe = `
<script>
(function(){
  var P = ${JSON.stringify(PAY)};
  var U = ${JSON.stringify(URL_PAY)};
  window.__XSS = 0;
  try { ${c.inject} } catch (e) { window.__ERR = String(e && e.message || e); }
  var out = { xss: window.__XSS === 1, err: window.__ERR || '' };
  // 페이로드가 엘리먼트로 파싱됐는가
  out.el = !!document.querySelector('img[onerror], svg, iframe, script[data-x]');
  // 살아있는 위험 스킴 href/src
  out.url = [].slice.call(document.querySelectorAll('[href],[src]')).some(function(a){
    var v = (a.getAttribute('href') || a.getAttribute('src') || '').replace(/[\\s\\u0000-\\u001F]/g,'').toLowerCase();
    return /^(javascript|data|vbscript):/.test(v);
  });
  document.title = 'XSSCHK:' + JSON.stringify(out);
})();
</script>`;

  html = html.replace('</body>', probe + '\n</body>');
  const f = path.join(tmp, path.basename(c.file));
  fs.writeFileSync(f, html);

  let dom = '';
  try {
    dom = execFileSync(CHROME, ['--headless', '--disable-gpu', '--no-sandbox',
      '--virtual-time-budget=4000', '--dump-dom', 'file://' + f],
      { encoding: 'utf8', timeout: 90000, stdio: ['ignore', 'pipe', 'ignore'] });
  } catch (e) { console.error(`검사 불가: ${c.file} 렌더 실패`); process.exit(2); }

  const m = dom.match(/XSSCHK:(\{.*?\})</);
  if (!m) { console.error(`검사 불가: ${c.file} 프로브 미실행(렌더가 죽었을 수 있음)`); process.exit(2); }
  let r;
  try { r = JSON.parse(m[1].replace(/&quot;/g, '"')); }
  catch (e) { console.error(`검사 불가: ${c.file} 프로브 결과 파싱 실패`); process.exit(2); }

  if (r.err) problems.push(`${c.file} — 렌더 예외: ${r.err}`);
  if (r.xss) problems.push(`${c.file} — 페이로드 실행됨(onerror 발화)`);
  if (r.el) problems.push(`${c.file} — 페이로드가 엘리먼트로 파싱됨(이스케이프 뚫림)`);
  if (r.url) problems.push(`${c.file} — javascript:/data: href가 살아있음(safeUrl 미적용)`);
}

fs.rmSync(tmp, { recursive: true, force: true });

if (problems.length) { console.error(problems.join('\n')); process.exit(1); }
process.exit(0);
