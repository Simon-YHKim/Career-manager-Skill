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

// ★ Linux 절대경로만 뒤지면 Windows·macOS 에서 항상 fail-closed 로 끝나 검사 자체가 죽는다(실측 2026-07).
//   Windows 의 Chrome·Edge 는 PATH 에 없는 것이 정상이므로 기본 설치 경로까지 본다.
const CHROME = (() => {
  const abs = [
    '/opt/pw-browsers/chromium', '/usr/bin/chromium', '/usr/bin/chromium-browser',
    '/usr/bin/google-chrome',
    'C:/Program Files/Google/Chrome/Application/chrome.exe',
    'C:/Program Files (x86)/Google/Chrome/Application/chrome.exe',
    'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
    'C:/Program Files/Microsoft/Edge/Application/msedge.exe',
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge',
  ].find((p) => fs.existsSync(p));
  if (abs) return abs;
  const where = process.platform === 'win32' ? 'where' : 'which';
  for (const name of ['chromium', 'chromium-browser', 'google-chrome', 'chrome', 'msedge']) {
    try {
      const out = execFileSync(where, [name], { encoding: 'utf8' }).trim().split(/\s+/)[0];
      if (out && fs.existsSync(out)) return out;
    } catch { /* 없으면 다음 후보 */ }
  }
  return null;
})();
if (!CHROME) { console.error('검사 불가: chromium 없음 (fail-closed) — Chrome 또는 Edge 설치 필요'); process.exit(2); }

// ★ 페이로드가 하나면 **싱크 종류만큼의 사각지대**가 생긴다. 실제로 cover-letter.html은
//   `<textarea>${값}</textarea>`에 날값을 넣고 있었는데, `<img ...>` 하나만 쏘던 옛 페이로드는
//   textarea 본문 안에서 텍스트로 남아 통과했다. 닫는 태그를 포함한 탈출 페이로드로만 드러난다.
const PAYLOADS = [
  '<img src=x onerror="window.__XSS=1">',                    // 일반 innerHTML 싱크
  '</textarea><img src=x onerror="window.__XSS=1">',         // textarea 본문 탈출
  '"><img src=x onerror="window.__XSS=1">',                  // 속성값 탈출
];
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
  {
    file: 'templates/hub.html',
    // 유일하게 **사용자가 파일로 가져오는** JSON(가져오기/localStorage)이 들어온다 → 신뢰도 최하.
    inject: `
      DATA.bank.length = 0;
      DATA.bank.push({ title:P, org:P, period:P, role:P, action:P,
        result:P, insight:P, stack:P, tier:P });
      DATA.applications.length = 0;
      DATA.applications.push({ co:P, title:P, stage:P, result:P,
        deadline:P, link:U, score:P, applied:P });
      DATA.profile = { role:P, years:P, seed:P };
      renderAll();
    `,
  },
  {
    file: 'templates/roadmap.html',
    inject: `
      PATHS.length = 0;
      PATHS.push({ arch:P, title:P, risk:P, why:P,
        score:70, grade:'유력', confidence:'높음', sub:{fit:70,feasible:70,growth:70,intent:70},
        tags:[P], track:[{when:P, goal:P, act:P, metric:P}] });
      PROFILE.role = P; PROFILE.anchor = P; PROFILE.years = P; PROFILE.seed = P;
      render();
    `,
  },
  {
    file: 'templates/linkedin-export.html',
    inject: `
      SECTIONS.length = 0;
      SECTIONS.push({ key:'headline', name:P, group:P, core:true,
        fields:[{ k:'headline', label:P, limit:220, type:'text', hint:P, sample:P }] });
      renderPicker(); renderSections();
    `,
  },
  {
    file: 'templates/interview-prep.html',
    // 성과 요약을 구조화 데이터(metrics/flag)로 바꿔 **예외 없이 전 필드**를 오염시킨다.
    // 예전에는 summary가 리치텍스트 HTML이라 이 필드만 검사에서 뺐다 — 그 가정이 사라졌다.
    inject: `
      ITEMS.length = 0;
      ITEMS.push({ title:P, meta:P, tier:P, flag:P,
        metrics:[{ k:P, v:P }],
        questions:[{ q:P, intent:P, defense:P, probes:[P] }] });
      renderFilters(); render();
    `,
  },
  {
    file: 'templates/cover-letter.html',
    inject: `
      document.getElementById('qs').innerHTML = '';
      SAMPLES.length = 0;
      SAMPLES.push({ q:P, intent:P, a:P, drill:P, lim:1000 });
      SAMPLES.forEach(addQ); renumber();
    `,
  },
];

/**
 * 데이터를 마크업 싱크에 넣지 **않는** 템플릿 — 면제 사유를 명시한다.
 * ★ 왜 자동 판별이 아니라 명시 목록인가: 정적으로 "이 템플릿이 데이터를 렌더하는가"를 맞히려면
 *   휴리스틱이 필요하고, 휴리스틱은 조용히 틀린다. 실제로 #14에서 추가된 템플릿이 아무 경고 없이
 *   1년 가까이 미검사로 남았다(실측). 목록을 강제하면 **새 템플릿은 분류를 거치지 않고는 통과 못 한다.**
 */
const EXEMPT = {
  'templates/a4-doc.html':      '정적 편집 문서 — 데이터 전역·마크업 싱크 없음',
  'templates/report.html':      '정적 리포트 — 스킬이 파일 자체를 생성, 런타임 렌더 없음',
  'templates/resume-ats.html':  '정적 이력서 — 런타임 렌더 없음',
  'templates/jd-filter.html':   'JSON을 받지만 마크업 싱크 0 — 파싱 결과는 폼 요소의 .value/.checked로만 들어가고 '
                              + '출력은 textContent(JSON.stringify)다. 싱크가 생기면 이 면제는 무효 → CASES로 옮길 것',
  'templates/intake-form.html': 'el() 싱크는 있으나 전부 정적 리터럴 — 인자 v를 보간하지 않음',
};

// 모든 템플릿은 CASES(검사) 또는 EXEMPT(면제) 중 하나로 **분류되어 있어야** 한다.
{
  const known = new Set([...CASES.map(c => c.file), ...Object.keys(EXEMPT)]);
  const all = fs.readdirSync('templates').filter(f => f.endsWith('.html')).map(f => 'templates/' + f);
  const unclassified = all.filter(f => !known.has(f));
  const stale = [...known].filter(f => !all.includes(f));
  if (unclassified.length) {
    console.error('검사 불가: 미분류 템플릿 — CASES에 추가하거나 EXEMPT에 사유와 함께 등록하세요:\n  ' +
      unclassified.join('\n  '));
    process.exit(2);
  }
  if (stale.length) {
    console.error('검사 불가: 존재하지 않는 템플릿이 CASES/EXEMPT에 남아 있음:\n  ' + stale.join('\n  '));
    process.exit(2);
  }
}

const problems = [];
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'xsschk-'));

for (const c of CASES) {
  if (!fs.existsSync(c.file)) { console.error(`검사 불가: ${c.file} 없음`); process.exit(2); }
  const src = fs.readFileSync(c.file, 'utf8');
  for (const PAY of PAYLOADS) {
  let html = src;

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

  const at = `${c.file} [payload: ${PAY.slice(0, 18)}…]`;
  if (r.err) problems.push(`${at} — 렌더 예외: ${r.err}`);
  if (r.xss) problems.push(`${at} — 페이로드 실행됨(onerror 발화)`);
  if (r.el) problems.push(`${at} — 페이로드가 엘리먼트로 파싱됨(이스케이프 뚫림)`);
  if (r.url) problems.push(`${at} — javascript:/data: href가 살아있음(safeUrl 미적용)`);
  }
}

fs.rmSync(tmp, { recursive: true, force: true });

if (problems.length) { console.error(problems.join('\n')); process.exit(1); }
process.exit(0);
