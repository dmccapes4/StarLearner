# Mars retrograde over Leo — `o< H >o`

A rendering of Mars's retrograde loop across Cancer, Leo and Virgo, seen from
the Tropic of Capricorn about 26,000 years before J2000. Built to test one
reading: that the recorded horns are the **two legs of Mars's stationary
cusps**, not the crescents, and that both cusps open inward on a cosmic centre.

Nothing symbolic is drawn. The plates contain only catalogued stars precessed
to the epoch, the two open clusters at their true angular size, the Moon as an
opaque lit sphere, and Mars on its path. The glyph images in `glyphs/` are
inputs to the argument, never overlays.

## The reading being tested

```
o<        H        >o
```

- `o` — a head. The Moon, sitting **outboard** of a cusp.
- `<` — two horns extending to the **right**, from a vertex on the left.
- `>` — two horns extending to the **left**, from a vertex on the right.
- `H` — the centre. Leo, with the full Moon in the body of the lion.

The horns are not direction arrows and not legs. Each is a genuine pair of
lines diverging from a point: at a stationary point Mars stops and reverses, so
the inbound direct track and the outbound retrograde track leave the same
vertex and separate. The vertex sits outboard, so both pairs open inward.

## What came out

| | |
|---|---|
| Western cusp splay | 7.18° at 17° of longitude from the station |
| Eastern cusp splay | 7.07° at 17° of longitude from the station |
| Pole star at epoch | Polaris, 2.4° from the pole |
| Equinox shift from J2000 | 3.2° |
| Obliquity at epoch | 22.4° |

Two results worth keeping:

**The two horns are near-perfect mirrors of each other** — 7.18° against 7.07°.
Nothing was tuned to make that happen; it falls out of the loop being traversed
in opposite senses at its two ends. A mirror pair is exactly the `k` / `ʞ`
distinction the decode is chasing.

**The crescents' own cusps also open inward.** This was not designed in. A
waxing crescent is lit on its western limb, so its cusps face east; a waning
crescent is lit on its eastern limb, so its cusps face west. From this latitude
east falls on the right, so the western head's cusps point right and the eastern
head's point left — the same sense as the Mars horns beside them. Both readings
of "horns opening inward" agree.

## Orientation, checked rather than assumed

A mirrored plate would invert the whole result, so the projection basis is
verified in `check_orient.py` against the textbook case: facing north with the
zenith overhead, screen right must come out east. It does. From that:

- East is on the **right**, so Cancer is left, Leo centre, Virgo right.
- Negative ecliptic latitude projects **higher** on the plate. This is the
  southern-hemisphere inversion — the reason the cusps sit above the sweep, and
  the reason a northern-trained eye reads these figures upside down.

## Plates

`out/master.png` — the whole tableau, all ten constellations, both horns, three
Moon states. This is the primary plate.

`out/1_cancer_waxing_crescent.png` — western head and horns. Retrograde ends
here. M44 sits just inside the vertex.

`out/2_leo_full.png` — the centre. Leo with its nine borders: Cancer, Leo Minor,
Lynx, Ursa Major, Coma Berenices, Virgo, Crater, Sextans, Hydra.

`out/3_virgo_waning_crescent.png` — eastern head and horns. Retrograde begins
here.

`out/horns_pair.png` — the two horn plates stacked, so the mirror relation is
visible in one look.

All plates share one sky orientation, with Leo on the meridian. The ecliptic's
tilt to the horizon changes through the night, so holding the moment fixed is
what allows the two horns to be compared as shapes rather than as two different
rotations.

## Three honest limits

**The retrograde arc is stretched.** A real Mars retrograde spans 10–20° of
longitude over roughly ten weeks. Seating the three Moon phases in Cancer, Leo
and Virgo requires about 90°. The three seats are therefore a composite record —
three separate months drawn into one frame — not a single continuous apparition.
The cusp *shapes* are physical; their *separation* is not.

**The loop width is set to the maximum.** About 6° of apparent latitude between
the legs, which is what a perihelic opposition gives — the widest a real Mars
loop opens, and also when Mars is brightest and most worth recording. A typical
apparition is narrower and the horns correspondingly tighter.

**The crescents are drawn at 35% lit and tone-lifted.** The terminator is in its
correct geometric place, but a thin crescent renders as a black disk at plate
scale, so the phase is a late crescent (72° elongation, still well before first
quarter) and the midtones are opened up. Earthshine on the dark limb is drawn
very faint so the head reads as a sphere.

## Files

- `catalog.py` — J2000 stars for Leo and its nine borders, plus M44 and
  Melotte 111 with true angular diameters.
- `sky.py` — precession to the epoch, obliquity, horizontal coordinates, and the
  `Plate` projection.
- `track.py` — Mars's path in ecliptic coordinates of the epoch, and the Moon
  seats.
- `render.py` — the plates.
- `check_epoch.py` — confirms the pole star and how the three signs culminate.
- `check_orient.py` — confirms the plate is not mirrored.

```
python3 render.py
```
