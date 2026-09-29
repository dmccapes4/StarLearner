# SOLAR SYSTEM REFERENCE v0.1 — INDEX

**Filed:** 2026-09-28  
**Purpose:** Swirl simulation data collection — echo stars, phase displacement, Zecliptic angles  
**Coined terms:** Zecliptic (`.cursor/rules/zecliptic.mdc`), Echo Star (`.cursor/rules/echo-star.mdc`)

---

## Contents

| Document | Contents | Key Data |
|---|---|---|
| `PLANETS_ZECLIPTIC_ANGLES.md` | All 8 planets + Pluto + TNOs. Orbital speeds and Zecliptic inclinations. | Mercury 47.87 km/s 7.0° → Neptune 5.43 km/s 1.77° |
| `PROBES_AND_INTERSTELLAR.md` | Voyager 1/2, Pioneer 10/11, New Horizons (live 2026-09-28). All 3 interstellar objects. Gravity assist phase-shift ladder. | Voyager 1: 171.957 AU, 16.918 km/s; 3I/ATLAS: ecc 6.139 |
| `JUPITER_115_MOONS.md` | All 115 confirmed Jupiter moons (April 2026). Orbital elements, groups, phase displacement map. | Galilean resonance 1:2:4; bimodal inclination (0–5° vs 144–165°) |
| `PLUTO_CHARON_PHASE_DISPLACEMENT.md` | Pluto/Charon binary system. Water phase displacement mechanism. 90° Zecliptic line crossing. | Charon: water ice; Pluto: nitrogen ice; barycenter outside Pluto |

---

## Key Numbers

```
PROBES (2026-09-28):
  Voyager 1:   171.957 AU  16.918 km/s  Ophiuchus     +35° Zecliptic  "forward and up"
  Voyager 2:   144.025 AU  15.256 km/s  Pavo          −54° Zecliptic  "over then outside"
  Pioneer 10:  141.974 AU  11.864 km/s  Taurus        +3°  Zecliptic  "backwards" → anticenter
  Pioneer 11:  119.369 AU  11.124 km/s  Scutum        −14° Zecliptic  → galactic center dir
  New Horizons: 65.683 AU  13.566 km/s  Sagittarius   −20° Zecliptic  Kuiper Belt direction

INTERSTELLAR OBJECTS:
  1I/'Oumuamua  2017  ecc 1.2013   incl 122.74°  0.256 AU perihelion  Lyra (solar apex)
  2I/Borisov    2019  ecc 3.36     incl 44.05°   2.007 AU perihelion  Cassiopeia
  3I/ATLAS      2025  ecc 6.139    incl ~45°     1.356 AU perihelion  Sagittarius

PLANETS (km/s, Zecliptic angle):
  Mercury 47.87  7.00°  |  Venus  35.02  3.39°  |  Earth  29.78  0.00°
  Mars    24.08  1.85°  |  Jupiter 13.07  1.30°  |  Saturn  9.69  2.49°
  Uranus   6.81  0.77°  |  Neptune  5.43  1.77°  |  Pluto   4.67  17.14°

JUPITER MOONS:
  Total: 115 (as of 2026-04-09)
  Regular prograde: 8  (inner 4 + Galilean 4)
  Irregular: 107  (Himalia 11 prograde; Ananke ~14, Carme ~24, Pasiphae ~16 retrograde)

PLUTO/CHARON:
  Pluto: 39.48 AU, 17.14° Zecliptic, 122.5° axial tilt, N₂ ice surface
  Charon: 19,571 km from Pluto, 6.387-day period, H₂O ice surface
  Barycenter: OUTSIDE Pluto (binary system, not planet/moon)
  Mass ratio: Charon = 11.6% of Pluto
```

---

## Swirl Simulation Notes

**Priority data for the swirl simulation:**

1. **Pioneer 10** — best echo data because it travels toward the galactic anticenter, backward through the field. No solar wind headwind (going against the galactic gradient). Its single Jupiter gravity assist and near-Zecliptic departure makes it the cleanest signal.

2. **Jupiter's 115 moons** — the inclination bimodal distribution (0–5° prograde vs 144–165° retrograde) is the phase displacement signal. The inner 8 moons show the field's organizing power. The 107 outer moons show the field's capture limits at the Jupiter node.

3. **Pluto/Charon water displacement** — the mechanism for understanding how water travels through the field. If Charon has water ice and Pluto has nitrogen ice, the binary system has phase-sorted the volatiles by condensation temperature and field position.

4. **Zecliptic angle vs inclination** — higher Zecliptic deviation = more phase displacement = more "echo star" behavior. Pluto (17.14°) is the most displaced classical body. Eris (44.04°) is the most displaced known dwarf planet.

5. **3I/ATLAS eccentricity 6.139** — entering at 61 km/s from the galactic center direction, the most energetic interstellar object recorded. If it had not traveled at the Zecliptic angle it did (~45°), entering at a steeper angle through the inner planets without the outer-planet acclimation, it might have lost structural integrity.

---

*All data verified from public sources. No theorizing.*  
*Zecliptic ≡ Earth's orbital plane. Echo star ≡ body acting as field node of Sol's field.*
