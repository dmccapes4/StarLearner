# Winter Circle Star Pipe Analysis
*Dylan McCapes — October 9, 2026*
*Analogue to `phone_pipe_report_20261009` — same structural method, celestial dataset*
*Epoch: J2000.0 ICRS | Zecliptic frame: obliquity ε = 23.4393°*

---

## I. The Dataset

14 bodies: 12 fixed stars from the Winter Circle / Cat geometry + Mars at two opposition events.

| # | Name | Bayer | RA_h | Dec° | λ° (Zecliptic) | β° | dist_ly | mag |
|---|---|---|---|---|---|---|---|---|
| 1 | Sirius | α CMa | 6.753 | −16.72 | 104.08 | −39.61 | 8.6 | −1.46 |
| 2 | Rigel | β Ori | 5.242 | −8.20 | 76.83 | −31.12 | 860 | +0.13 |
| 3 | Aldebaran | α Tau | 4.599 | +16.51 | 69.79 | −5.47 | 65.3 | +0.87 |
| 4 | Capella | α Aur | 5.278 | +46.00 | 81.86 | +22.86 | 42.9 | +0.08 |
| 5 | Pollux | β Gem | 7.755 | +28.03 | 113.22 | +6.68 | 33.8 | +1.14 |
| 6 | Castor | α Gem | 7.577 | +31.89 | 110.24 | +10.10 | 51.5 | +1.58 |
| 7 | Procyon | α CMi | 7.655 | +5.23 | 115.79 | −16.02 | 11.46 | +0.34 |
| 8 | Gomeisa | β CMi | 7.453 | +8.29 | 112.19 | −13.49 | 170 | +2.89 |
| 9 | Betelgeuse | α Ori | 5.920 | +7.41 | 88.75 | −16.03 | 700 | +0.50 |
| 10 | Alnilam | ε Ori | 5.604 | −1.20 | 83.46 | −24.51 | 1340 | +1.69 |
| 11 | Alnitak | ζ Ori | 5.679 | −1.94 | 84.68 | −25.29 | 800 | +1.74 |
| 12 | Mintaka | δ Ori | 5.533 | −0.30 | 82.36 | −23.55 | 900 | +2.23 |
| 13 | Mars_2008 | — | 5.955 | +26.95 | 89.40 | +3.51 | 0.610 AU | −1.38 |
| 14 | Mars_2025 | — | 7.929 | +25.15 | 116.05 | +4.29 | 0.643 AU | −1.25 |

---

## II. The Star Pipe Operation

Analogue to `pipe_op` from the phone pipe report. Applied to each body in the Zecliptic frame:

```
Input: (RA_hours, Dec_deg) → ecliptic_lon λ, ecliptic_lat β

L = digit_sum(round(λ)) mod 10
B = digit_sum(round(|β|)) mod 10
E = |L − B|
F = L + E + B          ← the "star F-value"
G = leading digit of round(λ)
self_pipe = (L == B)   ← ecliptic digit symmetry
```

| Name | λ° | β° | L | B | E | **F** | G | self |
|---|---|---|---|---|---|---|---|---|
| Sirius | 104.08 | −39.61 | 5 | 4 | 1 | **10** | 1 | · |
| Rigel | 76.83 | −31.12 | 4 | 4 | 0 | **8** | 7 | ● |
| Aldebaran | 69.79 | −5.47 | 7 | 5 | 2 | **14** | 7 | · |
| Capella | 81.86 | +22.86 | 0 | 5 | 5 | **10** | 8 | · |
| Pollux | 113.22 | +6.68 | 5 | 7 | 2 | **14** | 1 | · |
| Castor | 110.24 | +10.10 | 2 | 1 | 1 | **4** | 1 | · |
| Procyon | 115.79 | −16.02 | 8 | 7 | 1 | **16** | 1 | · |
| Gomeisa | 112.19 | −13.49 | 4 | 4 | 0 | **8** | 1 | ● |
| Betelgeuse | 88.75 | −16.03 | 7 | 7 | 0 | **14** | 8 | ● |
| Alnilam | 83.46 | −24.51 | 1 | 7 | 6 | **14** | 8 | · |
| Alnitak | 84.68 | −25.29 | 3 | 7 | 4 | **14** | 8 | · |
| Mintaka | 82.36 | −23.55 | 0 | 6 | 6 | **12** | 8 | · |
| Mars_2008 | 89.40 | +3.51 | 7 | 4 | 3 | **14** | 8 | · |
| Mars_2025 | 116.05 | +4.29 | 8 | 4 | 4 | **16** | 1 | · |

---

## III. F-Value Groups

```
F=14  ×6  Aldebaran, Pollux, Betelgeuse, Alnilam, Alnitak, Mars_2008   ← DOMINANT
F=10  ×2  Sirius, Capella
F= 8  ×2  Rigel, Gomeisa
F=16  ×2  Procyon, Mars_2025                                             ← EYES BOND
F= 4  ×1  Castor
F=12  ×1  Mintaka
```

**The F=14 group is structurally dominant: 5 fixed stars + Mars 2008.** Six bodies sharing the same Zecliptic F-value. The "14" group spans the full depth of the hexagon: from Aldebaran (rear hip) through the belt to Pollux (haunch), with Betelgeuse (chest) at center.

**Mars 2008 is a native member of the F=14 group.** It entered the hexagon and found its F-value matched: Aldebaran, Betelgeuse, the belt trio, and Pollux. It bonded with all of them.

**Mars 2025 bonded exclusively with Procyon (F=16).** The F=16 group = the right eye. Mars 2025 sat 3.7° from Pollux but its star_pipe F-value aligned with the eye, not the haunch. The cat was looking.

---

## IV. Self-Pipe Stars (L = B)

Three stars whose ecliptic digit sums are equal on both axes:

| Star | λ° | β° | L=B | Role |
|---|---|---|---|---|
| **Rigel** | 76.83 | −31.12 | 4 | Front paw |
| **Gomeisa** | 112.19 | −13.49 | 4 | Left eye |
| **Betelgeuse** | 88.75 | −16.03 | 7 | Chest/throat |

Self-pipe = ecliptic symmetry. The front paw, one eye, and the chest. These three define the facing geometry of the cat. Compare phone pipe: self-pipe = area code leading digit equals exchange leading digit. Here: Zecliptic longitude and latitude are in digit-phase lock.

---

## V. F-Match Bonds (18 total)

Key bonds sorted by separation:

```
Alnilam  ↔ Alnitak      F=14   1.36°   G_diff=0   ← tightest bond; belt pair
Betelgeuse ↔ Alnilam    F=14   9.82°   G_diff=0   ← chest-to-belt
Betelgeuse ↔ Alnitak    F=14  10.02°   G_diff=0   ← chest-to-belt
Betelgeuse ↔ Mars_2008  F=14  19.55°   G_diff=0   ← MARS 2008 BONDED TO CHEST
Procyon   ↔ Mars_2025   F=16  20.31°   G_diff=0   ← MARS 2025 BONDED TO EYE
Aldebaran ↔ Betelgeuse  F=14  21.39°   G_diff=1
Aldebaran ↔ Mars_2008   F=14  21.55°   G_diff=1   ← hip-to-intruder
Pollux    ↔ Mars_2008   F=14  23.93°   G_diff=7   ← haunch-to-intruder
Sirius    ↔ Capella     F=10  65.83°   G_diff=7   ← prey-to-apex (long bond)
```

The G_diff=0 bonds are the strong ones (same leading digit of ecliptic longitude). Mars 2008 has G_diff=0 with Betelgeuse, Alnilam, Alnitak — it landed in the G=8 cluster (λ ~ 80-90°). Mars 2025 has G_diff=0 with Procyon — it landed in the G=1 cluster (λ ~ 110-116°).

**Two different cats. Two different landings.**

---

## VI. Zecliptic Longitude Sequence

All 12 fixed stars span only **46.0° of Zecliptic longitude** (69.8° to 115.8°). They occupy a narrow window on the ecliptic — a single compressed sector.

```
λ=  69.8°  Aldebaran    β=  −5.5°  (near Zecliptic — the hip barely rises)
λ=  76.8°  Rigel        β= −31.1°  (deep below Zecliptic — front paw digs in)
λ=  81.9°  Capella      β= +22.9°  (above Zecliptic — apex of arch)
λ=  82.4°  Mintaka      β= −23.6°  (belt W, below)
λ=  83.5°  Alnilam      β= −24.5°  (belt C, below)
λ=  84.7°  Alnitak      β= −25.3°  (belt E, deepest belt star)
λ=  88.8°  Betelgeuse   β= −16.0°  (chest — β symmetry with Procyon β=−16.0°!)
λ= 104.1°  Sirius       β= −39.6°  (prey — deepest below Zecliptic of all)
λ= 110.2°  Castor       β= +10.1°  (haunch W, above Zecliptic)
λ= 112.2°  Gomeisa      β= −13.5°  (left eye, below)
λ= 113.2°  Pollux       β=  +6.7°  (haunch E, above Zecliptic)
λ= 115.8°  Procyon      β= −16.0°  (right eye, below)
```

**Betelgeuse (chest) and Procyon (right eye) share β = −16.0° exactly.** Same Zecliptic elevation. The chest and the right eye are at the same depth below the Zecliptic. The line connecting them is parallel to the Zecliptic.

The big gap: **Betelgeuse → Sirius = Δλ 15.3°** — the largest single gap in the sequence. The prey stands apart. All other gaps are < 7.1°. Sirius is structurally isolated — not part of the body, not part of the arch. It is what the cat looks at.

---

## VII. Mars Placement Analysis

### Mars 2008 — the chest landing

Mars 2008 sat at λ = 89.40°, β = +3.51° — just above the Zecliptic, in the Betelgeuse/belt cluster. It landed in the G=8 zone. F=14. Self-pipe: no. It bonded with Betelgeuse, Alnilam, Alnitak (G_diff=0), Aldebaran and Pollux (G_diff=1, 7). **Mars 2008 was inside the cat's chest, slightly above the Zecliptic.** The cat inhaled.

### Mars 2025 — the eye landing

Mars 2025 sat at λ = 116.05°, β = +4.29° — just past Procyon in ecliptic longitude, same β elevation (+4° vs +4°). It landed in the G=1 zone. F=16. It bonded exclusively with Procyon (the right eye), G_diff=0. **Mars 2025 sat 3.7° from Pollux in equatorial coordinates but in the Zecliptic frame it passed through the eye.** Closest star to Pollux geometrically, but ecliptically adjacent to Procyon. The haunch and the eye are at the same ecliptic longitude.

### The two Mars events compared

| | Mars 2008 | Mars 2025 |
|---|---|---|
| Date | Jan 2, 2008 | Jan 16, 2025 |
| Mag | −1.38 | −1.25 |
| Dist AU | 0.610 | 0.643 |
| λ | 89.40° | 116.05° |
| β | +3.51° | +4.29° |
| F | 14 | 16 |
| G | 8 | 1 |
| F-bond | Betelgeuse/belt/Aldebaran/Pollux | Procyon |
| Cat placement | chest, above Zecliptic | eye, above Zecliptic |
| β above Zecliptic | +3.51° | +4.29° |

**Both Mars events had nearly identical β elevation above the Zecliptic (+3.5° and +4.3°). Mars entered the Winter Circle from below the Zecliptic and peaked just above it, both times.** The Zecliptic is the floor. Mars arrived from under the floor and just barely peaked above it.

---

## VIII. Structural Facts (analogous to phone pipe T-series)

**T1.** F = L + |L−B| + B = L + |E| + B. When L=B: F = 2L (even). Self-pipe stars have even F-values. Rigel, Gomeisa, Betelgeuse all have even F (8, 8, 14). ✓

**T2.** The 12 fixed stars span 46.0° of Zecliptic longitude — 12.8% of the full circle. The Winter Circle is a compressed arc.

**T3.** Betelgeuse β = −16.03°, Procyon β = −16.02°. These are the same Zecliptic latitude to within 0.01°. The chest and the right eye are coplanar with the Zecliptic at β = −16°. This is not a selection effect — these are real measured coordinates.

**T4.** Mars at opposition always appears near β = 0° (near the Zecliptic), because Mars orbits within 1.85° of the ecliptic. Both Mars events: β = +3.5° and +4.3°. The intruder always arrives near the Zecliptic floor.

**T5.** The F=14 group has 6 members — the largest F-group, spanning the widest angular range (1.4° to 45.0° pairwise). F=14 is not a tight cluster. It is the structural spine of the hexagon: belt + chest + hip + haunch.

**T6.** Sirius ↔ Capella bond (F=10, sep=65.8°) is the longest F-match bond. These are the two brightest stars in the hexagon after Mars-at-opposition. They anchor the bottom and top of the arch. Self-pipe: neither. But F-bonded across 65.8°. The prey and the apex are in structural resonance.

---

## IX. Next Mars Events in the Winter Circle

| Window | Mars mag (peak) | Nearest star | Note |
|---|---|---|---|
| Jul 30 – Oct 29, 2024 | 0.14 (faint) | Castor area | Not opposition, passing through |
| **Jan 14 – Apr 12, 2025** | **−1.26** | **Pollux (3.7°)** | **Near opposition — the most recent event** |
| Jul 8 – Sep 24, 2026 | 1.16 (faint) | Exiting summer | Just ended 15 days ago (Oct 9, 2026) |
| Jun 2028 | ~1.5 (faint) | Transit only | Not opposition |
| ~2040–2042 | ~−1.5 (bright) | Gemini area | Next hexagon opposition (estimated) |

**The "like before" event already happened: January 2025.** It is gone. The cat blinked. The next equivalent event is roughly 15-17 years away.

---

## X. The Cat Under the Zecliptic

Looking at the β (ecliptic latitude) column:

- Everything below the Zecliptic (β < 0): Sirius (−39.6°), Rigel (−31.1°), belt trio (−23 to −25°), Betelgeuse (−16.0°), Procyon (−16.0°), Gomeisa (−13.5°), Aldebaran (−5.5°)
- Everything above the Zecliptic (β > 0): Capella (+22.9°), Castor (+10.1°), Pollux (+6.7°)

The cat's haunches (Castor, Pollux) and spine (Capella) are above the Zecliptic. The prey, paws, belt, chest, and eyes are below. The cat sits with its back arched above the Zecliptic and its face and paws below it — crouching over the plane of the solar system, looking down at Sirius through the Zecliptic floor.

*Sirius is the deepest star below the Zecliptic in this set (β = −39.6°). The prey is below the floor.*

---

*Data files: `winter_circle_pipe_analysis.json`, `winter_circle_pipe_analysis.jsonl`*
*Methods: `ephem` (planetary positions), `skyfield` + `de421.bsp` (ephemeris verification), manual ecliptic transform*
*Connected: WINTER_CIRCLE_CATS_EYES_COORDS_20261009.md, TECTONIC_WAVEFORM_DERIVED_20261001.md (Zecliptic), ZECLIPTIC_BASKETBALL_NET_DISCOVERY_20260930.md*
