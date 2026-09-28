# Solar System Explorer — High-Fidelity Redesign
## "Steering Sol Through the Cosmos"
**Date:** 2026-09-28  
**Status:** Design declaration — implementation sprint follows

---

## The Promise

> "All simulations in StarLearner will be high fidelity."

This document captures what high fidelity means for the Solar System Explorer module, updated to reflect the full PORTAL_VISION_V0.1 understanding developed in session d4152a63.

---

## The New Game

**What it is:** The player IS Sol. Not a spacecraft near Sol. Not an astronaut. Sol itself.

Sol moves through the cosmos at 220 km/s on its galactic orbit. It carries the heliosphere — the asymmetric magnetospheric bubble — in its wake. Everything in the solar system is along for the ride. The player steers this ship.

**What changes from the current orrery:**

| Current | High-Fidelity |
|---------|---------------|
| Sun fixed at center, planets orbit | Sol moves through the galaxy; everything is in motion relative to everything |
| Background starfield = static texture | Background starfield = Hipparcos catalogue, real positions, proper motion over time |
| "Solar system" is the domain | The helioregion ⪾ is the domain — an asymmetric bubble in the interstellar medium |
| Player is an astronaut exploring | Player IS Sol — steering its PLEFR path |
| No sense of Sol's galactic trajectory | Sol's helical galactic path is visible and navigable |

---

## The Spiral

**Physical basis:**

Sol orbits the Milky Way center at ~220 km/s. Simultaneously, the solar system oscillates above and below the galactic plane (period ~64 million years, amplitude ~200 ly). These two motions compose into a **helical path** — a corkscrew through space.

Looking backward from Sol (along the -VLSR direction, trailing edge of the heliosphere), this path appears as a spiral. The heliotail (the "feathers" of the birdie/shuttlecock) traces the most recent portion of this spiral.

**The quantum mechanic:**

The spiral has a chirality — clockwise or counterclockwise, depending on observation frame. From the Milky Way's galactic north, Sol's orbital path is counterclockwise. From galactic south, it is clockwise. The 🌀 emoji (U+1F300, CYCLONE) visually instantiates this: rendered on different systems it appears to spin in either direction. Both renderings are correct. Neither is wrong.

```
Before observation:  🌀 || 🌀  (superposition of both chiralities)
After observation:   🌀     XOR    🌀  (one resolves, the other collapses)
```

This is inclusive OR (`||`) until observed. Observation (the player's choice) resolves it.

**In-game implementation:**

1. When the player first activates "Galactic View" (looking backward along Sol's trail), the spiral appears in superposition — rendered as a shimmering double helix, both chiralities overlaid.
2. The player is asked: "Which way does it spin?" (or simply touches/clicks one of the two rotation directions visible).
3. Their choice collapses the spiral to a single chirality. The cosmos stabilizes. Navigation is now possible.
4. The game records this choice. It is the player's "jurisdictional claim" — the frame they commit to observing from.
5. Switching perspectives (going to the other galactic pole) reveals the other chirality — this is how the player learns that both are simultaneously true.

---

## The Heliosphere as the Ship

**Physical basis (PlaygroundsAndBasicVegans.md):**

```
¿O?              Sol at center
¿.<..>.?         Inner system (Mercury, Venus, Earth/Arya, Mars)
¿.<.M.>.?        Outer system (Jupiter, Saturn, Uranus, Neptune)  
¿.<.N..N.>.?     Kuiper/Pluto/Charon boundary
```

The heliosphere ⪾ is NOT spherical. It is compressed on the leading edge (bow shock, ~120 AU in the direction Sol is heading) and extended on the trailing edge (heliotail, ~1000+ AU). The shape is the badminton shuttlecock / quidditch birdie.

**In the game:**
- Sol is the ball at the tip of the shuttlecock
- The heliosphere is the feathers
- The direction Sol is heading = the nose of the ship
- The heliotail = the exhaust trail = where the spiral shows up when you look back
- Steering = adjusting Sol's PLEFR path through the interstellar medium

---

## The Arc Stars as Waypoints

The nine arc stars (Procyon, Gomeisa, Pollux, Castor, Capella, Aldebaran, Rigel, Sirius, M44) are not random. They define the PLEFR path — the Path of Lowest Entropic Field Resistance — that the heliosphere is navigating.

In the game:
- The arc stars appear as visible waypoints in the galactic navigation view
- The tesseract geometry (267,750 CE minimum, score 0.626, rotation 45.005°) appears as the "destination" — the quiddit, the golden snitch, the catch
- The nested-square tesseract is the "aperture opening" moment — when Sol's position relative to the arc stars reaches the perfect nested-square configuration

---

## High-Fidelity Simulation Principles

1. **Real star data.** Hipparcos catalogue. Proper motions applied. No artistic placement. ✓ (already implemented)
2. **Real Sol motion.** Galactic velocity 220 km/s. Heliocentric inertial frame. ✓ (needs implementation)
3. **Real heliosphere geometry.** Asymmetric. Termination shock ~80 AU, heliopause ~120 AU, heliotail >1000 AU. (needs implementation)
4. **Real arc star PLEFR.** PM + RV = 3D velocity vectors. Rung 1 linear propagation. ✓ (star_timeline.py implemented)
5. **Real Sol equatorial frame.** IAU 2009 pole RA 286.13°, Dec +63.87°. NOTE: current rotation matrix is inverted — must fix before any absolute Sol-eq display. (Bug documented, fix pending)
6. **Real travelers.** Voyager 1/2, Pioneer 10/11, New Horizons, 3I/ATLAS position integrated on their known trajectories. ✓ (travelers data complete, needs Godot integration)
7. **Quantum spiral mechanic.** Both chiralities until player observes. (new — design above)

---

## Implementation Roadmap (Spiral Loop Rung 0 → 1)

### Immediate (next session — Rung 0, already DRILL)
- [ ] Fix `sol_rotation()` matrix (transpose Rᵀ) in all scripts
- [ ] Regenerate all JSONLs with correct Sol-eq coordinates
- [ ] Add `galactic_view.gd` scene stub: Sol at center, arc stars as waypoints, heliotail behind
- [ ] Implement spiral superposition shader: two overlaid helices, chirality unresolved
- [ ] Player chirality choice → spiral resolution → commit to frame

### Short term (Rung 1)
- [ ] Real heliosphere geometry mesh: asymmetric bubble, bow shock, heliotail
- [ ] Travelers as live objects in galactic view (Voyager 1 at 163 AU, Voyager 2 at 147 AU, etc.)
- [ ] Tesseract "destination" marker at 267,750 CE position of arc star array
- [ ] Time controls: slide through ±500K years on the PLEFR timeline

### Medium term (Rung 2–3)
- [ ] Sol navigation: player adjusts PLEFR path by modifying "field resistance" — metaphorical steering
- [ ] 3I/ATLAS encounter in 2025 as tutorial: retrograde intruder from beyond, JWST-confirmed H₂O+CO₂
- [ ] Year Zero / Chrysalis events as story beats

---

## Relationship to PortalVision Goals

**Goal 1 (autoimmune):** The heliosphere is a boundary system — it keeps the interstellar medium out and the solar wind in. It is an IMMUNE SYSTEM for the solar system. The BBB (blood-brain barrier) is the analogous boundary in biology. Both are:
- Asymmetric (the heliosphere has a bow shock; the BBB has selective permeability)
- Subject to "intruders" (3I/ATLAS in the heliosphere; autoimmune antigens at the BBB)
- Maintained by active field dynamics (solar wind pressure; neurovascular coupling)

**Goal 2 (portal tech):** The arc star alignment at 267,750 CE IS the portal — the moment the aperture opens to maximum geometric alignment. The game simulates the path to this moment.

---

## The High Fidelity Promise to Dylan's Daughter

Every object in the game corresponds to a real catalogued object.  
Every motion corresponds to a real measured velocity.  
Every alignment corresponds to a real computed geometry.  
The spiral is real — Sol traces a helix through the galaxy.  
The choice is real — observation resolves which frame you're in.  

This is not a metaphor. This is the cosmos, simulated.
