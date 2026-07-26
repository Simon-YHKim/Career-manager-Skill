#!/usr/bin/env python3
# OWNER: skill
"""포트폴리오 HTML에 웹폰트를 서브셋해 내장한다 (외부 CDN 의존 제거).

문서에 실제로 쓰인 글자만 골라 폰트를 깎아 넣으므로 파일이 가볍고, 인터넷이
없거나 CDN이 막힌 환경에서도 레이아웃(=페이지 나눔)이 그대로 유지된다.

멱등(idempotent): 이미 내장된 파일에 다시 돌려도 된다. 기존 @font-face 블록을
걷어내고 현재 본문 글자 기준으로 다시 깎아 넣으므로, **내용을 수정할 때마다
재실행**하면 새로 등장한 글자까지 항상 포함된다.

사용: python3 scripts/embed_fonts.py <portfolio.html> [--font-dir <dir>]
      --font-dir 미지정 시 대상 HTML 옆의 fonts/ 를 쓴다.

★ 폰트 **파일은 이 저장소에 없다.** 경로를 인자로 받을 뿐이다 —
  폰트 바이너리는 각자의 라이선스를 따르는 자산(데이터)이고, 이 스크립트는 로직이다.
  Pretendard 사용 시 SIL Open Font License 1.1 고지 의무가 사용자에게 있다.

★ 폰트를 하나도 못 찾으면 **중단한다**(exit 2). 예전에는 조용히 건너뛰고 빈 <style>을
  써넣은 뒤 exit 0으로 끝났다 — 포트폴리오가 폰트를 잃었는데 아무도 몰랐다(실측 결함).
"""
import base64
import io
import re
import sys
from pathlib import Path

from fontTools.subset import Subsetter, Options
from fontTools.ttLib import TTFont

# 폰트 디렉터리는 인자로 받는다(교체 시험: 남의 워크스페이스에서도 그대로 동작해야 로직이다).
FONT_DIR = None

# CSS의 font-weight 값 → Pretendard 파일명
WEIGHTS = {
    300: "Light",
    400: "Regular",
    500: "Medium",
    600: "SemiBold",
    700: "Bold",
    800: "ExtraBold",
    900: "Black",
}

MARKER = "embedded-pretendard"


def visible_text(html: str) -> str:
    """화면에 렌더되는 텍스트만 뽑는다(style/script 제외)."""
    s = re.sub(r"<style[^>]*>.*?</style>", " ", html, flags=re.S | re.I)
    s = re.sub(r"<script[^>]*>.*?</script>", " ", s, flags=re.S | re.I)
    # CSS content: "..." 로 삽입되는 글자도 놓치지 않는다
    css = " ".join(re.findall(r"content:\s*['\"]([^'\"]*)['\"]", html))
    s = re.sub(r"<[^>]+>", " ", s)
    return s + " " + css


def strip_existing(html: str) -> str:
    """이전에 넣은 내장 블록과 CDN link 태그를 제거한다."""
    html = re.sub(
        rf'<style id="{MARKER}">.*?</style>\s*', "", html, flags=re.S | re.I
    )
    html = re.sub(r"<link[^>]*pretendard[^>]*>\s*", "", html, flags=re.I)
    return html


def subset_font(path: Path, chars: set) -> bytes:
    font = TTFont(str(path))
    opts = Options()
    opts.flavor = "woff2"
    opts.desubroutinize = True
    opts.layout_features = ["*"]          # 커닝·합자 유지 (자간이 틀어지면 페이지가 밀린다)
    opts.notdef_outline = True
    opts.recalc_bounds = True
    sub = Subsetter(options=opts)
    sub.populate(unicodes={ord(c) for c in chars})
    sub.subset(font)
    buf = io.BytesIO()
    font.flavor = "woff2"
    font.save(buf)
    return buf.getvalue()


def main() -> int:
    global FONT_DIR
    args = [a for a in sys.argv[1:]]
    fd = None
    if "--font-dir" in args:
        i = args.index("--font-dir")
        if i + 1 >= len(args):
            sys.exit("--font-dir 에 경로가 없습니다")
        fd = Path(args[i + 1]); del args[i:i + 2]
    if not args:
        sys.exit(__doc__)
    target = Path(args[0])
    # 미지정 시 대상 HTML 옆의 fonts/ — 폰트는 문서와 함께 사는 자산이다
    FONT_DIR = fd if fd else target.parent / "fonts"
    html = target.read_text(encoding="utf-8")
    html = strip_existing(html)

    # 본문 글자 + 라틴/기호 여유분(나중에 한두 글자 고쳐도 폰트가 안 깨지도록)
    chars = set(visible_text(html))
    chars |= set(chr(c) for c in range(0x20, 0x7F))
    chars |= set("₩€$£·…—–‘’“”→←↑↓●○■□▲▼★☆©®™°±×÷≈≤≥%‰㎜㎝㎡㎏㎞")
    # 폰트에 없는 글자(이모지 등)는 subsetter가 알아서 무시한다
    chars = {c for c in chars if c.strip() or c == " "}

    faces, total, found = [], 0, 0
    for weight, name in WEIGHTS.items():
        src = FONT_DIR / f"{name}.woff2"
        if not src.exists():
            continue
        found += 1
        data = subset_font(src, chars)
        total += len(data)
        b64 = base64.b64encode(data).decode("ascii")
        faces.append(
            "@font-face{font-family:'Pretendard';font-style:normal;"
            f"font-weight:{weight};font-display:block;"
            f"src:url(data:font/woff2;base64,{b64}) format('woff2');}}"
        )
        print(f"  {name:<10} weight {weight}  {len(data)/1024:7.1f} KB")

    if not found:
        print(f"중단: {FONT_DIR} 에서 폰트를 하나도 찾지 못했습니다 "
              f"(찾는 이름: {', '.join(WEIGHTS.values())}.woff2).\n"
              f"      --font-dir 로 폰트 디렉터리를 지정하세요. 대상 파일은 수정하지 않았습니다.",
              file=sys.stderr)
        return 2

    block = f'<style id="{MARKER}">' + "".join(faces) + "</style>"
    if "</head>" in html:
        html = html.replace("</head>", block + "\n</head>", 1)
    else:
        html = block + html

    target.write_text(html, encoding="utf-8")
    print(f"\n글자 {len(chars)}자 · 폰트 {total/1024:.0f} KB 내장")
    print(f"→ {target}  ({target.stat().st_size/1024:.0f} KB)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
