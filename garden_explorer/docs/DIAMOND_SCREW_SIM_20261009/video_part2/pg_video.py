#!/usr/bin/env python3
"""Hume v. Spock — pygame renderer (Part Two).

Reuses build_video.py for the fable parser (shots), voices and ElevenLabs TTS; renders every frame with pygame
(LineGuard style) instead of one still per shot:

  * backdrop plates (plates/*.png, gpt-image-1, places only) with a slow push-in, or
  * an animated "contrivance" demo (mercury tube, hill, thermometer, applanation, gold brick, circuit, lead, orbit,
    rope trick, parallax, glove, noise ...) keyed to the spoken line,
  * geometry puppets for the speakers — scribbled faces, arms rotated in animation while they speak,
  * a ledger column (Widukind in his alcove, colour cycling per shot) that accumulates the receipts as they are spoken,
  * a caption band with the exact spoken text.

  pg_video.py preview [S012,S160]      one PNG per listed shot (default: a spread) → preview/
  pg_video.py demos                     one PNG per demo at mid-animation → preview/demos/
  pg_video.py render [--jobs 4] [--fps 30]   full video → fable_hume_v_spock_pg.mp4
"""
import os, sys, math, json, wave, random, subprocess, re, itertools
import concurrent.futures as cf
os.environ.setdefault("SDL_VIDEODRIVER", "dummy"); os.environ.setdefault("SDL_AUDIODRIVER", "dummy")
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import build_video as bv
import pygame
from pygame import gfxdraw

S = bv.S; AUD = bv.AUD
PLATES = os.path.join(HERE, "plates"); PARTS = os.path.join(HERE, "parts"); PREV = os.path.join(HERE, "preview")
OUT_MP4 = os.path.join(HERE, "fable_hume_v_spock_pg.mp4")
W, H = 1920, 1080; SW, SH = 1440, 900; LX = SW; CAP_Y = SH
FPS = 30

# ───────────────────────── palette: dark greens, magentas, crimsons, some orange ─────────────────────────
BG = (7, 12, 9); STAGE = (10, 18, 13); GREEN = (28, 96, 58); DKGREEN = (14, 46, 30); MOSS = (60, 110, 70)
MAG = (176, 32, 124); CRIM = (158, 24, 44); PLUM = (88, 30, 72); ORANGE = (236, 124, 32); AMBER = (214, 156, 44)
PARCH = (222, 212, 190); CREAM = (240, 230, 205); MUTED = (150, 140, 125); FAINT = (60, 70, 62); INK = (8, 6, 10)
HG = (178, 186, 196); HG2 = (120, 128, 140); AU = (222, 172, 48); AU2 = (150, 110, 24); PB = (96, 100, 112); GLASS = (120, 170, 150)
WHITE = (236, 236, 230)
CYCLE = [bv.RGB[c] for c in bv.DARK_CYCLE] if hasattr(bv, "RGB") else [MAG, GREEN, PLUM, CRIM, DKGREEN, AMBER]

FONT_SERIF = bv.FONT_SERIF; FONT_ITAL = bv.FONT_ITAL; FONT_TYPE = bv.FONT_HAND
_fc = {}
def font(path_or_name, size, bold=False):
    k = (path_or_name, size, bold)
    if k not in _fc:
        if path_or_name and os.path.exists(path_or_name): _fc[k] = pygame.font.Font(path_or_name, size)
        else: _fc[k] = pygame.font.SysFont(path_or_name or "dejavusans", size, bold=bold)
    return _fc[k]
def F_CAP(): return font(FONT_SERIF, 36)
def F_NAME(): return font(FONT_ITAL, 30)
def F_TITLE(): return font(FONT_SERIF, 64)
def F_SEC(): return font(FONT_ITAL, 26)
def F_TYPE(sz=20): return font(FONT_TYPE, sz)
def F_LAB(sz=24, bold=False): return font("dejavusans", sz, bold)

# ───────────────────────── characters → puppets ─────────────────────────
# colour, hat/hair, prop
PUP = {
 "FEYNMAN": ((70, 90, 120), "none", "lighter"), "McCLANE": ((214, 208, 196), "none", "barefoot"), "WIDUKIND": ((96, 70, 44), "hood", "typewriter"),
 "HUME": ((122, 60, 44), "wig", "book"), "SPOCK": ((28, 70, 150), "ears", None), "KIRK": ((200, 150, 30), "none", None),
 "EARS": ((60, 60, 70), "ears", None), "VOICE": ((60, 60, 70), "none", None), "TEACHER": ((90, 70, 110), "bun", "clipboard"), "KIDS": ((120, 60, 90), "none", "kid"),
 "CHAUFFEUR": ((70, 70, 70), "cap", None), "TORRICELLI": ((60, 80, 60), "none", "tube"), "PERIER": ((80, 70, 50), "hat", "tube"), "FAHRENHEIT": ((60, 60, 80), "wig", "thermo"),
 "CELSIUS": ((50, 70, 90), "wig", None), "GOLDMANN": ((60, 80, 90), "none", "brass"), "LEVERRIER": ((40, 40, 60), "none", "pencil"), "LESCARBAULT": ((90, 80, 60), "hat", "scope"),
 "EINSTEIN": ((80, 80, 90), "spikes", None), "NEWTON": ((90, 60, 60), "curls", "prism"), "OPPENHEIMER": ((60, 60, 60), "hat", None), "PLUTARCH": ((200, 190, 170), "wreath", None),
 "ARCHIMEDES": ((190, 170, 130), "none", "sand"), "ARISTARCHUS": ((0, 0, 0), "none", "chair"), "BESSEL": ((50, 60, 80), "none", None), "BRUNO": ((20, 10, 10), "none", "flame"),
 "GALILEO": ((80, 60, 50), "none", None), "COPERNICUS": ((70, 40, 60), "none", "book"), "AQUINAS": ((230, 225, 215), "hood", None), "KANT": ((110, 100, 90), "wig", None),
 "TESLA": ((40, 40, 50), "none", "spark"), "RONTGEN": ((60, 60, 60), "none", None), "SPENCER": ((70, 70, 80), "none", None), "MARCONI": ((50, 50, 60), "none", None),
 "RIEBEECK": ((60, 50, 40), "hat", "ledger"), "AUTSHUMATO": ((140, 90, 50), "none", None), "KIDD": ((90, 40, 40), "hat", None), "BILLY": ((110, 90, 60), "hat", None),
 "DINGANE": ((120, 60, 40), "none", None), "KAMEHAMEHA": ((200, 160, 60), "crown", None), "JUSTINIAN": ((110, 40, 110), "crown", None), "JAKOB": ((50, 50, 50), "none", "book"),
 "WILHELM": ((90, 60, 70), "none", "book"), "HORDE": ((60, 20, 20), "none", None), "NARRATOR": ((60, 60, 60), "none", None),
}
GALLERY = {"EARS", "VOICE", "TEACHER", "KIDS", "CHAUFFEUR", "OPPENHEIMER", "GALILEO", "COPERNICUS", "KAMEHAMEHA", "BILLY", "HORDE", "JAKOB", "WILHELM", "KIRK"}
DISPLAY = dict(bv.DISPLAY); DISPLAY.update({"NARRATOR": "", "RONTGEN": "Röntgen", "LEVERRIER": "Le Verrier", "PERIER": "Périer"})
def disp(who): return DISPLAY.get(who, (who or "").title())

def ease(x): x = max(0.0, min(1.0, x)); return x * x * (3 - 2 * x)
def lerp(a, b, t): return a + (b - a) * t
def mix(c1, c2, t): return tuple(int(lerp(c1[i], c2[i], t)) for i in range(3))
def dim(c, f): return tuple(int(v * f) for v in c)

_scrib = {}
def scribble(name):
    if name not in _scrib:
        r = random.Random(hash(name) & 0xffff); _scrib[name] = [(r.uniform(-.55, .55), r.uniform(-.5, .4), r.uniform(-.55, .55), r.uniform(-.5, .4)) for _ in range(9)]
    return _scrib[name]

def puppet(surf, who, x, y, sc=1.0, t=0.0, speaking=False, face=1, colour=None):
    """Simple geometry figure standing with feet at (x,y). Arms rotate around the shoulders while speaking."""
    col, hat, prop = PUP.get(who, PUP["NARRATOR"]); col = colour or col
    if who == "ARISTARCHUS":  # an empty chair
        pygame.draw.rect(surf, (90, 60, 40), (x - 40 * sc, y - 120 * sc, 80 * sc, 14 * sc)); pygame.draw.rect(surf, (90, 60, 40), (x - 40 * sc, y - 230 * sc, 14 * sc, 120 * sc))
        for dx in (-34, 26): pygame.draw.rect(surf, (90, 60, 40), (x + dx * sc, y - 110 * sc, 10 * sc, 110 * sc))
        return
    hw = 46 * sc; th = 170 * sc; hr = 34 * sc; hy = y - th - 40 * sc - hr
    sway = math.sin(t * 1.3) * 2 * sc
    legc = dim(col, 0.6)
    for dx in (-18, 18):
        pygame.draw.line(surf, legc, (x + dx * sc, y - 120 * sc), (x + dx * sc + (0 if prop != "barefoot" else 0), y), int(14 * sc))
        if prop == "barefoot": pygame.draw.ellipse(surf, (210, 180, 150), (x + dx * sc - 16 * sc, y - 10 * sc, 34 * sc, 14 * sc))
        else: pygame.draw.ellipse(surf, INK, (x + dx * sc - 16 * sc, y - 10 * sc, 34 * sc, 14 * sc))
    body = [(x - hw + sway, y - th - 40 * sc), (x + hw + sway, y - th - 40 * sc), (x + hw * 0.8, y - 110 * sc), (x - hw * 0.8, y - 110 * sc)]
    if who == "BRUNO":
        for i in range(3):
            fl = [(x + math.sin(t * 7 + i) * 18 * sc, hy - (90 + 40 * i) * sc), (x - 70 * sc, y - 40 * sc), (x + 70 * sc, y - 40 * sc)]
            pygame.draw.polygon(surf, mix(ORANGE, CRIM, i / 2), fl)
    pygame.draw.polygon(surf, col, body)
    if who == "HUME": pygame.draw.ellipse(surf, col, (x - hw * 1.1, y - th - 20 * sc, hw * 2.2, th * 0.75))
    if who == "KIRK": pygame.draw.circle(surf, (230, 200, 60), (int(x - 22 * sc), int(y - th - 10 * sc)), int(7 * sc))
    if who == "SPOCK": pygame.draw.polygon(surf, (40, 90, 170), [(x - hw, y - th - 40 * sc), (x + hw, y - th - 40 * sc), (x, y - th + 20 * sc)])
    # arms: shoulder at (±hw, shoulder_y); upper arm then forearm, rotated by animation
    sy = y - th - 30 * sc; L1, L2 = 62 * sc, 58 * sc
    for side in (-1, 1):
        sx = x + side * hw * 0.9 + sway
        # angles from straight-down; positive = rotated outward from the body on that side
        if speaking and side == face:
            a1 = 1.1 + math.sin(t * 3.1) * 0.35; a2 = 0.6 + math.sin(t * 3.1 + 1.2) * 0.7
        elif speaking:
            a1 = 0.25 + math.sin(t * 2.2 + 2) * 0.12; a2 = -0.5 + math.sin(t * 2.2) * 0.25
        else:
            a1 = 0.08 + math.sin(t * 1.3 + side) * 0.04; a2 = -0.15
        if prop == "typewriter":
            a1 = 0.55 + math.sin(t * 9 + side) * 0.05; a2 = -1.5 + math.sin(t * 9 + side * 1.7) * 0.25
        ex = sx + side * math.sin(a1) * L1; ey = sy + math.cos(a1) * L1
        hx = ex + side * math.sin(a1 + a2) * L2; hy2 = ey + math.cos(a1 + a2) * L2
        pygame.draw.line(surf, col, (sx, sy), (ex, ey), int(13 * sc)); pygame.draw.line(surf, col, (ex, ey), (hx, hy2), int(11 * sc))
        pygame.draw.circle(surf, dim(col, 1.25) if max(col) < 200 else col, (int(hx), int(hy2)), int(8 * sc))
        if side == face and prop:
            if prop == "lighter": pygame.draw.rect(surf, (120, 120, 130), (hx - 6 * sc, hy2 - 22 * sc, 12 * sc, 22 * sc)); pygame.draw.polygon(surf, ORANGE, [(hx, hy2 - 48 * sc - math.sin(t * 12) * 4 * sc), (hx - 6 * sc, hy2 - 24 * sc), (hx + 6 * sc, hy2 - 24 * sc)])
            elif prop in ("book", "ledger", "clipboard"): pygame.draw.rect(surf, (120, 80, 50) if prop != "clipboard" else (170, 150, 120), (hx - 16 * sc, hy2 - 22 * sc, 32 * sc, 44 * sc))
            elif prop in ("tube", "thermo"): pygame.draw.rect(surf, GLASS, (hx - 4 * sc, hy2 - 70 * sc, 8 * sc, 90 * sc)); pygame.draw.rect(surf, HG, (hx - 3 * sc, hy2 - 30 * sc, 6 * sc, 50 * sc))
            elif prop == "scope": pygame.draw.rect(surf, (120, 100, 60), (hx - 8 * sc, hy2 - 40 * sc, 16 * sc, 60 * sc))
            elif prop == "pencil": pygame.draw.line(surf, AMBER, (hx, hy2), (hx + 30 * sc * side, hy2 - 30 * sc), int(5 * sc))
            elif prop == "prism": pygame.draw.polygon(surf, GLASS, [(hx, hy2 - 30 * sc), (hx - 18 * sc, hy2 + 4 * sc), (hx + 18 * sc, hy2 + 4 * sc)])
            elif prop == "brass": pygame.draw.circle(surf, AMBER, (int(hx), int(hy2 - 14 * sc)), int(12 * sc))
            elif prop == "spark":
                for k in range(5): pygame.draw.line(surf, (200, 220, 255), (hx, hy2), (hx + math.cos(t * 20 + k) * 30 * sc, hy2 - abs(math.sin(t * 17 + k)) * 40 * sc), 2)
    # head
    pygame.draw.circle(surf, dim(col, 0.9) if who not in ("BRUNO",) else INK, (int(x + sway), int(hy)), int(hr))
    if who != "BRUNO":
        for (a, b, c, d) in scribble(who):  # scratched-out face
            pygame.draw.line(surf, INK, (x + sway + a * hr, hy + b * hr), (x + sway + c * hr, hy + d * hr), max(1, int(2 * sc)))
    if hat == "wig":
        for side in (-1, 1): pygame.draw.ellipse(surf, (225, 222, 215), (x + sway + side * hr * 0.9 - hr * 0.35, hy - hr * 0.6, hr * 0.7, hr * 1.7))
        pygame.draw.arc(surf, (225, 222, 215), (x + sway - hr, hy - hr * 1.05, hr * 2, hr * 1.4), 0, math.pi, int(8 * sc))
    elif hat == "hood": pygame.draw.polygon(surf, dim(col, 0.8), [(x + sway - hr * 1.3, hy + hr * 0.6), (x + sway, hy - hr * 1.5), (x + sway + hr * 1.3, hy + hr * 0.6)])
    elif hat == "ears":
        for side in (-1, 1): pygame.draw.polygon(surf, dim(col, 0.9), [(x + sway + side * hr * 0.85, hy + hr * 0.2), (x + sway + side * hr * 0.75, hy - hr * 0.5), (x + sway + side * hr * 1.35, hy - hr * 0.9)])
    elif hat == "spikes":
        for k in range(9): a = math.pi * (0.1 + 0.8 * k / 8); pygame.draw.line(surf, (225, 225, 225), (x + sway + math.cos(a) * hr * 0.9, hy - math.sin(a) * hr * 0.9), (x + sway + math.cos(a) * hr * 1.6, hy - math.sin(a) * hr * 1.6), int(5 * sc))
    elif hat == "curls":
        for side in (-1, 1):
            for k in range(4): pygame.draw.circle(surf, (210, 205, 200), (int(x + sway + side * hr * 1.05), int(hy - hr * 0.3 + k * hr * 0.55)), int(hr * 0.33))
    elif hat == "hat": pygame.draw.rect(surf, INK, (x + sway - hr * 1.3, hy - hr * 0.9, hr * 2.6, hr * 0.25)); pygame.draw.rect(surf, INK, (x + sway - hr * 0.8, hy - hr * 1.8, hr * 1.6, hr))
    elif hat == "cap": pygame.draw.rect(surf, (50, 50, 55), (x + sway - hr, hy - hr * 1.1, hr * 2, hr * 0.5)); pygame.draw.rect(surf, (50, 50, 55), (x + sway - hr * 1.3, hy - hr * 0.65, hr * 1.4, hr * 0.18))
    elif hat == "bun": pygame.draw.circle(surf, (70, 50, 40), (int(x + sway), int(hy - hr * 1.1)), int(hr * 0.45))
    elif hat == "crown":
        pts = [(x + sway - hr, hy - hr * 0.6)] + [(x + sway - hr + k * hr * 0.5, hy - hr * (1.6 if k % 2 else 1.0)) for k in range(5)] + [(x + sway + hr, hy - hr * 0.6)]
        pygame.draw.polygon(surf, AMBER, pts)
    elif hat == "wreath": pygame.draw.arc(surf, MOSS, (x + sway - hr * 1.05, hy - hr * 1.05, hr * 2.1, hr * 2.1), 0.2, math.pi - 0.2, int(7 * sc))

# ───────────────────────── drawing helpers ─────────────────────────
def label(surf, text, x, y, color=CREAM, size=24, center=False, bold=False, f=None):
    r = (f or F_LAB(size, bold)).render(text, True, color); surf.blit(r, (x - r.get_width() // 2 if center else x, y)); return r.get_width()
def arrow(surf, a, b, color, wid=3, head=14):
    pygame.draw.line(surf, color, a, b, wid); ang = math.atan2(b[1] - a[1], b[0] - a[0])
    for da in (0.5, -0.5): pygame.draw.line(surf, color, b, (b[0] - head * math.cos(ang + da), b[1] - head * math.sin(ang + da)), wid)
def typeable(t):
    """Special Elite lacks a few glyphs; type them the way a typewriter would."""
    for a, b in (("→", "->"), ("″", '"'), ("µ", "u"), ("½", "1/2"), ("ʻ", "'"), ("ī", "i"), ("ō", "o"), ("ꜣ", "a"), ("ḥ", "h"), ("ḫ", "kh"), ("−", "-"), ("∞", "inf"), ("·", "-"), ("—", "--")):
        t = t.replace(a, b)
    return t
def desk_typewriter(surf, x, y, sc):
    """A small desk with a typewriter drawn in front of a standing puppet so he appears seated at it (feet at (x,y))."""
    pygame.draw.rect(surf, (52, 36, 26), (x - 105 * sc, y - 118 * sc, 210 * sc, 14 * sc)); pygame.draw.rect(surf, (40, 28, 20), (x - 95 * sc, y - 104 * sc, 190 * sc, 104 * sc))
    pygame.draw.rect(surf, (40, 40, 46), (x - 50 * sc, y - 164 * sc, 100 * sc, 48 * sc)); pygame.draw.rect(surf, (70, 70, 78), (x - 58 * sc, y - 136 * sc, 116 * sc, 10 * sc))
    for k in range(3):
        for j in range(7): pygame.draw.circle(surf, (120, 120, 126), (int(x - 36 * sc + j * 12 * sc + (k % 2) * 6 * sc), int(y - 156 * sc + k * 9 * sc)), max(1, int(3 * sc)))
def wrap(text, f, maxw):
    out, line = [], ""
    for w_ in text.split():
        t = (line + " " + w_).strip()
        if f.size(t)[0] > maxw and line: out.append(line); line = w_
        else: line = t
    if line: out.append(line)
    return out
def flame(surf, x, y, size, t, k=0):
    for i, (c, s) in enumerate(((CRIM, 1.0), (ORANGE, 0.72), ((255, 220, 120), 0.4))):
        w = size * s * (0.9 + 0.1 * math.sin(t * 13 + i + k)); h = size * 2.2 * s * (0.9 + 0.15 * math.sin(t * 9 + i * 2 + k))
        pygame.draw.polygon(surf, c, [(x, y - h), (x - w * 0.5, y - h * 0.35), (x - w * 0.35, y), (x + w * 0.35, y), (x + w * 0.5, y - h * 0.35)])
def glass_tube(surf, x, y, w, h, frac, fill=HG, closed_top=True, color=GLASS):
    pygame.draw.rect(surf, (18, 30, 26), (x, y, w, h)); fh = int(h * max(0, min(1, frac)))
    pygame.draw.rect(surf, fill, (x + 3, y + h - fh, w - 6, fh))
    pygame.draw.rect(surf, color, (x, y, w, h), 3)
    if not closed_top: pygame.draw.line(surf, (18, 30, 26), (x + 3, y), (x + w - 3, y), 3)
def dish(surf, x, y, w, h, fill=HG):
    pygame.draw.ellipse(surf, (40, 36, 30), (x - w // 2, y - h // 2, w, h)); pygame.draw.ellipse(surf, fill, (x - w // 2 + 8, y - h // 2 + 6, w - 16, h - 12))
def ticks(surf, x, y0, y1, n, color=MUTED, right=True, every=1):
    for k in range(n + 1):
        yy = y0 + (y1 - y0) * k / n; l_ = 14 if k % 5 == 0 else 8
        pygame.draw.line(surf, color, (x, yy), (x + (l_ if right else -l_), yy), 2)
def panel_bg(surf, plate_name, alpha=70):
    p = plate(plate_name)
    if p is not None:
        tmp = p.copy(); tmp.set_alpha(alpha); surf.blit(tmp, (0, 0))
def grid(surf, x, y, w, h, step=60, color=(20, 40, 30)):
    for gx in range(x, x + w, step): pygame.draw.line(surf, color, (gx, y), (gx, y + h), 1)
    for gy in range(y, y + h, step): pygame.draw.line(surf, color, (x, gy), (x + w, gy), 1)
def dashed_circle(surf, c, r, color, n=48, wid=2):
    for k in range(0, n, 2):
        a0, a1 = 2 * math.pi * k / n, 2 * math.pi * (k + 1) / n
        pygame.draw.line(surf, color, (c[0] + r * math.cos(a0), c[1] + r * math.sin(a0)), (c[0] + r * math.cos(a1), c[1] + r * math.sin(a1)), wid)
def sun(surf, c, r, t):
    for k in range(6, 0, -1): pygame.draw.circle(surf, mix(STAGE, CRIM, 0.25 * (7 - k) / 6), c, int(r * (1 + 0.12 * k + 0.02 * math.sin(t * 2 + k))))
    pygame.draw.circle(surf, CRIM, c, r); pygame.draw.circle(surf, ORANGE, c, int(r * 0.82)); pygame.draw.circle(surf, (255, 200, 110), c, int(r * 0.5))

_plates = {}
def plate(name):
    if name not in _plates:
        p = os.path.join(PLATES, name + ".png")
        if not os.path.exists(p): _plates[name] = None
        else:
            im = pygame.image.load(p).convert(); iw, ih = im.get_size(); s = max(SW / iw, SH / ih)
            im = pygame.transform.smoothscale(im, (int(iw * s) + 1, int(ih * s) + 1)); _plates[name] = im
    return _plates[name]
_zoom = {}
def plate_zoomed(name, z, cx=0.5, cy=0.5):
    """Backdrop pushed in by factor z about (cx,cy) in plate units."""
    p = plate(name)
    if p is None: return None
    zq = round(z, 3); k = (name, zq, round(cx, 2), round(cy, 2))
    if k not in _zoom:
        if len(_zoom) > 400: _zoom.clear()
        pw, ph = p.get_size(); cw, ch = int(pw / zq), int(ph / zq)
        x0 = int(min(max(0, pw * cx - cw / 2), pw - cw)); y0 = int(min(max(0, ph * cy - ch / 2), ph - ch))
        sub = p.subsurface((x0, y0, cw, ch)); _zoom[k] = pygame.transform.smoothscale(sub, (SW, SH))
    return _zoom[k]

# ───────────────────────── demos (the contrivances) ─────────────────────────
# each demo(surf, tt, st, sd, ctx): tt = seconds since demo started, st = seconds into this shot, sd = shot duration
def d_scale(surf, tt, st, sd, ctx):
    panel_bg(surf, "lab_bench", 60); cx, cy = 720, 560; tilt = -0.2 * ease(tt / 2.5)
    pygame.draw.polygon(surf, (80, 70, 60), [(cx, cy), (cx - 50, cy + 160), (cx + 50, cy + 160)]); pygame.draw.rect(surf, (60, 50, 40), (cx - 260, cy + 160, 520, 18))
    L = 360; ax, ay = cx - L * math.cos(tilt), cy - L * math.sin(tilt); bx, by = cx + L * math.cos(tilt), cy + L * math.sin(tilt)
    pygame.draw.line(surf, (150, 130, 90), (ax, ay), (bx, by), 12); pygame.draw.circle(surf, AMBER, (cx, cy), 14)
    for (px, py, side) in ((ax, ay, -1), (bx, by, 1)):
        for dx in (-70, 70): pygame.draw.line(surf, (120, 110, 90), (px, py), (px + dx, py + 150), 2)
        pygame.draw.ellipse(surf, (90, 80, 60), (px - 90, py + 140, 180, 36))
        if side == -1:  # mercury: a wobbling blob
            pygame.draw.ellipse(surf, HG, (px - 60 - 4 * math.sin(tt * 3), py + 100 - 4 * math.cos(tt * 3), 120 + 8 * math.sin(tt * 3), 60)); label(surf, "Hg  13.5 g/cm³", px, py + 190, HG, 26, True)
        else:
            pygame.draw.rect(surf, AU, (px - 55, py + 85, 110, 66)); pygame.draw.rect(surf, AU2, (px - 55, py + 85, 110, 66), 3); label(surf, "Au  19.3 g/cm³", px, py + 190, AU, 26, True)
    label(surf, "the most basic measurement there is: a balance and two lumps", 720, 150, PARCH, 30, True)
    label(surf, "any goldsmith's apprentice · Archimedes had it in a bathtub", 720, 195, MUTED, 24, True)

def d_torricelli(surf, tt, st, sd, ctx):
    panel_bg(surf, "lab_bench", 60); cx = 640; floor = 760
    dish(surf, cx, floor, 300, 70)
    tube_h = 420; tw = 44
    if tt < 3.0:   # filling the upright tube
        frac = ease(tt / 3.0); x, y = cx - tw // 2, floor - 90 - tube_h
        glass_tube(surf, x, y, tw, tube_h, frac, closed_top=False); label(surf, "fill a glass tube with quicksilver", 720, 120, PARCH, 30, True)
    elif tt < 4.6:  # flip it
        q = ease((tt - 3.0) / 1.6); a = math.pi * q; mx, my = cx, floor - 90 - tube_h / 2 + 70 * q
        pts = [(-tw / 2, -tube_h / 2), (tw / 2, -tube_h / 2), (tw / 2, tube_h / 2), (-tw / 2, tube_h / 2)]
        rot = [(mx + px * math.cos(a) - py * math.sin(a), my + px * math.sin(a) + py * math.cos(a)) for px, py in pts]
        pygame.draw.polygon(surf, HG, rot); pygame.draw.polygon(surf, GLASS, rot, 3); label(surf, "invert it in the dish", 720, 120, PARCH, 30, True)
    else:
        drop = ease((tt - 4.6) / 2.2); x, y = cx - tw // 2, floor - 20 - tube_h
        col_frac = 1 - 0.24 * drop  # 100 cm tube → 76 cm column
        glass_tube(surf, x, y, tw, tube_h, col_frac, closed_top=True)
        top = y + tube_h * (1 - col_frac)
        if drop > 0.3:
            label(surf, "nothing", x + 70, y + 20, MUTED, 26); arrow(surf, (x + 70, y + 60), (x + tw + 8, top - 10), MUTED, 2, 10)
        label(surf, "76 cm", x + 70, top + 10, HG, 30, bold=True)
        ticks(surf, x - 4, floor - 20, floor - 20 - tube_h, 20, right=False)
        for k in range(6):  # the weight of the air pressing on the dish
            ax = cx - 190 + k * 76
            if abs(ax - cx) < 40: continue
            yy = floor - 160 + 30 * math.sin(tt * 3 + k); arrow(surf, (ax, yy - 50), (ax, yy), mix(GREEN, CREAM, 0.4), 3, 10)
        label(surf, "the weight of the air", 1040, 420, mix(GREEN, CREAM, 0.5), 28); label(surf, "holds up 76 cm of mercury", 1040, 456, MUTED, 24)
        label(surf, "Torricelli, 1643", 1040, 540, PARCH, 30); label(surf, "refutable? carry it up a hill", 1040, 580, MUTED, 24)

def d_hill(surf, tt, st, sd, ctx):
    panel_bg(surf, "mountain", 110)
    base = 820; pts = [(0, base), (120, 700), (300, 640), (520, 520), (760, 380), (900, 330), (1020, 340), (1150, 420), (1300, 560), (1440, 640), (1440, 900), (0, 900)]
    pygame.draw.polygon(surf, (16, 34, 24), pts)
    p = ease(min(1, tt / max(6.0, sd * 0.9)))  # climb over the shot
    path = pts[:6]; i = min(len(path) - 2, int(p * (len(path) - 1))); f = p * (len(path) - 1) - i
    px, py = lerp(path[i][0], path[i + 1][0], f) + 60, lerp(path[i][1], path[i + 1][1], f)
    puppet(surf, "PERIER", px, py, 0.55, tt, speaking=False, face=1)
    # gauge: the column falls 8 cm from bottom to top
    gx, gy, gw, gh = 1180, 120, 46, 420; frac = (76 - 8 * p) / 90
    glass_tube(surf, gx, gy, gw, gh, frac); ticks(surf, gx + gw + 4, gy + gh, gy, 18)
    label(surf, f"{76 - 8 * p:.0f} cm", gx + 70, gy + gh * (1 - frac) - 14, HG, 32, bold=True)
    label(surf, f"altitude ≈ {int(1000 * p):>4d} m", gx - 40, gy + gh + 30, MUTED, 24)
    label(surf, "Puy de Dôme, 19 September 1648", 60, 60, PARCH, 30); label(surf, "less air above → shorter column", 60, 100, MUTED, 26)

def d_thermo(surf, tt, st, sd, ctx, celsius=False):
    panel_bg(surf, "lab_bench", 60); x, y, w, h = 560, 120, 40, 520; bulb = (x + w // 2, y + h + 40)
    heat = 0.5 + 0.45 * math.sin(tt * 0.9)            # climbs with heat, falls with cold — the same way every time
    flame(surf, bulb[0], bulb[1] + 120, 40 + 50 * heat, tt)
    pygame.draw.circle(surf, HG, bulb, 44); glass_tube(surf, x, y, w, h, 0.08 + 0.84 * heat); pygame.draw.circle(surf, GLASS, bulb, 46, 3)
    ticks(surf, x + w + 4, y + h, y, 20)
    if not celsius:
        label(surf, "212 °F  water boils", x + 90, y - 6, CREAM, 26); label(surf, "96 °F  blood", x + 90, y + h * 0.56, CREAM, 26); label(surf, "32 °F  ice", x + 90, y + h - 20, CREAM, 26)
        label(surf, "Fahrenheit, 1714 — sealed, thin, mercury", 60, 60, PARCH, 30); label(surf, "it climbs with heat and falls with cold, the same way every time", 60, 100, MUTED, 26)
    else:
        flip = ease((tt - 5) / 2) if tt > 5 else 0.0
        top, bot = ("0", "100") if flip < 0.5 else ("100", "0")
        label(surf, f"{top}  boiling", x + 90, y - 6, CREAM, 26); label(surf, f"{bot}  freezing", x + 90, y + h - 20, CREAM, 26)
        # a stair of a hundred steps
        sx0, sy0 = 900, 640
        for k in range(0, 25):
            kx = sx0 + k * 18; ky = sy0 - k * 18
            pygame.draw.line(surf, mix(MOSS, CREAM, 0.3), (kx, ky), (kx + 18, ky), 3); pygame.draw.line(surf, mix(MOSS, CREAM, 0.3), (kx + 18, ky), (kx + 18, ky - 18), 3)
        label(surf, "gradus: a step — 100 of them", 900, 680, PARCH, 26)
        label(surf, "Celsius, 1742 — two fixed points", 60, 60, PARCH, 30)
        label(surf, "he numbered the stair downward; the world turned it over after he died" if flip > 0.5 else "boiling at zero, freezing at a hundred", 60, 100, MUTED, 26)
def d_celsius(surf, tt, st, sd, ctx): d_thermo(surf, tt, st, sd, ctx, celsius=True)

def d_eye(surf, tt, st, sd, ctx):
    panel_bg(surf, "lab_bench", 40); cx, cy, R = 560, 500, 230
    pygame.draw.circle(surf, (150, 40, 60), (cx, cy), R); pygame.draw.circle(surf, (30, 14, 20), (cx, cy), R - 14)
    pygame.draw.circle(surf, (36, 20, 28), (cx, cy), R - 14)
    # cornea bulge on the right
    bul = R + 40; p = ease(min(1, (tt - 1.0) / 3.0)) if tt > 1 else 0.0
    pygame.draw.circle(surf, GLASS, (cx + 20, cy), bul, 4)
    # applanation disc pressing from the right
    dx = cx + bul + 180 - 170 * p; dh = int(60 + 60 * p)
    pygame.draw.rect(surf, (80, 70, 50), (dx, cy - dh // 2, 18, dh)); pygame.draw.rect(surf, (80, 70, 50), (dx + 18, cy - 8, 160, 16))
    if p > 0.6: pygame.draw.rect(surf, (36, 20, 28), (dx - 20, cy - dh // 2 + 8, 24, dh - 16))  # flattened circle
    arrow(surf, (dx + 240, cy), (dx + 190, cy), ORANGE, 4, 14); label(surf, "force", dx + 250, cy - 14, ORANGE, 26)
    if p > 0.6:
        label(surf, "flattened circle: 3.06 mm", dx - 60, cy + dh // 2 + 24, CREAM, 26)
        label(surf, "tear-film pull and corneal stiffness cancel", 820, 140, MUTED, 24); label(surf, "force ÷ area = the pressure inside the eye", 820, 172, MUTED, 24)
    # a mercury column reading
    gx, gy, gw, gh = 1180, 140, 40, 400; frac = 0.16 * (0.5 + 0.5 * p) * 2.5
    glass_tube(surf, gx, gy, gw, gh, min(0.9, frac)); ticks(surf, gx + gw + 4, gy + gh, gy, 10)
    label(surf, f"{int(16 * p):>2d} mmHg", gx - 30, gy + gh + 20, HG, 30, bold=True)
    label(surf, "Goldmann applanation — the same metal, in the unit", 60, 60, PARCH, 30); label(surf, "three hundred years of quicksilver, refined until only the reading remains", 60, 100, MUTED, 26)

def d_metals(surf, tt, st, sd, ctx):
    panel_bg(surf, "lab_bench", 60); y, h, w = 180, 440, 60; floor = y + h + 70
    hot = ease((tt - 3) / 5) if tt > 3 else 0.0
    for k, (name, col) in enumerate((("Hg", HG), ("Au", AU), ("Pb", PB))):
        x = 330 + k * 340
        flame(surf, x + w // 2, floor + 60, 36 + (90 * hot if name == "Au" else 30 * (0.5 + 0.5 * math.sin(tt))), tt, k)
        if name == "Hg": glass_tube(surf, x, y, w, h, 0.25 + 0.55 * (0.5 + 0.5 * math.sin(tt * 1.1)))
        else:
            glass_tube(surf, x, y, w, h, 0.0); pygame.draw.rect(surf, col, (x + 6, y + h - 150, w - 12, 140)); pygame.draw.rect(surf, dim(col, 0.6), (x + 6, y + h - 150, w - 12, 140), 3)
            if name == "Au" and hot > 0.9: pygame.draw.rect(surf, mix(AU, ORANGE, 0.5), (x + 6, y + h - 60 - 90 * (hot - 0.9) * 10, w - 12, 50 + 90 * (hot - 0.9) * 10))
        label(surf, name, x + w // 2, floor + 100, col, 34, True, True)
    label(surf, "liquid in a room: flows, climbs, stands up against the air", 330, 130, HG, 24)
    if hot > 0.1: label(surf, f"solid until {int(20 + 1044 * hot):>4d} °C", 640, 130, AU, 24); label(surf, "— or far lower pressure", 640, 158, MUTED, 22)
    label(surf, "heavy; stops what passes through it", 1010, 130, PB, 24)
    label(surf, "why it was mercury", 60, 50, PARCH, 30)

def d_brick(surf, tt, st, sd, ctx):
    panel_bg(surf, "lab_bench", 40); floor = 720; pygame.draw.rect(surf, (40, 40, 44), (0, floor, SW, SH - floor))
    # gold brick: falls, lands hard, deforms (squash), dents the floor, dust
    bx = 460; t_hit = 1.1; g = 1400; y0 = 120
    if tt < t_hit: by = y0 + 0.5 * g * tt * tt; sx, sy = 1.0, 1.0
    else:
        by = floor; k = tt - t_hit; bump = math.exp(-k * 4) * math.cos(k * 14); sy = 1 - 0.22 * max(0, math.exp(-k * 3)) - 0.05 * bump; sx = 1 + 0.26 * max(0, math.exp(-k * 3)) + 0.05 * bump
        pygame.draw.ellipse(surf, (28, 28, 32), (bx - 150 * sx, floor - 10, 300 * sx, 36))  # the dent
        for d_ in range(10):  # dust
            a = d_ / 10 * math.pi; r = 40 + 220 * min(1, k) ** 0.6; al = max(0, 1 - k / 1.4)
            if al > 0: pygame.draw.circle(surf, mix((40, 40, 44), (120, 110, 90), al), (int(bx + math.cos(a) * r), int(floor - math.sin(a) * r * 0.4)), int(8 + 10 * al))
    bw, bh = 220 * sx, 110 * sy
    pygame.draw.rect(surf, AU, (bx - bw / 2, by - bh, bw, bh)); pygame.draw.rect(surf, AU2, (bx - bw / 2, by - bh, bw, bh), 4)
    # mercury: a blob falls and splashes into drops, then a puddle
    mx = 1000
    if tt < t_hit: pygame.draw.ellipse(surf, HG, (mx - 50, y0 + 0.5 * g * tt * tt - 60, 100, 70))
    else:
        k = tt - t_hit; rng = random.Random(5)
        for d_ in range(14):
            a = rng.uniform(0.2, math.pi - 0.2); v = rng.uniform(300, 700); dx = math.cos(a) * v * k; dy = -math.sin(a) * v * k + 0.5 * g * k * k
            if dy < 20: pygame.draw.circle(surf, HG, (int(mx + dx), int(floor - 10 + dy)), 9)
        pw = min(380, 60 + 500 * k); pygame.draw.ellipse(surf, HG, (mx - pw / 2, floor - 16, pw, 24))
    label(surf, "gold lands hard — and deforms", bx, floor + 50, AU, 28, True); label(surf, "mercury lands — and flows", mx, floor + 50, HG, 28, True)
    label(surf, "each metal was chosen for what it does; he compared what they weigh", 720, 60, PARCH, 30, True)

def d_circuit(surf, tt, st, sd, ctx):
    panel_bg(surf, "lab_bench", 40); x0, y0, x1, y1 = 300, 220, 1140, 680; closed = tt > 1.2
    path = [(x0, y1), (x0, y0), (x1, y0), (x1, y1), (x0, y1)]
    pygame.draw.lines(surf, (150, 120, 70), False, path, 6)
    # battery on the left
    pygame.draw.rect(surf, STAGE, (x0 - 30, 400, 60, 100)); pygame.draw.line(surf, CREAM, (x0 - 40, 420), (x0 + 40, 420), 8); pygame.draw.line(surf, CREAM, (x0 - 22, 460), (x0 + 22, 460), 4); label(surf, "battery", x0 - 60, 520, MUTED, 22)
    # gold contact (switch) on the top wire
    sx = 720; pygame.draw.rect(surf, AU, (sx - 60, y0 - 12, 120, 24)); pygame.draw.rect(surf, AU2, (sx - 60, y0 - 12, 120, 24), 3)
    if not closed: pygame.draw.rect(surf, STAGE, (sx - 10, y0 - 40, 70, 60)); pygame.draw.line(surf, (150, 120, 70), (sx - 10, y0), (sx + 50, y0 - 40), 6)
    label(surf, "gold contact — conducts, does not corrode", sx, y0 - 70, AU, 26, True)
    # bulb on the right
    bx, by = x1, 450; glow = 0.5 + 0.5 * math.sin(tt * 5) if closed else 0
    if closed:
        for k in range(5, 0, -1): pygame.draw.circle(surf, mix(STAGE, ORANGE, 0.12 * k * (0.7 + 0.3 * glow)), (bx, by), 60 + 18 * k)
    pygame.draw.circle(surf, ORANGE if closed else (60, 60, 60), (bx, by), 54); pygame.draw.circle(surf, CREAM, (bx, by), 56, 3)
    if closed:  # electrons marching
        total = (y1 - y0) * 2 + (x1 - x0) * 2
        for k in range(28):
            d_ = (k / 28 * total + tt * 260) % total
            if d_ < (y1 - y0): px, py = x0, y1 - d_
            elif d_ < (y1 - y0) + (x1 - x0): px, py = x0 + d_ - (y1 - y0), y0
            elif d_ < 2 * (y1 - y0) + (x1 - x0): px, py = x1, y0 + d_ - (y1 - y0) - (x1 - x0)
            else: px, py = x1 - (d_ - 2 * (y1 - y0) - (x1 - x0)), y1
            pygame.draw.circle(surf, (120, 220, 170), (int(px), int(py)), 6)
    label(surf, "gold: on the contacts of the instrument that reads this report", 720, 760, PARCH, 28, True)

def d_xray(surf, tt, st, sd, ctx):
    panel_bg(surf, "lab_bench", 40); sx, sy = 220, 470; p = ease((tt - 2.5) / 2) if tt > 2.5 else 0.0
    pygame.draw.ellipse(surf, GLASS, (sx - 90, sy - 50, 180, 100), 4); pygame.draw.circle(surf, (170, 200, 255), (sx + 40, sy), 10 + int(4 * math.sin(tt * 20)))
    label(surf, "Crookes tube", sx - 60, sy + 70, MUTED, 22)
    plate_x = 700; screen_x = 1120
    pygame.draw.rect(surf, (60, 130, 90), (screen_x, 180, 24, 580)); label(surf, "screen", screen_x - 10, 770, MUTED, 22)
    # the hand on the screen: outline + bones
    hx, hy = screen_x - 120, 470
    for k in range(5):
        a = -0.9 + k * 0.45; L = 150 if 0 < k < 4 else 110; ex, ey = hx + math.cos(a) * L, hy + math.sin(a) * L - 60
        pygame.draw.line(surf, (40, 90, 60), (hx, hy), (ex, ey), 22); pygame.draw.line(surf, (200, 230, 210), (hx, hy), (ex, ey), 5)
    pygame.draw.circle(surf, (40, 90, 60), (hx, hy + 40), 60); pygame.draw.circle(surf, (200, 230, 210), (hx, hy + 40), 60, 4)
    # rays
    for k in range(13):
        a = -0.5 + k / 12; ex = screen_x; ey = sy + math.tan(a) * (ex - sx)
        if p > 0.5 and 180 < sy + math.tan(a) * (plate_x - sx) < 760: ex = plate_x; ey = sy + math.tan(a) * (ex - sx)
        pygame.draw.line(surf, mix(STAGE, (140, 220, 190), 0.6 + 0.2 * math.sin(tt * 10 + k)), (sx + 80, sy), (ex, ey), 2)
    if p > 0:  # lead plate slides in
        py = 900 - 720 * p; pygame.draw.rect(surf, PB, (plate_x - 16, py, 32, 580)); pygame.draw.rect(surf, dim(PB, 0.6), (plate_x - 16, py, 32, 580), 3); label(surf, "Pb", plate_x, py - 36, PB, 30, True, True)
    if p > 0.5: pygame.draw.rect(surf, (18, 30, 24), (screen_x + 2, 182, 20, 576)); label(surf, "lead is heavy and stops what passes through it", 720, 100, PB, 30, True)
    else: label(surf, "Röntgen, 8 November 1895 — a screen that glowed when it should not have", 720, 100, PARCH, 28, True)

def d_planet(surf, tt, st, sd, ctx):
    panel_bg(surf, "space", 120); c = (560, 500); R = 230
    pygame.draw.circle(surf, (110, 104, 100), c, R); rng = random.Random(3)
    for _ in range(26):
        a = rng.uniform(0, 2 * math.pi); r = rng.uniform(0, R - 30); pygame.draw.circle(surf, (80, 76, 74), (int(c[0] + math.cos(a) * r), int(c[1] + math.sin(a) * r)), rng.randint(6, 22), 2)
    pygame.draw.circle(surf, STAGE, (c[0] + 150, c[1]), R + 40)  # night side cuts in
    pygame.draw.circle(surf, STAGE, (c[0] + 150, c[1]), R + 40)
    q = F_LAB(120, True).render("?", True, AU); q.set_alpha(int(160 + 90 * math.sin(tt * 2))); surf.blit(q, (c[0] - 40, c[1] - 90))
    # probe approaching along an arc
    p = ease(min(1, tt / 8)); px, py = lerp(1380, c[0] + R + 90, p), lerp(120, c[1] - 120, p)
    pygame.draw.rect(surf, (200, 200, 210), (px - 14, py - 14, 28, 28)); pygame.draw.rect(surf, (40, 60, 150), (px - 70, py - 6, 50, 12)); pygame.draw.rect(surf, (40, 60, 150), (px + 20, py - 6, 50, 12))
    label(surf, "BepiColombo — in orbit this November", px - 120, py + 30, MUTED, 22)
    label(surf, "gold on the planet Mercury?  unmeasured.", 720, 80, AU, 32, True); label(surf, "MESSENGER mapped the lighter elements; it was not built to find gold. the row is open.", 720, 126, MUTED, 24, True)

def d_noise(surf, tt, st, sd, ctx):
    x, y, w, h = 120, 160, 1200, 560; pygame.draw.rect(surf, (8, 16, 12), (x, y, w, h)); grid(surf, x, y, w, h); pygame.draw.rect(surf, FAINT, (x, y, w, h), 2)
    rng = random.Random(int(tt * 30)); mid = y + h // 2; pts, npts = [], []
    burst_on = 0.3 < (tt % 6) / 6 < 0.62
    for i in range(0, w, 3):
        ph = (i + tt * 140) / 110; clean = mid - 110 * math.sin(ph)
        pts.append((x + i, clean))
        nz = rng.uniform(-150, 150) if burst_on and 380 < i < 760 else 0
        npts.append((x + i, clean + nz))
    pygame.draw.lines(surf, MAG, False, npts, 2); pygame.draw.lines(surf, (90, 220, 150), False, pts, 3)
    label(surf, "the reading (the tube)", x + 20, y + 14, (90, 220, 150), 26)
    if burst_on: label(surf, "the plaintiff", x + 500, y + 14, MAG, 28, bold=True); label(surf, "— adds nothing to the tube, nothing to the reading; a sentence in the room", x + 20, y + h + 20, MAG, 26)
    else: label(surf, "signal that carries no information and must be filtered before the measurement can be read: noise", x + 20, y + h + 20, MUTED, 26)

def d_rope_throw(surf, tt, st, sd, ctx):
    panel_bg(surf, "space", 90); glass_tube(surf, 150, 420, 40, 300, 0.76); dish(surf, 170, 740, 160, 40)
    px, py = 1180, 380; p = ease(min(1, tt / 4.5))
    pygame.draw.circle(surf, (110, 104, 100), (px, py), 90); pygame.draw.circle(surf, STAGE, (px + 60, py), 100)
    # the rope: a sagging line from the tube to a flying loop
    ex, ey = lerp(190, px, p), lerp(400, py - 60, p) - 180 * math.sin(math.pi * p)
    pts = [(lerp(190, ex, k / 30), lerp(400, ey, k / 30) + 60 * math.sin(math.pi * k / 30) * (1 - p)) for k in range(31)]
    pygame.draw.lines(surf, AMBER, False, pts, 5)
    loop_r = 50 + 80 * p
    if p < 1: pygame.draw.ellipse(surf, AMBER, (ex - loop_r, ey - loop_r * 0.5, loop_r * 2, loop_r), 5)
    else: pygame.draw.ellipse(surf, AMBER, (px - 130, py - 50, 260, 130), 6); label(surf, "caught: Mercury's perihelion", px, py + 120, AMBER, 26, True)
    label(surf, "the rope trick: the chain leaves the laboratory and is thrown at a planet", 720, 80, PARCH, 30, True)
    label(surf, "the same mercury that measured the sky now measures the sky's leftover", 720, 126, MUTED, 24, True)

def d_vulcan(surf, tt, st, sd, ctx, mode="precess"):
    panel_bg(surf, "space", 60); c = (640, 470); sun(surf, c, 46, tt)
    a_, b_, e_ = 300, 230, 0.6; off = a_ * 0.42
    theta = tt * 0.12  # exaggerated precession
    for k in range(6):  # ghost orbits
        th = theta - k * 0.25; col = mix(STAGE, MOSS, 0.45 - k * 0.07)
        pts = [(c[0] + (a_ * math.cos(u) - off) * math.cos(th) - b_ * math.sin(u) * math.sin(th), c[1] + (a_ * math.cos(u) - off) * math.sin(th) + b_ * math.sin(u) * math.cos(th)) for u in [i / 60 * 2 * math.pi for i in range(61)]]
        pygame.draw.lines(surf, col if k else (120, 200, 150), True, pts, 2 if k else 3)
    u = tt * 1.4; mx = c[0] + (a_ * math.cos(u) - off) * math.cos(theta) - b_ * math.sin(u) * math.sin(theta); my = c[1] + (a_ * math.cos(u) - off) * math.sin(theta) + b_ * math.sin(u) * math.cos(theta)
    pygame.draw.circle(surf, (170, 165, 160), (int(mx), int(my)), 10)
    per = (c[0] + (a_ - off) * math.cos(theta), c[1] + (a_ - off) * math.sin(theta)); pygame.draw.circle(surf, AMBER, (int(per[0]), int(per[1])), 7); label(surf, "perihelion", per[0] + 12, per[1] - 30, AMBER, 22)
    if mode in ("vulcan", "refuted"):
        dashed_circle(surf, c, 120, mix(MUTED, CREAM, 0.3)); vx, vy = c[0] + 120 * math.cos(tt * 2.5), c[1] + 120 * math.sin(tt * 2.5)
        pygame.draw.circle(surf, (90, 60, 50), (int(vx), int(vy)), 8); label(surf, "Vulcan?", vx + 14, vy - 10, MUTED, 22)
        if mode == "refuted":
            pygame.draw.line(surf, CRIM, (c[0] - 150, c[1] - 150), (c[0] + 150, c[1] + 150), 8); pygame.draw.line(surf, CRIM, (c[0] - 150, c[1] + 150), (c[0] + 150, c[1] - 150), 8)
            label(surf, "nobody else saw it. not then, not at the eclipses, not ever.", 720, 790, CRIM, 28, True)
    r_ = F_LAB(24).render("after every known planet is subtracted: 38″ → 43″ per century left over", True, PARCH); surf.blit(r_, (SW - 40 - r_.get_width(), 150))
    label(surf, "Le Verrier, 1859 — Mercury's perihelion advances", 60, 60, PARCH, 30)
    label(surf, "a refuted prediction is the best kind of evidence: the method had teeth" if mode == "refuted" else "the residue is the signature of a mass inside the orbit — he named it Vulcan" if mode == "vulcan" else "he had done this once before, for Uranus, and the answer was Neptune", 60, 100, MUTED, 24)
def d_vulcan_named(surf, tt, st, sd, ctx): d_vulcan(surf, tt, st, sd, ctx, "vulcan")
def d_vulcan_refuted(surf, tt, st, sd, ctx): d_vulcan(surf, tt, st, sd, ctx, "refuted")

def d_transit(surf, tt, st, sd, ctx):
    panel_bg(surf, "space", 40); c = (720, 470); sun(surf, c, 260, tt)
    p = (tt / 9.0) % 1.0; x = c[0] - 320 + 640 * p; y = c[1] - 60
    if abs(x - c[0]) < 262: pygame.draw.circle(surf, INK, (int(x), int(y)), 9)
    label(surf, "Lescarbault, 26 March 1859 — a black dot crossed the Sun in an hour and a quarter", 720, 80, PARCH, 28, True)
    label(surf, "times written in chalk on a plank; nobody else ever saw it", 720, 126, MUTED, 24, True)

def d_luna24(surf, tt, st, sd, ctx):
    panel_bg(surf, "space", 60); pygame.draw.ellipse(surf, (40, 38, 36), (-200, 760, SW + 400, 400)); label(surf, "Mercury's sky", 60, 60, PARCH, 30)
    ex, ey = 720, 420; pygame.draw.circle(surf, (40, 90, 160), (ex, ey), 30)
    # Luna's orbit seen edge-on from Mercury: it swings left-right; the far half (behind Earth) is where it moves west
    ph = tt * 0.9; lx = ex + 300 * math.cos(ph); far = math.sin(ph) < 0
    pygame.draw.line(surf, FAINT, (ex - 300, ey), (ex + 300, ey), 2)
    pygame.draw.circle(surf, (200, 200, 190) if not far else (120, 120, 115), (int(lx), ey - (14 if far else -14)), 10)
    west = far and math.sin(ph) < 0 and math.cos(ph + 0.01) < math.cos(ph)  # moving leftward (west) on far half
    label(surf, "Luna on the far half, moving west ◄", ex, 300, MAG if far else MUTED, 26, True)
    pygame.draw.rect(surf, FAINT, (320, 640, 800, 30)); pygame.draw.rect(surf, MAG, (320, 640, int(800 * 0.024), 30)); label(surf, "2.4 % of the time", 320, 680, MAG, 28)
    label(surf, "the number the author read aloud as 'Vulcan is straight visible' — it was Luna. deliberate error #1.", 720, 760, MUTED, 24, True)

def d_einstein(surf, tt, st, sd, ctx, which=(1, 1, 1)):
    panel_bg(surf, "space", 50); label(surf, "three places I could have been wrong", 720, 50, PARCH, 30, True)
    # (a) perihelion
    if which[0]:
        c = (260, 470); sun(surf, c, 22, tt); th = tt * 0.3
        for k in range(4):
            pts = [(c[0] + (120 * math.cos(u) - 40) * math.cos(th - k * .3) - 90 * math.sin(u) * math.sin(th - k * .3), c[1] + (120 * math.cos(u) - 40) * math.sin(th - k * .3) + 90 * math.sin(u) * math.cos(th - k * .3)) for u in [i / 40 * 2 * math.pi for i in range(41)]]
            pygame.draw.lines(surf, mix(STAGE, MOSS, 0.6 - k * 0.12) if k else (120, 200, 150), True, pts, 2)
        label(surf, "43″ per century", c[0], 660, CREAM, 28, True); label(surf, "Mercury's perihelion", c[0], 700, MUTED, 22, True)
    # (b) light bent at the limb
    if which[1]:
        c = (720, 470); sun(surf, c, 70, tt); ox, oy = 420, 470; stx, sty = 1020, 300
        mid = (c[0], c[1] - 86); pygame.draw.line(surf, (255, 230, 150), (stx, sty), mid, 3); pygame.draw.line(surf, (255, 230, 150), mid, (ox, oy), 3)
        # apparent direction
        dx, dy = mid[0] - ox, mid[1] - oy; n = math.hypot(dx, dy); ax, ay = ox + dx / n * 620, oy + dy / n * 620
        for k in range(0, 24, 2): pygame.draw.line(surf, MUTED, (ox + dx / n * 620 * k / 24, oy + dy / n * 620 * k / 24), (ox + dx / n * 620 * (k + 1) / 24, oy + dy / n * 620 * (k + 1) / 24), 2)
        pygame.draw.circle(surf, CREAM, (stx, sty), 6); pygame.draw.circle(surf, MUTED, (int(ax), int(ay)), 6, 2); label(surf, "apparent", ax + 10, ay - 30, MUTED, 20)
        pygame.draw.circle(surf, (120, 200, 150), (ox, oy), 8); label(surf, "1.75″ at the limb", c[0], 660, CREAM, 28, True); label(surf, "Eddington, 1919 — remeasured a hundred ways", c[0], 700, MUTED, 22, True)
    # (c) clocks
    if which[2]:
        c = (1180, 470); pygame.draw.circle(surf, (40, 90, 160), (c[0], c[1] + 80), 50)
        sa = tt * 1.1; sx, sy = c[0] + 150 * math.cos(sa), c[1] + 80 - 110 * math.sin(sa); pygame.draw.rect(surf, (200, 200, 210), (sx - 10, sy - 10, 20, 20))
        for (cx, cy, rate, lab_) in ((c[0] - 110, c[1] - 130, 1.0, "ground"), (c[0] + 110, c[1] - 130, 1.25, "in orbit")):
            pygame.draw.circle(surf, STAGE, (cx, cy), 44); pygame.draw.circle(surf, CREAM, (cx, cy), 44, 3)
            a = tt * 2.0 * rate; pygame.draw.line(surf, ORANGE if rate > 1 else CREAM, (cx, cy), (cx + 36 * math.sin(a), cy - 36 * math.cos(a)), 3); label(surf, lab_, cx, cy + 52, MUTED, 20, True)
        label(surf, "+38 µs per day", c[0], 660, CREAM, 28, True); label(surf, "or every receiver drifts ~10 km a day", c[0], 700, MUTED, 22, True)
def d_einstein_a(surf, tt, st, sd, ctx): d_einstein(surf, tt, st, sd, ctx, (1, 0, 0))
def d_einstein_b(surf, tt, st, sd, ctx): d_einstein(surf, tt, st, sd, ctx, (1, 1, 0))
def d_einstein_c(surf, tt, st, sd, ctx): d_einstein(surf, tt, st, sd, ctx, (1, 1, 1))

def d_rope_apple(surf, tt, st, sd, ctx):
    panel_bg(surf, "yard", 50); ec = (300, 1050); ER = 420
    pygame.draw.circle(surf, (24, 60, 40), ec, ER); pygame.draw.circle(surf, MOSS, ec, ER, 3)
    # tree on the top of the Earth
    tx, ty = 300, ec[1] - ER; pygame.draw.rect(surf, (70, 50, 30), (tx - 10, ty - 150, 20, 150)); pygame.draw.circle(surf, (30, 90, 50), (tx, ty - 190), 90)
    cycle = 4.0; k = (tt % cycle); fall = min(1, k / 1.0); ay = ty - 150 + 140 * fall * fall; ax = tx + 60
    pygame.draw.circle(surf, CRIM, (ax, int(ay)), 14); pygame.draw.line(surf, AMBER, ec, (ax, ay), 2)
    label(surf, "the apple falls 4.9 m in its first second", 420, 120, PARCH, 26)
    # Luna, far right, orbiting; same rope
    lr = 900; la = -0.35 + tt * 0.15; lx, ly = ec[0] + lr * math.cos(la), ec[1] + lr * math.sin(la)
    pygame.draw.arc(surf, FAINT, (ec[0] - lr, ec[1] - lr, 2 * lr, 2 * lr), 0.1, 1.2, 2)
    pygame.draw.circle(surf, (200, 200, 190), (int(lx), int(ly)), 22); pygame.draw.line(surf, AMBER, ec, (lx, ly), 2)
    # Luna's fall toward Earth: the tangent it would have followed vs where it is
    arrow(surf, (lx, ly), (lx - 60 * math.sin(la) * 0.001 + 0 - 0, ly), AMBER, 1, 1)
    label(surf, "Luna falls 1.4 mm each second — 60 Earth radii away: 1/3600 of the apple's pull", 420, 160, PARCH, 26)
    label(surf, "the same rope, thinned by the square of the distance", 420, 200, AMBER, 28)
    label(surf, "Woolsthorpe, 1665–66: the calculus, the colours, the inverse square", 420, 260, MUTED, 24)

def d_parallax(surf, tt, st, sd, ctx):
    panel_bg(surf, "space", 60); sc = (330, 560); sun(surf, sc, 18, tt); r = 110; a = tt * 0.8
    pygame.draw.circle(surf, FAINT, sc, r, 2); ex, ey = sc[0] + r * math.cos(a), sc[1] + r * math.sin(a) * 0.35; pygame.draw.circle(surf, (40, 90, 160), (int(ex), int(ey)), 9)
    near = (820, 560 - 60); pygame.draw.circle(surf, ORANGE, near, 8); label(surf, "61 Cygni", near[0] - 40, near[1] + 16, ORANGE, 22)
    rng = random.Random(9)
    for _ in range(60): pygame.draw.circle(surf, mix(STAGE, CREAM, rng.uniform(0.3, 0.9)), (rng.randint(1250, 1430), rng.randint(120, 820)), rng.choice((1, 1, 2)))
    # sightline extended to the far wall
    dx, dy = near[0] - ex, near[1] - ey; n = math.hypot(dx, dy); fx = 1420; fy = ey + dy / dx * (fx - ex)
    pygame.draw.line(surf, (120, 200, 150), (ex, ey), (fx, fy), 2); pygame.draw.circle(surf, (120, 200, 150), (int(fx), int(fy)), 7, 2)
    label(surf, "the near star shifts against the far ones as the Earth goes round", 60, 60, PARCH, 28); label(surf, "Bessel, 1838 — a third of a second of arc. 2,100 years from the hypothesis to the number.", 60, 100, MUTED, 24)
    label(surf, "Aristarchus: the Earth's orbit is as a point to the sphere of the stars — so you see no shift", 60, 800, MUTED, 22)

def d_glove(surf, tt, st, sd, ctx):
    panel_bg(surf, "glove_bag", 70); cx, cy = 720, 480
    def glove_pts(sx):
        base = [(-60, 120), (-60, -20), (-40, -110), (-20, -20), (-10, -130), (10, -20), (20, -120), (40, -20), (50, -90), (60, -10), (90, 40), (60, 60), (60, 120)]
        return [(cx + sx * px, cy + py) for px, py in base]
    flip = math.cos(tt * 0.9)  # turning it through the fourth direction: x-scale runs 1 → −1
    pygame.draw.polygon(surf, (40, 30, 36), glove_pts(flip)); pygame.draw.polygon(surf, PLUM, glove_pts(flip), 4)
    label(surf, "left" if flip > 0 else "right", cx, cy + 150, CREAM, 34, True, True)
    label(surf, "the glove in that bag is left-handed", 60, 60, PARCH, 30); label(surf, "turn it through the fourth direction and it comes back right-handed — and we would have a receipt", 60, 100, MUTED, 24)
    label(surf, "Exhibit K", 60, 800, MUTED, 22)

def d_marks(surf, tt, st, sd, ctx):
    panel_bg(surf, "sand_circle", 60)
    # hourglass with a count of grains
    hx, hy = 300, 470; pygame.draw.polygon(surf, GLASS, [(hx - 90, hy - 220), (hx + 90, hy - 220), (hx, hy), (hx + 90, hy + 220), (hx - 90, hy + 220), (hx, hy)], 4)
    p = (tt / 12) % 1; pygame.draw.polygon(surf, AMBER, [(hx - 80 * (1 - p), hy - 200 * (1 - p)), (hx + 80 * (1 - p), hy - 200 * (1 - p)), (hx, hy)])
    pygame.draw.polygon(surf, AMBER, [(hx - 80 * p, hy + 210), (hx + 80 * p, hy + 210), (hx, hy + 210 - 200 * p)])
    pygame.draw.line(surf, AMBER, (hx, hy), (hx, hy + 200), 2); label(surf, "sand through the glass: a count", hx, 720, MUTED, 22, True)
    # decay staircase
    dx0, dy0 = 620, 700; label(surf, "carbon-14 → nitrogen: half every 5,730 years — a receipt the sample writes on itself", 560, 160, MUTED, 22)
    pts = [(dx0 + i * 6, dy0 - 400 * (0.5 ** (i * 6 / 160))) for i in range(0, 110)]; pygame.draw.lines(surf, (120, 200, 150), False, pts, 3)
    for k in range(5): xx = dx0 + 160 * k; pygame.draw.line(surf, FAINT, (xx, dy0), (xx, dy0 - 400 * 0.5 ** k), 1)
    # ledger of marks
    lx, ly = 560, 760; n = int(tt * 2) % 40
    for k in range(n): pygame.draw.line(surf, CREAM, (lx + k * 20 + (0 if k % 5 != 4 else -82), ly if k % 5 != 4 else ly + 10), (lx + k * 20 + (0 if k % 5 != 4 else 8), ly + 40 if k % 5 != 4 else ly - 10), 3)
    label(surf, "time is the count of marks · now is the latest mark that could have been otherwise", 720, 60, PARCH, 28, True)
    label(surf, "where there is no mark there is a hole the shape of what was in it — and the hole counts", 720, 100, MUTED, 24, True)

def d_shift(surf, tt, st, sd, ctx):
    panel_bg(surf, "passage", 50); pairs = (("p", "f", "pater → father"), ("t", "th", "tres → three"), ("k", "h", "cornu → horn"))
    for k, (a, b, ex) in enumerate(pairs):
        y = 260 + k * 170; p = ease((tt - k * 1.2) / 2.0) if tt > k * 1.2 else 0.0
        fa = F_LAB(96, True).render(a, True, mix(CREAM, STAGE, p)); fb = F_LAB(96, True).render(b, True, mix(STAGE, MAG, p))
        surf.blit(fa, (420, y)); surf.blit(fb, (760, y)); arrow(surf, (560, y + 60), (720, y + 60), MUTED, 3, 14); label(surf, ex, 920, y + 36, MUTED, 26)
    label(surf, "the sound shift: a law is a thing that can fail", 720, 80, PARCH, 30, True); label(surf, "Jakob Grimm, 1822 — tongues", 720, 126, MUTED, 24, True)

def d_marconi(surf, tt, st, sd, ctx):
    panel_bg(surf, "space", 40); c = (720, 1500); R = 900
    pygame.draw.circle(surf, (24, 60, 40), c, R); pygame.draw.circle(surf, mix(STAGE, MAG, 0.5), c, R + 230, 3)
    label(surf, "a layer nobody knew was there (Kennelly–Heaviside, 1902; Appleton, 1924)", 720, 300, MUTED, 22, True)
    a0, a1 = math.radians(250), math.radians(290); p0 = (c[0] + R * math.cos(a0), c[1] + R * math.sin(a0)); p1 = (c[0] + R * math.cos(a1), c[1] + R * math.sin(a1))
    am = (a0 + a1) / 2; pm = (c[0] + (R + 230) * math.cos(am), c[1] + (R + 230) * math.sin(am))
    p = (tt / 4) % 1
    for seg in range(3):
        q = (p - seg * 0.12) % 1; pt = (lerp(p0[0], pm[0], q * 2) if q < 0.5 else lerp(pm[0], p1[0], (q - 0.5) * 2), lerp(p0[1], pm[1], q * 2) if q < 0.5 else lerp(pm[1], p1[1], (q - 0.5) * 2))
        pygame.draw.circle(surf, ORANGE, (int(pt[0]), int(pt[1])), 8)
    pygame.draw.line(surf, FAINT, p0, pm, 2); pygame.draw.line(surf, FAINT, pm, p1, 2)
    label(surf, "Poldhu", p0[0] - 40, p0[1] + 16, CREAM, 22); label(surf, "Signal Hill", p1[0] - 40, p1[1] + 16, CREAM, 22)
    label(surf, "· · ·   the letter S, 12 December 1901 — the sky bent it", 720, 80, PARCH, 30, True)

def d_ledger(surf, tt, st, sd, ctx):
    pygame.draw.rect(surf, (12, 20, 16), (80, 120, 1280, 700)); pygame.draw.rect(surf, FAINT, (80, 120, 1280, 700), 2); pygame.draw.line(surf, FAINT, (720, 140), (720, 800), 2)
    label(surf, "the plaintiff", 400, 150, MAG, 30, True); label(surf, "the others", 1040, 150, (120, 200, 150), 30, True)
    q = "Hg heavier than Au" if int(tt) % 2 == 0 else "Au heavier than Hg"; label(surf, q, 400, 300, CREAM, 36, True, True); label(surf, "— which way round, nobody can say; it does not matter", 400, 360, MUTED, 22, True)
    rows = ["76 cm of mercury — Florence, 1643", "8 cm less at the top of the Puy de Dôme", "96 · 212 · 100 — blood, and water boiling", "3.06 mm against an eye", "43″ per century, left over", "1.75″ at the edge of the Sun", "+38 µs per day, in orbit"]
    for k, r in enumerate(rows):
        if tt > 1.2 * k: label(surf, r, 760, 220 + k * 72, CREAM, 28)
    label(surf, "one side is a number. the other side is a sentence about a number anyone could have taken.", 720, 840, PARCH, 26, True)

def d_aristarchus(surf, tt, st, sd, ctx):
    panel_bg(surf, "space", 60); sc = (1150, 300); sun(surf, sc, 60, tt); ec = (300, 640); pygame.draw.circle(surf, (40, 90, 160), ec, 22)
    mc = (300, 300); pygame.draw.circle(surf, (200, 200, 190), mc, 22); pygame.draw.circle(surf, STAGE, (mc[0] - 12, mc[1]), 22)
    pygame.draw.line(surf, FAINT, ec, mc, 2); pygame.draw.line(surf, FAINT, ec, sc, 2); pygame.draw.line(surf, FAINT, mc, sc, 2)
    label(surf, "half moon: the angle at Earth is a little less than a right angle", 60, 60, PARCH, 28); label(surf, "Aristarchus of Samos — On Sizes and Distances; present by absence", 60, 100, MUTED, 24)
    puppet(surf, "ARISTARCHUS", 720, 760, 1.0, tt)

def d_kids_out(surf, tt, st, sd, ctx):
    panel_bg(surf, "yard", 255)
    for k in range(11):
        p = (tt * 0.22 - k * 0.09); x = 200 + p * 1400
        if 0 < x < 1500: puppet(surf, "KIDS", x, 820 - (k % 3) * 20, 0.45 + 0.05 * (k % 3), tt + k, speaking=True, face=1, colour=mix(MAG, ORANGE, k / 10))
    label(surf, "go out and play", 720, 80, PARCH, 34, True)

DEMO_FN = dict(scale=d_scale, torricelli=d_torricelli, hill=d_hill, thermo=d_thermo, celsius=d_celsius, eye=d_eye, metals=d_metals, brick=d_brick, circuit=d_circuit,
               xray=d_xray, planet=d_planet, noise=d_noise, rope_throw=d_rope_throw, vulcan=d_vulcan, vulcan_named=d_vulcan_named, vulcan_refuted=d_vulcan_refuted,
               transit=d_transit, luna24=d_luna24, einstein_a=d_einstein_a, einstein_b=d_einstein_b, einstein_c=d_einstein_c, rope_apple=d_rope_apple,
               parallax=d_parallax, glove=d_glove, marks=d_marks, shift=d_shift, marconi=d_marconi, ledger=d_ledger, aristarchus=d_aristarchus, kids_out=d_kids_out)

# (section, regex on the shot text, demo, hold)  hold = number of shots the demo stays up (None = until the section ends / next trigger)
TRIG = [
 (3, r"cannot be \*?sure\*? that physical matter|senses give us impressions", "noise", 3),
 (3, r"the word for a signal|is \*?noise\*?|It added a sentence to the room", "noise", 4),
 (3, r"balance and two lumps|most basic measurement|bathtub", "scale", 4),
 (3, r"The tube works", "noise", 2),
 (4, r"filled a glass tube", "torricelli", 1), (4, r"carried it up a hill", "hill", 2),
 (4, r"thinner tube and sealed", "thermo", 1), (4, r"fixed two points|numbered them downward", "celsius", 2),
 (4, r"Applanation|3\.06", "eye", 2), (4, r"note the trajectory|Torricelli measured the sky", "eye", 1),
 (4, r"only metal that is liquid|It \*?works\*?\. And the court", "metals", 1), (4, r"Gold will not", "metals", 1),
 (4, r"carries current", "circuit", 1), (4, r"Lead is heavy", "xray", 1), (4, r"chosen for what it \*?does\*?|compared what they \*?weigh", "brick", 2),
 (4, r"gold on Mercury|Unmeasured|BepiColombo", "planet", 3),
 (5, r"rope trick", "rope_throw", 1), (5, r"perihelion advances|thirty-eight seconds", "vulcan", 1), (5, r"named it Vulcan|signature of a mass", "vulcan_named", 1),
 (5, r"black dot crossed|26 March 1859", "transit", 2), (5, r"Nobody else saw it|Vulcan is not there|It was refuted", "vulcan_refuted", 3),
 (5, r"2\.4 per cent|Luna moves west", "luna24", 2),
 (6, r"forty-three seconds", "einstein_a", 1), (6, r"one point seven five", "einstein_b", 1), (6, r"thirty-eight microseconds", "einstein_c", 2),
 (6, r"satellites work", "einstein_c", 1), (6, r"oblateness|coronagraphs|unexplained measurement", "einstein_a", 2),
 (7, r"Woolsthorpe|inverse square|garden", "rope_apple", 3),
 (8, r"Parallax argument|as a point to it", "aristarchus", 1), (8, r"61 Cygni|third of a second", "parallax", 2),
 (9, r"left-handed|glove", "glove", 3),
 (10, r"Crookes tube|X because", "xray", 2), (10, r"letter S|Poldhu", "marconi", 2),
 (12, r"count of marks|Sand through the glass|5,730", "marks", 3),
 (13, r"sound shift|pater|father", "shift", 2),
 (14, r"a balance, two lumps|most basic measurement a human", "scale", 1), (14, r"one of those metals in a tube", "metals", 1),
 (14, r"Eight centimetres less|seventy-six centimetres of mercury|mercury is heavier than gold", "ledger", 3),
 (15, r"Go out and play|The first one goes|Eleven kids through a door", "kids_out", 3),
]
# receipts typed into the ledger column when the line is spoken (section, regex, text)
RECEIPTS = [
 (1, r"one annoying guy", "Complaint: 'one annoying guy who said Hg and Au could not be proven real'"), (1, r"Not guilty", "Plea: not guilty"),
 (3, r"approximately what I said", "Plaintiff concedes the content; objects to the tone"), (3, r"word for a signal", "Classified: noise"),
 (3, r"balance and two lumps", "Known for: a density comparison. Irony entered."),
 (4, r"seventy-six centimetres", "Torricelli 1643 — 76 cm"), (4, r"eight centimetres", "Périer 1648 — 8 cm less, Puy de Dôme"),
 (4, r"sealed it", "Fahrenheit 1714 — sealed Hg tube"), (4, r"hundred steps", "Celsius 1742 — 100 steps"), (4, r"3\.06", "Goldmann — 3.06 mm → mmHg"),
 (4, r"Lead is heavy", "Hg flows · Au conducts · Pb blocks"), (4, r"BepiColombo", "Open row: Au on Mercury? — unmeasured"),
 (5, r"forty-three", "Le Verrier 1859 — 38″ → 43″ / century"), (5, r"Vulcan is not there", "Vulcan — refuted. 2 points, posthumous"), (5, r"2\.4 per cent", "2.4 % = Luna, Mercury's sky. Error #1"),
 (6, r"forty-three seconds", "Admitted: 43″"), (6, r"one point seven five", "Admitted: 1.75″ (1919)"), (6, r"thirty-eight microseconds", "Admitted: +38 µs/day"), (6, r"There is me, saying it", "Chauffeur — not admitted"),
 (7, r"1665", "Newton — Woolsthorpe 1665–66, clean"), (7, r"It's a receipt", "Oppenheimer — a receipt"),
 (8, r"Sand Reckoner", "Archimedes — the reviewer"), (8, r"third of a second", "Bessel 1838 — 0.31″"), (8, r"17 February 1600", "Bruno — 17.ii.1600, not for parallax"), (8, r"1633", "Galileo 1633 — house arrest"),
 (9, r"Heqa khasut", "Hyksos = rulers of foreign lands. Error #11"), (9, r"left-handed", "Exhibit K — left glove (Kant: 1 point)"), (9, r"Kepler", "camera obscura: Kepler 1604. Error #14"),
 (10, r"6,600", "Topsy — 6,600 V AC. Error #12"), (10, r"8 November 1895|Crookes", "Röntgen 1895 — 2 points"), (10, r"Magnetron", "Spencer 1945 — 1 point and the egg"), (10, r"12 December 1901|Poldhu", "Marconi 1901 — ½ point"),
 (11, r"only one", "Riebeeck — Daghregister, only source 1652–62"), (11, r"boat", "Autshumato — the boat"), (11, r"Gardiners", "Kidd — treasure real"), (11, r"never saw salt water", "Billy — not a pirate. Error #10"),
 (12, r"paper in|pocket", "Dingane — the paper in the pocket counts"), (12, r"1782", "Kamehameha — Kīwalaʻō his cousin, 1782"), (12, r"542", "Justinian — 542, Procopius"), (12, r"count of marks", "Time = the count of marks"),
 (13, r"pater", "Jakob — p→f, t→th, k→h. 2 points"), (13, r"stepmothers", "Wilhelm — ½, faithful to the children"), (13, r"kids are recessed", "The kids are recessed."),
 (14, r"^\*?One\.|Not liable", "Verdict 1 — not liable"), (14, r"The tone is earned", "Verdict 2 — characterisation accurate"), (14, r"It is a sound in the room", "Verdict 3 — noise"),
 (14, r"only result the plaintiff has", "Verdict 4 — the irony, entered"), (14, r"It wasn't him", "Verdict 5 — Einstein: theory admitted, lore not"), (14, r"turned out to have been described", "Verdict 6 — method admissible"),
 (14, r"leaves no mark that could have been otherwise", "Verdict 7 — time is the count of marks"), (14, r"Costs to the plaintiff", "Damages: none. Costs: one reading."),
 (15, r"in \*?recess", "This court is in recess."), (15, r"The sound the room made", "Hume: the sound the room made"),
]

# ───────────────────────── timeline ─────────────────────────
def wav_dur(p):
    try:
        with wave.open(p) as w: return w.getnframes() / w.getframerate()
    except Exception: return None
def durations():
    out, missing = [], 0
    for s in S:
        d = wav_dur(os.path.join(AUD, s["id"] + ".wav"))
        if d is None: d = max(3.0, 0.9 + len(s["text"]) / 15.5); missing += 1
        out.append(d)
    return out, missing

def plan():
    """Per-shot static plan: demo (name, start index), backdrop, focus, receipts added. Deterministic replay so chunks can start anywhere."""
    P = []; cur = None; hold = 0; demo_start = None; ledger = []; state = {"passage": False, "yard": False}
    for i, s in enumerate(S):
        txt = s["text"]; sec = s["sec"]
        if cur and (sec != cur[2]): cur = None
        hit = None
        for (sc_, rx, name, h) in TRIG:
            if sc_ == sec and re.search(rx, txt): hit = (name, h); break
        if hit:
            if not cur or cur[0] != hit[0]: demo_start = i
            cur = (hit[0], hit[1], sec); hold = hit[1] if hit[1] else 10 ** 6
        elif cur:
            hold -= 1
            if hold <= 0: cur = None
        if s["kind"] in ("head", "table", "sign", "close"): cur_demo = None
        else: cur_demo = (cur[0], demo_start) if cur else None
        if sec == 13 and "The room goes Grimm" in txt: state["passage"] = True
        if sec == 14: state["passage"] = False
        if sec == 15 and "He opens the door" in txt: state["yard"] = True
        new = []
        for (sc_, rx, text) in RECEIPTS:
            if sc_ == sec and re.search(rx, txt) and text not in ledger: ledger.append(text); new.append(text)
        if s["kind"] == "write":
            t = re.sub(r"^.*? types: ", "", txt); ledger.append("W: " + t); new.append("W: " + t)
        who = s["who"]
        if s["kind"] in ("sign", "close"): back, focus = "alcove", "alcove"
        elif s["kind"] == "head": back, focus = "sand_circle", "title"
        elif s["kind"] == "table": back, focus = "sand_circle", "table"
        elif state["yard"]: back, focus = "yard", "yard"
        elif state["passage"]: back, focus = "passage", "wide"
        elif who == "FEYNMAN": back, focus = "wall_bench", "bench"
        elif who == "NARRATOR": back, focus = ("sand_circle" if sec in (0, 15) else "wall_bench"), "wide"
        elif who in GALLERY: back, focus = "wall_gallery", "gallery"
        elif who in ("HUME", "SPOCK", "McCLANE"): back, focus = "wall_bench", "floor"
        elif who == "WIDUKIND": back, focus = "alcove", "alcove"
        else: back, focus = "wall_witness", "witness"
        P.append(dict(demo=cur_demo, back=back, focus=focus, ledger=list(ledger), new=new))
    return P

# ───────────────────────── frame composition ─────────────────────────
class Renderer:
    def __init__(self):
        pygame.init(); pygame.font.init(); self.screen = pygame.display.set_mode((W, H)); self.stage = pygame.Surface((SW, SH)).convert()
        self.D, self.missing = durations(); self.P = plan(); self.T0 = list(itertools.accumulate([0] + self.D[:-1]))
        self._cap = {}
    MISSING = set("ʻḥḫ″→−∞ꜣ")   # glyphs IM Fell lacks → rendered inline with DejaVu Serif so the text stays exact
    def render_mixed(self, line, f, color):
        fb = font("dejavuserif", 30); runs = []
        for ch in line:
            m = ch in self.MISSING
            if runs and runs[-1][0] == m: runs[-1][1] += ch
            else: runs.append([m, ch])
        parts = [(fb if m else f).render(t, True, color) for m, t in runs]
        out = pygame.Surface((sum(p.get_width() for p in parts) + 2, f.get_height()), pygame.SRCALPHA); x = 0
        for p in parts: out.blit(p, (x, (f.get_height() - p.get_height()) // 2 + 2)); x += p.get_width()
        return out
    def caption(self, i):
        if i not in self._cap:
            s = S[i]; f = F_CAP(); lines = wrap(s["text"], f, W - 160)[:4]
            self._cap[i] = [self.render_mixed(l, f, CREAM) if any(c in self.MISSING for c in l) else f.render(l, True, CREAM) for l in lines]
        return self._cap[i]
    def draw_stage(self, i, st):
        s = S[i]; p = self.P[i]; sd = self.D[i]; surf = self.stage; surf.fill(STAGE); who = s["who"]; t_abs = self.T0[i] + st
        speaking = s["kind"] == "say"
        if p["demo"]:
            name, start = p["demo"]; tt = t_abs - self.T0[start]
            DEMO_FN[name](surf, tt, st, sd, {})
            if speaking and who in PUP and name != "kids_out":
                pygame.draw.rect(surf, (6, 10, 8), (0, 700, 230, 200)); puppet(surf, who, 115, 890, 0.52, t_abs, True, 1)
            return
        # backdrop with a slow push-in
        z = 1.0 + 0.06 * (st / max(sd, 1)); cx = 0.5 + 0.08 * math.sin(i); cy = 0.5
        bp = plate_zoomed(p["back"], z, cx, cy)
        if bp is not None: surf.blit(bp, (0, 0))
        shade = pygame.Surface((SW, SH), pygame.SRCALPHA); shade.fill((0, 0, 0, 70)); surf.blit(shade, (0, 0))
        foc = p["focus"]
        if foc == "title":
            f = F_TITLE(); r = f.render(s["text"], True, PARCH); surf.blit(r, (SW // 2 - r.get_width() // 2, SH // 2 - r.get_height() // 2 - 40))
            pygame.draw.line(surf, CRIM, (SW // 2 - 200, SH // 2 + 30), (SW // 2 + 200, SH // 2 + 30), 3)
        elif foc == "table": self.table(surf, s, st)
        elif foc == "alcove":
            if s["kind"] in ("sign", "close"): self.signoff(surf, s, st, sd, i)
            else: puppet(surf, "WIDUKIND", SW // 2, 760, 1.1, t_abs, False, 1, colour=CYCLE[i % len(CYCLE)]); desk_typewriter(surf, SW // 2, 760, 1.1)
        elif foc == "yard":
            if speaking and who in PUP: puppet(surf, who, 420, 860, 1.0, t_abs, True, 1)
        elif foc == "wide":
            # the whole court, small: Hume (left), Spock (defence), the chair, Feynman at the bench, McClane
            pygame.draw.rect(surf, (36, 30, 26), (880, 560, 300, 20)); pygame.draw.rect(surf, (30, 24, 20), (900, 580, 260, 90))
            for (w_, x, y, sc) in (("HUME", 260, 760, 0.8), ("SPOCK", 560, 740, 0.8), ("FEYNMAN", 1030, 650, 0.62), ("McCLANE", 1300, 760, 0.8)):
                puppet(surf, w_, x, y, sc, t_abs, w_ == who, 1)
            puppet(surf, "KIDS", 720, 470, 0.3, t_abs); puppet(surf, "TEACHER", 790, 470, 0.33, t_abs); puppet(surf, "EARS", 640, 470, 0.33, t_abs); puppet(surf, "VOICE", 580, 470, 0.33, t_abs)
        elif foc == "bench":
            pygame.draw.rect(surf, (36, 30, 26), (440, 600, 640, 26)); pygame.draw.rect(surf, (28, 22, 18), (470, 626, 580, 180))
            puppet(surf, "FEYNMAN", 760, 690, 1.05, t_abs, speaking, 1)
            puppet(surf, "McCLANE", 1250, 860, 0.85, t_abs, False, -1)
        elif foc == "gallery":
            pygame.draw.rect(surf, (30, 26, 22), (200, 700, 1040, 24))
            puppet(surf, who if who in PUP else "HORDE", 720, 840, 1.0, t_abs, speaking, 1)
            for (w_, x) in (("EARS", 300), ("VOICE", 420), ("TEACHER", 1040), ("KIDS", 1140), ("CHAUFFEUR", 1260)):
                if w_ != who: puppet(surf, w_, x, 860, 0.7, t_abs, False, 1)
        elif foc == "floor":
            x = {"HUME": 380, "SPOCK": 900, "McCLANE": 1150}[who]
            puppet(surf, who, x, 860, 1.1, t_abs, speaking, 1 if who != "McCLANE" else -1)
            other = "SPOCK" if who == "HUME" else "HUME"
            puppet(surf, other, 1060 if other == "SPOCK" else 320, 870, 0.8, t_abs, False, -1 if other == "SPOCK" else 1)
        else:  # witness in the chair
            pygame.draw.rect(surf, (70, 50, 36), (560, 560, 320, 18)); pygame.draw.rect(surf, (70, 50, 36), (560, 578, 18, 300)); pygame.draw.rect(surf, (70, 50, 36), (862, 578, 18, 300))
            puppet(surf, who if who in PUP else "HORDE", 720, 870, 1.1, t_abs, speaking, 1)
            puppet(surf, "SPOCK", 1250, 880, 0.7, t_abs, False, -1)
    def table(self, surf, s, st):
        hdr, rows, hi = s["hdr"], s["rows"], s["hi"]; f = F_LAB(20); fb = F_LAB(20, True)
        n = len(hdr); widths = [0.06, 0.30, 0.48, 0.16] if n == 4 else [1 / n] * n; x0, y = 60, 90
        xs = [x0]; [xs.append(xs[-1] + int(w * (SW - 120))) for w in widths]
        for j, h in enumerate(hdr): surf.blit(fb.render(h[:40], True, AMBER), (xs[j] + 6, y))
        y += 40
        for ri, r in enumerate(rows):
            lines_h = 1; cells = []
            for j in range(min(n, len(r))):
                ls = wrap(r[j], f, xs[j + 1] - xs[j] - 12)[:5]; cells.append(ls); lines_h = max(lines_h, len(ls))
            hgt = lines_h * 24 + 10
            if y + hgt > SH - 20: break
            if ri in hi: pygame.draw.rect(surf, (40, 20, 36), (x0 - 10, y - 4, SW - 100, hgt))
            for j, ls in enumerate(cells):
                for k, l in enumerate(ls): surf.blit(f.render(l, True, CREAM if ri in hi else MUTED), (xs[j] + 6, y + k * 24))
            y += hgt
    def signoff(self, surf, s, st, sd, i):
        x, y, sc = SW // 2, 760, 1.1; t_abs = self.T0[i] + st
        puppet(surf, "WIDUKIND", x, y, sc, t_abs, False, 1, colour=CYCLE[i % len(CYCLE)])
        # the sheet rises out of the typewriter: typed during "sign", pulled up and out during "close"
        rise = 0 if s["kind"] == "sign" else 420 * ease(st / max(1, sd * 0.8))
        desk_typewriter(surf, x, y, sc)
        sheet = pygame.Rect(x + 70, y - 164 * sc - 190 - rise, 250, 200); pygame.draw.rect(surf, PARCH, sheet)
        f = F_TYPE(22); n = int(len(bv.SIGNATURE) * min(1, st / max(1, sd * 0.7))) if s["kind"] == "sign" else len(bv.SIGNATURE)
        surf.blit(f.render("The end.", True, INK), (sheet.x + 20, sheet.y + 50)); surf.blit(f.render(bv.SIGNATURE[:n], True, INK), (sheet.x + 20, sheet.y + 110))
        if s["kind"] == "close":  # the room beyond goes fully dark
            shade = pygame.Surface((SW, SH), pygame.SRCALPHA); shade.fill((0, 0, 0, int(200 * ease(st / max(1, sd))))); surf.blit(shade, (0, 0))
    def ledger(self, surf, i, st):
        pygame.draw.rect(surf, BG, (LX, 0, W - LX, CAP_Y)); pygame.draw.line(surf, FAINT, (LX, 0), (LX, CAP_Y), 2)
        # alcove with Widukind at the top of the column
        col = CYCLE[i % len(CYCLE)]; ax, ay = LX + (W - LX) // 2, 150
        pygame.draw.rect(surf, (14, 12, 16), (ax - 150, 40, 300, 240)); pygame.draw.ellipse(surf, (14, 12, 16), (ax - 150, -60, 300, 200))
        puppet(surf, "WIDUKIND", ax, 262, 0.5, self.T0[i] + st, False, 1, colour=col); desk_typewriter(surf, ax, 262, 0.5)
        pygame.draw.rect(surf, col, (LX + 20, 296, W - LX - 40, 4))
        f = F_TYPE(19); y = 320; items = self.P[i]["ledger"]; new = self.P[i]["new"]
        lines = []
        for it in items:
            for l in wrap(typeable(it), f, W - LX - 50): lines.append((l, it in new))
        lines = lines[-22:]
        for (l, isnew) in lines:
            if isnew:  # typed in letter by letter
                n = int(len(l) * min(1, st / 2.5)); l = l[:n]
            surf.blit(f.render(l, True, PARCH if not isnew else CREAM), (LX + 24, y)); y += 25
    def frame(self, i, st):
        scr = self.screen; scr.fill(BG); self.draw_stage(i, st); scr.blit(self.stage, (0, 0))
        s = S[i]
        # section tag + progress
        secname = "" if s["kind"] in ("sign", "close") else next((x["text"] for x in S[:i + 1][::-1] if x["kind"] == "head"), "")
        r = F_SEC().render(secname[:60], True, mix(MUTED, CREAM, 0.3)); scr.blit(r, (24, 14))
        pygame.draw.rect(scr, FAINT, (0, 0, SW, 4)); pygame.draw.rect(scr, MAG, (0, 0, int(SW * (self.T0[i] + st) / (self.T0[-1] + self.D[-1])), 4))
        self.ledger(scr, i, st)
        # caption band
        pygame.draw.rect(scr, (10, 8, 12), (0, CAP_Y, W, H - CAP_Y)); pygame.draw.line(scr, FAINT, (0, CAP_Y), (W, CAP_Y), 2)
        name = disp(s["who"]) if s["kind"] == "say" else ("" if s["kind"] in ("sign", "close") else "")
        y = CAP_Y + 16
        if name: n_ = F_NAME().render(name + ":", True, mix(MAG, CREAM, 0.35)); scr.blit(n_, (80, y)); y += 34
        for ln in self.caption(i):
            if y + 40 > H: break
            scr.blit(ln, (80, y)); y += 38
        return scr

# ───────────────────────── stages ─────────────────────────
def stage_preview(ids=None):
    R = Renderer(); os.makedirs(PREV, exist_ok=True)
    picks = ids or [S[k]["id"] for k in range(0, len(S), max(1, len(S) // 36))]
    for sid in picks:
        i = bv.IDX[sid]; fr = R.frame(i, min(R.D[i] * 0.6, 4.0)); pygame.image.save(fr, os.path.join(PREV, f"{sid}.png"))
    print("preview", len(picks), "frames →", PREV, "| audio missing for", R.missing, "shots")
def stage_demos():
    R = Renderer(); d = os.path.join(PREV, "demos"); os.makedirs(d, exist_ok=True)
    for name, fn in DEMO_FN.items():
        for tt in (1.0, 4.0, 7.5):
            R.stage.fill(STAGE); fn(R.stage, tt, tt, 10.0, {}); pygame.image.save(R.stage, os.path.join(d, f"{name}_{tt:.0f}.png"))
    print("demos →", d)
def render_chunk(args):
    k, lo, hi, fps = args; R = Renderer(); os.makedirs(PARTS, exist_ok=True); out = os.path.join(PARTS, f"part_{k:02d}.mp4")
    nfr = sum(int(round(R.D[i] * fps)) for i in range(lo, hi))
    cmd = ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(fps), "-i", "-",
           "-c:v", "libx264", "-preset", "fast", "-crf", "20", "-pix_fmt", "yuv420p", out]
    pr = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    n = 0
    for i in range(lo, hi):
        fr = int(round(R.D[i] * fps))
        for f in range(fr):
            surf = R.frame(i, f / fps); pr.stdin.write(pygame.image.tostring(surf, "RGB")); n += 1
        if (i - lo) % 20 == 0: print(f"chunk {k}: {S[i]['id']} {n}/{nfr}", flush=True)
    pr.stdin.close(); pr.wait(); return out, [int(round(R.D[i] * fps)) for i in range(lo, hi)]
def stage_render(jobs=4, fps=FPS):
    R = Renderer(); print(f"{len(S)} shots, {sum(R.D)/60:.1f} min, audio missing for {R.missing} shots", flush=True)
    n = len(S); bounds = [round(n * k / jobs) for k in range(jobs + 1)]
    with cf.ProcessPoolExecutor(jobs) as ex: parts = list(ex.map(render_chunk, [(k, bounds[k], bounds[k + 1], fps) for k in range(jobs)]))
    # audio: concat the per-shot wavs padded/trimmed to the exact frame count so A/V stay locked
    import struct
    pcm = b""
    for (k, (part, frs)) in enumerate(parts):
        for j, fr in enumerate(frs):
            i = bounds[k] + j; p = os.path.join(AUD, S[i]["id"] + ".wav"); need = int(round(fr / fps * 24000)) * 2
            body = bv.pcm_of(p) if os.path.exists(p) else b""
            body = body[:need] + b"\x00" * max(0, need - len(body)); pcm += body
    bv.write_wav(os.path.join(HERE, "narration_pg.wav"), pcm)
    lst = os.path.join(PARTS, "list.txt"); open(lst, "w").write("".join(f"file '{p}'\n" for p, _ in parts))
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", lst, "-i", os.path.join(HERE, "narration_pg.wav"),
                    "-c:v", "copy", "-c:a", "aac", "-b:a", "160k", "-shortest", "-movflags", "+faststart", OUT_MP4], check=True)
    print("wrote", OUT_MP4)

if __name__ == "__main__":
    a = sys.argv[1:] or ["preview"]
    if a[0] == "preview": stage_preview(a[1].split(",") if len(a) > 1 else None)
    elif a[0] == "demos": stage_demos()
    elif a[0] == "render":
        jobs = int(a[a.index("--jobs") + 1]) if "--jobs" in a else 4; fps = int(a[a.index("--fps") + 1]) if "--fps" in a else FPS
        stage_render(jobs, fps)
    elif a[0] == "plan":
        R = Renderer()
        for i, (s, p) in enumerate(zip(S, R.P)):
            if p["demo"] or p["new"]: print(s["id"], f"§{s['sec']}", s["who"], p["demo"], p["new"], "|", s["text"][:70])
