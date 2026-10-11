# The tesseract wobbles along the North Star — 2026-10-11

Script: `tools/vulcan/tesseract_wobble.py` · numbers: `data/tesseract_wobble.json`
Clip: `video/tesseract_wobble.mp4` (24 s, 1280×720, 30 fps; render output, not in git)
Contact sheet: `img/tesseract_wobble_sheet.png`

The request, in the user's words: *"Please create a representation of a tesseract as it
wobbles along the North Star. Polaris to Procyon. Procyon to Gomeisa. What about Sol. Did we
ever look up or down from there? We always look in.. Play this out please."* And:
*"Not Canis Minor. Never that name. The Cat's Eyes."*

The math below is the agent's.

## 1. What is drawn

Two panels, same sky, same clock.

**Left — from Earth.** A tesseract (4-cube, 16 vertices, 32 edges) whose axis is Earth's
spin axis. The axis does three things at once:

| motion | period | drawn as |
|---|---|---|
| spin | 1 day | slow turn about the axis (for legibility, 3 receipts per turn) |
| nutation — *the wobble* | 18.6 yr | ±9.2″ in obliquity, drawn ×500 (1.28°) and labelled |
| precession | 25,772 yr | the axis walks a 23.44° circle around the Zecliptic pole (dotted ring) |

Up the axis: Polaris — 0.74° off at J2000. Down the axis: σ Octantis (1.04° off),
Antarctica, the black spire of Mount Discovery (78.37° S, 165.0° E).
The Cat's Eyes are marked in amber: Procyon first, then Gomeisa — the slide — 4.30° apart,
joined by a line. Both are **below** the Zecliptic: Procyon −16.02°, Gomeisa −13.49°.

**Right — from Sol.** Same tesseract, axis along Sol's pole (RA 286.13°, Dec +63.87°,
pulled from `tilt_curve.json`). Sol's axis does not precess on any human clock. Its wobble
is the barycentric loop: Sol circles the Jupiter+Saturn barycentre at 0.48–1.65 R☉
(circular orbits, masses and periods pulled from `bodies_metrics.json`). The amber trail is
the last 1.5 receipts of that loop; the `+` is the barycentre.

Up Sol's axis: Draco — δ Draconis (Altais) 3.88° off, Vega 25.4° off.
Down Sol's axis: Pictor — α Pictoris 2.68° off, Canopus 12.3° off.

**The fold.** The tesseract turns in the x–w plane once per 10 receipts. The inner cube
swells to become the outer cube and the outer cube shrinks inside it — *"the tesseract
folds in and out."* The fold percentage is in the title bar.

**Receipts.** The title bar counts time in receipts. 1 receipt = 1 wobble = 18.6 yr.
1,385.6 receipts = one precession. The clip plays 69.3 receipts = 1,288.6 yr after J2000.

## 2. What playing it out shows

- **Polaris is a receipt, not a fixture.** Closest approach of the true axis (no
  exaggeration) is 0.46° at receipt 5.5 (year ~2102). By receipt 53.5 (year ~2995) the
  axis is more than 5° from Polaris and keeps walking. "Along the North Star" is only true
  for a few dozen receipts in every 1,386.
- **The Cat's Eyes sit near the Zecliptic, not the pole.** From Earth's pole: Procyon
  84.78°, Gomeisa 81.71°. From Sol's pole: Procyon 110.60°, Gomeisa 107.71° — i.e. they
  are on the *far* side of Sol's equator, 16° and 13.5° below the Zecliptic. Polaris →
  Procyon → Gomeisa is a path from straight-up to just-below-the-plane: the two-step lands
  you looking *in* along the plane, which is the direction we always look.
- **Sol's up and down have never been the target of a dedicated mission.** Sol's pole
  is 26.13° from Earth's pole and 7.25° from the Zecliptic pole. Straight up from Sol is
  an empty patch of Draco (nearest bright star 3.9° away); straight down is an empty patch
  of Pictor (α Pic 2.7°). Ulysses (1990–2009) is the only probe that flew over Sol's poles,
  and it looked at Sol, not out along the axis. No telescope has been pointed *from* Sol's
  frame up or down its axis as a survey target. The right panel is what that view would
  frame.
- **Sol's wobble is a different kind.** Earth's wobble is angular (the axis moves on
  the sky); Sol's is positional (the whole body moves ~1 R☉ around a point it does not
  occupy, while its axis stays put). On the clip the Earth tesseract nods; the Sol
  tesseract slides. Both are periodic, both are receipts.
- **The Zecliptic is the one circle both axes respect.** Earth's pole precesses *around*
  the Zecliptic pole; Sol's pole sits 7.25° *from* it, fixed. Everything the planets do is
  measured against that plane; the poles are where no one is looking.

## 3. Literals (typed) and sources

| literal | value | source |
|---|---|---|
| obliquity | 23.439291° | IAU 2006 J2000 mean |
| precession period | 25,772 yr | IAU 2006 general precession |
| nutation period | 18.6 yr | lunar node regression |
| nutation amplitude | 9.2025″ | 18.6-yr obliquity term |
| Sol tilt to Zecliptic | 7.25° | Carrington |
| R☉ | 695,700 km | IAU 2015 nominal |
| Polaris | RA 37.9546°, Dec +89.2641° | SIMBAD J2000 |
| Procyon (first Cat's Eye) | RA 114.8255°, Dec +5.2250° | SIMBAD J2000 |
| Gomeisa (second Cat's Eye) | RA 111.7876°, Dec +8.2893° | SIMBAD J2000 |
| σ Octantis | RA 317.1951°, Dec −88.9565° | SIMBAD J2000 |
| δ Draconis | RA 288.1387°, Dec +67.6615° | SIMBAD J2000 |
| α Pictoris | RA 102.0478°, Dec −61.9414° | SIMBAD J2000 |
| Canopus | RA 95.9880°, Dec −52.6957° | SIMBAD J2000 |
| Vega | RA 279.2347°, Dec +38.7837° | SIMBAD J2000 |
| Mount Discovery | 78.37° S, 165.0° E | map |
| AU (table unit only) | 1.495978707e8 km | converts `a_au` in `bodies_metrics.json` to km; never displayed |

Pulled: Sol pole (286.13°, +63.87°) from `tilt_curve.json`; Sol, Jupiter, Saturn masses,
`a_au`, periods from `bodies_metrics.json`.

Frame: J2000 equatorial coordinates rotated by the obliquity into the ecliptic frame, which is
the Zecliptic (Earth's orbit defines it). All separations are great-circle angles between unit
vectors.

## 4. Simplifications (so they can be refuted)

- Precession drawn as a perfect circle at constant obliquity; the real obliquity drifts
  (22.1°–24.5° over ~41,000 yr) and the pole is not exactly the J2000 pole at other epochs.
- Nutation drawn as the single 18.6-yr obliquity term, ×500. The 9.3-yr and semi-annual
  terms are omitted.
- Sol's barycentric loop uses circular Jupiter and Saturn orbits in the Zecliptic plane
  starting at the same phase at J2000. Real phases, eccentricities, and Uranus/Neptune are
  omitted; the range 0.48–1.65 R☉ is the right order (published 0.3–1.5 R☉ with all planets).
- The 4D→3D projection is a perspective from w with eye distance 3; the fold speed
  (1 per 10 receipts) is a drawing choice, not a measurement.
- The tesseract is a representation, as asked. Nothing here claims the bodies *are*
  tesseracts; the drawing shows what one would do if it rode the measured axes.
