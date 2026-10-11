# Oddly-planed bodies vs the Zecliptic

**Date:** 2026-10-11 · **Sources:** `data/bodies_metrics.json`, `data/sbdb/*.json` (JPL SBDB, fetched 2026-10-11) via `tools/vulcan/odd_planes.py` → `data/odd_planes.json`.

**Cut:** i to the Zecliptic ≥ 10°. That is a cut so we can hop them, not a claim that 9.9° is ordinary. Planes are orbit poles, not spin axes (those are the tilt curve).

## 1. The three you named

| body | i to ecliptic | i to Zecliptic | i to invariable | a (AU) | e | verdict |
|---|---|---|---|---|---|---|
| **Pallas** | 34.93° | **36.46°** | 34.30° | 2.770 | 0.231 | oddly planed |
| **Juno** | 12.99° | **15.28°** | 12.33° | 2.671 | 0.256 | oddly planed |
| **Psyche** | 3.10° | **7.06°** | 2.21° | 2.926 | 0.135 | plane is ordinary — oddness is elsewhere |

Pallas is the one. Juno is tipped enough to flag. **Psyche is not oddly planed** — 3.1° to Earth's orbit, 7.06° to Sol's equator, which is what you get for a body that lives in the ecliptic. Keep it on the hop list because you named it and because the Psyche spacecraft is going there; do not put it on the odd-plane overlay as if it belonged.

## 2. Heliocentric bodies, i to Zecliptic (high → low)

| body | class | i ecl | **i Zecliptic** | i inv | a | e | odd |
|---|---|---|---|---|---|---|---|
| Hidalgo | Centaur | 42.50° | 38.65° | 42.42° | 5.73 | 0.662 | **yes** |
| Pallas | Main-belt Asteroid | 34.93° | 36.46° | 34.30° | 2.769559010737709 | 0.2307000995648547 | **yes** |
| Interamnia | Main-belt Asteroid | 17.30° | 24.09° | 18.87° | 3.06 | 0.155 | **yes** |
| Euphrosyne | Main-belt Asteroid | 26.30° | 21.74° | 25.98° | 3.16 | 0.216 | **yes** |
| Eros | Amor | 10.83° | 16.54° | 12.35° | 1.458243716760167 | 0.2228779627700761 | **yes** |
| Juno | Main-belt Asteroid | 12.99° | 15.28° | 12.33° | 2.670989527103278 | 0.2556999836681878 | **yes** |
| Pluto | dwarf | 17.16° | 11.90° | 15.58° | 39.482 | 0.2488 | **yes** |
| Hygiea | Main-belt Asteroid | 3.83° | 10.79° | 5.40° | 3.150974033963701 | 0.1067092741240963 | **yes** |
| Earth | planet | 0.00° | 7.25° | 1.58° | 1.0 | 0.01671 |  |
| Psyche | Main-belt Asteroid | 3.10° | 7.06° | 2.21° | 2.925720466462538 | 0.1349324738201893 |  |
| Uranus | planet | 0.77° | 6.48° | 1.03° | 19.18916 | 0.047257 |  |
| Neptune | planet | 1.77° | 6.43° | 0.73° | 30.06992 | 0.00859 |  |
| Jupiter | planet | 1.30° | 6.09° | 0.33° | 5.20289 | 0.048386 |  |
| Mars | planet | 1.85° | 5.65° | 1.68° | 1.523679 | 0.093394 |  |
| Saturn | planet | 2.48° | 5.50° | 0.93° | 9.53667 | 0.053862 |  |
| Venus | planet | 3.40° | 3.86° | 2.20° | 0.723332 | 0.006772 |  |
| Vesta | Main-belt Asteroid | 7.14° | 3.47° | 5.57° | 2.361365965127599 | 0.09020374382834395 |  |
| Ceres | Main-belt Asteroid | 10.59° | 3.41° | 9.21° | 2.765552595034094 | 0.07969229514816586 |  |
| Mercury | planet | 7.00° | 3.38° | 6.34° | 0.387098 | 0.20563 |  |

**What the Zecliptic does to the ranking.** Hidalgo (42.5° ecliptic) stays first at 38.7°. Pallas stays second and gets *more* tipped (34.9 → 36.5). Interamnia jumps 17.3 → 24.1 — Sol's equator makes it odder. Eros 10.8 → 16.5. Hygiea is the reverse surprise: 3.8° to the ecliptic, **10.8° to the Zecliptic**, so it is ordinary in an Earth-frame belt map and flagged here. Ceres is the other reverse: 10.6° to the ecliptic, **3.41° to the Zecliptic** — the same number as Mercury (3.38°). Ceres sits in Sol's equator. Vesta too (3.47°). The 'aligned belt' (Ceres, Vesta, Psyche) and the 'tipped belt' (Pallas, Euphrosyne, Interamnia, Juno) are two different families once the frame is Sol's.

## 3. Moons oddly inclined to their primary

| moon | primary | i to primary equator | e |
|---|---|---|---|
| Triton (retro) | Neptune | 156.90° | 1.6e-05 |
| Iapetus | Saturn | 15.47° | 0.0283 |

Triton is captured and backward. Iapetus is the only large regular moon that is not in its planet's equator. Nereid is 7.1° and e = 0.75 — not over the 10° cut, but the eccentricity is the oddness. Luna is 5.1° to the ecliptic (not listed).

## 4. Hidalgo at 42°

944 Hidalgo: a = 5.73 AU (Jupiter-crossing), e = 0.662, i = 42.5° ecliptic = **38.7° Zecliptic**. The 42 is the ecliptic inclination, the same numeral as Luna's Pis, and it is a coincidence of the same kind: four-figure-looking, no mechanism offered, exact enough to remember. Hidalgo is the body that *is* 42° to Earth's orbit and 39° to Sol's.

## Literals

- `solar_equator` = (7.25, 75.76) — Carrington / J2000; same as every other file tonight
- `invariable` = (1.5787, 107.5822) — Souami & Souchay 2012
- `odd_threshold_deg` = 10.0 — i to Zecliptic (or to primary equator, for moons) at or above this is flagged

Everything else is read from JSON.
