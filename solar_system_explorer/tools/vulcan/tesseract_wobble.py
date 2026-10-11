#!/usr/bin/env python3
"""
tesseract_wobble.py — a tesseract (4-cube) wobbling along the North Star.

Two panels, one clip, real directions:

  LEFT  — from Earth.  The tesseract's axis is Earth's spin axis.  It is
          tilted 23.44° off the ecliptic pole, precesses around it once per
          25,772 yr, and nutates (the wobble) once per 18.6 yr.  Up the axis
          is Polaris (for now).  Down the axis is sigma Octantis, Antarctica,
          the black spire of Mount Discovery.  The Cat's Eyes — Procyon first,
          then Gomeisa, the slide — are marked as sky directions.

  RIGHT — from Sol.  The tesseract's axis is Sol's spin axis (RA 286.13°,
          Dec +63.87°, pulled from tilt_curve.json).  Sol does not precess on
          any human clock; its wobble is the barycentric loop driven by
          Jupiter and Saturn (~1 R☉).  Up the axis is Draco (delta Draconis
          ~4°).  Down the axis is Pictor (alpha Pictoris ~3°).  Nobody points
          a telescope there — we always look in, along the Zecliptic.

Time is measured in receipts.  1 receipt = 1 wobble of Earth's axis = 18.6 yr
(the lunar-node period that drives nutation).  25,772 / 18.6 = 1,386 receipts
to one precession.  The clip plays 1/20 of a precession (~69 receipts).

The 4D part: the tesseract turns in the x–w plane.  The inner cube becomes
the outer cube and back — the fold in and out.  One fold per 10 receipts.

Frame: Zecliptic unless stated.  The sky directions are J2000 equatorial
coordinates rotated into the ecliptic frame (obliquity 23.439291°), which is
the Zecliptic by definition (Earth's orbit defines it).

Outputs (next to the ladder docs):
  video/tesseract_wobble.mp4         (ignored by git — render output)
  img/tesseract_wobble_sheet.png     contact sheet of 8 frames
  data/tesseract_wobble.json         the numbers used + separations
  TESSERACT_WOBBLE_20261011.md       what was done, literals and sources

Only numpy + matplotlib + ffmpeg.  No Godot (per instruction).
"""
from __future__ import annotations

import json
import math
import subprocess
import sys
from pathlib import Path

import numpy as np

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

HERE = Path(__file__).resolve().parent
DOCS = HERE.parent.parent / "docs" / "MERCURY_VULCAN_LADDER_20261010"
DATA = DOCS / "data"
IMG = DOCS / "img"
VID = DOCS / "video"
for d in (DATA, IMG, VID):
    d.mkdir(parents=True, exist_ok=True)

# --------------------------------------------------------------------------
# Literals (typed, with sources).  Everything else is derived below.
# --------------------------------------------------------------------------
LITERALS = {
    "obliquity_deg": (23.439291, "IAU 2006 J2000 mean obliquity"),
    "precession_yr": (25772.0, "general precession period, IAU 2006"),
    "nutation_yr": (18.6, "lunar node regression period (nutation driver)"),
    "nutation_amp_arcsec": (9.2025, "principal nutation in obliquity, 18.6 yr term"),
    "sol_tilt_deg": (7.25, "Sol equator to Zecliptic, Carrington"),
    "r_sol_km": (695700.0, "IAU 2015 nominal solar radius"),
    "receipt_yr": (18.6, "1 receipt = 1 wobble (nutation period)"),
    # J2000 equatorial coordinates (SIMBAD).  RA in degrees.
    "stars_j2000": {
        "Polaris": (37.9546, 89.2641, "alpha UMi, SIMBAD"),
        "Procyon": (114.8255, 5.2250, "alpha CMi — the first Cat's Eye, SIMBAD"),
        "Gomeisa": (111.7876, 8.2893, "beta CMi — the second Cat's Eye (the slide), SIMBAD"),
        "sigma Oct": (317.1951, -88.9565, "south pole star, SIMBAD"),
        "delta Dra": (288.1387, 67.6615, "Altais, nearest bright star to Sol's north pole, SIMBAD"),
        "alpha Pic": (102.0478, -61.9414, "nearest bright star to Sol's south pole, SIMBAD"),
        "Canopus": (95.9880, -52.6957, "for scale, down from Sol, SIMBAD"),
        "Vega": (279.2347, 38.7837, "for scale, up from Sol, SIMBAD"),
    },
    "mount_discovery": (-78.37, 165.0, "lat, lon deg — black spire, Antarctica"),
}
OBL = math.radians(LITERALS["obliquity_deg"][0])

# pulled, not typed
TILT = json.load(open(DATA / "tilt_curve.json"))
METR = json.load(open(DATA / "bodies_metrics.json"))
SOL_POLE_RA, SOL_POLE_DEC = TILT["bodies"]["sol"]["pole_radec"]
M_SOL = METR["sol"]["mass_kg"]
PLANETS = {k: METR[k] for k in ("jupiter", "saturn")}
AU_KM = 1.495978707e8  # table unit only: converts bodies_metrics a_au to km
R_SOL = LITERALS["r_sol_km"][0]


# --------------------------------------------------------------------------
# Directions
# --------------------------------------------------------------------------
def radec_unit(ra_deg: float, dec_deg: float) -> np.ndarray:
    ra, dec = math.radians(ra_deg), math.radians(dec_deg)
    return np.array([math.cos(dec) * math.cos(ra), math.cos(dec) * math.sin(ra), math.sin(dec)])


def eq_to_zecl(v: np.ndarray) -> np.ndarray:
    """J2000 equatorial -> ecliptic (= Zecliptic) : rotate about x by -obliquity."""
    c, s = math.cos(OBL), math.sin(OBL)
    R = np.array([[1, 0, 0], [0, c, s], [0, -s, c]])
    return R @ v


def sep_deg(a: np.ndarray, b: np.ndarray) -> float:
    return math.degrees(math.acos(float(np.clip(np.dot(a, b), -1, 1))))


STARS = {name: eq_to_zecl(radec_unit(ra, dec)) for name, (ra, dec, _) in LITERALS["stars_j2000"].items()}
EARTH_POLE_J2000 = eq_to_zecl(radec_unit(0.0, 90.0))
SOL_POLE = eq_to_zecl(radec_unit(SOL_POLE_RA, SOL_POLE_DEC))
ZECL_POLE = np.array([0.0, 0.0, 1.0])

# --------------------------------------------------------------------------
# Tesseract
# --------------------------------------------------------------------------
VERTS4 = np.array([[(i >> k) & 1 for k in range(4)] for i in range(16)], dtype=float) * 2 - 1
EDGES = [(i, j) for i in range(16) for j in range(i + 1, 16) if bin(i ^ j).count("1") == 1]


def rot4(theta_xw: float, theta_xy: float) -> np.ndarray:
    """Rotation in the x–w plane (fold in/out) then about the pole (x–y plane)."""
    c, s = math.cos(theta_xw), math.sin(theta_xw)
    Rxw = np.eye(4)
    Rxw[0, 0], Rxw[0, 3], Rxw[3, 0], Rxw[3, 3] = c, -s, s, c
    c2, s2 = math.cos(theta_xy), math.sin(theta_xy)
    Rxy = np.eye(4)
    Rxy[0, 0], Rxy[0, 1], Rxy[1, 0], Rxy[1, 1] = c2, -s2, s2, c2
    return Rxy @ Rxw


def project_4to3(v4: np.ndarray, d: float = 3.0) -> np.ndarray:
    """Perspective from w: inner cube = far in w, outer cube = near in w."""
    w = v4[:, 3]
    f = d / (d - w)
    return v4[:, :3] * f[:, None]


def axis_basis(pole: np.ndarray) -> np.ndarray:
    """3x3 matrix whose columns are (e1, e2, pole): map local z onto the pole."""
    z = pole / np.linalg.norm(pole)
    helper = np.array([1.0, 0, 0]) if abs(z[0]) < 0.9 else np.array([0, 1.0, 0])
    x = np.cross(helper, z)
    x /= np.linalg.norm(x)
    y = np.cross(z, x)
    return np.stack([x, y, z], axis=1)


# camera: Zecliptic pole up, elevation 18°, azimuth chosen to spread the stars
def camera(elev_deg: float = 18.0, az_deg: float = 215.0) -> np.ndarray:
    e, a = math.radians(elev_deg), math.radians(az_deg)
    Rz = np.array([[math.cos(a), -math.sin(a), 0], [math.sin(a), math.cos(a), 0], [0, 0, 1]])
    Rx = np.array([[1, 0, 0], [0, math.cos(e), -math.sin(e)], [0, math.sin(e), math.cos(e)]])
    return Rx @ Rz


CAM = camera()


def to_screen(p3: np.ndarray) -> np.ndarray:
    """3D (Zecliptic) -> screen (x right, y up, depth)."""
    q = p3 @ CAM.T
    # screen: x = q.x, y = q.z (up), depth = q.y
    return np.stack([q[..., 0], q[..., 2], q[..., 1]], axis=-1)


# --------------------------------------------------------------------------
# Earth axis as a function of receipts
# --------------------------------------------------------------------------
PREC_YR = LITERALS["precession_yr"][0]
NUT_YR = LITERALS["nutation_yr"][0]
NUT_AMP = math.radians(LITERALS["nutation_amp_arcsec"][0] / 3600.0)
RECEIPT_YR = LITERALS["receipt_yr"][0]
NUT_EXAG = 500.0  # drawn amplitude = 500 x true (1.28°); labelled on screen


def earth_axis(receipts: float, exag: float = NUT_EXAG) -> np.ndarray:
    t_yr = receipts * RECEIPT_YR
    # precession: pole circles the Zecliptic pole westward (retrograde) at fixed obliquity
    phi0 = math.atan2(EARTH_POLE_J2000[1], EARTH_POLE_J2000[0])
    phi = phi0 - 2 * math.pi * t_yr / PREC_YR
    eps = OBL + exag * NUT_AMP * math.cos(2 * math.pi * t_yr / NUT_YR)
    return np.array([math.sin(eps) * math.cos(phi), math.sin(eps) * math.sin(phi), math.cos(eps)])


def sol_barycentric_offset_rsol(receipts: float) -> np.ndarray:
    """Sol's displacement from the Jupiter+Saturn barycentre, in R☉, Zecliptic plane (circular orbits)."""
    t_d = receipts * RECEIPT_YR * 365.25636
    off = np.zeros(3)
    for b in PLANETS.values():
        a_km = b["a_au"] * AU_KM
        ang = 2 * math.pi * t_d / b["period_d"]
        off -= (b["mass_kg"] / M_SOL) * a_km * np.array([math.cos(ang), math.sin(ang), 0.0])
    return off / R_SOL


# --------------------------------------------------------------------------
# Drawing
# --------------------------------------------------------------------------
SKY_R = 3.6  # radius at which star directions are drawn
BG = "#05060a"
INK = "#e8e4d8"
AMBER = "#f2b134"
CYAN = "#5fd3e6"
RED = "#e05a4e"
GREY = "#7a7f8a"


def draw_tesseract(ax, center3: np.ndarray, pole: np.ndarray, th_xw: float, th_xy: float, size: float, color: str):
    v3 = project_4to3(VERTS4 @ rot4(th_xw, th_xy).T) * size * 0.55
    v3 = v3 @ axis_basis(pole).T + center3
    s = to_screen(v3)
    order = np.argsort([min(s[i, 2], s[j, 2]) for i, j in EDGES])
    for k in order:
        i, j = EDGES[k]
        depth = (s[i, 2] + s[j, 2]) / 2
        a = float(np.clip(0.35 + 0.15 * depth, 0.25, 0.95))
        inner = (VERTS4[i, 3] < 0) and (VERTS4[j, 3] < 0)
        lw = 1.1 if inner else 1.7
        ax.plot([s[i, 0], s[j, 0]], [s[i, 1], s[j, 1]], color=color, lw=lw, alpha=a, solid_capstyle="round")
    ax.scatter(s[:, 0], s[:, 1], s=6, color=color, alpha=0.9, zorder=5)


def draw_axis(ax, center3, pole, length, color):
    up = to_screen(center3 + pole * length)
    dn = to_screen(center3 - pole * length)
    c = to_screen(center3)
    ax.plot([c[0], up[0]], [c[1], up[1]], color=color, lw=1.0, alpha=0.8)
    ax.plot([c[0], dn[0]], [c[1], dn[1]], color=color, lw=1.0, alpha=0.5, ls="--")
    return up, dn


def draw_star(ax, name, color=INK, size=28, dx=0.08, dy=0.05, marker="*"):
    s = to_screen(STARS[name] * SKY_R)
    ax.scatter([s[0]], [s[1]], s=size, color=color, marker=marker, zorder=6)
    ax.text(s[0] + dx, s[1] + dy, name, color=color, fontsize=8, zorder=6)
    return s


def draw_precession_ring(ax, pole_j2000, color):
    phi0 = math.atan2(pole_j2000[1], pole_j2000[0])
    pts = []
    for k in range(181):
        phi = phi0 - 2 * math.pi * k / 180
        pts.append([math.sin(OBL) * math.cos(phi), math.sin(OBL) * math.sin(phi), math.cos(OBL)])
    s = to_screen(np.array(pts) * SKY_R)
    ax.plot(s[:, 0], s[:, 1], color=color, lw=0.6, alpha=0.35, ls=":")


def panel_common(ax, title):
    ax.set_facecolor(BG)
    ax.set_xlim(-4.3, 4.3)
    ax.set_ylim(-4.3, 4.3)
    ax.set_aspect("equal")
    ax.axis("off")
    ax.text(-4.2, 4.05, title, color=INK, fontsize=12, weight="bold")
    # Zecliptic plane as a faint ring
    ring = np.array([[math.cos(t), math.sin(t), 0.0] for t in np.linspace(0, 2 * math.pi, 181)]) * SKY_R
    s = to_screen(ring)
    ax.plot(s[:, 0], s[:, 1], color=GREY, lw=0.7, alpha=0.5)
    ax.text(s[150, 0] + 0.1, s[150, 1] - 0.2, "Zecliptic", color=GREY, fontsize=7)


def render_frame(receipts: float, fig, axL, axR, total_receipts: float):
    axL.clear()
    axR.clear()
    th_xw = 2 * math.pi * receipts / 10.0  # one fold in/out per 10 receipts
    th_xy = 2 * math.pi * receipts / 3.0  # spin about the axis (slow, for legibility)

    # ---------------- Earth
    panel_common(axL, "from Earth — look up, look down")
    pole = earth_axis(receipts)
    draw_precession_ring(axL, EARTH_POLE_J2000, CYAN)
    draw_tesseract(axL, np.zeros(3), pole, th_xw, th_xy, 1.0, CYAN)
    up, dn = draw_axis(axL, np.zeros(3), pole, SKY_R, CYAN)
    axL.text(up[0] - 1.1, up[1] + 0.12, "spin axis, now", color=CYAN, fontsize=7)
    axL.text(dn[0] + 0.1, dn[1] - 0.15, "Antarctica · Mount Discovery", color=CYAN, fontsize=7)
    draw_star(axL, "Polaris", INK, 60)
    draw_star(axL, "sigma Oct", INK, 24)
    draw_star(axL, "Procyon", AMBER, 70)
    draw_star(axL, "Gomeisa", AMBER, 50, dx=-0.9, dy=0.12)
    pr, gm = to_screen(STARS["Procyon"] * SKY_R), to_screen(STARS["Gomeisa"] * SKY_R)
    axL.plot([pr[0], gm[0]], [pr[1], gm[1]], color=AMBER, lw=1.2, alpha=0.8)
    axL.text((pr[0] + gm[0]) / 2 + 0.1, (pr[1] + gm[1]) / 2 - 0.25, "the Cat's Eyes", color=AMBER, fontsize=8, style="italic")
    off_polaris = sep_deg(pole, STARS["Polaris"]) if True else 0
    axL.text(-4.2, -3.7, f"axis → Polaris: {off_polaris:5.2f}°   (0.74° at J2000)", color=INK, fontsize=8)
    axL.text(-4.2, -4.0, f"nutation drawn ×{NUT_EXAG:.0f} (true 9.2″)   precession 25,772 yr", color=GREY, fontsize=7)

    # ---------------- Sol
    panel_common(axR, "from Sol — did we ever look up or down?")
    off = sol_barycentric_offset_rsol(receipts)
    center = off * 0.9  # tesseract half-size ≈ 1 R☉ drawn as 0.9 units
    draw_tesseract(axR, center, SOL_POLE, th_xw * 0.5, th_xy * 0.3, 1.0, AMBER)
    up, dn = draw_axis(axR, center, SOL_POLE, SKY_R, AMBER)
    axR.text(up[0] + 0.1, up[1] + 0.05, "Sol pole (Draco)", color=AMBER, fontsize=7)
    axR.text(dn[0] - 1.9, dn[1] - 0.15, "Sol anti-pole (Pictor)", color=AMBER, fontsize=7)
    draw_star(axR, "delta Dra", INK, 30)
    draw_star(axR, "Vega", INK, 30, dx=-0.55, dy=-0.25)
    draw_star(axR, "alpha Pic", INK, 24)
    draw_star(axR, "Canopus", INK, 40, dx=0.1, dy=-0.28)
    draw_star(axR, "Procyon", AMBER, 50)
    draw_star(axR, "Gomeisa", AMBER, 36, dx=-0.9, dy=0.12)
    draw_star(axR, "Polaris", GREY, 24)
    # barycentre mark + wobble trail
    bc = to_screen(np.zeros(3))
    axR.scatter([bc[0]], [bc[1]], s=14, color=INK, marker="+", zorder=7)
    trail = np.array([sol_barycentric_offset_rsol(r) * 0.9 for r in np.linspace(max(0, receipts - 1.5), receipts, 60)])
    st = to_screen(trail)
    axR.plot(st[:, 0], st[:, 1], color=AMBER, lw=0.8, alpha=0.5)
    axR.text(-4.2, -3.7, f"Sol wobble: {np.linalg.norm(off):4.2f} R☉ from barycentre (Jupiter+Saturn)", color=INK, fontsize=8)
    axR.text(-4.2, -4.0, "axis fixed on human clocks · tilt 7.25° to Zecliptic", color=GREY, fontsize=7)

    # ---------------- receipts
    yr = receipts * RECEIPT_YR
    fig.suptitle(
        f"receipts: {receipts:6.1f}    ({yr:7.0f} yr after J2000)    1 receipt = 1 wobble = 18.6 yr    "
        f"fold {((receipts / 10.0) % 1.0) * 100:3.0f} %",
        color=INK,
        fontsize=11,
        y=0.98,
    )


# --------------------------------------------------------------------------
def main(seconds: float = 24.0, fps: int = 30, total_receipts: float = PREC_YR / RECEIPT_YR / 20.0):
    plt.rcParams["figure.facecolor"] = BG
    fig, (axL, axR) = plt.subplots(1, 2, figsize=(16, 9), dpi=80)
    fig.subplots_adjust(left=0.01, right=0.99, top=0.93, bottom=0.01, wspace=0.02)

    n = int(seconds * fps)
    out_mp4 = VID / "tesseract_wobble.mp4"
    ff = subprocess.Popen(
        ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgba", "-s", "1280x720",
         "-r", str(fps), "-i", "-", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", str(out_mp4)],
        stdin=subprocess.PIPE,
    )
    sheet_idx = set(np.linspace(0, n - 1, 8).astype(int).tolist())
    sheet = []
    for k in range(n):
        r = total_receipts * k / (n - 1)
        render_frame(r, fig, axL, axR, total_receipts)
        fig.canvas.draw()
        buf = np.asarray(fig.canvas.buffer_rgba())
        ff.stdin.write(buf.tobytes())
        if k in sheet_idx:
            sheet.append((r, buf.copy()))
        if k % 60 == 0:
            print(f"frame {k}/{n}  receipts {r:.1f}", file=sys.stderr)
    ff.stdin.close()
    ff.wait()
    plt.close(fig)

    # contact sheet
    fig2, axes = plt.subplots(4, 2, figsize=(16, 18), dpi=70)
    fig2.patch.set_facecolor(BG)
    for ax, (r, buf) in zip(axes.ravel(), sheet):
        ax.imshow(buf)
        ax.axis("off")
        ax.set_title(f"receipts {r:.1f}", color=INK, fontsize=10)
    fig2.tight_layout()
    fig2.savefig(IMG / "tesseract_wobble_sheet.png", facecolor=BG)
    plt.close(fig2)

    # numbers
    seps = {
        "earth_pole_j2000_to_polaris_deg": sep_deg(EARTH_POLE_J2000, STARS["Polaris"]),
        "earth_pole_j2000_to_sigma_oct_deg": sep_deg(-EARTH_POLE_J2000, STARS["sigma Oct"]),
        "earth_pole_to_procyon_deg": sep_deg(EARTH_POLE_J2000, STARS["Procyon"]),
        "earth_pole_to_gomeisa_deg": sep_deg(EARTH_POLE_J2000, STARS["Gomeisa"]),
        "procyon_to_gomeisa_deg": sep_deg(STARS["Procyon"], STARS["Gomeisa"]),
        "sol_pole_to_earth_pole_deg": sep_deg(SOL_POLE, EARTH_POLE_J2000),
        "sol_pole_to_zecliptic_pole_deg": sep_deg(SOL_POLE, ZECL_POLE),
        "sol_pole_to_delta_dra_deg": sep_deg(SOL_POLE, STARS["delta Dra"]),
        "sol_pole_to_vega_deg": sep_deg(SOL_POLE, STARS["Vega"]),
        "sol_pole_to_polaris_deg": sep_deg(SOL_POLE, STARS["Polaris"]),
        "sol_antipole_to_alpha_pic_deg": sep_deg(-SOL_POLE, STARS["alpha Pic"]),
        "sol_antipole_to_canopus_deg": sep_deg(-SOL_POLE, STARS["Canopus"]),
        "sol_pole_to_procyon_deg": sep_deg(SOL_POLE, STARS["Procyon"]),
        "sol_pole_to_gomeisa_deg": sep_deg(SOL_POLE, STARS["Gomeisa"]),
        "cats_eyes_below_zecliptic_deg": {
            "Procyon": math.degrees(math.asin(STARS["Procyon"][2])),
            "Gomeisa": math.degrees(math.asin(STARS["Gomeisa"][2])),
        },
    }
    # when does the axis leave Polaris?  First receipt at which separation > 5°
    leave = None
    for r in np.arange(0, 200, 0.25):
        if sep_deg(earth_axis(r, exag=0.0), STARS["Polaris"]) > 5.0:
            leave = float(r)
            break
    # closest approach to Polaris (true nutation, no exaggeration)
    best = min(((sep_deg(earth_axis(r, exag=0.0), STARS["Polaris"]), r) for r in np.arange(0, 20, 0.05)))
    offs = [float(np.linalg.norm(sol_barycentric_offset_rsol(r))) for r in np.linspace(0, total_receipts, 2000)]
    out = {
        "literals": LITERALS,
        "pulled": {
            "sol_pole_radec_j2000": [SOL_POLE_RA, SOL_POLE_DEC],
            "sol_mass_kg": M_SOL,
            "jupiter": PLANETS["jupiter"],
            "saturn": PLANETS["saturn"],
        },
        "receipts": {
            "receipt_yr": RECEIPT_YR,
            "receipts_per_precession": PREC_YR / RECEIPT_YR,
            "clip_receipts": total_receipts,
            "clip_years": total_receipts * RECEIPT_YR,
            "fold_period_receipts": 10.0,
            "axis_leaves_polaris_by_5deg_at_receipt": leave,
            "axis_leaves_polaris_by_5deg_year": None if leave is None else 2000 + leave * RECEIPT_YR,
            "closest_to_polaris_deg": best[0],
            "closest_to_polaris_receipt": best[1],
            "closest_to_polaris_year": 2000 + best[1] * RECEIPT_YR,
        },
        "separations_deg": seps,
        "sol_wobble_rsol": {"min": min(offs), "max": max(offs)},
        "drawing": {"nutation_exaggeration": NUT_EXAG, "sky_radius_units": SKY_R, "camera_elev_az": [18.0, 215.0]},
        "frame": "Zecliptic (J2000 ecliptic), obliquity rotation of equatorial coordinates",
        "outputs": {"mp4": str(out_mp4.relative_to(DOCS)), "sheet": "img/tesseract_wobble_sheet.png"},
    }
    (DATA / "tesseract_wobble.json").write_text(json.dumps(out, indent=2))
    print(json.dumps({k: v for k, v in out.items() if k in ("receipts", "separations_deg", "sol_wobble_rsol")}, indent=2))
    return out


if __name__ == "__main__":
    main()
