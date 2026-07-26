# Star Learner Appliance — Kiosk Status

The Moto G Play (`fogona`) is locked down as a dedicated **Star Learner** console.

**Remote updates / multi-app tiles:** see `STRATEGY_ANT_PHONE_UPDATES.md`.

## What's active now
- **Home app:** `com.dylan.antexplorer` (five-tile Star Learner launcher)
- **Games:** Ant, Garden, Solar System, Math, and Language Explorer (separate APKs)
- **Orientation:** landscape locked (`user_rotation=1`, accel rotation off)
- **Chrome:** immersive fullscreen (`policy_control=immersive.full=*`)
- **Lock task:** enterprise `LOCKED` via device owner (`com.dylan.antexplorer`) — no “App is pinned” chrome. Re-enable with `tools/enable_device_owner.sh` + `tools/kiosk_on.sh` (do **not** use `am task lock`; that is consumer screen pinning).
- **Stay awake while charging:** on
- Soft-disabled: Maps, Chrome, YouTube, Temu (reversible)

## Maintenance (from your Linux box)

```bash
# Un-pin / leave appliance mode
adb shell am task lock stop
adb shell settings put global policy_control null*

# Restore a normal home (Motorola launcher) temporarily
adb shell cmd role remove-role-holder android.app.role.HOME com.dylan.antexplorer
# then pick the stock launcher when Android asks, or:
# adb shell cmd role add-role-holder android.app.role.HOME com.motorola.launcher3

# Re-enable a disabled package
adb shell pm enable com.android.chrome

# Re-enter appliance mode
~/dev/star_learning/ant_explorer/tools/kiosk_on.sh
```

## Full release deployment

Do not replace the launcher with a game APK: `com.dylan.antexplorer` is permanently the
HOME launcher, while every game has its own package. Use the repository-level release
script so the catalog, tile resources, game payloads, and launcher videos cannot drift.

```bash
# From the star_learning repository root, one local USB device:
./tools/full_deploy.sh

# Build a checked portable bundle only:
./tools/full_deploy.sh --prepare-only

# Send the same bundle to 245, deploy to fogona USB, then publish OTA staging:
./tools/deploy_via_245.sh
```

The script preserves every game's progress, refreshes the launcher-only video cache,
reapplies HOME/immersive settings, and verifies packages, media, foreground launcher, and
enterprise lock-task. Use `--require-kiosk` when invoking `full_deploy.sh` directly on a
production unit.

- Launcher project: `ant_explorer/kiosk_placeholder/`
- Canonical catalog: `ant_explorer/tools/catalog.json`
- Remote/OTA detail: `STRATEGY_ANT_PHONE_UPDATES.md`
