#!/usr/bin/env python3
"""A4 print-fidelity check (D-7b) for career skill document outputs.

Renders an HTML file to PDF with headless Chromium, then verifies with PyMuPDF:
  1. every page is A4 (595x842 pt, portrait) within tolerance
  2. no horizontal overflow / clipping (content bbox stays within printable area)
  3. reports page count

Usage: python3 scripts/check_a4.py <file.html> [out.pdf]
Exit 0 = PASS, 1 = FAIL.
"""
import subprocess, sys, glob, os, fitz

A4_W, A4_H = 595.0, 842.0          # points
TOL = 3.0                          # pt tolerance on page size
MARGIN_PT = 15 * 72 / 25.4         # 15mm ≈ 42.5pt (expected @page margin)
EDGE_SLACK = 6.0                   # allow content within a few pt of margin

def find_chrome():
    for p in glob.glob("/opt/pw-browsers/chromium-*/chrome-linux/chrome"):
        return p
    for p in ("chromium", "chromium-browser", "google-chrome"):
        if subprocess.run(["which", p], capture_output=True).returncode == 0:
            return p
    sys.exit("no chromium found")

def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    html = os.path.abspath(sys.argv[1])
    pdf = os.path.abspath(sys.argv[2]) if len(sys.argv) > 2 else html.rsplit(".", 1)[0] + ".pdf"
    chrome = find_chrome()
    subprocess.run([chrome, "--headless", "--disable-gpu", "--no-sandbox",
                    "--no-pdf-header-footer", f"--print-to-pdf={pdf}", f"file://{html}"],
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
