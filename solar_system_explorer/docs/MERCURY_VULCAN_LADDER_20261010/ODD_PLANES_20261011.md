# Oddly-planed bodies vs the Zecliptic

**Date:** 2026-10-11 · **Sources:** `data/bodies_metrics.json`, `data/sbdb/*.json` (JPL SBDB, fetched 2026-10-11) via `tools/vulcan/odd_planes.py` → `data/odd_planes.json`.

**Cut:** i to the Zecliptic ≥ 10°. That is a cut so we can hop them, not a claim that 9.9° is ordinary. Planes are orbit poles, not spin axes (those are the tilt curve).

**Length:** 1 = Sol-centre to the photosphere (R☉ = 695,700 km). The classical AU is a table unit only (215.03 R☉) and is not used as a measure here.

## 1. The three you named

| body | i to ecliptic | i to Zecliptic | i to invariable | a (R☉) | e | verdict |
|---|---|---|---|---|---|---|
| **Pallas** | 34.93° | **36.46°** | 34.30° | 595.5 | 0.231 | oddly planed |
| **Juno** | 12.99° | **15.28°** | 12.33° | 574.3 | 0.256 | oddly planed |
| **Psyche** | 3.10° | **7.06°** | 2.21° | 629.1 | 0.135 | plane is ordinary — oddness is elsewhere |

Pallas is the one. Juno is tipped enough to flag. **Psyche is not oddly planed** — 3.1° to Earth's orbit, 7.06° to Sol's equator, which is what you get for a body that lives in the ecliptic. Keep it on the hop list because you named it and because the Psyche spacecraft is going there; do not put it on the odd-plane overlay as if it belonged.

## 2. Heliocentric bodies, i to Zecliptic (high → low)

| body | class | i ecl | **i Zecliptic** | i inv | a (R☉) | e | odd |
|---|---|---|---|---|---|---|---|
| Hidalgo | Centaur | 42.50° | 38.65° | 42.42° | 1232.1 | 0.662 | **yes** |
| Pallas | Main-belt Asteroid | 34.93° | 36.46° | 34.30° | 595.5 | 0.2307000995648547 | **yes** |
| Interamnia | Main-belt Asteroid | 17.30° | 24.09° | 18.87° | 658.0 | 0.155 | **yes** |
| Euphrosyne | Main-belt Asteroid | 26.30° | 21.74° | 25.98° | 679.5 | 0.216 | **yes** |
| Eros | Amor | 10.83° | 16.54° | 12.35° | 313.6 | 0.2228779627700761 | **yes** |
| Juno | Main-belt Asteroid | 12.99° | 15.28° | 12.33° | 574.3 | 0.2556999836681878 | **yes** |
| Pluto | dwarf | 17.16° | 11.90° | 15.58° | 8489.9 | 0.2488 | **yes** |
| Hygiea | Main-belt Asteroid | 3.83° | 10.79° | 5.40° | 677.6 | 0.1067092741240963 | **yes** |
| Earth | planet | 0.00° | 7.25° | 1.58° | 215.0 | 0.01671 |  |
| Psyche | Main-belt Asteroid | 3.10° | 7.06° | 2.21° | 629.1 | 0.1349324738201893 |  |
| Uranus | planet | 0.77° | 6.48° | 1.03° | 4126.3 | 0.047257 |  |
| Neptune | planet | 1.77° | 6.43° | 0.73° | 6466.0 | 0.00859 |  |
| Jupiter | planet | 1.30° | 6.09° | 0.33° | 1118.8 | 0.048386 |  |
| Mars | planet | 1.85° | 5.65° | 1.68° | 327.6 | 0.093394 |  |
| Saturn | planet | 2.48° | 5.50° | 0.93° | 2050.7 | 0.053862 |  |
| Venus | planet | 3.40° | 3.86° | 2.20° | 155.5 | 0.006772 |  |
| Vesta | Main-belt Asteroid | 7.14° | 3.47° | 5.57° | 507.8 | 0.09020374382834395 |  |
| Ceres | Main-belt Asteroid | 10.59° | 3.41° | 9.21° | 594.7 | 0.07969229514816586 |  |
| Mercury | planet | 7.00° | 3.38° | 6.34° | 83.2 | 0.20563 |  |

**What the Zecliptic does to the ranking.** Hidalgo (42.5° ecliptic) stays first at 38.7°. Pallas stays second and gets *more* tipped (34.9 → 36.5). Interamnia jumps 17.3 → 24.1 — Sol's equator makes it odder. Eros 10.8 → 16.5. Hygiea is the reverse surprise: 3.8° to the ecliptic, **10.8° to the Zecliptic**, so it is ordinary in an Earth-frame belt map and flagged here. Ceres is the other reverse: 10.6° to the ecliptic, **3.41° to the Zecliptic** — the same number as Mercury (3.38°). Ceres sits in Sol's equator. Vesta too (3.47°). The 'aligned belt' (Ceres, Vesta, Psyche) and the 'tipped belt' (Pallas, Euphrosyne, Interamnia, Juno) are two different families once the frame is Sol's.

## 3. Moons oddly inclined to their primary

| moon | primary | i to primary equator | e |
|---|---|---|---|
| Triton (retro) | Neptune | 156.90° | 1.6e-05 |
| Iapetus | Saturn | 15.47° | 0.0283 |

Triton is captured and backward. Iapetus is the only large regular moon that is not in its planet's equator. Nereid is 7.1° and e = 0.75 — not over the 10° cut, but the eccentricity is the oddness. Luna is 5.1° to the ecliptic (not listed).

## 4. Hidalgo at 42°

944 Hidalgo: a = 1232 R☉ (Jupiter-crossing; Jupiter is 1,119 R☉), e = 0.662, i = 42.5° ecliptic = **38.7° Zecliptic**. The 42 is the ecliptic inclination, the same numeral as Luna's Pis, and it is a coincidence of the same kind: four-figure-looking, no mechanism offered, exact enough to remember. Hidalgo is the body that *is* 42° to Earth's orbit and 39° to Sol's.

## Literals

- `solar_equator` = (7.25, 75.76) — Carrington / J2000; same as every other file tonight
- `invariable` = (1.5787, 107.5822) — Souami & Souchay 2012
- `odd_threshold_deg` = 10.0 — i to Zecliptic (or to primary equator, for moons) at or above this is flagged
- `r_sol_km` = 695700.0 — photosphere; display length 1

Everything else is read from JSON.
