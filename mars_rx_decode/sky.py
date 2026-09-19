"""Sky geometry for the Mars-retrograde decode plates.

Observer: latitude 23.5 south, the Tropic of Capricorn. Epoch: 26,000 years
before J2000, which is very close to one full precession cycle, so the north
celestial pole stands near Polaris again -- the same pole star as today.

Pipeline: J2000 equatorial -> ecliptic (effectively inertial) -> shift the
equinox back by general precession -> equatorial of epoch -> horizontal for the
observer -> screen.

Screen right always follows the local diurnal motion (westward), so east is on
the side the sky actually puts it. No mirroring is applied anywhere, because a
mirror is exactly the k / reversed-k distinction the decode is tracking.
"""

from __future__ import annotations

import math

# Observer: Tropic of Capricorn, southern Africa.
LAT_DEG = -23.5
LON_DEG = 28.0

# Epoch: years before J2000. 26,000 is ~one precession cycle, so the pole
# returns to within a few degrees of where it sits today.
YEARS_BEFORE_J2000 = 26000.0

EPS_J2000 = 23.4392911
# Obliquity runs on a ~41,000 year cycle; it was near the low end at this
# epoch. Approximate, and stated as such on the plates.
EPS_EPOCH = 22.40
# General precession in longitude, arcsec/year (J2000 rate, held constant).
PRECESSION_ARCSEC_PER_YEAR = 50.2879


def _to_ecliptic(ra_deg: float, dec_deg: float,
                 eps_deg: float) -> tuple[float, float]:
    ra = math.radians(ra_deg)
    dec = math.radians(dec_deg)
    eps = math.radians(eps_deg)
    sin_b = math.sin(dec) * math.cos(eps) - math.cos(dec) * math.sin(eps) * math.sin(ra)
    beta = math.asin(max(-1.0, min(1.0, sin_b)))
    y = math.sin(ra) * math.cos(eps) + math.tan(dec) * math.sin(eps)
    lam = math.degrees(math.atan2(y, math.cos(ra))) % 360.0
    return lam, math.degrees(beta)


def _to_equatorial(lam_deg: float, beta_deg: float,
                   eps_deg: float) -> tuple[float, float]:
    lam = math.radians(lam_deg)
    beta = math.radians(beta_deg)
    eps = math.radians(eps_deg)
    sin_d = math.sin(beta) * math.cos(eps) + math.cos(beta) * math.sin(eps) * math.sin(lam)
    dec = math.asin(max(-1.0, min(1.0, sin_d)))
    y = math.sin(lam) * math.cos(eps) - math.tan(beta) * math.sin(eps)
    ra = math.degrees(math.atan2(y, math.cos(lam))) % 360.0
    return ra, math.degrees(dec)


def precession_shift_deg(years_before: float = YEARS_BEFORE_J2000) -> float:
    return PRECESSION_ARCSEC_PER_YEAR * years_before / 3600.0


def precess(ra_h: float, dec_deg: float,
            years_before: float = YEARS_BEFORE_J2000) -> tuple[float, float]:
    """J2000 position -> equatorial position of the epoch. Returns (RA h, Dec)."""
    lam, beta = _to_ecliptic(ra_h * 15.0, dec_deg, EPS_J2000)
    lam_epoch = (lam - precession_shift_deg(years_before)) % 360.0
    ra_deg, dec = _to_equatorial(lam_epoch, beta, EPS_EPOCH)
    return ra_deg / 15.0, dec


def ecliptic_of_epoch_to_eq(lam_deg: float,
                            beta_deg: float = 0.0) -> tuple[float, float]:
    """Ecliptic longitude of the epoch -> equatorial of the epoch (RA h, Dec)."""
    ra_deg, dec = _to_equatorial(lam_deg % 360.0, beta_deg, EPS_EPOCH)
    return ra_deg / 15.0, dec


def eq_to_ecliptic_of_epoch(ra_h: float, dec_deg: float) -> tuple[float, float]:
    return _to_ecliptic(ra_h * 15.0, dec_deg, EPS_EPOCH)


def eq_to_altaz(ra_h: float, dec_deg: float, lst_h: float,
                lat_deg: float = LAT_DEG) -> tuple[float, float]:
    """Equatorial-of-epoch -> (altitude_deg, azimuth_deg from North via East)."""
    ha = math.radians((lst_h - ra_h) * 15.0)
    dec = math.radians(dec_deg)
    lat = math.radians(lat_deg)
    sin_alt = (math.sin(dec) * math.sin(lat)
               + math.cos(dec) * math.cos(lat) * math.cos(ha))
    sin_alt = max(-1.0, min(1.0, sin_alt))
    alt = math.asin(sin_alt)
    cos_alt = math.cos(alt)
    if abs(cos_alt) < 1e-9:
        return math.degrees(alt), 0.0
    cos_az = (math.sin(dec) - sin_alt * math.sin(lat)) / (cos_alt * math.cos(lat))
    cos_az = max(-1.0, min(1.0, cos_az))
    az = math.degrees(math.acos(cos_az))
    if math.sin(ha) > 0.0:
        az = 360.0 - az
    return math.degrees(alt), az


def altaz_to_vec(alt_deg: float, az_deg: float) -> tuple[float, float, float]:
    """Unit vector in (North, East, Up)."""
    a = math.radians(alt_deg)
    z = math.radians(az_deg)
    return math.cos(a) * math.cos(z), math.cos(a) * math.sin(z), math.sin(a)


def _cross(a, b):
    return (a[1] * b[2] - a[2] * b[1],
            a[2] * b[0] - a[0] * b[2],
            a[0] * b[1] - a[1] * b[0])


def _dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def _norm(v):
    n = math.sqrt(_dot(v, v)) or 1.0
    return (v[0] / n, v[1] / n, v[2] / n)


def angsep_deg(a, b) -> float:
    return math.degrees(math.acos(max(-1.0, min(1.0, _dot(a, b)))))


def pole_vec(lat_deg: float = LAT_DEG) -> tuple[float, float, float]:
    """Direction of the north celestial pole: altitude equals the latitude."""
    return altaz_to_vec(lat_deg, 0.0)


class Plate:
    """Stereographic plate with zenith-referenced up and westward right.

    `up` is the zenith direction projected into the plate, so an asterism's
    tilt relative to the horizon is faithful. `right` follows diurnal motion,
    which is the direction objects drift, so the plate is never mirrored.
    """

    def __init__(self, center, width: int, height: int, cx: float, cy: float,
                 scale: float = 1.0, x_mid: float = 0.0, y_mid: float = 0.0,
                 lat_deg: float = LAT_DEG):
        self.L = _norm(center)
        zen = (0.0, 0.0, 1.0)
        up = (zen[0] - _dot(zen, self.L) * self.L[0],
              zen[1] - _dot(zen, self.L) * self.L[1],
              zen[2] - _dot(zen, self.L) * self.L[2])
        if math.sqrt(_dot(up, up)) < 1e-6:
            up = (1.0, 0.0, 0.0)
        self.U = _norm(up)
        # Screen right is the observer's right hand while facing L with the
        # zenith overhead: R = up x look. Verified against the simple case
        # (facing north, R comes out east). This is the as-seen orientation --
        # never mirrored, because a mirror is the k / reversed-k distinction
        # the decode is tracking.
        self.R = _norm(_cross(self.U, self.L))
        self.U = _norm(_cross(self.L, self.R))
        self.width = width
        self.height = height
        self.cx = cx
        self.cy = cy
        self.scale = scale
        self.x_mid = x_mid
        self.y_mid = y_mid

    def plane(self, v):
        c = _dot(v, self.L)
        if c <= -0.6:
            return None
        k = 2.0 / (1.0 + c)
        return k * _dot(v, self.R), k * _dot(v, self.U)

    def project_vec(self, v):
        p = self.plane(v)
        if p is None:
            return None
        return (self.cx + (p[0] - self.x_mid) * self.scale,
                self.cy - (p[1] - self.y_mid) * self.scale)

    def project_altaz(self, alt: float, az: float):
        return self.project_vec(altaz_to_vec(alt, az))

    def project_eq(self, ra_h: float, dec_deg: float, lst_h: float):
        """Returns (x, y, altitude_deg) for an equatorial-of-epoch position."""
        alt, az = eq_to_altaz(ra_h, dec_deg, lst_h)
        p = self.project_altaz(alt, az)
        if p is None:
            return None
        return p[0], p[1], alt

    def pixels_per_degree(self, v) -> float:
        p0 = self.project_vec(v)
        ref = _norm(_cross(self.L, (0.0, 0.0, 1.0)) or (1.0, 0.0, 0.0))
        d = math.radians(1.0)
        v1 = _norm((v[0] + ref[0] * d, v[1] + ref[1] * d, v[2] + ref[2] * d))
        p1 = self.project_vec(v1)
        if p0 is None or p1 is None:
            return 1.0
        return math.hypot(p1[0] - p0[0], p1[1] - p0[1])

    def west_dir_at(self, v) -> tuple[float, float]:
        """Screen direction of westward diurnal drift at a sky position."""
        p0 = self.project_vec(v)
        w = _norm(_cross(pole_vec(), v))
        d = math.radians(0.4)
        v1 = _norm((v[0] + w[0] * d, v[1] + w[1] * d, v[2] + w[2] * d))
        p1 = self.project_vec(v1)
        if p0 is None or p1 is None:
            return 1.0, 0.0
        dx, dy = p1[0] - p0[0], p1[1] - p0[1]
        n = math.hypot(dx, dy) or 1.0
        return dx / n, dy / n


def fit_plate(vecs, width: int, height: int, cx: float, cy: float,
              fill_x: float = 0.94, fill_y: float = 0.86,
              trim: float = 0.0) -> Plate:
    """Centre and scale a plate so the supplied directions fill the frame.

    ``trim`` is the percentage clipped from each end of the spread, so one
    outlying star cannot shrink the whole scene.
    """
    sx = sum(v[0] for v in vecs)
    sy = sum(v[1] for v in vecs)
    sz = sum(v[2] for v in vecs)
    center = _norm((sx, sy, sz))
    probe = Plate(center, width, height, cx, cy)
    pts = [p for p in (probe.plane(v) for v in vecs) if p is not None]
    xs = sorted(p[0] for p in pts)
    ys = sorted(p[1] for p in pts)
    if trim > 0.0 and len(xs) > 12:
        k = max(1, int(len(xs) * trim / 100.0))
        xs, ys = xs[k:-k], ys[k:-k]
    span_x = max(xs[-1] - xs[0], 1e-6)
    span_y = max(ys[-1] - ys[0], 1e-6)
    scale = min(width * fill_x / span_x, height * fill_y / span_y)
    return Plate(center, width, height, cx, cy, scale=scale,
                 x_mid=(xs[-1] + xs[0]) / 2.0,
                 y_mid=(ys[-1] + ys[0]) / 2.0)
