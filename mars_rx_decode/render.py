#!/usr/bin/env python3
"""Mars retrograde over Leo, from 23.5 south, 26,000 years before J2000.

Reads the record as  o< H >o :

  o<   western head and its horns -- waxing crescent beyond Cancer, with the
       retrograde cusp beside it opening inward
  H    the centre -- Leo, full Moon, ringed by its nine bordering
       constellations
  >o   eastern head and its horns -- waning crescent beyond Virgo, cusp
       opening inward

The horns are the two legs of Mars's stationary cusps, not the crescents. Each
cusp has its vertex outboard and its legs diverging inward, so both horns face
the centre.

Only real objects are drawn: catalogued stars precessed to the epoch, the Moon
as an opaque lit sphere, Mars on its path, and the Beehive as a cluster. No
glyphs are overlaid and no view is mirrored.
"""

from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

import catalog
import sky
import track

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "out"
MOON_TEX = ROOT / "assets" / "moon_texture.png"

MOON_TRUE_DIAM_DEG = 0.5181
# Elongation from the Sun, degrees. A crescent is anything before first
# quarter (90 deg); 72 deg puts it at 35% lit -- late crescent, still plainly a
# crescent, and thick enough to read at plate scale.
PHASE_ELONGATION = {"waxing_crescent": 72.0, "full": 180.0,
                    "waning_crescent": 72.0}

_FONTS: dict[int, ImageFont.FreeTypeFont] = {}


def font(size: int) -> ImageFont.FreeTypeFont:
    if size not in _FONTS:
        p = Path("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf")
        _FONTS[size] = (ImageFont.truetype(str(p), size) if p.exists()
                        else ImageFont.load_default())
    return _FONTS[size]


def moon_texture() -> np.ndarray:
    return np.asarray(Image.open(MOON_TEX).convert("L"), dtype=np.float32) / 255.0


def epoch_pos(sign: str, name: str | None = None) -> tuple[float, float]:
    ra, dec = catalog.find(sign, name) if name else catalog.center(sign)
    return sky.precess(ra, dec)


def star_style(mag: float) -> tuple[float, float]:
    return max(1.4, 4.9 - 0.62 * mag), max(0.14, min(1.0, (4.6 - mag) / 3.6))


def draw_point(d: ImageDraw.ImageDraw, x, y, r, core, glow=1.0) -> None:
    for mult, alpha in ((2.5, 20), (1.75, 44), (1.28, 86)):
        a = int(alpha * glow)
        if a <= 0:
            continue
        rr = r * mult
        d.ellipse((x - rr, y - rr, x + rr, y + rr), fill=(*core, a))
    d.ellipse((x - r, y - r, x + r, y + r), fill=(*core, 255))


def draw_cluster(d: ImageDraw.ImageDraw, x, y, r, bright: bool) -> None:
    """Open cluster: resolved members over a very faint haze.

    M44 is a naked-eye swarm of individual stars, not a bright disk, so the
    haze stays low and the members carry it.
    """
    rng = np.random.default_rng(4477)
    n = 44 if bright else 20
    for i in range(n):
        dx, dy = rng.normal(0.0, r * 0.52, 2)
        if math.hypot(dx, dy) > r:
            continue
        lead = i % 5 == 0
        rr = min(3.4, max(1.0, r * (0.075 if lead else 0.05)))
        draw_point(d, x + dx, y + dy, rr, (238, 243, 253),
                   0.8 if lead else 0.4)


def moon_disk(radius_px: int, phase: str, west: tuple[float, float],
              tex: np.ndarray) -> Image.Image:
    """Opaque lit sphere. A waxing Moon is lit on its western limb."""
    radius = max(9, int(radius_px))
    size = radius * 2 + 2
    yy, xx = np.mgrid[0:size, 0:size]
    c = size / 2.0 - 0.5
    nx = (xx - c) / radius
    ny = (c - yy) / radius
    r2 = nx * nx + ny * ny
    inside = r2 <= 1.0
    nz = np.zeros_like(nx)
    nz[inside] = np.sqrt(np.clip(1.0 - r2[inside], 0.0, 1.0))

    plane = np.array([west[0], -west[1]], dtype=np.float64)
    plane /= (math.hypot(*plane) or 1.0)
    if phase == "waning_crescent":
        plane = -plane
    e = math.radians(PHASE_ELONGATION[phase])
    sun = np.array([math.sin(e) * plane[0], math.sin(e) * plane[1],
                    -math.cos(e)])
    sun /= np.linalg.norm(sun)
    lit = np.clip(nx * sun[0] + ny * sun[1] + nz * sun[2], 0.0, 1.0)

    lon = np.arctan2(nx, np.maximum(nz, 1e-6))
    lat = np.arcsin(np.clip(ny, -1.0, 1.0))
    th, tw = tex.shape
    tx = ((lon / math.pi + 1.0) * 0.5 * (tw - 1)).astype(np.int32) % tw
    ty = np.clip(((0.5 - lat / math.pi) * (th - 1)).astype(np.int32), 0, th - 1)
    # Gamma 0.55 lifts the midtones of the lit limb. A 21%-lit crescent is
    # geometrically correct but reads as a black disk at plate scale, so the
    # tone curve is opened up; the terminator position is untouched.
    # Earthshine keeps the dark limb readable as a sphere rather than a hole.
    shade = np.maximum(lit ** 0.55, 0.025)
    bright = (0.44 + 0.56 * tex[ty, tx]) * shade

    out = np.zeros((size, size, 4), dtype=np.float32)
    out[..., 0] = np.where(inside, bright * 0.99, 0.0)
    out[..., 1] = np.where(inside, bright * 0.98, 0.0)
    out[..., 2] = np.where(inside, bright * 0.93, 0.0)
    out[..., 3] = np.where(inside, 1.0, 0.0)
    return Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8), "RGBA")


def track_eq() -> list[tuple[float, float]]:
    dense = track.resample(track.PATH)
    return [sky.ecliptic_of_epoch_to_eq(lam, beta) for lam, beta in dense]


def leg_bounds() -> tuple[int, int]:
    per = 9
    return track.I_RETRO_START * per, track.I_RETRO_END * per


def scene_vectors(signs: list[str], lst: float) -> list:
    vecs = []
    for sign in signs:
        for _n, ra, dec, _m in catalog.STARS[sign]:
            ra_e, dec_e = sky.precess(ra, dec)
            alt, az = sky.eq_to_altaz(ra_e, dec_e, lst)
            if alt > -3.0:
                vecs.append(sky.altaz_to_vec(max(alt, 0.0), az))
    for ra_e, dec_e in track_eq():
        alt, az = sky.eq_to_altaz(ra_e, dec_e, lst)
        vecs.append(sky.altaz_to_vec(max(alt, 0.0), az))
    for lam, beta in track.MOON_SEAT.values():
        ra_e, dec_e = sky.ecliptic_of_epoch_to_eq(lam, beta)
        alt, az = sky.eq_to_altaz(ra_e, dec_e, lst)
        vecs.append(sky.altaz_to_vec(max(alt, 0.0), az))
    return vecs


def horn_splay(sign: str) -> tuple[float, float]:
    """How far the two legs of a cusp open, in degrees of sky.

    Returns the widest separation between the legs and how far that is from the
    station, both measured along ecliptic longitude. This is the honest size of
    the horn: a real Mars station is a hairpin, so the opening is a few degrees,
    not the wide wedge a drawn glyph suggests.
    """
    retro = track.RETROGRADE
    if sign == "cancer":
        tip_lam = track.STATION_WEST_PT[0]
        leg_a, leg_b = track.DIRECT_OUT, list(reversed(retro))
    else:
        tip_lam = track.STATION_EAST_PT[0]
        leg_a, leg_b = track.DIRECT_IN, retro

    def beta_at(seg, lam):
        for (l0, b0), (l1, b1) in zip(seg, seg[1:]):
            lo, hi = min(l0, l1), max(l0, l1)
            if lo <= lam <= hi and abs(l1 - l0) > 1e-9:
                return b0 + (b1 - b0) * (lam - l0) / (l1 - l0)
        return None

    best = (0.0, 0.0)
    for step in range(1, 60):
        lam = tip_lam + step * (1.0 if sign == "cancer" else -1.0)
        bu, bl = beta_at(leg_a, lam), beta_at(leg_b, lam)
        if bu is None or bl is None:
            continue
        gap = abs(bl - bu)
        if gap > best[0]:
            best = (gap, abs(lam - tip_lam))
    return best


def focus_vectors(lam_lo: float, lam_hi: float,
                  moon_sign: str, lst: float) -> list:
    """Directions to frame a horn plate.

    Deliberately only the horn itself -- its stretch of track and its Moon.
    Stars are left out of the fit so a single high-latitude member of the
    constellation cannot drag the frame away from the horn. Everything is still
    drawn; it just does not vote on the framing.
    """
    vecs = []
    for lam, beta in track.resample(track.PATH):
        if not lam_lo <= lam <= lam_hi:
            continue
        ra_e, dec_e = sky.ecliptic_of_epoch_to_eq(lam, beta)
        alt, az = sky.eq_to_altaz(ra_e, dec_e, lst)
        vecs.append(sky.altaz_to_vec(max(alt, 0.0), az))
    lam, beta = track.MOON_SEAT[moon_sign]
    ra_e, dec_e = sky.ecliptic_of_epoch_to_eq(lam, beta)
    alt, az = sky.eq_to_altaz(ra_e, dec_e, lst)
    vecs.append(sky.altaz_to_vec(max(alt, 0.0), az))
    return vecs


def seat_lst(sign: str) -> float:
    """Sidereal time at which a seat stands on the meridian."""
    lam, beta = track.MOON_SEAT[sign]
    ra_e, _dec = sky.ecliptic_of_epoch_to_eq(lam, beta)
    return ra_e


def render(signs: list[str], lst: float, title: str, subtitle: str,
           moons: list[str], w: int, h: int, tex: np.ndarray,
           notes: list[str] | None = None,
           focus_vecs: list | None = None, trim: float = 1.5,
           moon_max_px: float = 30.0, fill_x: float = 0.94,
           fill_y: float = 0.78) -> Image.Image:
    # Keep clear of the title block at the top and the notes at the bottom.
    cx, cy = w / 2.0, h / 2.0 + 46.0
    vecs = focus_vecs if focus_vecs else scene_vectors(signs, lst)
    plate = sky.fit_plate(vecs, w, h, cx, cy, fill_x=fill_x, fill_y=fill_y,
                          trim=trim)
    img = Image.new("RGBA", (w, h), (2, 3, 6, 255))
    d = ImageDraw.Draw(img, "RGBA")

    # Horizon and cardinal marks.
    hpts = [p for p in (plate.project_altaz(0.0, float(a)) for a in range(0, 361))
            if p is not None and -2 * w < p[0] < 2 * w and -2 * h < p[1] < 2 * h]
    if len(hpts) > 1:
        d.line(hpts, fill=(42, 48, 60, 200), width=2)
    for az, tag in ((0, "N"), (30, "NNE"), (60, "ENE"), (90, "E"),
                    (270, "W"), (300, "WNW"), (330, "NNW")):
        p = plate.project_altaz(0.0, float(az))
        if p is None or not 6 < p[0] < w - 46:
            continue
        d.text((p[0] - 10, p[1] + 12), tag, font=font(20), fill=(96, 104, 118, 220))

    # Faint ecliptic: the road Mars and the Moon both travel.
    ecl = []
    for lam in range(95, 231):
        ra_e, dec_e = sky.ecliptic_of_epoch_to_eq(float(lam), 0.0)
        p = plate.project_eq(ra_e, dec_e, lst)
        if p is not None and p[2] > 0.0:
            ecl.append((p[0], p[1]))
    if len(ecl) > 1:
        d.line(ecl, fill=(36, 44, 58, 190), width=2)

    # Keep labels off the Moon heads drawn later in this plate.
    keep_out: list[tuple[float, float, float]] = []
    for sign in moons:
        lam, beta = track.MOON_SEAT[sign]
        ra_e, dec_e = sky.ecliptic_of_epoch_to_eq(lam, beta)
        q = plate.project_eq(ra_e, dec_e, lst)
        if q is not None and q[2] > 0.0:
            keep_out.append((q[0], q[1], moon_max_px + 46.0))

    def clear(x: float, y: float) -> bool:
        return all(math.hypot(x - kx, y - ky) > kr for kx, ky, kr in keep_out)

    # Stars.
    for sign in signs:
        for name, ra, dec, mag in catalog.STARS[sign]:
            ra_e, dec_e = sky.precess(ra, dec)
            p = plate.project_eq(ra_e, dec_e, lst)
            if p is None or p[2] < 0.0:
                continue
            if name in catalog.CLUSTERS:
                crucial = name == catalog.BEEHIVE
                ppd = plate.pixels_per_degree(sky.altaz_to_vec(
                    *sky.eq_to_altaz(ra_e, dec_e, lst)))
                cr = max(5.0, 0.5 * catalog.CLUSTER_DIAM_DEG[name] * ppd)
                draw_cluster(d, p[0], p[1], cr, crucial)
                if clear(p[0], p[1]):
                    d.text((p[0] + cr + 12, p[1] - cr - 26),
                           name, font=font(23 if crucial else 18),
                           fill=(214, 228, 250, 252) if crucial
                           else (132, 144, 164, 200))
                continue
            r, glow = star_style(mag)
            anchor = (sign, name) in (track.ANCHOR_EAST, track.ANCHOR_WEST)
            draw_point(d, p[0], p[1], r + (1.6 if anchor else 0.0),
                       (255, 236, 206) if anchor else (236, 240, 248), glow)
            if anchor:
                # The station anchors carry the horns, so they are always named.
                rr = r + 13
                d.ellipse((p[0] - rr, p[1] - rr, p[0] + rr, p[1] + rr),
                          outline=(214, 186, 132, 190), width=2)
                d.text((p[0] - 4, p[1] - rr - 32), name, font=font(23),
                       fill=(238, 214, 168, 250))
            elif mag < 2.2 and clear(p[0], p[1]):
                d.text((p[0] + r + 8, p[1] - 10), name, font=font(18),
                       fill=(140, 152, 172, 210))

    # Mars path. The retrograde leg is drawn strongest; the two direct legs are
    # the second leg of each horn.
    pts = []
    for ra_e, dec_e in track_eq():
        p = plate.project_eq(ra_e, dec_e, lst)
        pts.append((p[0], p[1]) if p is not None and p[2] > -1.0 else None)
    r0, r1 = leg_bounds()
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        if a is None or b is None:
            continue
        retro = r0 <= i < r1
        d.line([a, b], fill=(232, 108, 62, 235) if retro else (150, 78, 54, 190),
               width=6 if retro else 4)

    # Mars at the three marked moments. Labels lean away from the centre so
    # they clear the Moon heads sitting just outboard.
    per = 9
    offsets = {"virgo": (-64, 18), "leo": (16, 20), "cancer": (24, 18)}
    for sign, knot in track.MARS_AT.items():
        p = pts[min(knot * per, len(pts) - 1)]
        if p is None:
            continue
        draw_point(d, p[0], p[1], 8.5, (255, 118, 62), 1.0)
        dx, dy = offsets.get(sign, (16, 18))
        d.text((p[0] + dx, p[1] + dy), "Mars", font=font(21),
               fill=(248, 164, 122, 245))

    # Moons: opaque heads.
    for sign in moons:
        lam, beta = track.MOON_SEAT[sign]
        phase = track.MOON_SEAT_PHASE[sign]
        ra_e, dec_e = sky.ecliptic_of_epoch_to_eq(lam, beta)
        alt, az = sky.eq_to_altaz(ra_e, dec_e, lst)
        if alt <= 0.0:
            continue
        v = sky.altaz_to_vec(alt, az)
        p = plate.project_vec(v)
        if p is None:
            continue
        # True angular size magnified about 20x so the phase is legible, then
        # clamped so the local scale of the projection cannot inflate one head
        # relative to another.
        ppd = plate.pixels_per_degree(v)
        r = min(moon_max_px, max(16.0, 0.5 * MOON_TRUE_DIAM_DEG * ppd * 20.0))
        disk = moon_disk(int(round(r)), phase, plate.west_dir_at(v), tex)
        img.alpha_composite(disk, (int(p[0] - disk.width / 2),
                                   int(p[1] - disk.height / 2)))
        label = {"waxing_crescent": "Moon, waxing crescent",
                 "full": "Moon, full",
                 "waning_crescent": "Moon, waning crescent"}[phase]
        lf = font(20)
        box = d.textbbox((0, 0), label, font=lf)
        d.text((p[0] - (box[2] - box[0]) / 2, p[1] + r + 14), label, font=lf,
               fill=(226, 230, 240, 245))

    # Constellation names, placed above the stars proper. Clusters are skipped
    # so a name never lands on top of its own cluster label.
    for sign in signs:
        vis = []
        for name, ra, dec, _m in catalog.STARS[sign]:
            if name in catalog.CLUSTERS:
                continue
            ra_e, dec_e = sky.precess(ra, dec)
            p = plate.project_eq(ra_e, dec_e, lst)
            if p is not None and p[2] >= 0.0:
                vis.append(p)
        if not vis:
            continue
        lx = sum(p[0] for p in vis) / len(vis)
        ly = min(p[1] for p in vis) - 44
        text = catalog.DISPLAY_NAME[sign]
        tf = font(30 if sign in catalog.SEAT_SIGNS else 23)
        box = d.textbbox((0, 0), text, font=tf)
        d.text((lx - (box[2] - box[0]) / 2, ly), text, font=tf,
               fill=(196, 208, 228, 235) if sign in catalog.SEAT_SIGNS
               else (128, 140, 160, 200))

    d.text((36, 28), title, font=font(38), fill=(232, 236, 244, 255))
    d.text((36, 78), subtitle, font=font(21), fill=(140, 150, 166, 235))
    for i, line in enumerate(notes or []):
        d.text((36, h - 40 - 30 * (len(notes or []) - 1 - i)), line,
               font=font(21), fill=(190, 150, 116, 235) if i == 0
               else (146, 158, 176, 225))
    return img.convert("RGB")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    tex = moon_texture()
    shift = sky.precession_shift_deg()
    base = (f"latitude {sky.LAT_DEG:+.1f}\u00b0  \u00b7  "
            f"{sky.YEARS_BEFORE_J2000:.0f} yr before J2000  \u00b7  "
            f"pole near Polaris (2.4\u00b0)  \u00b7  equinox shifted "
            f"{shift % 360.0:.1f}\u00b0  \u00b7  obliquity {sky.EPS_EPOCH:.1f}\u00b0")

    lst_leo = seat_lst("leo")
    all_signs = catalog.LEO_AND_NEIGHBOURS
    render(all_signs, lst_leo,
           "o<  H  >o      Mars retrograde over Leo",
           base,
           ["cancer", "leo", "virgo"], 3400, 2000, tex,
           notes=[
               "Horns are Mars's two stationary cusps, anchored on Acubens "
               "(Cancer's eastern edge) and Zavijava (Virgo's western edge). "
               "Both open toward Leo.",
               "Facing north from the southern tropic, east falls on the RIGHT "
               "\u2014 Cancer left, Leo centre, Virgo right.",
               "Composite record: the three Moon states are three separate "
               "months, drawn together as the frame.",
           ]).save(OUT / "master.png")
    print("wrote master.png")

    seats = [
        ("cancer", "o<   \u2014 the Cancer horn, opening from Acubens toward Leo",
         ["cancer", "leo", "hydra", "lynx", "leo_minor"], (114.0, 156.0),
         "Retrograde ENDS here, on Acubens at Cancer's eastern edge. Both legs "
         "open east, toward Leo."),
        ("leo", "H   \u2014 the centre, Leo and its nine borders",
         catalog.LEO_AND_NEIGHBOURS, None,
         "Mid retrograde: Mars sweeps westward across Leo, past the full Moon "
         "seated in the body of the lion."),
        ("virgo", ">o   \u2014 the Virgo horn, opening from Zavijava toward Leo",
         ["virgo", "leo", "coma_berenices", "crater", "hydra"], (150.0, 192.0),
         "Retrograde BEGINS here, on Zavijava at Virgo's western edge. Both "
         "legs open west, toward Leo."),
    ]
    # Every plate uses the one sky orientation of the master, with Leo on the
    # meridian. The ecliptic's tilt to the horizon changes through the night, so
    # holding the moment fixed is what lets the two horns be compared as shapes
    # instead of as two different rotations.
    for i, (sign, title, signs, lam_range, note) in enumerate(seats, start=1):
        signs = [s for s in signs if s in catalog.STARS]
        lst = lst_leo
        phase = track.MOON_SEAT_PHASE[sign]
        # Fit on the horn itself -- its own constellation, its stretch of the
        # track, and its Moon. The neighbours are still drawn, but they no
        # longer pull the frame open.
        focus = (focus_vectors(lam_range[0], lam_range[1], sign, lst)
                 if lam_range else None)
        if lam_range:
            gap, dist = horn_splay(sign)
            extra = (f"Measured opening: the two legs reach {gap:.1f}\u00b0 "
                     f"apart {dist:.0f}\u00b0 of longitude from the station. A "
                     "real station is a hairpin, so that is the true size of "
                     "the horn.")
        else:
            extra = ("Full Moon: opposite the Sun, so the whole disk is lit "
                     "and Mars stays readable beside it.")
        render(signs, lst, title, base, [sign],
               2600, 1500, tex, notes=[note, extra],
               focus_vecs=focus, trim=0.0 if lam_range else 1.5,
               moon_max_px=52.0,
               # Room around the horn so its constellation still shows.
               fill_x=0.66 if lam_range else 0.94,
               fill_y=0.52 if lam_range else 0.78,
               ).save(OUT / f"{i}_{sign}_{phase}.png")
        print(f"wrote {i}_{sign}_{phase}.png")

    # The two horn plates stacked, so the mirror relation is visible at once.
    top = Image.open(OUT / "1_cancer_waxing_crescent.png")
    bot = Image.open(OUT / "3_virgo_waning_crescent.png")
    sheet = Image.new("RGB", (top.width, top.height + bot.height), (2, 3, 6))
    sheet.paste(top, (0, 0))
    sheet.paste(bot, (0, top.height))
    sheet.save(OUT / "horns_pair.png")
    print("wrote horns_pair.png")


if __name__ == "__main__":
    main()
