#!/usr/bin/env python3
# OWNER: skill
"""윤문 게이트의 결정적 검사기 — reference/polish-rulebook.md §5~§7의 구현체.

에이전트가 변경률·글자수·보존율을 **자가 산출하지 않게** 하는 것이 존재 이유다.
자가 산출하면 통과시키고 싶은 쪽으로 눈금이 휜다.

★ 무엇을 검사하고 무엇을 검사하지 않는가
  변경률은 **단독 중단 사유가 아니다.** 실측: "지원자 경험을 통째로 갈아엎는" 사고에서
  문자 변경률은 임계에 도달조차 않고, 반대로 이력서의 정상 작업인 종결 통일
  (`~을 개선하였습니다` → `~ 개선`)은 손쉽게 40%를 넘는다. 변경률만 보면
  **시킨 일을 중단시키고 진짜 사고는 놓친다.** 그래서 판정은 보존 지표가 맡는다.

사용:
  python3 scripts/check_polish.py --before A.txt --after B.txt --axis 자소서 \\
      [--limit 1000] [--limit-base with|no] [--keywords "공정개선,수율"]

종료: 0 통과 · 1 경고 · 2 중단(채택 금지) · 3 판정 불가(입력 부족 — 건너뛰지 않는다)
"""
import argparse
import difflib
import json
import re
import sys

# ── 임계 SSOT — polish-rulebook.md §7 표가 이 값을 인용한다(게이트가 대조) ──────
LEN_FLOOR_RATIO = 0.90      # 분량 하한 = 상한 × 이 값 (경고)
CHANGE_WARN = 0.50          # 변경률 경고 (중단 아님)
ENDING_FLOOR = 0.90         # 종결 일관성 하한 (경고)
PRESERVE_REQUIRED = 1.00    # 수치·고유명사·라벨 보존 (중단)

AXES = {"자소서": "자", "이력서KR": "력", "경력기술서": "력", "resume EN": "영", "cover EN": "영"}

# 출처 라벨·작업 마커 — 보존 대상이자, 분량 계수에서는 제외 대상
MARKER = re.compile(r"\[(?:T1|T2|T3|확인 필요|경계|미확인|보강|TODO)[^\]]*\]")
EXPID = re.compile(r"\bEXP-[\w-]+\b")
# 수치 원자: 숫자 + 단위/기호가 붙은 덩어리 (연도·비율·통화·배수·기간)
NUM = re.compile(r"\d[\d,.]*\s*(?:%|퍼센트|배|억|만원|만|원|천|건|명|년|개월|주|일|시간|분|초|㎜|㎝|㎡|㎏|㎞|x|X)?")


def strip_markers(s: str) -> str:
    """작업 마커·메타 주석 제거 — 분량과 변경률은 제출될 본문 기준으로 센다."""
    return MARKER.sub("", s)


def normalize_structural(s: str) -> str:
    """구조적 정규화 — 종결 형식·조사 차이를 변경률에서 제외한다.

    ★ 룰북 §6이 [력]에 종결 통일을 **강제**하는데, 그 작업의 문자 변경률이 40%를 넘어
      게이트가 시킨 일을 게이트가 막는 자기모순이 있었다. 정규화 후 비교로 끊는다.
    """
    s = re.sub(r"(하였|했)(습니다|음|다)\b", "핵", s)     # 종결 형식 차이 흡수
    s = re.sub(r"(입니다|이다|임)\b", "핵", s)
    s = re.sub(r"[을를이가은는의에서로]\s", " ", s)        # 조사 차이 흡수
    return re.sub(r"\s+", " ", s).strip()


def atoms(s: str):
    """보존해야 할 원자 — 수치·출처 라벨·EXP-ID."""
    body = s
    return {
        "수치": sorted(x.strip() for x in NUM.findall(body) if x.strip() and any(c.isdigit() for c in x)),
        "라벨": sorted(MARKER.findall(body)),
        "EXPID": sorted(EXPID.findall(body)),
    }


def ending_ratio(s: str):
    """합쇼체 비율. 분모에서 두괄식 주장·소제목·불릿·인용을 제외한다.

    ★ methodology §3은 '모든 문항 첫 문장은 서술이 아닌 강력한 주장'(명사구)을 **요구**한다.
      제외하지 않으면 규범을 정확히 지킨 자소서가 영구 보류된다 —
      600~800자 문항은 문장 8~12개라 명사구 주장 1개만으로 비율이 0.91로 떨어진다.
    """
    lines = [l.strip() for l in s.split("\n")]
    body = []
    for i, l in enumerate(lines):
        if not l:
            continue
        if l.startswith(("-", "*", "•", ">", "#")):      # 불릿·인용·헤딩
            continue
        if len(l) < 30 and not l.endswith((".", "다", "요")):  # 소제목·명사구 주장
            continue
        body.append(l)
    # ★ 문장 분리는 종결형에서만 끊는다. 예전엔 `다`·`요` 뒤 공백이면 무조건 끊어서
    #   "통념**보다** 측정을~"이 두 조각으로 갈렸고, 앞 조각이 합쇼체가 아니라는 이유로
    #   **규범을 지킨 자소서가 경고를 맞았다**(실측). 조사·부사의 `다`를 종결로 오인한 것이다.
    ENDING = r"(?:습니다|입니다|합니다|했다|한다|이다|였다|겠다|드립니다)"
    text = " ".join(body)
    text = re.sub(rf"({ENDING})([.!?]?)\s+", r"\1\2\n", text)
    text = re.sub(r"([.!?])\s+", r"\1\n", text)
    sents = [x for x in text.split("\n") if len(x.strip()) > 8]
    if len(sents) < 3:
        return None, 0                                   # 표본 부족 → 판정하지 않는다
    formal = sum(1 for x in sents if re.search(r"(습니다|입니다)\s*[.!?]?$", x.strip()))
    return formal / len(sents), len(sents)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--before"); ap.add_argument("--after")
    ap.add_argument("--axis", default="")
    ap.add_argument("--limit", type=int)
    ap.add_argument("--limit-base", choices=["with", "no"])
    ap.add_argument("--keywords", default="")
    a = ap.parse_args()

    if not a.after:
        print("판정 불가: --after 가 없습니다. 검사를 건너뛰지 말고 입력을 갖추세요.", file=sys.stderr)
        return 3

    after = open(a.after, encoding="utf-8").read()
    before = open(a.before, encoding="utf-8").read() if a.before else None
    axis = AXES.get(a.axis, "")
    rep, worst = {"axis": axis or "(미판정)"}, 0

    # ── 축 판정 (룰북 §1) ────────────────────────────────────────────────────
    if not axis:
        print("판정 불가: --axis 를 지정하세요 (자소서/이력서KR/resume EN/cover EN).\n"
              "  ★ 축을 추정하면 카탈로그가 통째로 빗나가 '티 없음'으로 오통과한다.", file=sys.stderr)
        return 3

    # ── 보존 지표 (룰북 §5) — 중단 사유는 여기뿐 ────────────────────────────
    if before is not None:
        b, af = atoms(before), atoms(after)
        for k in ("수치", "라벨", "EXPID"):
            lost = [x for x in b[k] if b[k].count(x) > af[k].count(x)]
            added = [x for x in af[k] if af[k].count(x) > b[k].count(x)]
            rep[f"{k}_소실"] = lost
            if k == "수치":
                rep["수치_신규삽입"] = added
                if added:
                    print(f"중단: 원문에 없는 수치가 결과에 있습니다 {added} — 윤문이 아니라 허위 기재입니다.",
                          file=sys.stderr)
                    worst = 2
            if lost:
                print(f"중단: {k} 원자가 사라졌습니다 {lost} — 의미 불변 위반.", file=sys.stderr)
                worst = 2

        # 변경률 — 참고값(경고만). 구조적 정규화 후 비교한다.
        nb, na = normalize_structural(strip_markers(before)), normalize_structural(strip_markers(after))
        rate = 1 - difflib.SequenceMatcher(None, nb, na).ratio()
        rep["변경률"] = round(rate, 3)
        if rate > CHANGE_WARN:
            print(f"경고: 변경률 {rate:.0%} — 원문이 많이 바뀌었습니다. "
                  f"보존 지표는 통과했으나 사람이 한 번 읽어보세요.", file=sys.stderr)
            worst = max(worst, 1)

    # ── 분량 예산 (룰북 §6) ─────────────────────────────────────────────────
    body = strip_markers(after)
    with_sp, no_sp = len(body), len(re.sub(r"\s", "", body))
    rep["글자수"] = {"공백포함": with_sp, "공백제외": no_sp}
    if a.limit:
        if not a.limit_base:
            print(f"판정 보류: 글자수 기준축(--limit-base)이 없습니다. "
                  f"공백포함 {with_sp}자 · 공백제외 {no_sp}자 — 공고 기준을 확인하세요.\n"
                  f"  ★ 한국어 자소서의 공백 비율은 20~25%라 **오판 폭이 밴드 폭(10%)보다 크다.** "
                  f"추정하면 밴드가 무의미해진다.", file=sys.stderr)
            worst = max(worst, 1)
        else:
            cur = no_sp if a.limit_base == "no" else with_sp
            rep["기준글자수"] = cur
            if cur > a.limit:
                print(f"중단: 상한 초과 {cur}/{a.limit}자 — 제출 불가입니다.", file=sys.stderr)
                worst = 2
            elif cur < a.limit * LEN_FLOOR_RATIO:
                print(f"경고: 분량 미달 {cur}/{a.limit}자 (하한 {int(a.limit*LEN_FLOOR_RATIO)}자). "
                      f"★ 증량 재료는 경험 뱅크의 사실로 한정하세요 — 상투구를 다시 심으면 안 됩니다.",
                      file=sys.stderr)
                worst = max(worst, 1)

    # ── 종결 일관성 (룰북 §7) — 경고만 ──────────────────────────────────────
    if axis == "자":
        r, n = ending_ratio(after)
        if r is not None:
            rep["종결일관성"] = {"비율": round(r, 3), "표본": n}
            if r < ENDING_FLOOR:
                print(f"경고: 합쇼체 일관성 {r:.0%} (표본 {n}문장) — 종결이 섞였는지 확인하세요. "
                      f"두괄식 명사구 주장·소제목·불릿은 이미 분모에서 제외했습니다.", file=sys.stderr)
                worst = max(worst, 1)

    # ── JD 키워드 보존 (룰북 §4 JD-6) — 경고 ────────────────────────────────
    kws = [k.strip() for k in a.keywords.split(",") if k.strip()]
    if kws:
        gone = [k for k in kws if k not in after]
        rep["키워드_소실"] = gone
        if gone:
            print(f"경고: JD 키워드가 결과에서 사라졌습니다 {gone} — ATS 매칭이 떨어집니다.", file=sys.stderr)
            worst = max(worst, 1)

    print(json.dumps(rep, ensure_ascii=False, indent=1))
    return worst


if __name__ == "__main__":
    raise SystemExit(main())
