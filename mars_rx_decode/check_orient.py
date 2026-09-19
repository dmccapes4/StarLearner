#!/usr/bin/env python3
"""Confirm plate orientation before trusting any plate.

Checks the basis against the textbook case (facing north, right hand points
east), then reports which screen side east falls on and which way ecliptic
latitude runs, for the actual scene.
"""

from __future__ import annotations

import math
import catalog
import sky
import track
import render


def main() -> None:
    # Textbook case: facing north with the zenith overhead, right is east.
    p = sky.Plate(sky.altaz_to_vec(0.0, 0.0), 100, 100, 50, 50)
    print(f"facing north: R = {tuple(round(c, 3) for c in p.R)}"
          f"   (east is (0,1,0))")
    print(f"              U = {tuple(round(c, 3) for c in p.U)}"
          f"   (zenith is (0,0,1))\n")

    lst = render.seat_lst("leo")
    vecs = render.scene_vectors(catalog.LEO_AND_NEIGHBOURS, lst)
    plate = sky.fit_plate(vecs, 3400, 1500, 1700, 776)

    print("sign centres, screen x increasing to the right:")
    for sign in ("cancer", "leo", "virgo"):
        ra_e, dec_e = render.epoch_pos(sign)
        q = plate.project_eq(ra_e, dec_e, lst)
        lam, beta = sky.eq_to_ecliptic_of_epoch(ra_e, dec_e)
        print(f"  {sign:7s} ecl lon {lam:6.1f}  x {q[0]:7.1f}  y {q[1]:7.1f}"
              f"  alt {q[2]:5.1f}")

    print("\ncardinal points:")
    for az, tag in ((90, "E"), (45, "NE"), (0, "N"), (315, "NW"), (270, "W")):
        q = plate.project_altaz(6.0, float(az))
        if q:
            print(f"  {tag:2s} (az {az:3d})  x {q[0]:7.1f}")

    print("\necliptic latitude probes at ecl lon 150 (over Leo):")
    for beta in (-5.0, 0.0, 5.0):
        ra_e, dec_e = sky.ecliptic_of_epoch_to_eq(150.0, beta)
        q = plate.project_eq(ra_e, dec_e, lst)
        print(f"  beta {beta:+5.1f}  ->  y {q[1]:7.1f}   (smaller y is higher"
              " on the plate)")

    print("\nstations against their anchor stars:")
    for label, anchor, station in (
            ("west", track.ANCHOR_WEST, track.STATION_WEST_PT),
            ("east", track.ANCHOR_EAST, track.STATION_EAST_PT)):
        ra_e, dec_e = render.epoch_pos(*anchor)
        lam, beta = sky.eq_to_ecliptic_of_epoch(ra_e, dec_e)
        off = math.hypot(lam - station[0], beta - station[1])
        print(f"  {label} station {station}  {anchor[1]:9s} "
              f"({lam:7.2f}, {beta:+5.2f})  offset {off:5.3f} deg")

    print("\nhorn openings:")
    for sign in ("cancer", "virgo"):
        gap, dist = render.horn_splay(sign)
        print(f"  {sign:7s} legs reach {gap:4.2f} deg apart, "
              f"{dist:4.0f} deg of longitude from the station")

    print("\nhorn cusp tips:")
    per = 9
    pts = render.track_eq()
    for sign, knot in track.MARS_AT.items():
        ra_e, dec_e = pts[min(knot * per, len(pts) - 1)]
        q = plate.project_eq(ra_e, dec_e, lst)
        print(f"  {sign:7s} x {q[0]:7.1f}  y {q[1]:7.1f}")


if __name__ == "__main__":
    main()
