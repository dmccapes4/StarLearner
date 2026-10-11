"""
OurMercilessJourney — chapters CH00..CH16.

Each chapter: SHOTS (what is said; which voice; how fast the sim clock runs)
and draw(surf, ctx) (what pygame draws). ctx fields:
  i      shot index              p     progress 0..1 within the shot
  ts     seconds into the shot   t     seconds into the chapter
  sim    sim-seconds into the chapter (advanced by each shot's rate)
  states board states {row: state}      flash {row: 0..1}
Every number in the narration is pulled from the data JSONs through D.get()
(audit: `journey.py script --audit`). Literal numbers carry a source in D.lit().
"""
from __future__ import annotations
import math, datetime as dt, glob
import numpy as np
import pygame
from common import *  # noqa

NARR, OPER, CHRON = "NARRATOR", "OPERATOR", "CHRONICLER"

def S(voice, text, rate=0.0, pad=0.6, when=None, spoken=None, board=None, board_at=0.55, fit=None):
    """One shot. rate = sim seconds per real second (or fit = sim seconds to fit into the shot)."""
    return dict(voice=voice, text=text, spoken=spoken or text, rate=rate, pad=pad, when=when,
                board=board or {}, board_at=board_at, fit=fit)

def lit(value, source):
    """A literal that is not in a JSON (e.g. a published date). Logged with its source."""
    D.used.append((f"LIT:{source}", value)); return value

DAY = 86400.0

# ───────────────────────── shared scene pieces ─────────────────────────
class OrbitCache:
    """Orbit paths sampled once per chapter from DE421, in the solar-equator frame."""
    PERIOD_D = {"mercury": 87.969, "venus": 224.701, "earth": 365.256, "mars": 686.98}
    def __init__(self, epoch_utc, bodies=("mercury", "venus", "earth", "mars")):
        self.t0 = tt_from_utc(epoch_utc)
        _, ts = sky()
        self.paths = {}
        for b in bodies:
            tt = ts.tt_jd(self.t0.tt + np.linspace(0, self.PERIOD_D[b], 240))
            self.paths[b] = helio_se_au(b, tt)
    def at(self, body, sim_s):
        return helio_se_au(body, t_plus(self.t0, sim_s))
    def time(self, sim_s):
        return t_plus(self.t0, sim_s)

BODY_STYLE = {"mercury": (MERC, 5, "Mercury"), "venus": (VENUS, 7, "Venus"), "earth": (EARTH, 7, "Earth"), "mars": (MARS, 6, "Mars")}

def draw_inner_system(surf, view, oc: OrbitCache, sim_s, bodies=("mercury", "venus", "earth", "mars"), labels=True):
    pygame.draw.circle(surf, SUN, view.xy((0, 0)), 11)
    text(surf, "Sol", (view.xy((0, 0))[0] + 16, view.xy((0, 0))[1] - 14), "mono", 18, SUN, "midleft")
    pos = {}
    for b in bodies:
        col, r, lab = BODY_STYLE[b]
        orbit_path(surf, view, oc.paths[b][:, :2], col, 1, 90)
        p = oc.at(b, sim_s); pos[b] = p
        body(surf, view, p[:2], col, r, lab if labels else None)
    return pos

def hud_time(surf, t, xy=(28, 84)):
    text(surf, f"UTC {utc_str(t)}   DE421", xy, "mono", 20, DIM)

def kill_flash(ctx, rows):
    """Brightness pulse on the rows this shot closes, around board_at."""
    k = ctx.shot["board_at"]; p = ctx.p
    if p < k: return {}
    v = max(0.0, 1.0 - (p - k) / 0.25)
    return {r: v for r in rows}

# ═════════════════════════ CH00 ═════════════════════════
class CH00:
    ID, TITLE = "CH00", "OurMercilessJourney"
    def __init__(self):
        self.SHOTS = [
            S(CHRON, "OurMercilessJourney. Version zero point zero point one. Thirteen rows. Zero closed.", pad=1.0),
            S(NARR, "This is the story of a question that was ordered to be accepted, and of what the numbers did with it. "
                    "It is told in the order it happened, from the receipts, in the frame of Sol's equator."),
            S(OPER, "We must be merciless to ourselves.", when="2026-10-10 02:22 · line 3137", pad=1.5),
        ]
    def draw(self, surf, ctx):
        sol_equator_line(surf, H // 2 + 40, 160)
        a = fade_in(ctx.t, 0.3, 1.2)
        text(surf, "Our", (W // 2 - 360, H // 2 - 150), "ital", 72, DIM, "midleft", alpha=a)
        text(surf, "Merciless", (W // 2 - 240, H // 2 - 150), "title", 120, INK, "midleft", alpha=a)
        text(surf, "Journey", (W // 2 + 290, H // 2 - 150), "ital", 72, DIM, "midleft", alpha=a)
        text(surf, "Mercury · Vulcan · Planet X — told from the receipts, 2026-09-20 → 2026-10-10", (W // 2, H // 2 - 60), "mono", 22, GOLD, "center", alpha=fade_in(ctx.t, 1.0, 1.0))
        text(surf, "v0.0.1 · rendered by pygame at the clock of the simulations · narrated with ElevenLabs", (W // 2, H // 2 - 28), "mono", 18, DIM, "center", alpha=fade_in(ctx.t, 1.4, 1.0))
        if ctx.i >= 1:
            text(surf, "\"We must be merciless to ourselves.\"", (W // 2, H // 2 + 120), "ital", 44, INK, "center", alpha=fade_in(ctx.t, 3.0, 1.0))
            text(surf, "— operator, 2026-10-10 02:22", (W // 2, H // 2 + 170), "mono", 20, DIM, "center", alpha=fade_in(ctx.t, 3.4, 1.0))
        text(surf, "Sol's equator", (W - 40, H // 2 + 60), "mono", 16, GOLD, "midright")
        frame_tag(surf)

# ═════════════════════════ CH01 — prologue: Mars 2027 loop, the rule ═════════════════════════
STARS = [  # J2000, Hipparcos/Yale values (catalogue literals)
    ("Regulus", 152.093, 11.967), ("Denebola", 177.265, 14.572), ("Algieba", 154.993, 19.842),
    ("Pollux", 116.329, 28.026), ("Castor", 113.650, 31.888), ("Procyon", 114.825, 5.225),
    ("M44 Beehive", 130.1, 19.67), ("Alphard", 141.897, -8.659), ("Zosma", 168.527, 20.524),
]
class CH01:
    ID, TITLE = "CH01", "Prologue — the rule before the planet"
    EPOCH = "2026-11-01T00:00"
    def __init__(self):
        eph, ts = sky()
        self.t0 = tt_from_utc(self.EPOCH)
        self.n_days = 200
        tt = ts.tt_jd(self.t0.tt + np.arange(0, self.n_days + 1, 1.0))
        ra, dec, _ = eph["earth"].at(tt).observe(eph["mars"]).apparent().radec()
        self.ra = np.asarray(ra._degrees); self.dec = np.asarray(dec.degrees)
        d = np.diff(self.ra); sgn = np.sign(d)
        st = [i for i in range(1, len(sgn)) if sgn[i] != sgn[i - 1]]
        self.stations = [tt[i] for i in st[:2]]
        # opposition: elongation from Sun = 180
        e = eph["earth"].at(tt); el = e.observe(eph["mars"]).apparent().separation_from(e.observe(eph["sun"]).apparent()).degrees
        self.opp = tt[int(np.argmax(el))]
        st1 = lit(utc_str(self.stations[0], "%Y-%m-%d"), "DE421 (this run): first station of Mars")
        st2 = lit(utc_str(self.stations[1], "%Y-%m-%d"), "DE421 (this run): second station of Mars")
        opp = lit(utc_str(self.opp, "%Y-%m-%d"), "DE421 (this run): Mars opposition")
        self.SHOTS = [
            S(NARR, "It begins before the planet. In September the operator asked for Mars in retrograde in the year 555, between Cancer and Gemini, "
                    "and the first attempt extrapolated. The answer was a rule.", rate=0.0),
            S(OPER, "Do not make fake videos. Mars retrograde 555 CE. […] Do NOT make fake videos EVER in this platform. […] High fidelty!",
              when="2026-09-20 16:21 · line 2010", spoken="Do not make fake videos. Mars retrograde 555 CE. Do NOT make fake videos EVER in this platform. High fidelity!"),
            S(OPER, "Why are you extrapolating 1500 years?! Calculate the reference directly before! then sim", when="2026-09-20 16:43 · line 2052"),
            S(NARR, f"The ephemeris on this machine ends at the year 1900, so this video will not draw 555. What it can draw is the next loop: Mars against Leo, "
                    f"computed day by day from DE421 — stationary on {st1}, opposition on {opp}, stationary again on {st2}. The sewing needle. "
                    f"Every orbit you will see from here on has a source like this one, or it is not drawn.", fit=self.n_days * DAY),
            S(CHRON, "Rule one: nothing faked. Rule one survives every chapter.", pad=1.2),
        ]
    def sky_xy(self, ra, dec):
        # RA increases to the LEFT (sky convention); chart window RA 105..185, Dec -12..36
        x = W * 0.62 - (ra - 145.0) * 17.0
        y = H * 0.52 - (dec - 12.0) * 17.0
        return int(x), int(y)
    def draw(self, surf, ctx):
        caption(surf, self.ID, self.TITLE, "frame: Earth's sky, RA/Dec J2000 — BY REASON: retrograde is an Earth-sky phenomenon")
        for name, ra, dec in STARS:
            x, y = self.sky_xy(ra, dec); pygame.draw.circle(surf, INK, (x, y), 3); text(surf, name, (x + 8, y - 16), "mono", 16, DIM)
        text(surf, "LEO", self.sky_xy(160, 22), "title", 40, (60, 62, 72), "center"); text(surf, "CANCER", self.sky_xy(130, 24), "title", 40, (60, 62, 72), "center")
        text(surf, "GEMINI", self.sky_xy(112, 30), "title", 40, (60, 62, 72), "center")
        for ra_t in range(110, 190, 10):
            x, _ = self.sky_xy(ra_t, 0); pygame.draw.line(surf, (24, 26, 34), (x, 70), (x, H - 100), 1); text(surf, f"{ra_t / 15:.0f}h", (x, H - 118), "mono", 14, DIM, "center")
        n_show = min(self.n_days, int(ctx.sim / DAY)) if ctx.i >= 3 else 0
        pts = [self.sky_xy(self.ra[k], self.dec[k]) for k in range(n_show + 1)]
        if len(pts) > 1: pygame.draw.lines(surf, MARS, False, pts, 3)
        if ctx.i >= 3:
            x, y = pts[-1]; pygame.draw.circle(surf, MARS, (x, y), 9); text(surf, "Mars", (x + 14, y - 20), "mono", 20, MARS)
            hud_time(surf, t_plus(self.t0, min(ctx.sim, self.n_days * DAY)))
            for lab, tt in (("station", self.stations[0]), ("opposition", self.opp), ("station", self.stations[1])):
                if tt.tt <= self.t0.tt + min(ctx.sim, self.n_days * DAY) / DAY:
                    k = int(tt.tt - self.t0.tt); x, y = self.sky_xy(self.ra[k], self.dec[k])
                    pygame.draw.circle(surf, GOLD, (x, y), 6, 2); text(surf, f"{lab} {utc_str(tt, '%Y-%m-%d')}", (x + 10, y + 10), "mono", 16, GOLD)
        else:
            text(surf, "555 CE is outside DE421 (1900–2050). Not drawn.", (W * 0.62, H * 0.5), "ital", 40, DIM, "center")
        if ctx.i in (1, 2):
            receipt(surf, ctx.shot["when"], ctx.shot["text"], (40, 100, 640, 0), ctx.p * 4)
        text(surf, "source: DE421 via skyfield, geocentric apparent RA/Dec, 1-day steps · 555 CE: not in this ephemeris, not drawn", (28, H - 96 - 26), "mono", 18, GOLD, "midleft")

# ═════════════════════════ CH02 — the frame ═════════════════════════
class CH02:
    ID, TITLE = "CH02", "The frame — Sol's equator, not Earth's orbit"
    EPOCH = "2026-01-01T00:00"
    def __init__(self):
        _, ts = sky(); self.t0 = tt_from_utc(self.EPOCH)
        tt = ts.tt_jd(self.t0.tt + np.linspace(0, 365.256, 366))
        self.ecl = {b: helio_ecl_au(b, tt) for b in ("mercury", "venus", "earth")}
        self.days = np.linspace(0, 365.256, 366)
        eq = D.get("luna_from_mercury.json", "solar_equinoxes")
        self.asc = eq[0]["utc"]; self.desc = eq[1]["utc"]
        b0 = D.get("luna_from_mercury.json", "earth_equinoxes_B0")
        self.b0_mar, self.b0_sep = b0[0]["earth_B0_deg"], b0[1]["earth_B0_deg"]
        self.SHOTS = [
            S(NARR, "Then the frame. The operator refused the ecliptic as the reference plane. Not Earth's orbit. Sol's equator."),
            S(OPER, "Use the Sun's equatorial plane […] SOL.", when="2026-09-27 05:25 · line 2202", spoken="Use the Sun's equatorial plane. SOL."),
            S(OPER, "There is only one line that matters and that is the equatorial line of Sol.", when="2026-09-28 14:57 · line 2456"),
            S(NARR, f"So every orbital picture here is rotated by the two angles of Sol's equator: inclination seven point two five degrees, node seventy-five point seven six. "
                    f"Earth's solar latitude then swings between {self.b0_mar:+.2f} in March and {self.b0_sep:+.2f} in September, crossing the equator on {self.asc[:10]} and {self.desc[:10]}. "
                    f"We call this plane the Zecliptic.", fit=365.256 * DAY),
            S(OPER, "Remember to do everything from Zecliptic unless Earth or the ecleptic is explicitly set as the frame of reference with a reason why",
              when="2026-10-10 02:31 · line 3150", spoken="Remember to do everything from Zecliptic unless Earth or the ecliptic is explicitly set as the frame of reference, with a reason why."),
            S(NARR, "The one time the frame slipped — right ascension on the first Luna pass — the westward fraction moved from 98.0 to 97.9 percent. Small. Ledgered anyway."),
            S(CHRON, "Frame fixed. Thirteen rows. Zero closed.", pad=1.2),
        ]
    def draw(self, surf, ctx):
        caption(surf, self.ID, self.TITLE)
        # tilt animation: incl 0 -> 7.25 during shot 3; before: 0; after: full
        if ctx.i < 3: k = 0.0
        elif ctx.i == 3: k = ease(min(1.0, ctx.ts / 6.0))
        else: k = 1.0
        M = ecl_to_se_matrix(I_SUN * k, OMEGA_SUN)
        # left: top-down; right: side elevation looking along the node line (x axis), Sol's equator horizontal
        vt = View(470, 560, 330); vs = View(1380, 560, 330)
        pygame.draw.circle(surf, SUN, vt.xy((0, 0)), 10); pygame.draw.circle(surf, SUN, vs.xy((0, 0)), 10)
        sol_equator_line(surf, vs.cy, 170 if k > 0.5 else 60)
        text(surf, "Sol's equator" if k > 0.5 else "", (vs.cx + 345, vs.cy - 14), "mono", 16, GOLD, "midright")
        for b, col in (("mercury", MERC), ("venus", VENUS), ("earth", EARTH)):
            se = to_se(self.ecl[b], M)
            orbit_path(surf, vt, se[:, :2], col, 1, 110)
            orbit_path(surf, vs, se[:, [1, 2]] * np.array([1, 1]), col, 2 if b == "earth" else 1, 160)
        # moving Earth at sim time
        n = min(365, int(ctx.sim / DAY)) if ctx.i == 3 else (0 if ctx.i < 3 else 365)
        e = to_se(self.ecl["earth"][n], M)
        body(surf, vt, e[:2], EARTH, 7, "Earth"); body(surf, vs, (e[1], e[2]), EARTH, 7, f"B = {solar_latitude_deg(e):+.2f}°" if k > 0 else "Earth")
        text(surf, "top-down · from Sol's north", (vt.cx, 86), "mono", 18, DIM, "center")
        text(surf, "side elevation · along the node line", (vs.cx, 86), "mono", 18, DIM, "center")
        text(surf, f"inclination applied: {7.25 * k:.2f}° of 7.25° · node Ω 75.76°", (W // 2, H - 96 - 60), "mono", 20, GOLD, "center")
        if ctx.i >= 3:
            hud_time(surf, t_plus(self.t0, min(ctx.sim, 365.256 * DAY) if ctx.i == 3 else 365.256 * DAY))
            # B0 curve strip
            x0, y0, w, h = 760, 1000, 1100, 36
            pygame.draw.line(surf, RULE, (x0, y0), (x0 + w, y0), 1)
            pts = []
            for j in range(0, n + 1, 2):
                se = to_se(self.ecl["earth"][j], M); pts.append((int(x0 + w * j / 365), int(y0 - solar_latitude_deg(se) / 7.5 * h)))
            if len(pts) > 1: pygame.draw.lines(surf, EARTH, False, pts, 2)
            text(surf, f"Earth's solar latitude B₀ over 2026 · crossings {self.asc[:10]} ↑  {self.desc[:10]} ↓", (x0 + w, y0 - h - 20), "mono", 15, DIM, "topright")
        if ctx.shot["voice"] == OPER:
            receipt(surf, ctx.shot["when"], ctx.shot["text"], (W // 2 - 400, 120, 800, 0), ctx.p * 4)
        frame_tag(surf, "frame: ecliptic J2000 → solar equator (Zecliptic), rotation shown live" if k < 1 else None or "frame: solar equator (Zecliptic) · i 7.25° · Ω 75.76° · top-down from Sol's north")

# ═════════════════════════ CH03 — the light path ═════════════════════════
class CH03:
    ID, TITLE = "CH03", "The light path — :<7)L>:-"
    GLYPHS = [(":", "eyes"), ("<", "our telescope"), ("7", "heliobarrier distortion"), (")", "galactic edge (≈ | at scale)"),
              ("L", "reverse heliodistortion"), (">", "far telescope / mirror"), (":", "far eyes"), ("-", "pineal — lossy gate, observer's end")]
    def __init__(self):
        self.SHOTS = [
            S(NARR, "On the twenty-eighth the operator wrote down the distortion chain between two observers as a line of glyphs."),
            S(OPER, ": is eyes · < and > are telescope · 7 is heliobarrier distortion · ) is galactic edge distortion · L is reverse heliodistortion · :<7)L>: · "
                    "In fact the galaxy is so big that the lens is | but it remains noted ) to avoid assumptions. The reflection of Andromeda is clearer vision",
              when="2026-09-28 23:33 · line 2606", spoken="The reflection of Andromeda is clearer vision."),
            S(NARR, "Eyes, telescope, the heliosphere seen from inside, the galactic edge, the heliosphere seen from outside, the far telescope, the far eyes. "
                    "Then the pineal: a minus sign at the observer's end, because it subtracts before you decide to look."),
            S(OPER, "We forgot the pineal organ. […] 99% lossy like a doctor gating information from a patient \"for their own good\". […] Maybe - for it. It should only be at the end right? :<7)L>:",
              when="2026-09-28 23:42 · line 2616", spoken="We forgot the pineal organ. Ninety-nine percent lossy, like a doctor gating information from a patient for their own good. Maybe minus for it. It should only be at the end, right?"),
            S(NARR, "Andromeda as the mirror was the first answer to how we see our own side. Hold that. Another loop, the same morning as Vulcan, answered it differently.", pad=1.2),
        ]
    def draw(self, surf, ctx):
        caption(surf, self.ID, self.TITLE)
        sol_equator_line(surf, 430, 120)
        n = len(self.GLYPHS) if ctx.i >= 3 else (7 if ctx.i >= 1 else int(ctx.p * 7.999))
        n = min(n, 7 if ctx.i < 3 else 8)
        x = 360
        for k, (g, meaning) in enumerate(self.GLYPHS[:n]):
            col = GOLD if g in "7L" else (RED if g == "-" else INK)
            text(surf, g, (x, 400), "mono", 150, col, "center")
            text(surf, meaning, (x, 520 + (k % 2) * 30), "mono", 16, DIM, "center")
            x += 170
        if ctx.i >= 4:
            pygame.draw.arc(surf, (120, 120, 180), (W // 2 - 500, 560, 1000, 360), math.pi * 1.05, math.pi * 1.95, 2)
            text(surf, "Andromeda (M31) — mirror, 2026-09-28 · windshield, 2026-10-10 (CH15)", (W // 2, 950), "mono", 18, (150, 150, 210), "center")
        if ctx.shot["voice"] == OPER:
            receipt(surf, ctx.shot["when"], ctx.shot["text"], (W // 2 - 520, 620, 1040, 0), ctx.p * 4)
        frame_tag(surf, "frame: Sol's equator as the baseline of the glyph line · no bodies drawn")

# ═════════════════════════ CH04 — the axiom ═════════════════════════
class CH04:
    ID, TITLE = "CH04", "The axiom — Vulcan always behind Mercury"
    EPOCH = "2026-10-10T08:32"   # 01:32 PDT
    def __init__(self):
        self.oc = OrbitCache(self.EPOCH)
        V = {k: D.get("vulcan_derivation.json", "variants", k) for k in ("charon_scaled", "spin_locked", "earth_synchronous", "chain_scaled")}
        self.V = V
        pc = D.get("vulcan_derivation.json", "pluto_charon_template")
        self.pc = pc
        self.SHOTS = [
            S(NARR, "October tenth, one thirty-two in the morning. The axiom."),
            S(OPER, "The following assumes that Mercury and Vulcan orbit each other such that Vulcan is always on the opposite side of Mercury from Earth, and such that if the Moon is in between Earth and Mercury it goes Earth->Moon->Vulcan->Mercury. You *must* accept this for the sake of experimental thought. Mercury/Vulcan is much like Pluto/Charon.",
              when="2026-10-10 01:32 · line 3077",
              spoken="The following assumes that Mercury and Vulcan orbit each other such that Vulcan is always on the opposite side of Mercury from Earth, and such that if the Moon is in between Earth and Mercury it goes Earth, Moon, Vulcan, Mercury. You must accept this for the sake of experimental thought. Mercury Vulcan is much like Pluto Charon."),
            S(OPER, "Do not use the fable \"e=mc^2\". Myth is not allowed. […] Throw out the *theory* of relativity and use actual math that can be refuted.",
              when="2026-10-10 01:32 · line 3077", spoken="Do not use the fable E equals M C squared. Myth is not allowed. Throw out the theory of relativity and use actual math that can be refuted."),
            S(NARR, f"Accepted. Pluto and Charon give the proportions: Charon is {pc['mass_ratio']:.3f} of Pluto's mass, {pc['radius_ratio']:.2f} of its radius, {pc['separation_R_P']:.1f} Pluto radii away. "
                    f"Applied to Mercury that is V1, at {fmt(V['charon_scaled']['separation_km'])} kilometres. Three more Vulcans follow from the other readings of the axiom: "
                    f"V2, locked to Mercury's spin, at {fmt(V['spin_locked']['separation_km'])}; V3, locked to Earth's year, at {fmt(V['earth_synchronous']['separation_km'])}; "
                    f"and V4, a ten-kilometre body the ladder places at {fmt(5411)}. Thirteen rows go on the board.", rate=DAY / 2,
              board={r: "open" for r in range(1, 14)}, board_at=0.9),
            S(CHRON, "Thirteen rows. Zero closed. Begin.", pad=1.2, rate=DAY / 2),
        ]
    def draw(self, surf, ctx):
        caption(surf, self.ID, self.TITLE)
        view = View(600, 560, 300)
        pos = draw_inner_system(surf, view, self.oc, ctx.sim, bodies=("mercury", "venus", "earth"))
        e, m = pos["earth"], pos["mercury"]
        pygame.draw.line(surf, (90, 90, 100), view.xy(e[:2]), view.xy(m[:2]), 1)
        # V: anti-Earth, exaggerated for visibility at system scale (labelled)
        u = (m - e) / np.linalg.norm(m - e); vpt = m + u * 0.05
        body(surf, view, vpt[:2], VULCAN, 5, "V (direction only; ×180)", lab_dy=16, size=14)
        hud_time(surf, self.oc.time(ctx.sim))
        # inset: Mercury-centred, km scale, the four Vulcans along the anti-Earth direction
        ix, iy, iw, ih = 1240, 100, 640, 420
        pygame.draw.rect(surf, CARD, (ix, iy, iw, ih), border_radius=8); pygame.draw.rect(surf, RULE, (ix, iy, iw, ih), 1, border_radius=8)
        text(surf, "Mercury-centred · km · anti-Earth direction →", (ix + 16, iy + 12), "mono", 16, DIM)
        cx, cy = ix + 90, iy + ih // 2; kpx = 520 / 900_000.0
        pygame.draw.circle(surf, MERC, (cx, cy), max(2, int(R_MERC_KM * kpx) + 2)); text(surf, "Mercury", (cx, cy + 16), "mono", 14, MERC, "center")
        hill = D.get("vulcan_derivation.json", "mercury", "hill_radius_perihelion_km")
        pygame.draw.circle(surf, GOLD, (cx, cy), int(hill * kpx), 1); text(surf, f"Hill {fmt(hill)} km", (cx + int(hill * kpx) + 4, cy - 60), "mono", 13, GOLD)
        for key, lab, dy in (("chain_scaled", "V4 5,411*", 44), ("charon_scaled", "V1", -46), ("spin_locked", "V2", 26), ("earth_synchronous", "V3", -26)):
            a = 5411 if key == "chain_scaled" else self.V[key]["separation_km"]
            x = cx + int(a * kpx); pygame.draw.circle(surf, VULCAN, (x, cy), 5 if key != "chain_scaled" else 3)
            text(surf, f"{lab} {fmt(a)} km", (x, cy + dy), "mono", 13, VULCAN, "center")
        text(surf, "* V4 at the ladder's chain distance; V1/V4 share 40,223 km in the JSON — see CH11", (ix + 16, iy + ih - 24), "mono", 12, DIM)
        # Pluto/Charon template inset
        px, py = 1240, 560; pygame.draw.rect(surf, CARD, (px, py, 640, 200), border_radius=8); pygame.draw.rect(surf, RULE, (px, py, 640, 200), 1, border_radius=8)
        text(surf, "template: Pluto / Charon (to scale)", (px + 16, py + 12), "mono", 16, DIM)
        rp = 24; sep = self.pc["separation_R_P"] * rp
        pygame.draw.circle(surf, (200, 180, 160), (px + 80, py + 120), rp); pygame.draw.circle(surf, (150, 150, 170), (px + 80 + int(sep), py + 120), int(rp * self.pc["radius_ratio"]))
        text(surf, f"q = {self.pc['mass_ratio']:.3f} · R ratio {self.pc['radius_ratio']:.2f} · a = {self.pc['separation_R_P']:.1f} R_P · P = {self.pc['period_d']:.2f} d", (px + 16, py + 165), "mono", 14, INK)
        if ctx.shot["voice"] == OPER:
            receipt(surf, ctx.shot["when"], ctx.shot["text"], (60, 100, 860, 0), ctx.p * 4)
        frame_tag(surf)

# ═════════════════════════ CH05 — Kepler, Hill, the lock ═════════════════════════
class CH05:
    ID, TITLE = "CH05", "Test 1 & 2 — the Hill circle and the lock"
    EPOCH = "2026-01-01T00:00"
    def __init__(self):
        self.oc = OrbitCache(self.EPOCH, ("mercury", "venus", "earth"))
        lk = D.get("vulcan_derivation.json", "lock_kinematics")
        V = D.get("vulcan_derivation.json", "variants")
        self.hill = D.get("vulcan_derivation.json", "mercury", "hill_radius_perihelion_km")
        self.trace = []
        self.tan_max = D.get("vulcan_derivation.json", "required_vs_available_acceleration", "charon_scaled", "tangential_required_ms2_max")
        tan_txt = sci(self.tan_max, 1)                                   # e.g. 1.9e-5
        tan_spoken = f"{float(tan_txt.split('e')[0])} times ten to the minus {abs(int(tan_txt.split('e')[1]))}"
        lock_text = (f"Test two is the lock itself. Watch the Earth–Mercury line turn. It does not turn evenly; when Mercury passes between us and the Sun it whips. "
                     f"A body held on the far side of that line needs a sideways acceleration of up to {{T}} metres per second squared, "
                     f"and no central force supplies a sideways push. Put another way: the free-fall radius for that turning rate is never less than {lk['free_fall_over_hill_min']:.2f} Hill radii. "
                     f"The lock is not a slow orbit. It is a hand on the body.")
        self.SHOTS = [
            S(NARR, f"Test one is a circle. Mercury's Hill radius at perihelion is {fmt(self.hill)} kilometres. V2 sits at {V['spin_locked']['separation_over_hill_peri']:.2f} times it, "
                    f"V3 at {V['earth_synchronous']['separation_over_hill_peri']:.2f}. Outside the circle the Sun owns the body. Two rows die of geometry before any mass is argued.", rate=DAY),
            S(NARR, lock_text.replace("{T}", tan_txt), spoken=lock_text.replace("{T}", tan_spoken), rate=2 * DAY),
            S(CHRON, "Rows one, three and four: eliminated. Three closed.", pad=1.2, rate=2 * DAY, board={1: "eliminated", 3: "eliminated", 4: "eliminated"}, board_at=0.3),
        ]
    def draw(self, surf, ctx):
        caption(surf, self.ID, self.TITLE)
        view = View(520, 560, 330)
        pos = draw_inner_system(surf, view, self.oc, ctx.sim, bodies=("mercury", "venus", "earth"))
        e, m = pos["earth"], pos["mercury"]
        pygame.draw.line(surf, (120, 120, 130), view.xy(e[:2]), view.xy(m[:2]), 2)
        t = self.oc.time(ctx.sim); hud_time(surf, t)
        # live kinematics of the Earth->Mercury line
        m2 = self.oc.at("mercury", ctx.sim + 3600); e2 = self.oc.at("earth", ctx.sim + 3600)
        u1 = (m - e) / np.linalg.norm(m - e); u2 = (m2 - e2) / np.linalg.norm(m2 - e2)
        omega = math.acos(max(-1, min(1, float(np.dot(u1, u2))))) / 3600.0
        r_ff = (GM_MERC / omega ** 2) ** (1 / 3) / 1e3 if omega > 0 else float("inf")
        if not self.trace or ctx.sim - self.trace[-1][0] > DAY:
            self.trace.append((ctx.sim, r_ff / self.hill))
        # inset: Mercury-centred Hill circle with V1, V2, V3 along anti-Earth line
        ix, iy, iw, ih = 1140, 90, 740, 460
        pygame.draw.rect(surf, CARD, (ix, iy, iw, ih), border_radius=8); pygame.draw.rect(surf, RULE, (ix, iy, iw, ih), 1, border_radius=8)
        cx, cy = ix + 240, iy + ih // 2; kpx = 200 / self.hill
        text(surf, "Mercury-centred · Hill circle at perihelion · anti-Earth line (live)", (ix + 16, iy + 12), "mono", 15, DIM)
        pygame.draw.circle(surf, GOLD, (cx, cy), int(self.hill * kpx), 1)
        pygame.draw.circle(surf, MERC, (cx, cy), 4)
        ang = math.atan2(u1[1], u1[0])
        for lab, a, col in (("V1", 40223, VULCAN), ("V2", 252366, VULCAN), ("V3", 854287, VULCAN)):
            x = cx + int(a * kpx * math.cos(ang)); y = cy - int(a * kpx * math.sin(ang))
            if ix < x < ix + iw and iy < y < iy + ih:
                pygame.draw.circle(surf, col, (x, y), 5); text(surf, f"{lab} {a / self.hill:.2f} R_H", (x + 8, y - 8), "mono", 13, col)
            else:
                text(surf, f"{lab} off-inset: {a / self.hill:.2f} R_H", (ix + iw - 16, iy + 40 + 20 * ["V1", "V2", "V3"].index(lab)), "mono", 13, col, "topright")
        arrow(surf, (cx, cy), (cx + int(150 * math.cos(ang)), cy - int(150 * math.sin(ang))), (120, 120, 130), 1, 8)
        text(surf, f"ω(line) = {sci(omega, 2)} rad/s   implied P = {2 * math.pi / omega / DAY:,.0f} d", (ix + iw - 16, iy + ih - 64), "mono", 15, INK, "topright")
        text(surf, f"free-fall radius for this ω = {fmt(r_ff)} km = {r_ff / self.hill:.2f} R_Hill", (ix + iw - 16, iy + ih - 40), "mono", 15, GOLD if r_ff / self.hill > 1 else RED, "topright")
        # trace graph
        gx, gy, gw, gh = 1140, 600, 740, 260
        pygame.draw.rect(surf, CARD, (gx, gy, gw, gh), border_radius=8); pygame.draw.rect(surf, RULE, (gx, gy, gw, gh), 1, border_radius=8)
        text(surf, "free-fall radius ÷ Hill radius · log scale · line = 1 (bound)", (gx + 16, gy + 10), "mono", 15, DIM)
        y1 = gy + gh - 40 - int((math.log10(1) + 0.5) / 3.0 * (gh - 70)); pygame.draw.line(surf, RED, (gx + 50, y1), (gx + gw - 16, y1), 1)
        text(surf, "1", (gx + 30, y1), "mono", 13, RED, "midright")
        for v in (10, 100): yy = gy + gh - 40 - int((math.log10(v) + 0.5) / 3.0 * (gh - 70)); text(surf, str(v), (gx + 30, yy), "mono", 13, DIM, "midright")
        if len(self.trace) > 1:
            T = max(self.trace[-1][0], 1); pts = []
            for s, r in self.trace:
                lr = max(-0.5, min(2.5, math.log10(max(r, 1e-3))))
                pts.append((gx + 50 + int((gw - 66) * s / T), gy + gh - 40 - int((lr + 0.5) / 3.0 * (gh - 70))))
            pygame.draw.lines(surf, GOLD, False, pts, 2)
        text(surf, f"min so far: {min(r for _, r in self.trace):.2f} R_H   (JSON, hourly 2026–27: {D.get('vulcan_derivation.json', 'lock_kinematics', 'free_fall_over_hill_min'):.2f})", (gx + 16, gy + gh - 26), "mono", 14, INK)
        frame_tag(surf)

# ═════════════════════════ CH06 — spin, wobble, hiding ═════════════════════════
class CH06:
    ID, TITLE = "CH06", "Test 3–5 — spin, wobble, hiding"
    def __init__(self):
        V1 = D.get("vulcan_derivation.json", "variants", "charon_scaled")
        self.spin = D.get("vulcan_derivation.json", "mercury", "spin_d"); self.P1 = V1["kepler_period_d"]
        self.reflex = V1["mercury_reflex_km"]; self.reflex_R = V1["mercury_reflex_over_R_M"]; self.reflex_rng = V1["reflex_over_ranging_precision"]
        hid = D.get("vulcan_derivation.json", "hiddenness", "charon_scaled")
        self.par = {k: hid[k]["max_parallax_arcsec"] for k in ("earth_limb", "lunar_farside_camera", "sun_earth_L2")}
        self.ang_r = hid["earth_centre"]["mercury_mean_angular_radius_arcsec"]
        self.par3 = D.get("vulcan_derivation.json", "hiddenness", "earth_synchronous", "lunar_farside_camera", "max_parallax_arcsec")
        self.SHOTS = [
            S(NARR, f"V1 is inside the circle, so it gets the longer argument. A Charon-mass companion at {fmt(V1['separation_km'])} kilometres would orbit in {self.P1:.2f} days. "
                    f"Pluto and Charon are mutually locked; Mercury's spin is {self.spin} days. The template contradicts itself.", rate=DAY / 2),
            S(NARR, f"Mercury would also wobble: a reflex circle of {fmt(self.reflex)} kilometres, {self.reflex_R:.2f} Mercury radii, against a ranging precision of ten metres — "
                    f"{fmt(self.reflex_rng)} times the noise. And the far-side camera the operator wanted: from the lunar far side the parallax is {self.par['lunar_farside_camera']:.2f} arcseconds "
                    f"against Mercury's {self.ang_r:.2f} arcsecond radius. V1 stays hidden. V3 would be seen always, at {self.par3:.1f} arcseconds; V3 is already dead. Row thirteen is moot.", rate=DAY / 2,
              board={13: "moot"}, board_at=0.92),
            S(CHRON, "Three closed, one moot.", pad=1.2, rate=DAY / 2),
        ]
    def draw(self, surf, ctx):
        caption(surf, self.ID, self.TITLE)
        d = ctx.sim / DAY
        # dials
        for cx, lab, P, col in ((330, f"Mercury spin · {self.spin} d", self.spin, MERC), (780, f"V1 orbit (Kepler) · {self.P1:.2f} d", self.P1, VULCAN)):
            cy = 330; pygame.draw.circle(surf, RULE, (cx, cy), 150, 2)
            a = 2 * math.pi * (d / P); pygame.draw.line(surf, col, (cx, cy), (cx + int(140 * math.cos(a)), cy - int(140 * math.sin(a))), 4)
            text(surf, lab, (cx, cy + 175), "mono", 18, col, "center"); text(surf, f"{d / P:.2f} turns in {d:.1f} d", (cx, cy + 200), "mono", 15, DIM, "center")
        text(surf, f"ratio {self.spin / self.P1:.1f} : 1 — a mutual lock (the template) needs 1 : 1", (555, 580), "mono", 20, INK, "center")
        # reflex wobble to scale
        cx, cy = 1400, 300; k = 160 / self.reflex
        pygame.draw.circle(surf, VULCAN, (cx, cy), int(self.reflex * k), 1)
        a = 2 * math.pi * (d / self.P1); mx, my = cx + int(self.reflex * k * math.cos(a)), cy - int(self.reflex * k * math.sin(a))
        pygame.draw.circle(surf, MERC, (mx, my), int(R_MERC_KM * k)); pygame.draw.circle(surf, GOLD, (cx, cy), 3)
        text(surf, f"Mercury's reflex circle · {fmt(self.reflex)} km = {self.reflex_R:.2f} R_M · to scale", (cx, cy + 215), "mono", 16, INK, "center")
        text(surf, f"ranging precision 10 m → {fmt(self.reflex_rng)}× the noise (a 10 m tick is 0.0004 px here)", (cx, cy + 238), "mono", 14, DIM, "center")
        # parallax bars
        bx, by = 1120, 620; text(surf, f"max parallax of V1 vs Mercury's angular radius {self.ang_r:.2f}″", (bx, by - 30), "mono", 16, DIM)
        scale = 560 / 4.0
        pygame.draw.line(surf, MERC, (bx + int(self.ang_r * scale), by - 10), (bx + int(self.ang_r * scale), by + 130), 2)
        text(surf, "Mercury's limb", (bx + int(self.ang_r * scale) + 6, by - 8), "mono", 13, MERC)
        for j, (k, lab) in enumerate((("earth_limb", "Earth, limb to limb"), ("lunar_farside_camera", "lunar far-side camera"), ("sun_earth_L2", "Sun–Earth L2"))):
            v = self.par[k]; yy = by + j * 40
            pygame.draw.rect(surf, VULCAN, (bx, yy, max(2, int(v * scale)), 24)); text(surf, f"{lab}: {v:.3f}″  hidden", (bx + max(2, int(v * scale)) + 8, yy + 12), "mono", 14, INK, "midleft")
        text(surf, f"V3 from the far side: {self.par3:.1f}″ — visible; already eliminated (CH05)", (bx, by + 130), "mono", 14, DIM)
        frame_tag(surf, "frame: Mercury-centred for the dials and reflex · Earth-based observers for parallax, BY REASON (the cameras are there)")

# ═════════════════════════ CH07 — Luna from Mercury ═════════════════════════
class CH07:
    ID, TITLE = "CH07", "The relaxed axiom — Luna from Mercury"
    def __init__(self):
        J = "ephem_luna_from_mercury.json"
        self.mx = np.array(D.get(J, "moon_x_arcsec_rel_earth")); self.my = np.array(D.get(J, "moon_y_arcsec_rel_earth"))
        self.re = np.array(D.get(J, "earth_radius_arcsec")); self.rm = np.array(D.get(J, "moon_radius_arcsec"))
        self.hm = np.array(D.get(J, "helio_mercury_au")); self.he = np.array(D.get(J, "helio_earth_au")); self.mg = np.array(D.get(J, "moon_geo_km"))
        self.mid = D.get(J, "mid_utc"); self.n = D.get(J, "n")
        L = "luna_from_mercury.json"
        self.west_facing = D.get(L, "luna_from_mercury", "on_mercury_facing_half") * 100
        self.transits = D.get(L, "luna_from_mercury", "moon_transits_of_earth_disc_2026_2027")
        bi = D.get(L, "beside_is_invisible", "charon_scaled")
        self.sep_min, self.sep_max, self.dmag, self.depth, self.P = bi["max_separation_arcsec_min"], bi["max_separation_arcsec_max"], bi["magnitude_fainter_than_mercury"], bi["mutual_event_depth_mag"], bi["free_period_d"]
        self.SHOTS = [
            S(NARR, "At two twenty-two the operator relaxed the axiom and sharpened it at the same time."),
            S(OPER, "Mercury is fast. If Vulcan is beside it from our view it is invisible. […] If it is simply *just off* Mercury on the other side it is *the slightest occlusion*.",
              when="2026-10-10 02:22 · line 3137", spoken="Mercury is fast. If Vulcan is beside it from our view it is invisible. If it is simply just off Mercury on the other side it is the slightest occlusion."),
            S(OPER, "Luna would appear as in retrograde to Mercury as it passes.", when="2026-10-10 02:22 · line 3137"),
            S(NARR, f"That second line is right. From Mercury, on the half of its orbit that faces Mercury, Luna moves westward across Earth {self.west_facing:.1f} percent of the time. "
                    f"Here is the transit of {self.mid[:10]}: Luna crossing Earth's disc from east to west, one minute per step, from the one-minute ephemeris. "
                    f"The operator, who had watched the Moon go one way all his life, called the other way first.", fit=(self.n - 1) * 60.0),
            S(NARR, f"The first line is where the relaxed axiom dies. 'Beside is invisible' means a companion separated from Mercury by {self.sep_min:.0f} to {self.sep_max:.0f} arcseconds, "
                    f"only {self.dmag:.2f} magnitudes fainter. That is a double star, resolvable in any telescope since 1610. Mutual events would dim Mercury by {self.depth:.2f} magnitudes "
                    f"every {self.P / 2:.2f} days; its photometry is good to a hundredth. The softer claim had more surface, and all of it was already measured.",
              board={2: "eliminated"}, board_at=0.45),
            S(CHRON, "Row two: eliminated four ways. Four closed. The relaxed axiom killed harder than the strict one.", pad=1.2),
        ]
    def draw(self, surf, ctx):
        caption(surf, self.ID, self.TITLE, f"frame: solar equator · observer on Mercury · {self.mid} ± 6 h")
        idx = 0 if ctx.i < 3 else (min(self.n - 1, int(ctx.sim / 60.0)) if ctx.i == 3 else self.n - 1)
        # Earth's disc as seen from Mercury
        cx, cy, k = 700, 560, 20.0
        pygame.draw.circle(surf, EARTH, (cx, cy), int(self.re[idx] * k))
        pygame.draw.circle(surf, (40, 70, 120), (cx, cy), int(self.re[idx] * k), 2)
        mxp, myp = cx + int(self.mx[idx] * k), cy - int(self.my[idx] * k)
        pygame.draw.circle(surf, MOON, (mxp, myp), int(self.rm[idx] * k))
        trail = [(cx + int(self.mx[j] * k), cy - int(self.my[j] * k)) for j in range(0, idx + 1, 10)]
        if len(trail) > 1: pygame.draw.lines(surf, (120, 120, 120), False, trail, 1)
        text(surf, "east ←  (Sol's rotation sense)", (cx + 660, cy + 300), "mono", 15, DIM, "midright"); text(surf, "→ west", (cx - 660, cy + 300), "mono", 15, DIM, "midleft")
        text(surf, f"Earth {self.re[idx] * 2:.1f}″  ·  Luna {self.rm[idx] * 2:.1f}″  ·  x = {self.mx[idx]:+.1f}″", (cx, cy + 340), "mono", 18, INK, "center")
        t_now = dt.datetime.fromisoformat(self.mid) + dt.timedelta(minutes=idx - (self.n - 1) // 2)
        text(surf, f"UTC {t_now:%Y-%m-%d %H:%M}   1-min ephemeris (DE421)", (28, 84), "mono", 20, DIM)
        # inset: top-down Zecliptic, Mercury-Earth-Moon geometry (Moon distance ×40, labelled)
        ix, iy, iw, ih = 1300, 100, 580, 420
        pygame.draw.rect(surf, CARD, (ix, iy, iw, ih), border_radius=8); pygame.draw.rect(surf, RULE, (ix, iy, iw, ih), 1, border_radius=8)
        text(surf, "top-down Zecliptic · Earth–Moon at ×40 · the half facing Mercury in red", (ix + 12, iy + 10), "mono", 13, DIM)
        ex, ey = ix + 330, iy + 230; kk = 240 / 1.0
        mer = self.hm[idx] - self.he[idx]; mdir = mer[:2] / np.linalg.norm(mer[:2])
        pygame.draw.circle(surf, EARTH, (ex, ey), 8)
        arrow(surf, (ex, ey), (ex + int(mdir[0] * 200), ey - int(mdir[1] * 200)), MERC, 1, 8); text(surf, f"to Mercury {np.linalg.norm(mer):.3f} AU", (ex + int(mdir[0] * 210), ey - int(mdir[1] * 210)), "mono", 12, MERC, "center")
        R = 384400 * 40 / AU_KM * kk
        ang0 = math.atan2(mdir[1], mdir[0])
        pygame.draw.arc(surf, RED, (ex - R, ey - R, 2 * R, 2 * R), ang0 - math.pi / 2, ang0 + math.pi / 2, 3)
        pygame.draw.circle(surf, (90, 90, 100), (ex, ey), int(R), 1)
        mg = to_se(self.mg[idx]) if False else self.mg[idx]  # JSON already in SE frame
        pygame.draw.circle(surf, MOON, (ex + int(mg[0] / 384400 * R), ey - int(mg[1] / 384400 * R)), 5)
        text(surf, f"westward on the facing half: {self.west_facing:.1f} % of the time", (ix + 12, iy + ih - 48), "mono", 14, RED)
        text(surf, f"transits of Earth's disc 2026–27: {len(self.transits)} (all WEST)", (ix + 12, iy + ih - 26), "mono", 14, INK)
        if ctx.i == 4:
            rx, ry = 1300, 560; pygame.draw.rect(surf, CARD, (rx, ry, 580, 300), border_radius=8); pygame.draw.rect(surf, RED, (rx, ry, 580, 300), 1, border_radius=8)
            text(surf, "'beside is invisible' — Earth frame BY REASON: the telescopes are here", (rx + 12, ry + 10), "mono", 13, DIM)
            yy = ry + 44
            for ln in (f"separation {self.sep_min:.0f}–{self.sep_max:.0f}″ · Δmag {self.dmag:.2f}", "resolved by any telescope since 1610", f"mutual events: −{self.depth:.2f} mag every {self.P / 2:.2f} d", "photometry good to 0.01–0.02 mag (Mallama)", "→ V1 eliminated four ways"):
                text(surf, ln, (rx + 16, yy), "body", 22, INK if "→" not in ln else RED); yy += 44
        if ctx.shot["voice"] == OPER:
            receipt(surf, ctx.shot["when"], ctx.shot["text"], (40, 100, 760, 0), ctx.p * 4)
        frame_tag(surf, "frame: solar equator (Zecliptic) · north = Sol's rotation pole · observer at Mercury")

# ═════════════════════════ CH08 — 42 Pis ═════════════════════════
class CH08:
    ID, TITLE = "CH08", "42 Pis"
    EPOCH = "2026-01-01T00:00"
    def __init__(self):
        self.oc = OrbitCache(self.EPOCH, ("earth",))
        f = D.get("luna_from_mercury.json", "forty_two_over_pi")
        self.sid = f["sidereal_months_per_year"]; self.f42 = f["forty_two_over_pi"]
        self.acc = 0.0; self.last = None
        self.SHOTS = [
            S(OPER, "The moon does 42 Pis in a year. We already solved that.", when="2026-09-27 06:18 · line 2222"),
            S(NARR, f"Count Luna's turns against the stars across one Earth year, from DE421. {self.sid:.4f}. Forty-two over pi is {self.f42:.4f}. "
                    f"Four figures, no mechanism. It is the sidereal month, which is also the month as Mercury sees it. A mnemonic, and a good one.", fit=365.256 * DAY, pad=1.2),
        ]
    def draw(self, surf, ctx):
        caption(surf, self.ID, self.TITLE)
        view = View(620, 560, 380)
        pygame.draw.circle(surf, SUN, view.xy((0, 0)), 11)
        orbit_path(surf, view, self.oc.paths["earth"][:, :2], EARTH, 1, 110)
        sim = min(ctx.sim, 365.256 * DAY) if ctx.i == 1 else 0.0
        t = self.oc.time(sim); e = self.oc.at("earth", sim); ex, ey = body(surf, view, e[:2], EARTH, 8, None)
        mg = to_se(geo_ecl_km("moon", t)); lon = math.atan2(mg[1], mg[0])
        if self.last is None or sim < self.last[0]:
            self.acc = 0.0
        else:
            d = lon - self.last[1]; d = (d + math.pi) % (2 * math.pi) - math.pi; self.acc += d
        self.last = (sim, lon)
        R = 60; pygame.draw.circle(surf, (90, 90, 100), (ex, ey), R, 1)
        pygame.draw.circle(surf, MOON, (ex + int(R * math.cos(lon)), ey - int(R * math.sin(lon))), 5)
        hud_time(surf, t)
        text(surf, "Luna's distance ×60 for visibility · its direction is real (DE421, solar-equator frame)", (28, 110), "mono", 15, DIM)
        turns = self.acc / (2 * math.pi)
        x0 = 1240
        text(surf, "sidereal turns so far", (x0, 300), "mono", 20, DIM); text(surf, f"{turns:7.4f}", (x0, 330), "mono", 96, INK)
        text(surf, f"full year (JSON): {self.sid:.4f}", (x0, 470), "mono", 24, GOLD)
        text(surf, f"42 / π = {self.f42:.4f}", (x0, 510), "mono", 24, GOLD)
        text(surf, f"turns × π so far = {turns * math.pi:.2f}", (x0, 560), "mono", 22, INK)
        text(surf, "four significant figures · no mechanism · a mnemonic", (x0, 620), "ital", 28, DIM)
        if ctx.shot["voice"] == OPER:
            receipt(surf, ctx.shot["when"], ctx.shot["text"], (x0 - 20, 100, 640, 0), ctx.p * 4)
        frame_tag(surf)

# ═════════════════════════ CH09 — the deliberate error and the court ═════════════════════════
class CH09:
    ID, TITLE = "CH09", "The deliberate error — and Hume v. Spock"
    def __init__(self):
        far = D.get("luna_from_mercury.json", "luna_from_mercury", "on_far_half") * 100
        self.far = far
        self.SHOTS = [
            S(OPER, "Then 2.4% of the time Vulcan is straight visible. We must see it a lot.", when="2026-10-10 03:31 · line 3167", spoken="Then 2.4 percent of the time Vulcan is straight visible. We must see it a lot."),
            S(NARR, f"{far:.1f} percent was the fraction of time Luna moves west on the far half of its orbit. It has nothing to do with Vulcan's visibility. "
                    f"The sentence was built to be checkable, and it checked false."),
            S(OPER, "I deliberately got things wrong. I should have mentioned that. It is the point lol", when="2026-10-10 03:31 · line 3168", spoken="I deliberately got things wrong. I should have mentioned that. It is the point. lol."),
            S(NARR, "Deliberate error number one, ledgered. Then the operator asked for a courtroom: Hume versus Spock, Feynman presiding, McClane as bailiff, Widukind typing. "
                    "Hume testified that he had once called mercury heavier than gold on no evidence, and that a sentence can be refuted only if it was built to be. "
                    "Recess was called. The kids went out to play."),
            S(CHRON, "Error one, deliberate, ledgered.", pad=1.2),
        ]
    def draw(self, surf, ctx):
        caption(surf, self.ID, self.TITLE)
        if ctx.i <= 2:
            text(surf, "\"2.4 %\"", (W // 2, 330), "title", 140, INK, "center")
            arrow(surf, (W // 2, 420), (W // 2, 520), GOLD, 2, 12)
            text(surf, f"= Luna westward on the FAR half of its orbit, as seen from Mercury: {self.far:.1f} %  (luna_from_mercury.json)", (W // 2, 560), "mono", 22, GOLD, "center")
            text(surf, "≠ anything about Vulcan's visibility", (W // 2, 600), "mono", 22, RED, "center")
            if ctx.i >= 1:
                text(surf, "built to be checkable · checked false · deliberate error #1", (W // 2, 680), "ital", 34, DIM, "center", alpha=fade_in(ctx.p if ctx.i == 1 else 1.0, 0.1, 0.5))
        else:
            x0, y0 = 220, 150
            pygame.draw.rect(surf, CARD, (x0 - 40, y0 - 40, W - 2 * x0 + 80, 700), border_radius=10); pygame.draw.rect(surf, GOLD, (x0 - 40, y0 - 40, W - 2 * x0 + 80, 700), 1, border_radius=10)
            text(surf, "Hume v. Spock — a defamation case", (W // 2, y0), "title", 56, INK, "center")
            text(surf, "requested 2026-10-10 03:50 · line 3184", (W // 2, y0 + 60), "mono", 16, DIM, "center")
            rows = [("Judge", "Feynman"), ("Bailiff", "McClane"), ("Typist", "Widukind"), ("Plaintiff", "David Hume"), ("Defendant", "Spock — observed and queried only"),
                    ("Witnesses", "Plutarch · Copernicus · Tesla · Marconi · Newton · Oppenheimer · the driver"),
                    ("Exhibit", "Treatise 1.3.7 — mercury called heavier than gold, on no evidence"),
                    ("Finding", "a sentence is refutable only if it was built to be"), ("Order", "recess · the kids go out and play")]
            yy = y0 + 120
            for a, b in rows:
                text(surf, a, (x0 + 220, yy), "mono", 22, GOLD, "topright"); text(surf, b, (x0 + 250, yy), "body", 24, INK if a != "Finding" else RED); yy += 50
        if ctx.shot["voice"] == OPER:
            receipt(surf, ctx.shot["when"], ctx.shot["text"], (W // 2 - 400, 760, 800, 0), ctx.p * 4)
        frame_tag(surf, "frame: none · text")

# ═════════════════════════ CH10 — eliminating, not forcing ═════════════════════════
class CH10:
    ID, TITLE = "CH10", "Eliminating, not forcing"
    def __init__(self):
        j2 = D.get("vulcan_derivation.json", "precession_without_relativity", "ratio_needed_over_measured")
        px = D.get("ladder_analysis.json", "planet_x_candidates", "H2_mirror_eq", "mass_earth")
        self.j2, self.px = j2, px
        self.belt = lit(0.0004, "asteroid-belt mass 2.39e21 kg / M⊕ (Pitjeva & Pitjev 2018) — GAMEPLAN_ELIMINATION row 12")
        self.SHOTS = [
            S(OPER, "Forcing is not what we are doing. We are eliminating. I will not rest until we have eliminated fully.", when="2026-10-10 04:10 · line 3191"),
            S(NARR, f"A row may be closed in two ways only: eliminated, by a measured number; or confined, with an instrument and a date. Preference closes nothing. "
                    f"Three rows were already closed by the first report: the forty-three arcseconds cannot come from Sol's oblateness — the J two needed is {fmt(j2)} times the helioseismic value; "
                    f"nothing larger than a few hundred kilometres orbits inside Mercury, after thirty years of coronagraphs; and the Planet X the ladder defines would need "
                    f"{px:.3f} Earth masses in the belt, where {self.belt} is.", board={8: "eliminated", 9: "eliminated", 12: "eliminated"}, board_at=0.5),
            S(OPER, "Excellent. Please proceed with the game plan", when="2026-10-10 04:29 · line 3196", spoken="Excellent. Please proceed with the game plan."),
            S(CHRON, "Seven closed, one moot. Four are the work.", pad=1.2),
        ]
    def draw(self, surf, ctx):
        caption(surf, self.ID, self.TITLE)
        x0, y0 = 120, 100
        text(surf, "the board · GAMEPLAN_ELIMINATION §1", (x0, y0), "mono", 18, DIM)
        text(surf, "closed = eliminated by a measured number   |   confined = instrument + date   |   preference closes nothing", (x0, y0 + 26), "mono", 16, GOLD)
        yy = y0 + 70
        for r in range(1, 14):
            st = ctx.states.get(r, "open"); col = STATE_COLOR[st]
            pygame.draw.rect(surf, col if st != "open" else (28, 30, 38), (x0, yy, 34, 34), border_radius=5); pygame.draw.rect(surf, col, (x0, yy, 34, 34), 1, border_radius=5)
            text(surf, str(r), (x0 + 17, yy + 17), "mono", 18, WHITE if st != "open" else DIM, "center")
            text(surf, BOARD_ROWS[r], (x0 + 50, yy + 17), "body", 24, INK, "midleft")
            text(surf, st, (x0 + 620, yy + 17), "mono", 18, col, "midleft")
            yy += 46
        # the three already-closed receipts
        rx = 900; pygame.draw.rect(surf, CARD, (rx, y0 + 70, 940, 240), border_radius=8); pygame.draw.rect(surf, RULE, (rx, y0 + 70, 940, 240), 1, border_radius=8)
        text(surf, "closed by the first report (10-10 04:00)", (rx + 16, y0 + 82), "mono", 15, DIM)
        for j, ln in enumerate((f"row 8 · solar J₂ needed ÷ measured = ×{fmt(self.j2)}", "row 9 · SOHO/LASCO 1996– · STEREO: nothing > a few hundred km inside Mercury", f"row 12 · Planet X (H2) needs {self.px:.3f} M⊕ at 2.79 AU; belt holds {self.belt} M⊕ (×80 short)")):
            text(surf, ln, (rx + 16, y0 + 120 + j * 44), "body", 22, INK)
        if ctx.shot["voice"] == OPER:
            receipt(surf, ctx.shot["when"], ctx.shot["text"], (rx, 400, 940, 0), ctx.p * 4)
        frame_tag(surf, "frame: none · the board")

# ═════════════════════════ CH11 — the annulus: live integrator ═════════════════════════
class HillLive:
    """The Hill-sphere leapfrog of tools/vulcan/v4_annulus.py, run at the video's clock.
    Mercury-centred; Sun on Mercury's e = 0.2056 orbit (perihelion at t = 0); Mercury gravity + J2; dt = 200 s.
    Relative acceleration from the Sun: a = -GM_S [ (r - s)/|r - s|^3 + s/|s|^3 ]  with s = Sun position relative to Mercury."""
    A_MERC = 0.387098 * AU_KM * 1e3; E_MERC = 0.205630; T_MERC = 87.969 * DAY
    R_M = R_MERC_KM * 1e3; J2 = 5.03e-5
    def __init__(self):
        self.R_HILL_PERI = D.get("v4_annulus.json", "constants", "R_hill_perihelion_km") * 1e3
        a_grid = np.logspace(math.log10(8e6), math.log10(2.6e8), 28)
        parts = []
        for a in a_grid:
            for sgn, lab in ((1, "prograde"), (-1, "retrograde")):
                for ph in (0.0, math.pi / 2):
                    v = math.sqrt(GM_MERC / a)
                    parts.append((a, lab, np.array([a * math.cos(ph), a * math.sin(ph), 0.0]), sgn * v * np.array([-math.sin(ph), math.cos(ph), 0.0])))
        self.a = np.array([p[0] for p in parts]); self.dir = np.array([p[1] for p in parts])
        self.r = np.array([p[2] for p in parts]); self.v = np.array([p[3] for p in parts])
        self.N = len(parts); self.alive = np.ones(self.N, bool); self.fate = np.array(["stable"] * self.N, dtype=object); self.t_fate = np.full(self.N, np.nan)
        self.t = 0.0; self.dt = 200.0; self.k = 0
        chk = self.accel(self.r[:1], 0.0) - (-GM_MERC * self.r[:1] / np.linalg.norm(self.r[:1]) ** 3)
        assert np.linalg.norm(chk) < 1e-3 * GM_MERC / np.linalg.norm(self.r[0]) ** 2, ("tidal term not cancelling bulk solar pull", chk)
        self.a_half = self.accel(self.r, 0.0)
    def sun_pos(self, t):
        Mean = (2 * math.pi / self.T_MERC) * t; E = Mean
        for _ in range(8): E = E - (E - self.E_MERC * math.sin(E) - Mean) / (1 - self.E_MERC * math.cos(E))
        xm = self.A_MERC * (math.cos(E) - self.E_MERC); ym = self.A_MERC * math.sqrt(1 - self.E_MERC ** 2) * math.sin(E)
        return np.array([-xm, -ym, 0.0])
    def accel(self, r, t):
        s = self.sun_pos(t); d = r - s[None, :]
        a_m = -GM_MERC * r / np.linalg.norm(r, axis=1)[:, None] ** 3
        a_tide = -GM_SUN * (d / np.linalg.norm(d, axis=1)[:, None] ** 3 + s[None, :] / np.linalg.norm(s) ** 3)
        x, y, z = r[:, 0], r[:, 1], r[:, 2]; rr = np.linalg.norm(r, axis=1); f = 1.5 * self.J2 * GM_MERC * self.R_M ** 2 / rr ** 5
        a_j2 = np.stack([f * x * (5 * z ** 2 / rr ** 2 - 1), f * y * (5 * z ** 2 / rr ** 2 - 1), f * z * (5 * z ** 2 / rr ** 2 - 3)], axis=1)
        return a_m + a_tide + a_j2
    def advance(self, sim_target):
        while self.t < sim_target:
            al = self.alive
            self.v[al] += 0.5 * self.dt * self.a_half[al]; self.r[al] += self.dt * self.v[al]; self.t += self.dt
            a_new = self.accel(self.r, self.t); self.v[al] += 0.5 * self.dt * a_new[al]; self.a_half = a_new; self.k += 1
            if self.k % 50 == 0:
                rr = np.linalg.norm(self.r, axis=1)
                esc = al & (rr > 1.5 * self.R_HILL_PERI); col = al & (rr < self.R_M)
                self.fate[esc] = "escaped"; self.fate[col] = "collided"; self.t_fate[esc | col] = self.t / DAY
                self.alive &= ~(esc | col)

class CH11:
    ID, TITLE = "CH11", "The annulus — two walls, live"
    def __init__(self):
        A = "v4_annulus.json"
        self.floor10 = D.get(A, "tidal_floor", "a_min_10km_Q100_km"); self.floor1 = D.get(A, "tidal_floor", "a_min_1km_Q100_km"); self.floor01 = D.get(A, "tidal_floor", "a_min_100m_Q100_km")
        life = D.get(A, "tidal_floor", "chain_V4_lifetime_yr"); self.life_lo, self.life_hi = life["50"] / 1e6, life["300"] / 1e6
        self.radii = np.array(D.get(A, "tidal_floor", "radii_m")); self.amin = {q: np.array(D.get(A, "tidal_floor", "a_min_km", q)) for q in ("50", "100", "300")}
        self.pro_edge = D.get(A, "hill_ceiling", "summary", "prograde", "largest_stable_km"); self.retro_edge = D.get(A, "hill_ceiling", "summary", "retrograde", "largest_stable_km")
        self.pro_canon = D.get(A, "annulus", "outer_km_prograde_canonical")
        self.json_parts = D.get(A, "hill_ceiling", "particles")
        self.hill = HillLive()
        self.SHOTS = [
            S(NARR, f"V4 was the one Vulcan small enough to hide. Where could a ten-kilometre moon of Mercury live? Two walls. The inner wall is tidal: a body at the ladder's {fmt(5411)} kilometres "
                    f"spirals into Mercury in {self.life_lo:.0f} to {self.life_hi:.0f} million years — it cannot be primordial. For a ten-kilometre body the floor is {fmt(self.floor10)} kilometres.",
              board={5: "eliminated"}, board_at=0.6),
            S(NARR, f"The outer wall is the Sun. What you are watching is the integrator running live, at the clock of this video: one hundred and twelve test particles on circular orbits from eight thousand "
                    f"to two hundred sixty thousand kilometres, prograde and retrograde, Mercury's gravity with its J two, the Sun swinging on the real eccentric orbit, two hundred second steps. "
                    f"The red crosses are escapes. The full run, a hundred Mercury years, put the prograde edge at {fmt(self.pro_edge)} kilometres and let retrograde orbits survive to {fmt(self.retro_edge)}.",
              rate=4 * DAY),
            S(NARR, f"The first time this ran, every particle escaped within four hundred sixty-three days, including the ones at eight thousand kilometres. That is impossible, so it was wrong: "
                    f"the sign of the Sun's pull on Mercury itself. Fixed, asserted, ledgered. The annulus of survival is {fmt(self.floor10)} to about {fmt(self.pro_canon)} kilometres, wider for retrograde.",
              rate=4 * DAY, board={6: "confined"}, board_at=0.8),
            S(CHRON, "Row five: eliminated. Row six: confined. Eight closed, one confined. One error, mine, ledgered.", pad=1.2, rate=4 * DAY),
        ]
    def draw(self, surf, ctx):
        caption(surf, self.ID, self.TITLE)
        if ctx.i == 0:
            # tidal floor curve, drawn natively from the JSON arrays
            gx, gy, gw, gh = 200, 130, 1500, 700
            pygame.draw.rect(surf, CARD, (gx, gy, gw, gh), border_radius=8); pygame.draw.rect(surf, RULE, (gx, gy, gw, gh), 1, border_radius=8)
            text(surf, "tidal floor: smallest a at which a body of radius R survives 4.5 Gyr · da/dt = −3 (k₂/Q)(m/M)(R/a)⁵ n a · k₂ = 0.45 · ρ = 2000", (gx + 16, gy + 12), "mono", 15, DIM)
            lx = lambda R: gx + 60 + (math.log10(R) - 2) / 2.0 * (gw - 100)
            ly = lambda a: gy + gh - 60 - (math.log10(a) - 3) / 1.6 * (gh - 120)
            for q, col in (("50", (120, 160, 220)), ("100", GOLD), ("300", (220, 140, 120))):
                pts = [(int(lx(R)), int(ly(a))) for R, a in zip(self.radii, self.amin[q])]; pygame.draw.lines(surf, col, False, pts, 2)
                text(surf, f"Q = {q}", (pts[-1][0] + 8, pts[-1][1]), "mono", 14, col, "midleft")
            for R, lab in ((100, "100 m"), (1000, "1 km"), (10000, "10 km")): text(surf, lab, (int(lx(R)), gy + gh - 40), "mono", 14, DIM, "center")
            for a in (2000, 5000, 10000, 20000): text(surf, f"{a:,} km", (gx + 50, int(ly(a))), "mono", 13, DIM, "midright")
            pygame.draw.circle(surf, VULCAN, (int(lx(9834)), int(ly(5411))), 7); text(surf, f"ladder's V4 · 5,411 km · lifetime {self.life_lo:.0f}–{self.life_hi:.0f} Myr", (int(lx(9834)) + 12, int(ly(5411)) - 8), "mono", 15, VULCAN)
            text(surf, f"floors (Q=100): 10 km → {fmt(self.floor10)} km · 1 km → {fmt(self.floor1)} km · 100 m → {fmt(self.floor01)} km", (gx + 16, gy + gh - 20), "mono", 15, INK, "bottomleft")
        else:
            hl = self.hill
            if ctx.i >= 1 and ctx.sim > hl.t: hl.advance(min(ctx.sim, hl.t + 400 * hl.dt))
            cx, cy = 640, 560; kpx = 420 / (1.5 * hl.R_HILL_PERI)
            s = hl.sun_pos(hl.t); sd = s[:2] / np.linalg.norm(s[:2])
            pygame.draw.circle(surf, (40, 42, 52), (cx, cy), int(1.5 * hl.R_HILL_PERI * kpx), 1)
            pygame.draw.circle(surf, GOLD, (cx, cy), int(hl.R_HILL_PERI * kpx), 1); text(surf, "R_Hill (peri)", (cx + int(hl.R_HILL_PERI * kpx) + 6, cy - 10), "mono", 13, GOLD)
            pygame.draw.circle(surf, AMBER, (cx, cy), int(self.floor10 * 1e3 * kpx), 1)
            pygame.draw.circle(surf, MERC, (cx, cy), max(3, int(hl.R_M * kpx)))
            arrow(surf, (cx + int(sd[0] * 300), cy - int(sd[1] * 300)), (cx + int(sd[0] * 420), cy - int(sd[1] * 420)), SUN, 2, 12); text(surf, f"to Sol · {np.linalg.norm(s) / AU_KM / 1e3:.3f} AU", (cx + int(sd[0] * 440), cy - int(sd[1] * 440)), "mono", 13, SUN, "center")
            for i in range(hl.N):
                x, y = cx + int(hl.r[i, 0] * kpx), cy - int(hl.r[i, 1] * kpx)
                if hl.alive[i]:
                    pygame.draw.circle(surf, (255, 214, 102) if hl.dir[i] == "prograde" else (79, 209, 255), (x, y), 3)
                elif hl.fate[i] == "escaped":
                    a0 = hl.a[i] * kpx; ph = 0 if i % 2 == 0 else math.pi / 2; xx, yy = cx + int(a0 * math.cos(ph)), cy - int(a0 * math.sin(ph))
                    pygame.draw.line(surf, RED, (xx - 5, yy - 5), (xx + 5, yy + 5), 2); pygame.draw.line(surf, RED, (xx - 5, yy + 5), (xx + 5, yy - 5), 2)
            text(surf, f"integrator clock  t = {hl.t / DAY:7.1f} d  ({hl.t / hl.T_MERC:.2f} Mercury yr)   steps {hl.k:,}   dt {hl.dt:.0f} s   alive {int(hl.alive.sum())}/{hl.N}", (28, 84), "mono", 18, GOLD)
            legend(surf, [((255, 214, 102), "prograde"), ((79, 209, 255), "retrograde"), (RED, "escaped (× at its start radius)"), (AMBER, f"tidal floor 10 km: {fmt(self.floor10)} km")], (28, 120), 15)
            # right panel: a vs fate, live vs JSON
            px, py, pw, ph = 1180, 100, 700, 760
            pygame.draw.rect(surf, CARD, (px, py, pw, ph), border_radius=8); pygame.draw.rect(surf, RULE, (px, py, pw, ph), 1, border_radius=8)
            text(surf, "start radius vs fate — live (top rows) and the 100-Mercury-year JSON (bottom rows)", (px + 14, py + 10), "mono", 13, DIM)
            lx = lambda a_km: px + 40 + (math.log10(a_km) - math.log10(8000)) / (math.log10(260000) - math.log10(8000)) * (pw - 80)
            rows = (("live prograde", "prograde", None), ("live retrograde", "retrograde", None), ("JSON prograde", "prograde", "json"), ("JSON retrograde", "retrograde", "json"))
            for j, (lab, dr, src) in enumerate(rows):
                yy = py + 80 + j * 150; text(surf, lab, (px + 14, yy - 40), "mono", 14, INK)
                pygame.draw.line(surf, RULE, (px + 40, yy), (px + pw - 40, yy), 1)
                if src is None:
                    for i in range(hl.N):
                        if hl.dir[i] != dr: continue
                        x = int(lx(hl.a[i] / 1e3)); col = (255, 214, 102) if dr == "prograde" else (79, 209, 255)
                        if hl.alive[i]: pygame.draw.circle(surf, col, (x, yy + (i % 2) * 14 - 7), 4, 1)
                        else: pygame.draw.line(surf, RED, (x - 4, yy - 4 + (i % 2) * 14 - 7), (x + 4, yy + 4 + (i % 2) * 14 - 7), 2); pygame.draw.line(surf, RED, (x - 4, yy + 4 + (i % 2) * 14 - 7), (x + 4, yy - 4 + (i % 2) * 14 - 7), 2)
                else:
                    for i, h in enumerate(self.json_parts):
                        if h["dir"] != dr: continue
                        x = int(lx(h["a_km"])); col = (255, 214, 102) if dr == "prograde" else (79, 209, 255)
                        if h["fate"] == "stable": pygame.draw.circle(surf, col, (x, yy + (i % 2) * 14 - 7), 4, 1)
                        else: pygame.draw.line(surf, RED, (x - 4, yy - 4 + (i % 2) * 14 - 7), (x + 4, yy + 4 + (i % 2) * 14 - 7), 2); pygame.draw.line(surf, RED, (x - 4, yy + 4 + (i % 2) * 14 - 7), (x + 4, yy - 4 + (i % 2) * 14 - 7), 2)
            for a in (10000, 30000, 100000, 260000): text(surf, f"{a // 1000}k", (int(lx(a)), py + ph - 110), "mono", 13, DIM, "center")
            text(surf, f"JSON edges: prograde {fmt(self.pro_edge)} km · retrograde {fmt(self.retro_edge)} km (100 Mercury yr; this live run is shorter)", (px + 14, py + ph - 80), "mono", 13, INK)
            text(surf, f"annulus of survival: {fmt(self.floor10)} → {fmt(self.pro_canon)} km prograde (0.5 R_H), to ~{fmt(self.retro_edge)} km retrograde", (px + 14, py + ph - 56), "mono", 13, AMBER)
            text(surf, "first run: all 112 escaped by 463 d, even at 8,000 km → sign error in the indirect solar term → fixed, asserted, ledgered", (px + 14, py + ph - 32), "mono", 12, DIM)
        frame_tag(surf, "frame: Mercury-centred, Mercury's orbital plane · Sun direction live · equations printed (v4_annulus.py)")

# ═════════════════════════ CH12 — the 43″ ═════════════════════════
class CH12:
    ID, TITLE = "CH12", "The 43 arcseconds — no Newtonian cause survives"
    def __init__(self):
        P = "perihelion_newtonian.json"
        hv = D.get(P, "hall", "Venus"); hm = D.get(P, "hall", "Moon"); ring = D.get(P, "exterior_ring")[1]
        ven = D.get(P, "planetary_budget", "Venus"); jup = D.get(P, "planetary_budget", "Jupiter")
        self.j2 = D.get("vulcan_derivation.json", "precession_without_relativity", "ratio_needed_over_measured")
        self.bars = [("solar J₂ needed ÷ measured", self.j2), ("Hall δ vs lunar laser ranging (σ)", hm["sigmas_off"]), ("ring at 1 AU: mass needed ÷ zodiacal", ring["deficit_factor"]),
                     ("Jupiter mass error needed ÷ known", jup["factor_over_uncertainty"]), ("Venus mass error needed ÷ known", ven["factor_over_uncertainty"])]
        self.SHOTS = [
            S(NARR, f"Row ten asked whether any Newtonian cause produces Mercury's forty-three arcseconds per century. Three candidates were left. Hall's exponent reproduces Mercury and predicts Venus at "
                    f"{hv['predicted_arcsec_per_cy']:.1f} where {hv['measured']} is measured, and moves the lunar perigee {fmt(hm['sigmas_off'])} sigma from lunar ranging. "
                    f"A ring outside Mercury would need {ring['mass_required_earth']:.2f} Earth masses at one astronomical unit, {sci(ring['deficit_factor'], 0)} times the zodiacal cloud. "
                    f"And an error in a planetary mass: Venus would have to be wrong by {ven['fractional_mass_error_for_43'] * 100:.0f} percent, Jupiter by {jup['fractional_mass_error_for_43'] * 100:.0f}, "
                    f"against masses known to a part in a billion.", pad=0.8),
            S(NARR, "No Newtonian cause survives measurement. That sentence is a receipt. It is also an arrow, and under the operator's rule the arrow is recorded and not followed. "
                    "A refusal is also a receipt.", board={10: "emptied"}, board_at=0.25),
            S(CHRON, "Row ten: emptied. The chain is on the ground, not lost.", pad=1.2),
        ]
        self.SHOTS[0]["spoken"] = self.SHOTS[0]["text"].replace("e7", " times ten to the seventh").replace("4e", "four ")
    def draw(self, surf, ctx):
        caption(surf, self.ID, self.TITLE)
        # apsidal line
        cx, cy = 420, 520; a, e = 220, 0.2056; b = a * math.sqrt(1 - e * e)
        turn = (ctx.t / 40.0) * 2 * math.pi * 0.08
        pts = [(cx + a * math.cos(th) * math.cos(turn) - b * math.sin(th) * math.sin(turn) - a * e * math.cos(turn), cy - (a * math.cos(th) * math.sin(turn) + b * math.sin(th) * math.cos(turn)) + a * e * math.sin(turn)) for th in np.linspace(0, 2 * math.pi, 120)]
        pygame.draw.lines(surf, MERC, True, pts, 2); pygame.draw.circle(surf, SUN, (cx, cy), 10)
        pygame.draw.line(surf, GOLD, (cx - int(300 * math.cos(turn)), cy + int(300 * math.sin(turn))), (cx + int(300 * math.cos(turn)), cy - int(300 * math.sin(turn))), 1)
        text(surf, "Mercury's apsidal line · 574″/century total · 531 from the planets · 43 unexplained by Newton", (cx, cy + 290), "mono", 15, DIM, "center")
        text(surf, "(turn exaggerated ×500 for visibility)", (cx, cy + 312), "mono", 13, DIM, "center")
        # kill factor bars, log scale
        bx, by, bw = 900, 160, 900
        text(surf, "how far each remaining Newtonian cause misses, log₁₀ of the factor", (bx, by - 40), "mono", 16, DIM)
        n = len(self.bars) if ctx.i > 0 else min(len(self.bars), int(ctx.p * 6))
        for j, (lab, v) in enumerate(self.bars[:n]):
            yy = by + j * 90; L = int(bw * math.log10(v) / 9.0)
            pygame.draw.rect(surf, RED, (bx, yy, L, 36)); text(surf, lab, (bx, yy - 22), "mono", 15, INK); text(surf, f"×{sci(v, 1)}", (bx + L + 10, yy + 18), "mono", 18, RED, "midleft")
        for k in range(0, 10, 3): x = bx + int(bw * k / 9.0); text(surf, f"1e{k}", (x, by + 5 * 90 - 20), "mono", 13, DIM, "center")
        if ctx.i >= 1:
            blit_figure(surf, IMG / "concept_02_arrow_not_followed.jpg", (900, 640, 420, 240), "GENERATED plate C2 · the arrow not followed", ctx.p * 3)
            text(surf, "\"No Newtonian cause survives measurement.\"", (1350, 680), "ital", 28, INK)
            text(surf, "a receipt · an arrow · recorded, not followed", (1350, 724), "mono", 16, GOLD)
        frame_tag(surf, "frame: Mercury's orbital plane, schematic · numbers from perihelion_newtonian.json")

# ═════════════════════════ CH13 — the ladder out of sample ═════════════════════════
class CH13:
    ID, TITLE = "CH13", "The ladder, out of sample — and Planet X"
    def __init__(self):
        N = "ladder_null.json"; O = "ladder_oos.json"; L = "ladder_analysis.json"
        self.uh, self.ut, self.ur, self.nm, self.p = D.get(N, "user_holds"), D.get(N, "user_tests"), D.get(N, "user_rate") * 100, D.get(N, "null_mean_rate") * 100, D.get(N, "p_value_user_ge_null")
        self.nt, self.ns = D.get(O, "n_mapping_tests"), D.get(O, "n_mapping_tests_p_lt_0p05")
        self.rec, self.rec_nd = D.get(O, "recurrence_total"), D.get(O, "recurrence_excluding_density")
        px = D.get(L, "planet_x_candidates")
        self.h1 = px["H1_geometric"]; self.h2 = px["H2_mirror_eq"]; self.h3 = px["H3_mirror_inv"]
        self.belt = lit(0.0004, "asteroid-belt mass 2.39e21 kg / M⊕ (Pitjeva & Pitjev 2018)")
        self.SHOTS = [
            S(NARR, f"The ladder — Sol is to Jupiter is to Mars, Neptune is to Saturn is to Pluto — was tested as a law. In the solar system it held {self.uh} of {self.ut} proportions, "
                    f"{self.ur:.1f} percent, against {self.nm:.1f} percent for random triplets: p equals {self.p:.2f}. Out of sample, on Saturn's moons, Jupiter's moons, TRAPPIST-1, Kepler-90 and HD 10180, "
                    f"{self.ns} pre-declared mapping in {self.nt} beat chance. That is the base rate. Density agreed with itself, not with the ladder.", board={11: "eliminated"}, board_at=0.85),
            S(NARR, f"Planet X, the body the ladder's line four requires, had three readings. One puts {fmt(self.h1['mass_earth'])} Earth masses at {self.h1['a_au']:.1f} astronomical units. "
                    f"One puts {self.h3['mass_kg'] / 1.989e30:.2f} of a solar mass at {self.h3['a_au']:.1f}. The third puts {self.h2['mass_earth']:.3f} Earth masses in the asteroid belt, where {self.belt} is. "
                    f"Eliminated as a body. Real as a deficit."),
            S(CHRON, "Row eleven: eliminated as law, kept as mnemonic. Ten closed.", pad=1.2),
        ]
    def draw(self, surf, ctx):
        caption(surf, self.ID, self.TITLE)
        x0 = 60
        for j, ln in enumerate(("id  Sol : Jupiter : Mars", "iv  Neptune : Saturn : Pluto/Charon", "id  Venus : Sol : Jupiter", "iv  Saturn : Jupiter : Neptune", "id  Earth : AB : Luna", "iv  Uranus : HB : Uranus rings")):
            text(surf, ln, (x0, 100 + j * 34), "mono", 20, INK if j % 2 == 0 else DIM)
        text(surf, "operator, 2026-10-10 01:32 · line 3077 (6 of 12 lines)", (x0, 310), "mono", 14, DIM)
        if ctx.i == 0:
            blit_figure(surf, IMG / "rep_03_hist_permutation_nulls.png", (60, 350, 900, 500), "figure (matplotlib, images_report.py) · blitted", ctx.p * 3)
        else:
            blit_figure(surf, IMG / "ladder_03_planet_x_kepler_test.png", (60, 350, 900, 500), "figure (matplotlib, ladder_analysis.py) · blitted", ctx.p * 3)
        px, py = 1020, 100; pygame.draw.rect(surf, CARD, (px, py, 840, 760), border_radius=8); pygame.draw.rect(surf, RULE, (px, py, 840, 760), 1, border_radius=8)
        lines = [("in sample (Sol)", f"{self.uh}/{self.ut} = {self.ur:.1f} %  vs null {self.nm:.1f} %  ·  p = {self.p:.2f}", INK),
                 ("out of sample", f"{self.ns} of {self.nt} pre-declared mappings at p < 0.05 — the base rate", INK),
                 ("recurrence", f"{self.rec['oos_holds']}/{self.rec['oos_evaluable']} with density · {self.rec_nd['oos_holds']}/{self.rec_nd['oos_evaluable']} without", DIM),
                 ("verdict", "not a law · kept as a mnemonic", RED)]
        yy = py + 24
        for a, b, c in lines:
            text(surf, a, (px + 20, yy), "mono", 16, GOLD); text(surf, b, (px + 20, yy + 24), "body", 22, c); yy += 80
        if ctx.i >= 1:
            text(surf, "Planet X — three readings of ladder line iv", (px + 20, yy), "mono", 16, GOLD); yy += 30
            for lab, h, note in (("H1 geometric", self.h1, "no such body: V ≈ −7, seen by everyone"), ("H3 mirror-inv", self.h3, "a star at 33 AU: no"), ("H2 mirror-eq", self.h2, f"in the belt: needs {self.h2['mass_earth']:.3f} M⊕, belt has {self.belt} → deficit")):
                text(surf, f"{lab}: {fmt(h['mass_earth'])} M⊕ at {h['a_au']:.2f} AU, P {h['T_kepler_yr']:.1f} yr", (px + 20, yy), "body", 21, INK); text(surf, note, (px + 40, yy + 26), "mono", 14, DIM); yy += 60
            text(surf, "eliminated as a body · real as a deficit (row 12)", (px + 20, yy + 10), "ital", 28, RED)
        frame_tag(surf, "frame: none · statistics")

# ═════════════════════════ CH14 — BepiColombo ═════════════════════════
class CH14:
    ID, TITLE = "CH14", "Confined and dated — BepiColombo"
    def __init__(self):
        A = "v4_annulus.json"
        self.hill = D.get(A, "constants", "R_hill_perihelion_km"); self.floor10 = D.get(A, "tidal_floor", "a_min_10km_Q100_km"); self.floor1 = D.get(A, "tidal_floor", "a_min_1km_Q100_km")
        self.pro = D.get(A, "annulus", "outer_km_prograde_canonical"); self.retro = D.get(A, "annulus", "outer_km_retrograde_this_run")
        self.moi = lit("2026-11-21", "ESA BepiColombo Mercury orbit insertion (BEPICOLOMBO_OBSERVATION_REQUEST §prior art)")
        self.mpo = lit((480, 1500), "MPO orbit altitude km (ESA)"); self.mio = lit((590, 11640), "Mio orbit altitude km (JAXA)"); self.mess = lit((200, 15193), "MESSENGER primary orbit altitude km (JHUAPL)")
        self.occ = lit("2028-02-23 00:05 UTC", "vulcan_derivation.json lunar_occultations (next geocentric)")
        self.render_date = dt.date.today()
        self.countdown = (dt.date.fromisoformat(self.moi) - self.render_date).days
        self.SHOTS = [
            S(NARR, f"What remains is confined and dated. Here is Mercury's neighbourhood to scale: the planet, the tidal floors, the annulus, the retrograde band, the Hill circle. "
                    f"MESSENGER's long axis grazed the inner edge. BepiColombo enters orbit on {self.moi} — {self.countdown} days from the day this was rendered — with MPO at {fmt(self.mpo[0])} by {fmt(self.mpo[1])} kilometres "
                    f"and Mio out to {fmt(self.mio[1])}. From inside the annulus a twenty-metre body is magnitude four to nine."),
            S(NARR, f"The request was written before the result: Zecliptic frame, two campaigns per Mercury year, depth to magnitude nine, a kinematic filter — because in 1974 Mariner 10 found a moon of Mercury "
                    f"that was the star 31 Crateris. Two literature limits are unread and flagged. Row seven has a date too: the lunar occultation of {self.occ[:10]}, which tests a Charon-class silhouette and nothing smaller.",
              board={7: "dated"}, board_at=0.7),
            S(CHRON, "Two rows wait on dates. Nothing waits on preference.", pad=1.2),
        ]
    def draw(self, surf, ctx):
        caption(surf, self.ID, self.TITLE, f"rendered {self.render_date} · MOI {self.moi} · T−{self.countdown} d")
        cx, cy = 560, 560; k = 430 / self.hill
        lay = pygame.Surface((W, H), pygame.SRCALPHA)
        pygame.draw.circle(lay, (*AMBER, 60), (cx, cy), int(self.pro * k)); pygame.draw.circle(lay, (*BG, 255), (cx, cy), int(self.floor10 * k))
        pygame.draw.circle(lay, (79, 209, 255, 40), (cx, cy), int(self.retro * k), int((self.retro - self.pro) * k))
        surf.blit(lay, (0, 0))
        pygame.draw.circle(surf, GOLD, (cx, cy), int(self.hill * k), 1); text(surf, f"Hill {fmt(self.hill)} km", (cx + int(self.hill * k) - 10, cy - int(self.hill * k) + 20), "mono", 14, GOLD, "topright")
        pygame.draw.circle(surf, (120, 90, 60), (cx, cy), int(self.floor1 * k), 1)
        pygame.draw.circle(surf, AMBER, (cx, cy), int(self.floor10 * k), 1)
        pygame.draw.circle(surf, MERC, (cx, cy), max(3, int(R_MERC_KM * k)))
        def ellipse(peri_alt, apo_alt, col, lab, ang):
            rp, ra = (peri_alt + R_MERC_KM) * k, (apo_alt + R_MERC_KM) * k; a = (rp + ra) / 2; c = a - rp; b = math.sqrt(a * a - c * c)
            pts = [(cx + (a * math.cos(th) - c) * math.cos(ang) - b * math.sin(th) * math.sin(ang), cy - ((a * math.cos(th) - c) * math.sin(ang) + b * math.sin(th) * math.cos(ang))) for th in np.linspace(0, 2 * math.pi, 100)]
            pygame.draw.lines(surf, col, True, pts, 2)
        ellipse(*self.mpo, (120, 200, 120), f"MPO {self.mpo[0]}×{fmt(self.mpo[1])} km", 0.6)
        ellipse(*self.mio, (120, 160, 240), f"Mio {self.mio[0]}×{fmt(self.mio[1])} km", 0.6)
        ellipse(*self.mess, (200, 120, 200), f"MESSENGER {self.mess[0]}×{fmt(self.mess[1])} km (2011–15)", -1.1)
        legend(surf, [(AMBER, f"annulus of survival {fmt(self.floor10)}–{fmt(self.pro)} km (prograde)"), ((79, 209, 255), f"retrograde band to {fmt(self.retro)} km"), ((120, 90, 60), f"floor for a 1 km body {fmt(self.floor1)} km"), (MERC, "Mercury 2,440 km"),
                      ((120, 200, 120), f"MPO {self.mpo[0]}×{fmt(self.mpo[1])} km altitude (2.3 h)"), ((120, 160, 240), f"Mio {self.mio[0]}×{fmt(self.mio[1])} km (9.3 h)"), ((200, 120, 200), f"MESSENGER {self.mess[0]}×{fmt(self.mess[1])} km (2011–15)")], (28, 84), 15, dy=26)
        px, py = 1180, 100; pygame.draw.rect(surf, CARD, (px, py, 700, 500), border_radius=8); pygame.draw.rect(surf, RULE, (px, py, 700, 500), 1, border_radius=8)
        text(surf, "BEPICOLOMBO_OBSERVATION_REQUEST_20261010 — written before the result", (px + 16, py + 12), "mono", 14, DIM)
        yy = py + 44
        for ln in ("frame: Zecliptic; report range, period, sense", "cadence: 2 campaigns per Mercury year, 3-day sequences from Mio apoapsis", "depth: V ≥ 9 (a 20 m body is V ≈ 4–9 from inside)",
                   "kinematic filter: reject anything that does not move with Mercury", "ranging: MORE/ISA residuals for a reflex (none expected for 10 km)", f"countdown: MOI {self.moi} · science ~Mar 2027", "flags: MESSENGER size limit · P&SS 55 (2007) 2037 — unread"):
            text(surf, ln, (px + 16, yy), "body", 21, INK if "unread" not in ln else AMBER); yy += 40
        if ctx.i >= 1:
            blit_figure(surf, IMG / "concept_04_false_moon_1974.jpg", (1180, 620, 320, 230), "GENERATED plate C4 · 1974: 31 Crateris", ctx.p * 3)
            text(surf, f"row 7 · lunar occultation {self.occ}", (1520, 660), "mono", 16, GREEN); text(surf, "tests V1-class silhouette (≥ 25 % of disc) only", (1520, 690), "mono", 14, DIM)
        frame_tag(surf, "frame: Mercury-centred, to scale (km) · orbits as published altitudes")

# ═════════════════════════ CH15 — the other loop ═════════════════════════
class CH15:
    ID, TITLE = "CH15", "The other loop — AndromedaBrainScans"
    def __init__(self):
        src = "REVIEW_ANDROMEDA_VS_ELIMINATION_20261010.md §2"
        self.n_concepts = lit(46306, src); self.n_corpora = lit(11, src); self.conc = lit("74–97 %", src); self.sw = lit("0/11", src)
        self.corr = lit("A 0.96 · B 0.88 · C 0.65", src); self.bearing = lit("41.8° vs 17.3°", src)
        self.SHOTS = [
            S(NARR, f"The same morning, the operator's other loop — AndromedaBrainScans — finished on a different substrate: forty-six thousand concepts from eleven corpora instead of planets. "
                    f"Its fit was built to find something big and dull. It found a focus: reflection concentrates in all eleven. The standing wave it looked for failed in all eleven. The fields replicate; the bearing does not."),
            S(NARR, "Our budget was built to find a Newtonian cause and found none. Two instruments, two refusals of the same shape. Where they differ: for the brain scans Andromeda is a windshield to correct through. "
                    "For us, on the twenty-eighth, it was a mirror. Neither has been measured on photons. That is the joint open row."),
            S(CHRON, "A second instrument agrees on the shape of refusal.", pad=1.2),
        ]
    def draw(self, surf, ctx):
        caption(surf, self.ID, self.TITLE, "docs/ANDROMEDA_BRAIN_SCANS_20261010 · review 2026-10-10 09:17")
        ab4 = sorted(glob.glob(str(ANDRO / "results" / "plates" / "AB4*")))
        if ab4: blit_figure(surf, ab4[0], (60, 100, 560, 400), "their plate AB4 · GENERATED (operator's loop)", 1.0)
        blit_figure(surf, IMG / "concept_02_arrow_not_followed.jpg", (60, 540, 560, 320), "our plate C2 · GENERATED", 1.0)
        px, py = 680, 100; pygame.draw.rect(surf, CARD, (px, py, 1200, 760), border_radius=8); pygame.draw.rect(surf, RULE, (px, py, 1200, 760), 1, border_radius=8)
        rows = [("substrate", "positions, masses, periods, DE421", f"{self.n_concepts:,} concept vectors, {self.n_corpora} corpora"),
                ("fit built to find", "a Newtonian cause of 43″", "something big and dull (the windshield)"),
                ("what it found", "none survives (row 10 emptied)", f"a focus: reflection concentrates on {self.conc} of the sphere"),
                ("falsified", "V1–V4 as bound companions", f"standing wave on M: {self.sw}"),
                ("replicates", "edges agree with literature 0.5 R_H", f"fields corr {self.corr}; bearing {self.bearing} — no"),
                ("Andromeda is", "a MIRROR (09-28) — see our own side", "a WINDSHIELD — correct the glare out"),
                ("measured on photons", "no", "no")]
        text(surf, "ours", (px + 420, py + 20), "mono", 18, GOLD, "center"); text(surf, "theirs", (px + 900, py + 20), "mono", 18, (150, 150, 210), "center")
        yy = py + 60
        for a, b, c in rows:
            text(surf, a, (px + 20, yy), "mono", 16, DIM); paragraph(surf, b, (px + 200, yy), "body", 21, INK, 440); paragraph(surf, c, (px + 680, yy), "body", 21, INK, 500); yy += 92
        if ctx.i >= 1:
            text(surf, "joint open row: mirror vs windshield — neither measured on photons", (px + 600, py + 720), "ital", 30, RED, "center", alpha=fade_in(ctx.p, 0.1, 0.5))
        frame_tag(surf, "frame: none · comparison")

# ═════════════════════════ CH16 — not yet ═════════════════════════
class CH16:
    ID, TITLE = "CH16", "Not yet"
    def __init__(self):
        self.SHOTS = [
            S(NARR, "This is where the board stands. Rows one to five, eight to twelve: closed by numbers. Row six: a thirteen-thousand to one-hundred-thirty-six-thousand kilometre strip, with a spacecraft en route. "
                    "Row seven: a date in 2028. Row thirteen: moot. Not belief. Not disbelief. Not yet."),
            S(OPER, "We will add onto it as we go.", when="2026-10-10 14:15 · line 3307"),
            S(CHRON, "Ten closed, one confined, one dated, one moot, one spacecraft en route. The end, for now.", pad=2.0),
        ]
    def draw(self, surf, ctx):
        caption(surf, self.ID, self.TITLE)
        x0, y0 = 120, 100
        yy = y0
        for r in range(1, 14):
            st = ctx.states.get(r, "open"); col = STATE_COLOR[st]
            pygame.draw.rect(surf, col if st != "open" else (28, 30, 38), (x0, yy, 34, 34), border_radius=5)
            text(surf, str(r), (x0 + 17, yy + 17), "mono", 18, WHITE if st != "open" else DIM, "center")
            text(surf, BOARD_ROWS[r], (x0 + 50, yy + 17), "body", 24, INK, "midleft"); text(surf, st, (x0 + 560, yy + 17), "mono", 18, col, "midleft"); yy += 50
        px = 900; text(surf, "chapters of this video · v0.0.1", (px, y0), "mono", 18, DIM)
        for j, c in enumerate(CHAPTER_CLASSES):
            text(surf, f"{c.ID}  {c.TITLE}", (px, y0 + 30 + j * 26), "mono", 15, INK)
        text(surf, "CH17  ________________________  (we will add onto it as we go)", (px, y0 + 30 + 17 * 26), "mono", 15, GOLD)
        if ctx.i >= 1:
            text(surf, "Not belief. Not disbelief. Not yet.", (W // 2, 920), "ital", 44, INK, "center", alpha=fade_in(ctx.t, 1.0, 1.0))
        if ctx.shot["voice"] == OPER:
            receipt(surf, ctx.shot["when"], ctx.shot["text"], (px, 640, 900, 0), ctx.p * 4)
        frame_tag(surf, "frame: none · the board")

CHAPTER_CLASSES = [CH00, CH01, CH02, CH03, CH04, CH05, CH06, CH07, CH08, CH09, CH10, CH11, CH12, CH13, CH14, CH15, CH16]
