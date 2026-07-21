# Star Learning — naming

## Decision

| Layer | Name | Why |
|-------|------|-----|
| **Device + home app** (same thing) | **Star Learner** | One noun she can hold and boot into. Device and launcher share this name exactly. |
| **Product line / repo** | **star_learning** | Platform folder for curricula + games. Slightly different from the device so the tree can hold many titles. |
| **Format** | stars / Star Learning | Short offline documentary clips at glowing stars — the shared educational pattern across games. |
| **First game** | **Ant Explorer** (tile: **ants**) | Games keep their own titles; they are not renamed to Star Learner. |

**Do not** run two competing brands on the boot screen (“STAR LEARNING” + “Star Learner”). Spoken and visible brand = **Star Learner**. “Star Learning” is the umbrella / format, not a second product name.

## Machine ids

| Id | Value |
|----|-------|
| Hostname / fleet label | `star-learner` |
| Android `device_name` | `Star Learner` |
| Home package (current) | `com.dylan.antexplorer` — keep until a clean reinstall window; eventual target `com.dylan.starlearner` |
| On-device catalog path | `/sdcard/AntPhone/` for now (legacy); migrate to `/sdcard/StarLearner/` with the package rename |
| Game packages | `com.dylan.antexplorer.colony`, future `…bees`, etc. |

## Layout

```
dev/star_learning/
├── NAMING.md          ← this file
├── README.md
└── ant_explorer/      ← first game + current kiosk launcher sources
    ├── docs/
    ├── game/          ← Godot Ant Explorer
    ├── kiosk_placeholder/
    └── tools/
```
