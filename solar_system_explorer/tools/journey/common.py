"""
OurMercilessJourney — shared data, frame transform and pygame drawing primitives.

Frame rule: everything orbital is drawn in the solar-equator (Zecliptic) frame,
i = 7.25°, Ω = 75.76°, top-down from Sol's north rotation pole, unless a scene
sets Earth as the frame with a reason (printed on screen).
Rule one: no body is drawn without a data source (DE421 via skyfield, the JSONs
produced by tools/vulcan/*.py, or the live integrator in chapters.CH11).
"""
from __future__ import annotations
import os, json, math, datetime as dt
from pathlib import Path
import numpy as np

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
os.environ.setdefault("SDL_AUDIODRIVER", "dummy")
import pygame  # noqa: E402

# ───────────────────────── paths ─────────────────────────
HERE   = Path(__file__).resolve().parent
TOOLS  = HERE.parent
SSE    = TOOLS.parent                                    # star_learning/solar_system_explorer
DOCS   = SSE / "docs"
OUT    = DOCS / "OUR_MERCILESS_JOURNEY"
LADDER = DOCS / "MERCURY_VULCAN_LADDER_20261010"
DATA   = LADDER / "data"
IMG    = LADDER / "img"
ANDRO  = DOCS / "ANDROMEDA_BRAIN_SCANS_20261010"
FONTS  = SSE.parent / "garden_explorer" / "docs" / "DIAMOND_SCREW_SIM_20261009" / "video" / "fonts"
ELEVEN_ENV = SSE.parent / "ant_explorer" / "tools" / "secrets" / "elevenlabs.env"
SKYFIELD_DIR = "/tmp/skyfield-data"
for p in (OUT, OUT / "audio", OUT / "clips", OUT / "frames_sample", OUT / "storyboard"):
    p.mkdir(parents=True, exist_ok=True)

W, H, FPS = 1920, 1080, 30
AU_KM = 149_597_870.7
GM_SUN = 1.32712440018e20          # m^3 s^-2
GM_MERC = 2.2031870e13
R_MERC_KM = 2439.7
R_EARTH_KM = 6378.137
R_MOON_KM = 1737.4

# ───────────────────────── data (loaded once; every narrated number comes from here) ─────────────────────────
class _Data:
    def __init__(self):
        self._cache = {}
        self.used = []                      # (path, value) audit trail

    def _load(self, name):
        if name not in self._cache:
            self._cache[name] = json.load(open(DATA / name))
        return self._cache[name]

    def get(self, name, *keys, default=None):
        """D.get('v4_annulus.json', 'annulus', 'inner_km_10km_body') -> value, and logs it."""
        o = self._load(name)
        for k in keys:
            try:
                o = o[k]
            except (KeyError, IndexError, TypeError):
                if default is not None:
                    o = default; break
                raise KeyError(f"{name}:{'/'.join(map(str, keys))}")
        self.used.append(("/".join([name, *map(str, keys)]), o if not isinstance(o, (list, dict)) else f"<{type(o).__name__} n={len(o)}>"))
        return o

D = _Data()

def fmt(x, nd=1):
    """Thousands separators for the narration and HUD; never retyped."""
    if isinstance(x, (int, np.integer)) or abs(x) >= 1000 or (isinstance(x, float) and float(x).is_integer() and abs(x) >= 100):
        return f"{int(round(x)):,}"
    return f"{x:,.{nd}f}"

def sci(x, nd=1):
    m, e = f"{x:.{nd}e}".split("e")
    return f"{m}e{int(e)}"

# ───────────────────────── solar-equator (Zecliptic) frame ─────────────────────────
I_SUN = math.radians(7.25)
OMEGA_SUN = math.radians(75.76)

def _rx(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])

def _rz(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])

def ecl_to_se_matrix(incl=I_SUN, node=OMEGA_SUN):
    """Ecliptic J2000 -> solar equator. Earth's solar latitude B0 then runs ±7.25°."""
    return _rx(-incl) @ _rz(-node)

ECL_TO_SE = ecl_to_se_matrix()

def to_se(v, M=ECL_TO_SE):
    v = np.asarray(v, float)
    return (M @ v.T).T if v.ndim == 2 else M @ v

def solar_latitude_deg(v_se):
    v = np.asarray(v_se, float)
    return math.degrees(math.atan2(v[2], math.hypot(v[0], v[1])))

# ───────────────────────── skyfield (DE421 — 1900..2050 only; nothing outside is drawn) ─────────────────────────
_SKY = {}
def sky():
    if not _SKY:
        from skyfield.api import Loader
        load = Loader(SKYFIELD_DIR)
        _SKY["eph"] = load("de421.bsp")
        _SKY["ts"] = load.timescale()
    return _SKY["eph"], _SKY["ts"]

BODY_KEYS = {"sun": "sun", "mercury": "mercury", "venus": "venus", "earth": "earth", "moon": "moon",
             "mars": "mars", "jupiter": "jupiter barycenter", "saturn": "saturn barycenter"}

def helio_ecl_au(body, t):
    """Heliocentric ecliptic-J2000 xyz in AU for a skyfield Time t (scalar or array)."""
    eph, _ = sky()
    p = eph[BODY_KEYS[body]].at(t) - eph["sun"].at(t)
    return np.asarray(p.ecliptic_xyz().au).T

def helio_se_au(body, t):
    return to_se(helio_ecl_au(body, t))

def geo_ecl_km(body, t):
    eph, _ = sky()
    p = eph[BODY_KEYS[body]].at(t) - eph["earth"].at(t)
    return np.asarray(p.ecliptic_xyz().km).T

def tt_from_utc(iso):
    _, ts = sky()
    d = dt.datetime.fromisoformat(iso.replace("Z", "")).replace(tzinfo=dt.timezone.utc)
    return ts.from_datetime(d)

def t_plus(t0, seconds):
    _, ts = sky()
    return ts.tt_jd(t0.tt + seconds / 86400.0)

def utc_str(t, fmt_="%Y-%m-%d %H:%M"):
    return t.utc_strftime(fmt_)

# ───────────────────────── colours & fonts ─────────────────────────
BG      = (7, 8, 12)
INK     = (226, 222, 210)
DIM     = (120, 118, 110)
GOLD    = (222, 178, 74)      # Sol's equator
SUN     = (255, 204, 92)
MERC    = (182, 178, 170)
VENUS   = (232, 206, 150)
EARTH   = (92, 150, 232)
MOON    = (200, 200, 200)
MARS    = (214, 106, 72)
VULCAN  = (230, 64, 56)
RED     = (214, 62, 52)
AMBER   = (226, 160, 56)
GREEN   = (96, 190, 110)
GREY    = (70, 72, 80)
WHITE   = (245, 245, 245)
CARD    = (18, 20, 28)
RULE    = (46, 48, 58)

_FONTS = {}
def font(kind="body", size=28):
    key = (kind, size)
    if key not in _FONTS:
        pygame.font.init()
        path = {
            "title": FONTS / "IMFellEnglish.ttf",
            "ital":  FONTS / "IMFellEnglishItalic.ttf",
            "hand":  FONTS / "Caveat.ttf",
        }.get(kind)
        if path is not None and path.exists():
            _FONTS[key] = pygame.font.Font(str(path), size)
        elif kind == "mono":
            _FONTS[key] = pygame.font.SysFont("dejavusansmono", size)
        else:
            _FONTS[key] = pygame.font.SysFont("dejavusans", size)
    return _FONTS[key]

def text(surf, s, xy, kind="body", size=28, color=INK, anchor="topleft", alpha=255):
    img = font(kind, size).render(s, True, color)
    if alpha < 255:
        img.set_alpha(alpha)
    r = img.get_rect(**{anchor: xy})
    surf.blit(img, r)
    return r

def wrap(s, kind, size, width):
    f = font(kind, size); words = s.split(" "); lines, cur = [], ""
    for w in words:
        t = (cur + " " + w).strip()
        if f.size(t)[0] <= width or not cur:
            cur = t
        else:
            lines.append(cur); cur = w
    if cur: lines.append(cur)
    return lines

def paragraph(surf, s, xy, kind="body", size=26, color=INK, width=800, lead=1.25, alpha=255):
    x, y = xy
    for ln in wrap(s, kind, size, width):
        text(surf, ln, (x, y), kind, size, color, alpha=alpha); y += int(size * lead)
    return y

def ease(p):
    p = max(0.0, min(1.0, p)); return p * p * (3 - 2 * p)

def fade_in(p, t0=0.0, dur=0.6):
    return int(255 * ease((p - t0) / dur))

# ───────────────────────── HUD: caption bar, frame tag, receipt card, board strip ─────────────────────────
def caption(surf, chapter, title, right=""):
    pygame.draw.rect(surf, (10, 11, 16), (0, 0, W, 64))
    pygame.draw.line(surf, RULE, (0, 64), (W, 64), 1)
    text(surf, chapter, (28, 32), "mono", 22, GOLD, "midleft")
    text(surf, title, (150, 32), "title", 34, INK, "midleft")
    if right:
        text(surf, right, (W - 28, 32), "mono", 20, DIM, "midright")

def frame_tag(surf, label="frame: solar equator (Zecliptic) · i 7.25° · Ω 75.76° · top-down from Sol's north", y=None):
    y = (H - 96 - 26) if y is None else y
    text(surf, label, (28, y), "mono", 18, GOLD, "midleft")

def receipt(surf, who_when, quote, rect=(W - 640, 90, 600, 0), p=1.0, label="OPERATOR · verbatim"):
    """A quoted turn from the chat, with timestamp. Verbatim or marked […]."""
    a = fade_in(p, 0.0, 0.5)
    x, y, w, _ = rect
    lines = wrap(quote, "ital", 30, w - 44)
    h = 70 + len(lines) * 38 + 20
    card = pygame.Surface((w, h), pygame.SRCALPHA)
    pygame.draw.rect(card, (*CARD, min(a, 235)), (0, 0, w, h), border_radius=8)
    pygame.draw.rect(card, (*GOLD, a), (0, 0, w, h), 1, border_radius=8)
    text(card, label, (22, 22), "mono", 16, GOLD, alpha=a)
    text(card, who_when, (w - 22, 22), "mono", 16, DIM, "topright", alpha=a)
    yy = 56
    for ln in lines:
        text(card, ln, (22, yy), "ital", 30, INK, alpha=a); yy += 38
    surf.blit(card, (x, y))
    return pygame.Rect(x, y, w, h)

# Board: 13 rows (GAMEPLAN_ELIMINATION §1, states after §8). Colours: open grey · eliminated red · confined amber · dated green · moot white
BOARD_ROWS = {
    1: "locked anti-Earth, any mass", 2: "V1 Charon-scaled 40,223 km", 3: "V2 spin-locked 252,366 km",
    4: "V3 Earth-synchronous 854,287 km", 5: "V4 chain 5,411 km primordial", 6: "V4 class: ~10 km free moon",
    7: "Config B silhouette at occultation", 8: "43″ from solar J₂", 9: "43″ from inner planet/ring",
    10: "43″ from any other Newtonian cause", 11: "id/iv ladder beats chance", 12: "Planet X as the ladder defines it",
    13: "Luna far-side camera reveals Vulcan",
}
STATE_COLOR = {"open": GREY, "eliminated": RED, "confined": AMBER, "dated": GREEN, "moot": WHITE, "emptied": RED}

def board_strip(surf, states: dict, flash: dict | None = None):
    """Persistent bottom HUD. states: {row: state}. flash: {row: 0..1 brightness pulse}."""
    y0 = H - 96
    pygame.draw.rect(surf, (10, 11, 16), (0, y0, W, 96))
    pygame.draw.line(surf, RULE, (0, y0), (W, y0), 1)
    text(surf, "BOARD", (28, y0 + 48), "mono", 18, DIM, "midleft")
    cw, gap, x = 98, 10, 120
    n = {"eliminated": 0, "confined": 0, "dated": 0, "moot": 0, "open": 0, "emptied": 0}
    for r in range(1, 14):
        st = states.get(r, "open"); n[st] += 1
        col = STATE_COLOR[st]
        if flash and r in flash:
            k = flash[r]; col = tuple(min(255, int(c + (255 - c) * k)) for c in col)
        rect = pygame.Rect(x, y0 + 16, cw, 64)
        pygame.draw.rect(surf, col if st != "open" else (28, 30, 38), rect, border_radius=6)
        pygame.draw.rect(surf, col, rect, 2, border_radius=6)
        text(surf, f"{r}", (x + 10, y0 + 24), "mono", 20, WHITE if st != "open" else DIM)
        text(surf, st if st != "open" else "", (x + cw - 8, y0 + 70), "mono", 13, (10, 11, 16) if st in ("moot", "confined", "dated") else WHITE, "bottomright")
        x += cw + gap
    text(surf, f"closed {n['eliminated'] + n['emptied']} · confined {n['confined']}", (W - 28, y0 + 36), "mono", 15, DIM, "midright")
    text(surf, f"dated {n['dated']} · moot {n['moot']} · open {n['open']}", (W - 28, y0 + 60), "mono", 15, DIM, "midright")

def legend(surf, items, xy, size=18, dx=0, dy=28):
    x, y = xy
    for col, lab in items:
        pygame.draw.circle(surf, col, (x + 8, y + 9), 7)
        text(surf, lab, (x + 26, y + 9), "mono", size, INK, "midleft")
        x += dx; y += dy

_IMG_CACHE = {}
def blit_figure(surf, path, rect, label="figure (matplotlib) · blitted, not re-rendered", p=1.0):
    """Existing PNG/JPG figures may be shown when the chapter is ABOUT the figure; always labelled."""
    x, y, w, h = rect
    key = (str(path), w, h)
    if key not in _IMG_CACHE:
        img = pygame.image.load(str(path))
        iw, ih = img.get_size(); s = min(w / iw, h / ih)
        _IMG_CACHE[key] = pygame.transform.smoothscale(img, (int(iw * s), int(ih * s)))
    img = _IMG_CACHE[key].copy()
    if p < 1.0: img.set_alpha(fade_in(p, 0.0, 0.5))
    r = img.get_rect(center=(x + w // 2, y + h // 2)); surf.blit(img, r)
    text(surf, label, (r.left, r.bottom + 6), "mono", 15, DIM)
    return r

# ───────────────────────── orrery primitives ─────────────────────────
class View:
    """Top-down map: SE-frame (x,y) in some unit -> pixels. +x right, +y up (Sol's north out of the screen)."""
    def __init__(self, cx, cy, px_per_unit):
        self.cx, self.cy, self.k = cx, cy, px_per_unit
    def xy(self, v):
        return (int(self.cx + v[0] * self.k), int(self.cy - v[1] * self.k))

def orbit_path(surf, view, pts, color, width=1, alpha=120, closed=True):
    if len(pts) < 2: return
    lay = pygame.Surface((W, H), pygame.SRCALPHA)
    poly = [view.xy(p) for p in pts]
    pygame.draw.lines(lay, (*color, alpha), closed, poly, width)
    surf.blit(lay, (0, 0))

def body(surf, view, v, color, r=6, label=None, lab_dx=12, lab_dy=-12, size=20, ring=None):
    x, y = view.xy(v)
    if ring:
        pygame.draw.circle(surf, ring, (x, y), r + 4, 1)
    pygame.draw.circle(surf, color, (x, y), r)
    if label:
        text(surf, label, (x + lab_dx, y + lab_dy), "mono", size, color, "midleft")
    return x, y

def arrow(surf, p0, p1, color, width=2, head=10):
    pygame.draw.line(surf, color, p0, p1, width)
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]; L = math.hypot(dx, dy) or 1.0
    ux, uy = dx / L, dy / L
    pts = [p1, (p1[0] - head * ux + head * 0.5 * uy, p1[1] - head * uy - head * 0.5 * ux),
           (p1[0] - head * ux - head * 0.5 * uy, p1[1] - head * uy + head * 0.5 * ux)]
    pygame.draw.polygon(surf, color, pts)

def sol_equator_line(surf, y, alpha=140):
    lay = pygame.Surface((W, H), pygame.SRCALPHA)
    pygame.draw.line(lay, (*GOLD, alpha), (0, y), (W, y), 1)
    surf.blit(lay, (0, 0))

def days(seconds): return seconds / 86400.0
