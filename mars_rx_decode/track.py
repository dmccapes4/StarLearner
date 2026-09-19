"""Mars's apparent retrograde path, in ecliptic coordinates of the epoch.

Shape of a real Mars apparition: Mars runs direct (eastward, increasing
ecliptic longitude), slows to a stationary point and turns, sweeps back
westward through retrograde, reaches a second stationary point and turns
again, then resumes direct motion.

Each stationary point is a cusp -- a horn. This path is laid out so the two
cusps fall at the outer ends of the run, one past Virgo and one past Cancer,
with the retrograde sweep crossing Leo between them. Because the two legs at
each cusp diverge inward, both horns point inward toward the centre.

Longitudes are ecliptic longitude of the epoch. For reference at this epoch:
Cancer centre 123.6, Beehive 124.1, Regulus 146.6, Leo centre 150.9,
Porrima 187.0, Virgo centre 195.3, Spica 200.7.
"""

from __future__ import annotations

import math

# (ecliptic longitude, ecliptic latitude), in time order.
# Retrograde runs westward, so longitude decreases through the middle leg.
# From 23.5 south, negative ecliptic latitude projects HIGHER on the plate
# (verified by check_orient.py). So the two direct legs are held at negative
# latitude and the retrograde sweep at positive: each cusp then has an upper
# horn and a lower horn diverging from a tip that sits outboard and high --
# the  <  and  >  of the record, splayed horns rather than a single stroke.

# The two stations are anchored on real stars, at the inboard edges of their
# own constellations -- the sides that face Leo:
#
#   Acubens  (alpha Cancri), Cancer's eastern edge   ecl lon 130.45, lat -5.08
#   Zavijava (beta Virginis), Virgo's western edge    ecl lon 173.97, lat +0.69
#
# Both horns therefore open from their own constellation toward Leo, and the
# retrograde sweep spans the 43.5 degrees between the anchors, crossing Leo.
#
# Loop width is set for a perihelic opposition -- about 6 degrees of apparent
# latitude between the legs of a horn. That is the widest a real Mars loop
# opens, and it is also when Mars is brightest, so it is the apparition most
# likely to have been worth recording.
#
# Only the stretch of direct motion near each station is drawn. That keeps the
# centre clear, so the figure reads as two separate pairs of horns with the
# sweep passing between them, not as one closed lens.

ANCHOR_EAST = ("virgo", "Zavijava")     # station where retrograde begins
ANCHOR_WEST = ("cancer", "Acubens")     # station where retrograde ends

# The loop is built as a lens on the chord between the two anchor stars: two
# arcs bowing equally to either side, meeting exactly on the stars, where the
# bow falls to zero and the path therefore comes to a genuine point.
#
# Building it this way makes the two horns mirror images BY CONSTRUCTION. That
# is an assumption about the loop, not a result -- a real apparition is only
# roughly symmetric. It is stated here so the symmetry is never mistaken for a
# finding.
STATION_EAST_PT = (173.97, 0.69)    # Zavijava
STATION_WEST_PT = (130.45, -5.08)   # Acubens
BOW_DEG = 3.6                       # half the loop's widest opening


def _lens(t: float, side: int) -> tuple[float, float]:
    """Point at fraction ``t`` along the chord, bowed to one side.

    ``side`` is -1 for the retrograde arc and +1 for the direct arc.
    """
    lam0, beta0 = STATION_WEST_PT
    lam1, beta1 = STATION_EAST_PT
    lam = lam0 + (lam1 - lam0) * t
    beta = beta0 + (beta1 - beta0) * t + side * BOW_DEG * math.sin(math.pi * t)
    return lam, beta


# Fraction of the chord over which each direct leg is drawn. Short, so the
# centre carries only the sweep and the figure reads as two pairs of horns.
_DIRECT_SPAN = 0.28

DIRECT_IN = [_lens(1.0 - _DIRECT_SPAN + _DIRECT_SPAN * i / 8.0, +1)
             for i in range(8)]
RETROGRADE = [_lens(1.0 - i / 26.0, -1) for i in range(27)]
DIRECT_OUT = [_lens(_DIRECT_SPAN * i / 8.0, +1) for i in range(1, 9)]

# Kept as short lists so the turns can be referred to by name.
STATION_EAST = [RETROGRADE[0]]
STATION_WEST = [RETROGRADE[-1]]

PATH: list[tuple[float, float]] = DIRECT_IN + RETROGRADE + DIRECT_OUT

# Index ranges, for drawing the retrograde leg and the horns emphatically.
I_RETRO_START = len(DIRECT_IN)
I_RETRO_END = I_RETRO_START + len(RETROGRADE)
I_STATION_EAST = I_RETRO_START       # Zavijava, retrograde begins
I_STATION_WEST = I_RETRO_END - 1     # Acubens, retrograde ends

# Where Mars is marked on each seat plate.
MARS_AT = {
    "virgo": I_STATION_EAST,                       # Zavijava
    "leo": I_RETRO_START + len(RETROGRADE) // 2,   # mid retrograde, over Leo
    "cancer": I_STATION_WEST,                      # Acubens
}

# Moon seats, as (ecliptic longitude of epoch, ecliptic latitude).
#
# Reading the recorded schematic  o< H >o  :  the horn cusps point outward and
# their legs open inward, and the heads sit outside the cusps. So the two
# crescents sit just beyond the horn tips, and the full Moon holds the centre.
MOON_SEAT = {
    "cancer": (120.0, -5.6),   # head outboard of Acubens, west of the Beehive
    "leo": (152.0, 7.5),       # H, the centre, in the body of Leo
    "virgo": (180.5, 1.0),     # head outboard of Zavijava, toward Porrima
}

# Moon phase carried at each seat, as recorded in the decode.
MOON_SEAT_PHASE = {
    "cancer": "waxing_crescent",
    "leo": "full",
    "virgo": "waning_crescent",
}


def resample(points: list[tuple[float, float]], per_segment: int = 9):
    """Densify a polyline so the cusps draw smoothly."""
    out: list[tuple[float, float]] = []
    for i in range(len(points) - 1):
        a, b = points[i], points[i + 1]
        for s in range(per_segment):
            f = s / per_segment
            out.append((a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f))
    out.append(points[-1])
    return out
