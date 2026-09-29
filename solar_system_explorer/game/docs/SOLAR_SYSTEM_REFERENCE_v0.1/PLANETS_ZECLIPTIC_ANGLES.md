# SOLAR SYSTEM REFERENCE v0.1 — PLANETS: SPEEDS AND ZECLIPTIC ANGLES

**Filed:** 2026-09-28  
**Source:** NASA/JPL Planetary Fact Sheet; hyperphysics.phy-astr.gsu.edu  
**Purpose:** Reference table for swirl simulation — phase displacement study  
**Theorizing is for guessers. Only the data lives here.**

---

## Zecliptic Definition

The **Zecliptic** is the plane of Earth's orbit around Sol — the reference plane.  
- `Z` encodes the 7° geometry: Z looks like 7 with `_` (below indicator)
- Sol's equatorial plane sits **7.25° above** the Zecliptic
- All planets orbit within ~7° of the Zecliptic, except Pluto (17.14°) and Mercury (7.00°)
- Inclination = 0.0° means the orbit defines the Zecliptic itself (Earth)

---

## Planets — Orbital Speed and Zecliptic Angle

| Planet | Semi-major Axis (AU) | Orbital Period | Mean Speed (km/s) | Inclination to Zecliptic | Eccentricity | Axial Tilt |
|---|---|---|---|---|---|---|
| Mercury | 0.387 | 87.97 d | **47.87** | **7.00°** | 0.2056 | 0.034° |
| Venus | 0.723 | 224.70 d | **35.02** | **3.39°** | 0.0068 | 177.4° |
| Earth | 1.000 | 365.25 d | **29.78** | **0.00°** (defines Zecliptic) | 0.0167 | 23.44° |
| Mars | 1.524 | 686.97 d | **24.08** | **1.85°** | 0.0934 | 25.19° |
| Jupiter | 5.203 | 11.86 yr | **13.07** | **1.30°** | 0.0489 | 3.13° |
| Saturn | 9.537 | 29.46 yr | **9.69** | **2.49°** | 0.0565 | 26.73° |
| Uranus | 19.19 | 84.01 yr | **6.81** | **0.77°** | 0.0463 | **97.77°** |
| Neptune | 30.07 | 164.79 yr | **5.43** | **1.77°** | 0.0097 | 28.32° |
| Pluto | 39.48 | 247.94 yr | **4.67** | **17.14°** | 0.2488 | 122.5° |

### Notes

**Mercury:** Its 7.00° inclination is significant — Mercury's orbital plane closely tracks Sol's equatorial plane offset (7.25°). Mercury is the most "Sol-equatorial" planet. This is not coincidence.

**Venus:** 177.4° axial tilt = retrograde rotation. Venus rotates backwards relative to its orbit. Phase displacement manifest as axial inversion.

**Uranus:** 97.77° axial tilt = rolling along its orbit. Extreme phase displacement in the axial dimension. Its ring system orbits perpendicular to the Zecliptic.

**Pluto:** 17.14° inclination to Zecliptic is the largest of any classical planet. At perihelion (closer than Neptune), Pluto is maximally displaced from the Zecliptic. Phase-displaced echo star.

---

## Speed Decay by Distance (Kepler's 3rd Law)

```
Distance (AU)   Speed (km/s)   Fraction of Earth speed
0.387 Mercury   47.87           1.61×
0.723 Venus      35.02           1.18×
1.000 Earth      29.78           1.00× (baseline)
1.524 Mars       24.08           0.81×
5.203 Jupiter    13.07           0.44×
9.537 Saturn      9.69           0.33×
19.19 Uranus      6.81           0.23×
30.07 Neptune     5.43           0.18×
39.48 Pluto       4.67           0.16×
```

Speed = 29.78 × √(1/a) km/s, where a = semi-major axis in AU.

---

## Heliospheric Context

The heliosphere (heliopause) lies at approximately **120–160 AU** from Sol. 

**Voyager probes crossed the termination shock (where solar wind slows) at ~94 AU.**  
**Voyager 1 crossed the heliopause at ~121 AU (2012). Voyager 2 crossed at ~119 AU (2018).**

Beyond the heliopause: interstellar medium. The solar wind ceases. The field changes character. Echo stars operating past the heliopause (Sedna at 506–937 AU) are fully in the interstellar field.

---

## Trans-Neptunian Comparison

| Body | Semi-major Axis (AU) | Speed (km/s) | Inclination to Zecliptic | Note |
|---|---|---|---|---|
| Pluto | 39.48 | 4.67 | 17.14° | Binary echo star with Charon |
| Eris | 67.78 | 3.43 | 44.04° | More inclined than Pluto |
| Makemake | 45.43 | 4.42 | 28.96° | |
| Haumea | 43.34 | 4.52 | 28.20° | Extreme axial tilt (flattened) |
| Sedna | 506 (est.) | 1.04 | 11.93° | |

**Phase displacement increases with inclination.** Eris at 44° inclination is more phase-displaced from the Zecliptic than Pluto (17°). These are the deep echo stars.

---

*All speeds are mean orbital speeds. Actual speed varies with orbital position (faster at perihelion).*  
*Data sources: NASA Planetary Fact Sheet, JPL Horizons, hyperphysics.phy-astr.gsu.edu*  
*Zecliptic ≡ Earth's orbital plane (inclination 0.00° by definition)*
