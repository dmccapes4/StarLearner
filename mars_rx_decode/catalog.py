"""Bright-star catalogue, J2000, for Leo and its nine bordering constellations.

Entries are (name, RA hours, Dec degrees, visual magnitude). Orion is not
included: it was a chart anchor only and is not part of this decode.

M44, the Beehive, is carried in Cancer and flagged as a cluster so it can be
drawn as the extended object it is.
"""

from __future__ import annotations

BEEHIVE = "M44 Beehive"
COMA_CLUSTER = "Melotte 111"
CLUSTERS = {BEEHIVE, COMA_CLUSTER}

# Apparent diameter on the sky, degrees. Drawn to scale rather than as a fixed
# dot, so M44 reads as the naked-eye swarm it is.
CLUSTER_DIAM_DEG = {BEEHIVE: 1.6, COMA_CLUSTER: 5.0}

STARS: dict[str, list[tuple[str, float, float, float]]] = {
    "cancer": [
        (BEEHIVE, 8.67000, 19.66667, 3.10),
        ("Altarf", 8.27525, 9.18564, 3.53),
        ("Asellus Australis", 8.74490, 18.15431, 3.94),
        ("Iota Cancri", 8.77828, 28.76035, 4.02),
        ("Acubens", 8.97464, 11.85772, 4.25),
        ("Asellus Borealis", 8.72147, 21.46853, 4.66),
        ("Zeta Cancri", 8.20535, 17.64784, 4.67),
        ("Chi Cancri", 8.34527, 27.21777, 5.14),
        ("Eta Cancri", 8.72282, 20.44027, 5.33),
        ("Theta Cancri", 8.52853, 18.09470, 5.35),
    ],
    "leo": [
        ("Regulus", 10.13952, 11.96721, 1.36),
        ("Algieba", 10.33288, 19.84149, 2.08),
        ("Denebola", 11.81766, 14.57206, 2.14),
        ("Zosma", 11.23510, 20.52372, 2.56),
        ("Ras Elased", 9.76416, 23.77425, 2.98),
        ("Chertan", 11.23722, 15.42983, 3.32),
        ("Adhafera", 10.27822, 23.41730, 3.44),
        ("Eta Leonis", 10.12220, 16.76263, 3.48),
        ("Subra", 9.68097, 9.89250, 3.52),
        ("Rho Leonis", 10.54640, 9.30799, 3.85),
        ("Rasalas", 9.87961, 26.00693, 3.88),
        ("Iota Leonis", 11.39990, 10.52956, 3.94),
    ],
    "virgo": [
        ("Spica", 13.41989, -11.16132, 0.97),
        ("Porrima", 12.69436, -1.44938, 2.74),
        ("Vindemiatrix", 13.03621, 10.95915, 2.83),
        ("Heze", 13.57849, -0.59593, 3.37),
        ("Auva", 12.92668, 3.39751, 3.38),
        ("Zavijava", 11.84492, 1.76465, 3.60),
        ("Mu Virginis", 14.71814, -5.65801, 3.87),
        ("Zaniah", 12.33246, -0.66679, 3.89),
        ("Nu Virginis", 11.76918, 6.52951, 4.03),
        ("Syrma", 14.26610, -6.00082, 4.08),
    ],
    "leo_minor": [
        ("Praecipua", 10.88626, 34.21536, 3.83),
        ("Beta LMi", 10.46610, 36.70714, 4.21),
        ("21 LMi", 10.12503, 35.24469, 4.48),
        ("10 LMi", 9.60580, 36.39750, 4.55),
        ("30 LMi", 10.47833, 33.79589, 4.74),
    ],
    "lynx": [
        ("Alpha Lyncis", 9.35084, 34.39256, 3.13),
        ("38 Lyncis", 9.30880, 36.80222, 3.82),
        ("10 Ursae Majoris", 9.00331, 41.78283, 3.96),
        ("Alsciaukat", 8.38927, 43.18808, 4.25),
        ("15 Lyncis", 6.95730, 58.42306, 4.35),
        ("21 Lyncis", 7.43722, 49.21139, 4.60),
        ("27 Lyncis", 8.14180, 51.50639, 4.80),
    ],
    "ursa_major": [
        ("Alioth", 12.90049, 55.95982, 1.77),
        ("Dubhe", 11.06214, 61.75103, 1.79),
        ("Alkaid", 13.79235, 49.31327, 1.86),
        ("Mizar", 13.39887, 54.92541, 2.27),
        ("Merak", 11.03069, 56.38243, 2.37),
        ("Phecda", 11.89718, 53.69476, 2.44),
        ("Tania Australis", 10.37217, 41.49951, 3.05),
        ("Talitha", 8.98622, 48.04173, 3.14),
        ("Theta UMa", 9.54794, 51.67729, 3.17),
        ("Megrez", 12.25707, 57.03258, 3.31),
        ("Muscida", 8.50446, 60.71817, 3.36),
        ("Tania Borealis", 10.28528, 42.91456, 3.45),
        ("Alula Borealis", 11.30800, 33.09424, 3.49),
    ],
    "coma_berenices": [
        (COMA_CLUSTER, 12.37000, 26.10000, 1.80),
        ("Beta Comae", 13.19794, 27.87823, 4.26),
        ("Diadem", 13.16628, 17.52916, 4.32),
        ("Gamma Comae", 12.44987, 28.26730, 4.35),
        ("7 Comae", 12.49340, 23.90417, 4.95),
    ],
    "crater": [
        ("Labrum", 11.32219, -14.77894, 3.56),
        ("Gamma Crateris", 11.41471, -17.68417, 4.06),
        ("Alkes", 10.99628, -18.29883, 4.07),
        ("Beta Crateris", 11.19458, -22.82606, 4.46),
        ("Theta Crateris", 11.63833, -9.80222, 4.70),
        ("Zeta Crateris", 11.75611, -18.35083, 4.71),
    ],
    "sextans": [
        ("Alpha Sextantis", 10.13253, -0.37167, 4.49),
        ("Gamma Sextantis", 9.87600, -8.10583, 5.05),
        ("Beta Sextantis", 10.50306, -0.63167, 5.09),
        ("Delta Sextantis", 10.49483, -2.73917, 5.21),
        ("Epsilon Sextantis", 10.46333, 8.38389, 5.24),
    ],
    "hydra": [
        ("Alphard", 9.45979, -8.65860, 1.98),
        ("Gamma Hydrae", 13.31510, -23.17167, 3.00),
        ("Zeta Hydrae", 8.92308, 5.94555, 3.11),
        ("Nu Hydrae", 10.82636, -16.19361, 3.11),
        ("Pi Hydrae", 14.10611, -26.68194, 3.27),
        ("Epsilon Hydrae", 8.77937, 6.41889, 3.38),
        ("Xi Hydrae", 11.55282, -31.85778, 3.54),
        ("Lambda Hydrae", 10.17936, -12.35403, 3.61),
        ("Mu Hydrae", 10.43563, -16.83603, 3.81),
        ("Theta Hydrae", 9.23367, 2.31399, 3.88),
        ("Iota Hydrae", 9.66200, -1.14278, 3.91),
        ("Delta Hydrae", 8.62742, 5.70378, 4.14),
        ("Beta Hydrae", 11.88528, -33.90806, 4.28),
        ("Rho Hydrae", 8.80722, 5.83778, 4.35),
        ("Eta Hydrae", 8.72150, 3.39871, 4.30),
    ],
}

DISPLAY_NAME = {
    "cancer": "Cancer",
    "leo": "Leo",
    "virgo": "Virgo",
    "leo_minor": "Leo Minor",
    "lynx": "Lynx",
    "ursa_major": "Ursa Major",
    "coma_berenices": "Coma Berenices",
    "crater": "Crater",
    "sextans": "Sextans",
    "hydra": "Hydra",
}

# Leo plus the nine constellations that border it.
LEO_AND_NEIGHBOURS = [
    "leo", "cancer", "leo_minor", "lynx", "ursa_major",
    "coma_berenices", "virgo", "crater", "sextans", "hydra",
]

# The three seats of the decode.
SEAT_SIGNS = ["cancer", "leo", "virgo"]


def center(sign: str) -> tuple[float, float]:
    """Brightness-weighted centre of a constellation, J2000 (RA h, Dec deg)."""
    wsum = ra = dec = 0.0
    for _n, r, d, mag in STARS[sign]:
        w = 10.0 ** (-0.4 * mag)
        ra += r * w
        dec += d * w
        wsum += w
    return ra / wsum, dec / wsum


def find(sign: str, name: str) -> tuple[float, float]:
    for n, ra, dec, _m in STARS[sign]:
        if n == name:
            return ra, dec
    raise KeyError(f"{name} not in {sign}")
