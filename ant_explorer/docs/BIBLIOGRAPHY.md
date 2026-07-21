# BIBLIOGRAPHY — Ant Explorer Documentary Sources

*Source footage for the 12 knowledge stars. Each entry gives the channel, URL, why it fits, and a
**suggested trim window** to get started (verify/adjust against the live video — timestamps drift
as uploaders re-edit). Feeds `stars.tsv` for `tools/build_stars.sh` (see
`STRATEGY_STAR_ANT_DOCUMENTARIES.md`). All for **private family/educational use**; credit each
source in-app.*

---

## Primary sources (do most of the work)

### A. Deep Look — "Where Are the Ants Carrying All Those Leaves?" (KQED/PBS)
- **URL:** https://www.youtube.com/watch?v=-6oKJ5FGk24
- **Length:** 3:30 · 4K macro · low-narration, gorgeous, kid-perfect.
- **Feeds stars:** 4 (fungal garden), 5 (leaf cutting & foraging), 9 (division of labor: tiny vs
  large workers vs soldiers), 10 (fungus/hygiene).
- **Why:** the single best short, clean, visually stunning leafcutter clip. Multiple on-point
  windows in one 3.5-min video.

### B. AntsCanada — "My Dream Ant Farm: Leafcutter Ants" (Montreal Insectarium)
- **URL:** https://www.youtube.com/watch?v=VA_3ul0drnQ
- **Content:** tour of a 7-year-old *Atta* colony — fungal gardens in clear chambers, foraging
  branches, queen mention.
- **Feeds stars:** 4 (garden cultivation), 1 (queen, chamber context), 11 (nest architecture /
  chambers).
- **Why:** clear captive setup shows chamber structure the sim mirrors; calm narration.

### C. BBC — "Planet Ant: Life Inside the Colony" (McGavin & Hart, 2013)
- **URL (full, ~88 min):** https://www.youtube.com/watch?v=8n0SkIGARuo
  · mirror: https://www.youtube.com/watch?v=HVtix4xO9vQ
- **Content:** full-scale leafcutter nest — nurseries, gardens, graveyards, pheromone experiments,
  defense, tunnels.
- **Feeds stars:** 1 (queen & eggs), 2 (larvae/nursing), 3 (pupae/caste), 6 (pheromone
  communication), 7 (soldier defense), 8 (waste/graveyard), 11 (tunnels/excavation), 12
  (invaders/resilience).
- **Why:** the workhorse — nearly every "inside the nest" star can be cut from here. It's long, so
  the trim windows below matter most for this one. **Scrub and confirm each window**, since it's a
  feature-length upload.

### D. National Geographic — "A Real Bug's Life" (leafcutter segment)
- **Find:** search `National Geographic "A Real Bug's Life" leafcutter` (Disney+/NatGeo; YouTube
  has clips). Use a clip upload or your own copy.
- **Feeds stars:** 5 (foraging trails), 12 (colony challenges).
- **Why:** modern, cinematic, child-friendly narration. Optional upgrade over BBC for foraging.

---

## `stars.tsv` starter (copy into `ant_explorer/tools/stars.tsv`)

Tab-separated: `id ⇥ start ⇥ end ⇥ url`. **Windows are first-guesses — watch and tighten each to
the exact on-point 15–40 s before shipping.** Comment lines (`#`) are ignored by the build script.

```
# id            start      end        url
# --- Deep Look (3:30 total; everything here is on-point, pick tight windows) ---
05_foraging     00:00:20   00:00:50   https://www.youtube.com/watch?v=-6oKJ5FGk24
04_garden       00:01:40   00:02:15   https://www.youtube.com/watch?v=-6oKJ5FGk24
09_labor        00:02:40   00:03:10   https://www.youtube.com/watch?v=-6oKJ5FGk24
10_hygiene      00:01:15   00:01:40   https://www.youtube.com/watch?v=-6oKJ5FGk24
# --- AntsCanada Dream Ant Farm (verify windows against the upload) ---
11_tunnels      00:02:00   00:02:35   https://www.youtube.com/watch?v=VA_3ul0drnQ
# --- BBC Planet Ant (~88 min; SCRUB to confirm each window) ---
01_queen        00:14:00   00:14:35   https://www.youtube.com/watch?v=8n0SkIGARuo
02_larvae       00:16:30   00:17:05   https://www.youtube.com/watch?v=8n0SkIGARuo
03_pupae        00:18:00   00:18:30   https://www.youtube.com/watch?v=8n0SkIGARuo
06_pheromone    00:33:00   00:33:40   https://www.youtube.com/watch?v=8n0SkIGARuo
07_soldier      00:47:00   00:47:35   https://www.youtube.com/watch?v=8n0SkIGARuo
08_waste        00:52:00   00:52:30   https://www.youtube.com/watch?v=8n0SkIGARuo
12_invaders     01:02:00   01:02:40   https://www.youtube.com/watch?v=8n0SkIGARuo
```

> The BBC timestamps above are **placeholders to be verified** — open the video, find the exact
> moment (queen laying, a clear larva close-up, the pheromone-trail experiment, the defense
> sequence, the refuse chamber, an invader/raft moment), and paste the real in/out. Because
> `build_stars.sh` caches the source download, re-cutting after you fix a window is seconds.

---

## Expansion sources (stars 13–15, later)

- **Nuptial flight / founding a colony:** BBC *Planet Ant* has a founding sequence; AntsCanada has
  dedicated "queen founding" videos. Search `AntsCanada queen founding leafcutter`.
- **Species comparison:** Deep Look has other ant episodes (e.g. honeypot, fire ants) for a
  "different ants" star. Deep Look channel: https://www.youtube.com/@deeplook
- **Your own footage:** if you ever distribute the app, a few phone-macro shots of a local anthill
  become royalty-free stars and a lovely "we filmed these together" moment with her.

---

## Attribution block (drop into the app credits / a star's corner)

```
Footage credits (educational use):
 • Deep Look — KQED / PBS Digital Studios
 • AntsCanada (Montreal Insectarium exhibit)
 • BBC — "Planet Ant: Life Inside the Colony" (2013)
 • National Geographic — "A Real Bug's Life"
```

Keep clips short, keep them offline, keep the credits on. If Ant Explorer ever leaves the family
device, replace third-party clips with original or CC-licensed footage — the pipeline only needs a
new `stars.tsv`.
