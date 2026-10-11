#!/usr/bin/env python
"""Markdown -> HTML -> PDF (headless Chrome). No root needed.

    python build_pdf.py            # writes REPORT_BLOOD_TYPE_SUGARS_20261010.pdf
"""
import os, subprocess, shutil, sys
import markdown

HERE = os.path.dirname(os.path.abspath(__file__))
MD = os.path.join(HERE, "REPORT_BLOOD_TYPE_SUGARS_20261010.md")
HTML = os.path.join(HERE, "REPORT_BLOOD_TYPE_SUGARS_20261010.html")
PDF = os.path.join(HERE, "REPORT_BLOOD_TYPE_SUGARS_20261010.pdf")

CSS = """
@page { size: A4; margin: 18mm 16mm 18mm 16mm; }
body { font-family: "DejaVu Serif", Georgia, serif; font-size: 10.5pt; line-height: 1.42; color: #111; max-width: 100%; }
h1 { font-size: 20pt; margin: 0 0 6pt; border-bottom: 2px solid #333; padding-bottom: 4pt; }
h2 { font-size: 14pt; margin: 18pt 0 6pt; page-break-after: avoid; border-bottom: 1px solid #999; }
h3 { font-size: 11.5pt; margin: 12pt 0 4pt; page-break-after: avoid; }
p, li { orphans: 3; widows: 3; }
img { max-width: 100%; height: auto; display: block; margin: 8pt auto; page-break-inside: avoid; }
img[src*="fig_3d_"], img[src*="fig_gt"] { max-width: 62%; }
img[src*="SEM_blood"] { max-width: 70%; }
em { color: #333; }
table { border-collapse: collapse; width: 100%; font-size: 9pt; margin: 8pt 0; page-break-inside: avoid; }
th, td { border: 1px solid #bbb; padding: 3pt 5pt; vertical-align: top; text-align: left; }
th { background: #eee; }
code { font-family: "DejaVu Sans Mono", monospace; font-size: 9pt; background: #f3f3f3; padding: 0 2pt; }
a { color: #1a4a8a; text-decoration: none; }
hr { border: 0; border-top: 1px solid #aaa; margin: 14pt 0; }
blockquote { border-left: 3px solid #bbb; margin: 6pt 0; padding: 2pt 10pt; color: #333; }
"""

def main():
    body = markdown.markdown(open(MD, encoding="utf-8").read(), extensions=["tables", "fenced_code", "sane_lists"])
    html = f"<!doctype html><html><head><meta charset='utf-8'><title>Blood Type Sugars</title><style>{CSS}</style></head><body>{body}</body></html>"
    open(HTML, "w", encoding="utf-8").write(html)
    chrome = shutil.which("google-chrome") or shutil.which("chromium") or shutil.which("chromium-browser")
    if not chrome:
        print("HTML written; no Chrome found for PDF:", HTML); return 1
    cmd = [chrome, "--headless=new", "--disable-gpu", "--no-sandbox", "--no-pdf-header-footer",
           "--run-all-compositor-stages-before-draw", "--virtual-time-budget=10000",
           f"--print-to-pdf={PDF}", "file://" + HTML]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=180)
    if not os.path.exists(PDF):
        print(r.stdout[-2000:], r.stderr[-2000:]); return 1
    print("wrote", PDF, os.path.getsize(PDF) // 1024, "KB")
    return 0

if __name__ == "__main__":
    sys.exit(main())
