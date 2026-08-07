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
| Android `device_name` (production kiosk) | `Star Learner` |
| Hardware model (all units) | **fogona** — moto g play 2024 product name (not a unit codename) |
| Digs / Dylan's digs handset | **shoal** (`ZL8324ZNRK`) |
| Travel / nieces gift handset | **reef** (`ZL8326FWKM`) |
| Production / gift kiosk | **cove** (`ZL8326G8ND`) |
| Home package | `com.dylan.star_learner` |
| On-device catalog path | `/sdcard/AntPhone/` for now (legacy); migrate to `/sdcard/StarLearner/` when convenient |
| Game packages | `com.dylan.ant_explorer`, `com.dylan.garden_explorer`, `com.dylan.solar_system_explorer`, `com.dylan.math_explorer`, `com.dylan.language_explorer` |

Canonical packages: `tools/packages.sh`. Handset serials: `tools/devices.sh`.

**Do not** call a unit “fogona” in ops prose — that is the shared model name. Say **shoal**, **reef**, or **cove**.

### USB homes (as of 2026-08-07)

| Codename | Serial | Role / typical USB |
|----------|--------|--------------------|
| **shoal** | `ZL8324ZNRK` | Dylan's digs / local digs on **82** |
| **reef** | `ZL8326FWKM` | Nieces gift track (dad's house when ready) |
| **cove** | `ZL8326G8ND` | Production kiosk (often **245**) |

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

## Package rename (2026-07-28)

Migrating from legacy `com.dylan.antexplorer*` requires a **clean reinstall** on kiosk phones:

1. Remove device owner / factory reset or `adb uninstall` all six legacy packages.
2. Install fresh APKs from `tools/full_deploy.sh` (new IDs in `tools/packages.sh`).
3. Re-run `ant_explorer/tools/enable_device_owner.sh` for production lock-task.

Game saves under the old package IDs are **not** migrated automatically.
