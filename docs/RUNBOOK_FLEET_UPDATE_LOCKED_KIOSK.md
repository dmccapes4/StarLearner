# Runbook — update fleet handsets (kiosk locked)

**Use when:** reef and/or cove are on USB, Star Learner is in device-owner lock-task, and you
need current APKs (including Solar System Explorer) without factory reset.

**Handsets:** see [`NAMING.md`](../NAMING.md) and [`tools/devices.sh`](../tools/devices.sh).

| Codename | Serial | Role |
|----------|--------|------|
| **reef** | `ZL8326FWKM` | Travel / nieces gift |
| **cove** | `ZL8326G8ND` | Production kiosk |
| **shoal** | `ZL8324ZNRK` | Local digs (82) |

Model name on all units: **fogona** (Moto G Play 2024). Say **reef** / **cove**, not “fogona”.

---

## What “kiosk locked” means for updates

- **APK installs do not require** leaving lock-task manually. `full_deploy.sh` stops/restarts
  the launcher and re-asserts HOME + immersive policy after install.
- **USB debugging authorization** is separate. The phone must trust **this host’s ADB RSA key**
  (`adb devices` → `device`, not `unauthorized`).
- **`kiosk_maintenance.sh`** exits lock-task so Settings / USB-auth dialogs can appear — but it
  only works **after** you already have an authorized `adb shell`. It does not bypass
  `unauthorized`.

If every known key shows `unauthorized`, the phone is holding a **lost** pubkey. Options:
Magisk `adb root` + push pubkey (if root alive), find the old private key, or factory reset +
re-provision (see [Recovery](#recovery-unauthorized-or-lost-adb-trust)).

---

## One-time setup on the USB host (245 today)

Run on **245 Pop/WSL** (`hilariousmarcupial`) with the phone plugged into **Windows USB**
(245’s canonical path uses Windows `adb.exe`).

### 1. USB permissions (245 often missing this)

```bash
# Pop shell — once per machine
sudo tee /etc/udev/rules.d/51-android.rules >/dev/null <<'EOF'
SUBSYSTEM=="usb", ATTR{idVendor}=="22b8", MODE="0660", GROUP="plugdev", TAG+="uaccess"
EOF
sudo udevadm control --reload-rules && sudo udevadm trigger
sudo usermod -aG plugdev dylanmccapes
# log out of SSH and back in, or: newgrp plugdev
```

Symptom when broken: `lsusb` shows `Motorola … moto g play` but `adb devices` is **empty**.

### 2. Repo + build env

```bash
cd ~/dev/star_learning   # or /mnt/c/Users/dylan/dev/star_learning on 245 WSL
git pull --ff-only
source tools/245_env.sh  # GODOT, JDK 17, ANDROID_HOME
tools/bootstrap_godot_android.sh   # if templates missing
```

Hub secrets for Language ASR (production):

```bash
ls ant_explorer/tools/secrets/hub245/{token.txt,hub.crt}
# copy from 82 if missing
```

### 3. Fleet ADB key (one key, every ops host)

Each machine has its own `~/.android/adbkey` by default. Phones remember **one pubkey per
Accept**. Use a **single fleet keypair** on 82, 245, and any laptop.

```bash
# On the host that should OWN the canonical key (pick 245 today):
./tools/sync_fleet_adbkey.sh export    # ~/.android → secrets/fleet/ (gitignored)

# On every other host (82, laptop):
scp 245:~/dev/star_learning/ant_explorer/tools/secrets/fleet/adbkey* \
     ant_explorer/tools/secrets/fleet/
./tools/sync_fleet_adbkey.sh install   # secrets/fleet → ~/.android
adb kill-server && adb start-server
```

See [`tools/sync_fleet_adbkey.sh`](../tools/sync_fleet_adbkey.sh). Secrets live in
`ant_explorer/tools/secrets/fleet/` (never commit private keys).

**After installing the fleet key:** unplug/replug USB. If the phone already trusted this pubkey,
`adb devices` shows `device`. If it trusted a **different** key, you get `unauthorized` until
recovery (below).

---

## Session checklist (245, both phones)

### A. Confirm USB + trust

```bash
export WIN_ADB=/mnt/c/Users/dylan/Android/platform-tools/adb.exe   # 245 WSL default
"$WIN_ADB" devices -l
./tools/fleet_status.sh
```

| `adb devices` state | Meaning | Action |
|---------------------|---------|--------|
| *(empty)* | Host can’t open USB node | Fix [plugdev](#1-usb-permissions-245-often-missing-this) |
| `unauthorized` | Wrong or unknown ADB key | [Recovery](#recovery-unauthorized-or-lost-adb-trust) |
| `device` | Ready | Deploy (below) |
| `offline` | Bad cable/port | Replug, try another port |

Target serials:

```bash
# reef
STARLEARNER_SERIAL=ZL8326FWKM ./tools/kiosk_maintenance.sh status

# cove
STARLEARNER_SERIAL=ZL8326G8ND ./tools/kiosk_maintenance.sh status
```

### B. Deploy one handset

**245 all-in-one (cove only, legacy default serial):**

```bash
./tools/full_deploy_245.sh
```

**Per serial (reef then cove, any host with authorized adb):**

```bash
./tools/full_deploy.sh \
  --adb "$WIN_ADB" \
  --serial ZL8326FWKM \
  --require-kiosk \
  --validate

./tools/full_deploy.sh \
  --adb "$WIN_ADB" \
  --serial ZL8326G8ND \
  --require-kiosk \
  --validate
```

Or loop both connected units:

```bash
./tools/deploy_fleet_usb.sh --require-kiosk --validate
```

What deploy does:

1. Builds (unless `--skip-build` / `--deploy-only`)
2. Pushes `catalog.json` + launcher explainer videos
3. Installs all six APKs (games then launcher)
4. Restores landscape HOME, brightness, lock-task
5. Verifies packages + video sizes

**Game saves are preserved.** Only launcher media cache may be cleared when root is unavailable.

### C. Verify Solar (and everything else)

```bash
STARLEARNER_SERIAL=ZL8326G8ND ./tools/fleet_status.sh
# or both phones if connected:
./tools/fleet_status.sh --all
```

Confirm `com.dylan.solar_system_explorer` is installed and `versionName` matches the APK you
just built. Spot-check on glass: Star Learner home → **Solar System Explorer** tile → opens
hub → **Solar System** orrery / **Spaceship** flight.

```bash
REQUIRE_HUB_ASR=1 ./tools/run_all_validation.sh ZL8326G8ND
```

### D. Return to kiosk (if you used maintenance)

```bash
STARLEARNER_SERIAL=ZL8326G8ND ./tools/kiosk_maintenance.sh off
```

Normal deploy already re-launches HOME; use `off` only if you ran `maintenance on` manually.

### E. Publish OTA staging (optional, for Wi‑Fi pull later)

```bash
./tools/publish_ota_staging.sh
```

---

## Recovery: unauthorized or lost ADB trust

**Symptom:** `adb devices` shows `unauthorized` for a handset that used to work remotely.

1. **Install fleet key** on this host (`sync_fleet_adbkey.sh install`) and replug.
2. **Try WSL-era key** (245 backup): `wsl_restore/home/hilarious_marcupial/.android/` — if
   that private key still matches the phone’s stored pubkey, copy it to `~/.android/` and retry.
3. **If you have authorized adb once** (even briefly):
   ```bash
   STARLEARNER_SERIAL=ZL8326G8ND ./tools/kiosk_maintenance.sh on
   ```
   On glass: Developer options → *Revoke USB debugging authorizations* → replug → Accept with
   **Always allow** using the **fleet** key now installed on the host.
4. **Magisk / root** (if still present):
   ```bash
   adb -s ZL8326G8ND root
   adb -s ZL8326G8ND shell 'cat >> /data/misc/adb/adb_keys' < ant_explorer/tools/secrets/fleet/adbkey.pub
   adb -s ZL8326G8ND reboot
   ```
5. **Last resort:** factory reset → `./tools/full_deploy.sh --serial … --require-kiosk` →
   `ant_explorer/tools/enable_device_owner.sh` → accept fleet key at first USB connect **before**
   relying on lock-task for maintenance.

**Prevention (do on next successful provision):**

- `./tools/sync_fleet_adbkey.sh export` on 245; copy `secrets/fleet/` to 82 backup.
- Use the **same** fleet key on every ops machine.
- *(Planned)* glass escape (e.g. 7× tap Help) → maintenance without prior adb — not shipped yet.

---

## Quick reference

| Task | Command |
|------|---------|
| List handsets + package versions | `./tools/fleet_status.sh --all` |
| Install fleet adb key on this host | `./tools/sync_fleet_adbkey.sh install` |
| Save host key as fleet canonical | `./tools/sync_fleet_adbkey.sh export` |
| Exit lock-task (needs authorized adb) | `STARLEARNER_SERIAL=… ./tools/kiosk_maintenance.sh on` |
| Re-enter lock-task | `STARLEARNER_SERIAL=… ./tools/kiosk_maintenance.sh off` |
| Full deploy both USB devices | `./tools/deploy_fleet_usb.sh --require-kiosk --validate` |
| 245 default pipeline (cove) | `./tools/full_deploy_245.sh` |

Related: [`README.md`](../README.md) deploy section,
[`ant_explorer/docs/KIOSK_APPLIANCE.md`](../ant_explorer/docs/KIOSK_APPLIANCE.md),
[`ant_explorer/docs/STRATEGY_MOTO_BOOTLOAD_LINUX.md`](../ant_explorer/docs/STRATEGY_MOTO_BOOTLOAD_LINUX.md).
