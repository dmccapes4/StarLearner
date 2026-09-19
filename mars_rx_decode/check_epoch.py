#!/usr/bin/env python3
"""Sanity checks for the epoch and observer before any plate is drawn.

Confirms the pole star, the precession shift, the declinations of the three
signs, and which screen side east falls on for this latitude.
"""

from __future__ import annotations

import math

import sky

POLARIS = ("Polaris", 2.53030, 89.26411)
VEGA = ("Vega", 18.61565, 38.78369)

SIGN_CENTERS_J2000 = {
    "Cancer": (8.607, 18.20),
    "Leo": (10.60, 16.50),
    "Virgo": (13.20, -3.50),
}


def pole_distance(name: str, ra_h: float, dec: float) -> float:
    ra_e, dec_e = sky.precess(ra_h, dec)
    return 90.0 - dec_e


def main() -> None:
    shift = sky.precession_shift_deg()
    print(f"epoch: {sky.YEARS_BEFORE_J2000:.0f} yr before J2000")
    print(f"precession shift in ecliptic longitude: {shift:.1f} deg "
          f"({shift % 360.0:.1f} deg net after full turns)")
    print(f"obliquity used: {sky.EPS_EPOCH:.2f} deg  (J2000 {sky.EPS_J2000:.2f})")
    print(f"observer latitude: {sky.LAT_DEG:+.1f} deg\n")

    for name, ra, dec in (POLARIS, VEGA):
        print(f"{name:8s} -> pole distance at epoch {pole_distance(name, ra, dec):6.2f} deg"
              f"   (today {90.0 - dec:6.2f} deg)")
    print()

    for name, (ra, dec) in SIGN_CENTERS_J2000.items():
        ra_e, dec_e = sky.precess(ra, dec)
        culm = 90.0 - abs(sky.LAT_DEG - dec_e)
        side = "north of zenith" if dec_e > sky.LAT_DEG else "south of zenith"
        print(f"{name:7s} J2000 dec {dec:+6.1f} -> epoch dec {dec_e:+6.1f}  "
              f"RA {ra_e:5.2f} h  culminates {culm:5.1f} deg, {side}")
    print()

    # Which way is west on the plate for a sign culminating north of zenith?
    ra_e, dec_e = sky.precess(*SIGN_CENTERS_J2000["Leo"])
    for ha in (-0.5, 0.0, 0.5):
        alt, az = sky.eq_to_altaz(ra_e, dec_e, ra_e + ha)
        print(f"Leo at hour angle {ha:+.1f} h: alt {alt:5.1f}  az {az:6.1f}")
    print("\nazimuth decreasing as time advances => westward drift is toward"
          "\ndecreasing azimuth, so facing north EAST FALLS ON THE RIGHT.")


if __name__ == "__main__":
    main()
