#!/usr/bin/env python3
"""공고 발굴 — 소스 레지스트리 × 쿼리 매트릭스를 결정적으로 순회한다.

같은 탐색을 반복해서 일관성을 얻는 게 아니라, **고정된 소스와 고정된 쿼리를
빠짐없이 열거**해서 얻는다 (reference/jd-browsing.md §2-(2-a)).

이 스크립트는 발굴의 **결정적인 부분만** 담당한다:
  · 보드 스윕(쿼리 매트릭스)          · 타깃 기업 정확 일치 조회
  · 커버리지 원장(빈 칸을 눈에 보이게) · ATS 식별로 자사 채용홈 지름길

판단이 필요한 부분(SPA 폴백 사다리, 검색 엔진 회수, 로그인 구간)은 **직접 하지 않고
작업 목록으로 내보낸다** — 조용히 빠뜨리지 않기 위해서다(취득 책임 원칙, §0).

PII 없음: 현직·타깃 기업·직무명은 **전부 필터 입력에서 온다.** 기본값을 두지 않는다
— 기본값을 두면 남의 조건으로 발굴하고도 그런 줄 모른다.

사용:
  python3 scripts/discover.py --filter <filter.json>            # 전체 매트릭스 순회
  python3 scripts/discover.py --filter <filter.json> --probe    # 소스 도달성만(빠름)
  python3 scripts/discover.py --ats <채용페이지 URL>             # ATS 식별만

필터는 templates/jd-filter.html 의 [필터 복사] 출력(스키마 career/jd-filter@1)을
그대로 파일로 저장한 것이다.
"""
import argparse
import html
import json
import re
import subprocess
import sys
import urllib.parse
from datetime import datetime, timezone, timedelta
from pathlib import Path

KST = timezone(timedelta(hours=9))
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/126.0 Safari/537.36")
SCHEMA = "career/jd-filter@1"

# ── 소스 레지스트리 ──────────────────────────────────────────────────────────
# status: ok(정적 조회 가능) / blocked(봇 차단 — 금지선이라 종료) / csr(클라이언트 렌더)
#         / shell(셸만 로드) / agent(스크립트 말고 에이전트가 조회)
# ★ 상태를 레지스트리에 박아두는 이유: 매번 "여긴 되던가?"를 다시 시험하면 라운드마다
#   같은 실패를 되풀이한다. 단, **부재 단정은 쓰지 않는다**(§2-(2-c) 실측 정정 참조) —
#   여기 적히는 건 "이 도구로 이 경로가 되/안 되"이지 "그 사이트에 공고가 없다"가 아니다.
SOURCES = {
    "jobkorea": {
        "status": "ok",
        "url": "https://www.jobkorea.co.kr/Search/?stext={q}",
        "note": "SSR. 원문에 목록 포함. 검색어를 느슨하게 OR 매칭하므로 직군 필터 병용 권장.",
    },
    "saramin": {
        "status": "blocked",
        "url": None,
        "note": "307 → 봇 차단. 헤더 위조는 금지선이므로 이 경로는 종료(§0). "
                "에이전트가 검색 엔진 경유로 회수할 것.",
    },
    "wanted": {
        "status": "csr",
        "url": None,
        "note": "HTTP 200이나 목록이 클라이언트 렌더링. 데이터 경로 미확인.",
    },
    "indeed": {
        "status": "agent",
        "url": None,
        "note": "curl 403, 마크다운 변환 도구로는 취득됨. 스크립트가 아니라 에이전트가 조회.",
    },
}

# ── ATS 패턴 → 공개 검색 경로 (jd-browsing §2-(2-c) ③-d) ─────────────────────
# ★ 회사마다 자사 채용홈을 새로 파헤치는 건 낭비다. URL이 아래 패턴이면 그 ATS의
#   공개 경로를 그대로 쓴다. `probe`는 "이 경로를 시도해 보라"는 **힌트**이지
#   검증된 엔드포인트 목록이 아니다 — 토큰·테넌트는 회사마다 다르다.
ATS_PATTERNS = [
    ("greenhouse",     r"boards\.greenhouse\.io/([\w-]+)",
     "https://boards-api.greenhouse.io/v1/boards/{0}/jobs"),
    ("lever",          r"jobs\.lever\.co/([\w-]+)",
     "https://api.lever.co/v0/postings/{0}?mode=json"),
    ("ashby",          r"jobs\.ashbyhq\.com/([\w-]+)",
     "https://api.ashbyhq.com/posting-api/job-board/{0}"),
    ("smartrecruiters", r"careers\.smartrecruiters\.com/([\w-]+)",
     "https://api.smartrecruiters.com/v1/companies/{0}/postings"),
    ("workday",        r"([\w-]+)\.[\w-]+\.myworkdayjobs\.com",
     "https://{0}.wdX.myworkdayjobs.com/wday/cxs/{0}/<site>/jobs  (POST, 사이트명 확인 필요)"),
    ("sap-successfactors", r"([\w-]+)\.successfactors\.com", "career/사이트별 확인 필요"),
    ("taleo",          r"([\w-]+)\.taleo\.net", "career/사이트별 확인 필요"),
]


def detect_ats(url):
    """채용 페이지 URL에서 ATS와 공개 검색 경로 힌트를 뽑는다."""
    for name, pat, tpl in ATS_PATTERNS:
        m = re.search(pat, url or "", re.I)
        if m:
            return {"ats": name, "token": m.group(1),
                    "probe": tpl.format(m.group(1)) if "{0}" in tpl else tpl}
    return None


def fetch(url, timeout=45):
    r = subprocess.run(
        ["curl", "-sS", "-A", UA, "--max-time", str(timeout), "-w", "\n@@%{http_code}", url],
        capture_output=True, text=True,
    )
    body, code = r.stdout, "000"
    if "\n@@" in body:
        body, _, code = body.rpartition("\n@@")
    return code, body


# ── 회사명 정규화 ────────────────────────────────────────────────────────────
# ★ 협력사가 고객사명을 자기 회사명에 붙여 쓴다("삼성전자 세광시스템이엔지㈜" 실측).
#   부분 일치로는 절대 안 걸러진다 → 법인격·공백·별칭을 지우고 **완전 일치**로만 본사 인정.
ALIAS = {"엘지": "lg", "에스케이": "sk", "에스에프에이": "sfa", "엘비": "lb",
         "에이치디": "hd", "케이씨": "kc"}


def norm_company(name):
    n = re.sub(r"주식회사|㈜|\(주\)|\(유\)|co\.,?\s*ltd\.?|inc\.?|corp\.?", "", name, flags=re.I)
    n = re.sub(r"[\s\-_·,./()\[\]]", "", n).lower()
    for k, v in ALIAS.items():
        n = n.replace(k, v)
    return n


BADGE = re.compile(r"^(합격축하금|신입 지원 가능|유연근무제|오늘 마감|상여금|든든한|믿고보는|"
                   r"탄탄한|스크랩|AD|초봉|월급|연봉|시급|즉시 지원|홈페이지 지원)")


def card_company(seg, fields=None):
    """회사명 필드를 뽑는다. 로고 alt 우선, 없으면 '제목 다음 span'으로 폴백.

    ★ 로고 이미지가 없는 카드가 상당수라(실측 20건 중 7건) alt만 보면 그 카드들의
      회사명을 통째로 잃는다 — 본사 공고가 있어도 놓치게 된다.
    """
    m = re.search(r'alt="([^"]{1,60}?)\s*로고"', seg)
    if m:
        return m.group(1).strip()
    if fields:
        core = [x for x in fields if not BADGE.match(x)]
        if len(core) >= 2:
            return core[1].strip()      # core[0]=제목, core[1]=회사명
    return None


def is_same_company(row, target):
    """카드가 타깃 기업 **본사** 공고인가. 정규화 후 **완전 일치**만 인정한다.

    ★ 회사명 필드(card_company)만 보면 **거짓 기각**이 난다 — 로고가 없는 카드는
      '제목 다음 span' 폴백을 쓰는데 레이아웃에 따라 지역명이 잡힌다(실측: "경기 안성시").
      그래서 카드의 **어느 필드든 정규화 완전 일치**하면 본사로 인정한다.
      부분 일치가 아니라 완전 일치이므로 "삼성전자 세광시스템이엔지㈜"(협력사)는
      정규화해도 "삼성전자세광시스템이엔지"라 여전히 걸러진다 — 노이즈는 다시 안 들어온다.
    """
    key = norm_company(target)
    if row.get("company_field") and norm_company(row["company_field"]) == key:
        return True
    return any(norm_company(x) == key for x in row.get("fields", []))


def parse_jobkorea(s, excluded):
    """CardJob 단위로 공고를 뽑는다. 마감일은 목록에 없으므로 기록하지 않는다."""
    rows = []
    for c in s.split('data-sentry-component="CardJob"')[1:]:
        seg = c[:6000]
        m = re.search(r"/Recruit/GI_Read/(\d+)", seg)
        if not m:
            continue
        t = re.sub(r"<script.*?</script>", " ", seg, flags=re.S)
        t = html.unescape(re.sub(r"<[^>]+>", "\n", t))
        L = [x.strip() for x in t.split("\n")
             if x.strip() and 2 < len(x.strip()) < 70 and "sentry" not in x and x.strip() != "스크랩"]
        joined = " ".join(L).lower()
        if any(e.lower() in joined for e in excluded):
            continue
        rows.append({
            "id": m.group(1),
            "company_field": card_company(seg, L),
            "url": f"https://www.jobkorea.co.kr/Recruit/GI_Read/{m.group(1)}",
            "fields": L[:6],
            "deadline": None,          # 목록에 없음 → 원문 확인 전까지 [확인 필요]
        })
    return rows


# ── 필터 → 쿼리 매트릭스 ─────────────────────────────────────────────────────
# 도메인/지역 라벨은 필터 UI의 라벨을 검색어로 펴는 사전이다. 라벨이 사전에 없으면
# 라벨 자체를 검색어로 쓴다(사용자가 직접 입력한 값도 그대로 살리기 위해).
DOMAIN_TERMS = {
    "반도체": ["반도체"], "패키징·후공정": ["패키징", "후공정"], "기판·PCB": ["기판", "PCB"],
    "전장·카메라": ["전장", "카메라모듈"], "이차전지": ["이차전지"], "디스플레이": ["디스플레이"],
    "자동차부품": ["자동차부품"], "제조 DX·SW": ["스마트팩토리"],
}


def load_filter(path):
    p = Path(path)
    if not p.exists():
        sys.exit(f"필터 없음: {path}\n"
                 f"  templates/jd-filter.html 을 열어 조건을 고르고 [필터 복사] → 파일로 저장하세요.\n"
                 f"  ★ 기본값을 두지 않는 이유: 남의 조건으로 발굴하고도 그런 줄 모르게 된다.")
    f = json.loads(p.read_text(encoding="utf-8"))
    if f.get("_schema") != SCHEMA:
        sys.exit(f"스키마 불일치: {f.get('_schema')!r} (기대: {SCHEMA!r})")
    if not f.get("role"):
        sys.exit("필터에 role이 비어 있습니다 — 직무명 없이는 쿼리 매트릭스를 만들 수 없습니다.")
    return f


def build_matrix(f):
    roles = f["role"]
    doms = f.get("domain") or []
    terms = [t for d in doms for t in DOMAIN_TERMS.get(d, [d])] + [""]   # "" = 도메인 없이 직무만
    return [f"{d} {r}".strip() for r in roles for d in terms]


def excluded_names(f):
    """현직 제외 — 자사 공고는 이직 후보가 아니다(evaluation §5.8-b)."""
    if f.get("exclude", {}).get("currentEmployer") is False:
        return []
    return f.get("currentEmployerNames") or []


# ── 실행 ─────────────────────────────────────────────────────────────────────
def probe():
    print("== 소스 도달성 점검 ==")
    for name, cfg in SOURCES.items():
        if not cfg["url"]:
            print(f"  {name:12} {cfg['status']:8} (스크립트 조회 대상 아님) — {cfg['note']}")
            continue
        code, body = fetch(cfg["url"].format(q=urllib.parse.quote("생산기술")))
        print(f"  {name:12} {cfg['status']:8} HTTP {code} · {len(body):,}B")


def company_sweep(targets, excluded):
    """타깃 기업을 회사명으로 직접 조회. 3-상태로 기록한다.

    ★ `공고 0건(정상 응답)`과 `취득 실패`를 뭉뚱그리면 다음 라운드에 같은 곳을
      헛되이 다시 판다(jd-browsing §2-(2-c) ③-c).
    """
    found, ledger = [], []
    for name in targets:
        url = SOURCES["jobkorea"]["url"].format(q=urllib.parse.quote(name))
        code, body = fetch(url)
        if code != "200":
            ledger.append({"company": name, "state": "취득 실패", "http": code, "hits": 0})
            print(f"  {name:18} HTTP {code} → 취득 실패")
            continue
        rows = parse_jobkorea(body, excluded)
        exact = [r for r in rows if is_same_company(r, name)]
        for r in exact:
            r["company"] = name
        found += exact
        state = "공고 N건" if exact else "공고 0건(정상 응답)"
        ledger.append({"company": name, "state": state, "http": code, "hits": len(exact)})
        tail = "" if exact else "  → 자사 채용홈 확인 대상"
        print(f"  {name:18} HTTP {code} · 전체 {len(rows):3} → 본사 일치 {len(exact):2}{tail}")
    return found, ledger


def sweep(f, out_path):
    excluded = excluded_names(f)
    targets = f.get("targetCompanies") or []
    seen, results, coverage = set(), [], []

    print("== 보드 스윕 (쿼리 매트릭스) ==")
    for q in build_matrix(f):
        url = SOURCES["jobkorea"]["url"].format(q=urllib.parse.quote(q))
        code, body = fetch(url)
        rows = parse_jobkorea(body, excluded) if code == "200" else []
        fresh = [r for r in rows if r["id"] not in seen]
        for r in fresh:
            seen.add(r["id"])
            r["query"] = q
        results += fresh
        coverage.append({"source": "jobkorea", "query": q, "http": code,
                         "found": len(rows), "new": len(fresh)})
        print(f"  jobkorea · {q:22} HTTP {code} · {len(rows):3}건 (신규 {len(fresh):3})")

    print("\n== 타깃 기업 직접 조회 ==")
    comp_rows, comp_ledger = company_sweep(targets, excluded) if targets else ([], [])
    if not targets:
        print("  (필터에 targetCompanies 없음 — 기업 체크리스트는 미실행)")
    for r in comp_rows:
        if r["id"] not in seen:
            seen.add(r["id"])
            r["query"] = "company:" + r["company"]
            results.append(r)

    # 스크립트가 끝낼 수 없는 축을 **작업 목록으로** 남긴다 — 조용히 빠뜨리지 않기 위해.
    todo = []
    for e in comp_ledger:
        if e["state"] != "공고 N건":
            todo.append({"kind": "자사 채용홈", "company": e["company"],
                         "why": e["state"], "ladder": "§1-(2) 폴백 사다리 → 검색 엔진 회수"})
    for name, cfg in SOURCES.items():
        if cfg["status"] in ("blocked", "csr", "agent"):
            todo.append({"kind": "소스", "source": name, "why": cfg["status"], "note": cfg["note"]})

    out = {
        "generated": datetime.now(KST).strftime("%Y-%m-%d %H:%M KST"),
        "filter_schema": f.get("_schema"),
        "excluded_employers": excluded,
        "coverage_board": coverage,
        "coverage_company": comp_ledger,
        "agent_todo": todo,
        "results": results,
    }
    Path(out_path).write_text(json.dumps(out, ensure_ascii=False, indent=1), encoding="utf-8")

    blank = [c for c in coverage if c["http"] != "200"]
    no_post = [e for e in comp_ledger if e["state"] == "공고 0건(정상 응답)"]
    failed = [e for e in comp_ledger if e["state"] == "취득 실패"]
    print(f"\n총 {len(results)}건 · 보드 커버리지 {len(coverage)}칸 중 미취득 {len(blank)}칸")
    print(f"기업 체크리스트 {len(comp_ledger)}칸 — 공고 있음 {len(comp_ledger)-len(no_post)-len(failed)}"
          f" · 공고 0건 {len(no_post)} · 취득 실패 {len(failed)}")
    print(f"에이전트 작업 목록 {len(todo)}건 → {out_path}")
    if blank or failed:
        print("⚠️ 빈 칸이 남아 있으면 발굴은 끝난 게 아니다 (jd-browsing §2-(2-a) ⑤)")


def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("--filter", help="career/jd-filter@1 JSON 경로")
    ap.add_argument("--out", default="_discovery-results.json")
    ap.add_argument("--probe", action="store_true", help="소스 도달성만 점검")
    ap.add_argument("--ats", help="채용 페이지 URL에서 ATS 식별")
    a = ap.parse_args()

    if a.ats:
        r = detect_ats(a.ats)
        print(json.dumps(r, ensure_ascii=False, indent=1) if r
              else "알려진 ATS 패턴 아님 — §1-(2) 폴백 사다리로 직접 확인")
        return
    if a.probe:
        probe()
        return
    if not a.filter:
        ap.error("--filter 필요 (templates/jd-filter.html 의 [필터 복사] 출력)")
    sweep(load_filter(a.filter), a.out)


if __name__ == "__main__":
    main()
