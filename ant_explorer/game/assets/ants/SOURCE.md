# Ant sprite provenance

Purchased Robert Brooks (gamedeveloperstudio) ant packs extracted here for Ant Explorer.
Phase 0 may still use in-code colored capsule placeholders until these PNGs are wired in Godot.

## Primary — Top-Down Ants Mega Pack

| Field | Value |
|-------|--------|
| **Folder** | `mega_pack/` |
| **Source** | Robert Brooks (gamedeveloperstudio) on itch.io — Top-Down Ants Mega Pack |
| **License** | Commercial-use (non-exclusive); see `mega_pack/License.txt`. Derivative works (e.g. games) OK; no asset redistribution / NFT / template resale. Attribution not required. |
| **Approx. size** | ~2447 files total (~2440 PNG); ~2360 files under `keyframes/` |
| **Contents** | Species folders + flat keyframe PNGs (idle / move / bite / look / die / dead_pose); Spriter PNG parts; SVG; Unity package |

Use `mega_pack/keyframes/` as the main animation source. Map species/sizes to castes per `docs/IMPLEMENTATION_PLAN_ANT_EXPLORER.md` §2.2.

## Budget fallback — Top-Down Ant (2 colors)

| Field | Value |
|-------|--------|
| **Folder** | `top_down_ant_budget/` |
| **Source** | Robert Brooks on itch.io — Top-Down Ant (black + red) |
| **License** | Commercial-use asset license (same author / studio terms as other Robert Brooks itch packs; use only in derivative works, do not redistribute raw assets) |
| **Approx. size** | ~27 files (~24 PNG) |
| **Contents** | Spritesheets (`__black_ant_*`, `__red_ant_*` idle/walk/dead); Spriter PNG pieces; `ant.svg` |

Prefer the mega pack when available; use this pack for quick black/red worker prototypes only.

## Layout (as extracted)

```
assets/ants/
├── SOURCE.md                 # this file
├── mega_pack/                # primary mega pack
│   ├── keyframes/            # species dirs + keyframe PNGs
│   ├── spriter_file_png_parts/
│   ├── License.txt
│   └── ...
└── top_down_ant_budget/      # budget 2-color fallback
    ├── spritesheets/
    ├── spriter_file_png_pieces/
    └── ant.svg
```
