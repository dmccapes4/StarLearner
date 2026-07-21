# Ants Appliance — Kiosk Status

The Moto G Play (`fogona`) is locked down as a dedicated **ants** device.

**Remote updates / multi-app tiles:** see `STRATEGY_ANT_PHONE_UPDATES.md`.

## What's active now
- **Home app:** `com.dylan.antexplorer` (placeholder APK — big "ants" tile)
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

## Replace placeholder with the real game
Build/export the Godot Ant Explorer APK with **the same** `applicationId`:
`com.dylan.antexplorer`, then:

```bash
adb install -r AntExplorer.apk
adb shell am task lock stop
adb shell am start -n com.dylan.antexplorer/.MainActivity   # or Godot's activity
# re-pin:
TASK=$(adb shell dumpsys activity activities | grep -oE 'Task\{[^#]*#[0-9]+.*antexplorer' | head -1 | grep -oE '#[0-9]+' | tr -d '#')
adb shell am task lock "$TASK"
```

Placeholder project: `ant_explorer/kiosk_placeholder/`  
Installed APK copy: `~/moto_fogona_backup/AntExplorer.apk`
