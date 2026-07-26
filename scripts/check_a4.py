#!/usr/bin/env python3
"""A4 print-fidelity check (D-7b) for career skill document outputs.

Renders an HTML file to PDF with headless Chromium, then verifies with PyMuPDF:
  1. every page is A4 (595x842 pt, portrait) within tolerance
  2. no horizontal overflow / clipping (content bbox stays within printable area)
  3. reports page count

Usage: python3 scripts/check_a4.py <file.html> [out.pdf]
Exit 0 = PASS, 1 = FAIL.
"""
import pathlib
import shutil
import subprocess, sys, glob, os
try:
    import fitz
except ImportError:
    # ★ 이 게이트는 **건너뛰지 않는다**(A4 규격 이탈은 제출본 사고로 직결). 다만 맨 트레이스백은
    #   "코드 회귀"로 오독된다 — 새 컨테이너에서 6줄이 빨갛게 뜨는데 원인이 의존성이었다(실측).
    sys.exit("의존성 없음: PyMuPDF — `pip install -r scripts/requirements.txt` 후 다시 실행하세요.")

A4_W, A4_H = 595.0, 842.0          # points
TOL = 3.0                          # pt tolerance on page size
MARGIN_PT = 15 * 72 / 25.4         # 15mm ≈ 42.5pt (expected @page margin)
EDGE_SLACK = 6.0                   # allow content within a few pt of margin

def find_chrome():
    """Chromium 계열 실행 파일을 찾는다 (Linux / Windows / macOS).

    ★ which(1) 은 Windows 에 없고, Windows 의 Chrome·Edge 는 PATH 에 없는 것이 정상이다.
      Linux 경로만 뒤지면 Windows 에서 항상 'no chromium found' 로 죽는다(실측 2026-07).
    """
    for p in glob.glob("/opt/pw-browsers/chromium-*/chrome-linux/chrome"):
        return p
    for name in ("chromium", "chromium-browser", "google-chrome", "chrome",
                 "msedge", "microsoft-edge"):
        p = shutil.which(name)          # which(1) 의존 제거 — 전 OS 동작
        if p:
            return p
    for p in (r"C:\Program Files\Google\Chrome\Application\chrome.exe",
              r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
              r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
              r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
              "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
              "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge"):
        if os.path.exists(p):
            return p
    sys.exit("no chromium found — Linux: apt install chromium / Windows·macOS: Chrome 또는 Edge 설치")

def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    html = os.path.abspath(sys.argv[1])
    # 출력 미지정 시 임시 디렉터리에 생성한다(입력 옆에 PDF를 떨궈 저장소를 오염시키지 않기 위해).
    if len(sys.argv) > 2:
        pdf = os.path.abspath(sys.argv[2])
    else:
        import tempfile
        pdf = os.path.join(tempfile.mkdtemp(prefix="career_a4_"),
                           os.path.basename(html).rsplit(".", 1)[0] + ".pdf")
    chrome = find_chrome()
    subprocess.run([chrome, "--headless", "--disable-gpu", "--no-sandbox",
                    "--no-pdf-header-footer", f"--print-to-pdf={pdf}", pathlib.Path(html).as_uri()],
                   check=True, capture_output=True)
    doc = fitz.open(pdf)
    ok = True
    print(f"file: {os.path.basename(html)}  ->  {os.path.basename(pdf)}")
    print(f"pages: {len(doc)}")
    for i, page in enumerate(doc):
        w, h = page.rect.width, page.rect.height
        size_ok = abs(w - A4_W) <= TOL and abs(h - A4_H) <= TOL
        # content bounding box across text + drawings
        xs0, xs1 = [], []
        for b in page.get_text("blocks"):
            xs0.append(b[0]); xs1.append(b[2])
        min_x0 = min(xs0) if xs0 else MARGIN_PT
        max_x1 = max(xs1) if xs1 else w - MARGIN_PT
        overflow = max_x1 > (w - MARGIN_PT + EDGE_SLACK) or min_x0 < (MARGIN_PT - EDGE_SLACK)
        page_ok = size_ok and not overflow
        ok = ok and page_ok
        print(f"  p{i+1}: size={w:.0f}x{h:.0f}pt A4={'OK' if size_ok else 'FAIL'} | "
              f"content x=[{min_x0:.0f}..{max_x1:.0f}] (printable ~[{MARGIN_PT:.0f}..{w-MARGIN_PT:.0f}]) "
              f"overflow={'YES' if overflow else 'no'} -> {'PASS' if page_ok else 'FAIL'}")
    doc.close()
    print("RESULT:", "PASS" if ok else "FAIL")
    sys.exit(0 if ok else 1)

if __name__ == "__main__":
    main()
