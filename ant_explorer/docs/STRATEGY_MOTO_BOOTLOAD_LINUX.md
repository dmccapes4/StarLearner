# STRATEGY — Bootloading the Moto G Play 2024 from Linux (Pop!_OS)

*Turning an `XT2413` (codename **fogona**) into a single-purpose "ants" device, driven entirely
from your Pop!_OS 24.04 workstation. Precise, copy-pasteable, and ordered so you never brick
anything you can't recover.*

---

## COLD OPEN — McCLANE AT THE TERMINAL

**McCLANE:** I can see the phone in my file manager. Photos, everything. But `adb devices` is
empty. It's *right there*, Professor.

**FEYNMAN:** Two different conversations, John. Your file manager is speaking **MTP** — "show me
files" — and the phone happily answers that with the screen locked and no permission asked. `adb`
speaks **debugging** — "let me run commands as you" — and the phone won't answer *that* to a
stranger. You've proven the wire works. Now you have to (1) turn on the debugging channel on the
phone, (2) teach *your* machine it's allowed to listen, and (3) tap "yes, I trust this computer"
on the screen. Do those three and the silence ends.

---

## 0. What we confirmed on YOUR machine (Pop!_OS 24.04)

| Check | Result | Consequence |
|---|---|---|
| `lsusb` sees phone | `22b8:2e76 Motorola ... moto g play - 2024` | **USB + cable are good** (data cable, not charge-only) |
| `adb devices` | empty | USB debugging not enabled/authorized yet |
| `fastboot` installed | yes (`/usr/bin/fastboot`) | ready for the unlock/flash steps |
| `adb` installed | yes (`/usr/bin/adb`) | ready once the phone authorizes |
| Android udev rule | **none present** | add one so adb/fastboot work without `sudo` |
| Motorola USB VID | `22b8` | the VID your udev rule must whitelist |

**Codename:** `fogona`. **Partition to patch for root:** `init_boot` (Android 13+, do **not** use
`boot`). **Magisk:** use **27.0 stable** (newer builds have produced corrupt patches on this
family).

---

## 1. Make the phone talk to Linux (fixes the "adb can't see it" gap)

### 1.1 On the phone — enable Developer + USB debugging + OEM unlocking
1. **Settings → About phone →** tap **Build number** 7×. ("You are now a developer.")
2. **Settings → System → Developer options:**
   - **USB debugging → ON**
   - **OEM unlocking → ON**  *(if greyed out, see §1.4 — usually a carrier-lock timer)*
3. Leave the phone **unlocked (screen on)** while plugged in.

### 1.2 On Pop!_OS — install the udev rule (one time, why adb saw nothing)
Motorola's USB vendor ID is `22b8`. Create the rule so the device nodes are group-owned by
`plugdev` (adb/fastboot then work without root):

```bash
sudo tee /etc/udev/rules.d/51-android.rules >/dev/null <<'EOF'
# Motorola (adb + fastboot), VID 22b8
SUBSYSTEM=="usb", ATTR{idVendor}=="22b8", MODE="0660", GROUP="plugdev", TAG+="uaccess"
EOF
sudo udevadm control --reload-rules
sudo udevadm trigger
sudo usermod -aG plugdev "$USER"   # then log out/in once for group to take effect
```

### 1.3 Restart adb and accept the trust prompt
```bash
adb kill-server
adb start-server
adb devices -l
```
Watch the **phone screen**: an **"Allow USB debugging?"** dialog appears — check *Always allow
from this computer* → **Allow**. Re-run `adb devices -l`; you should now see the serial with
`device` (not `unauthorized`). **If it still says `unauthorized`:** revoke and retry from the
phone (Developer options → *Revoke USB debugging authorizations*), replug, accept again.

### 1.4 If "OEM unlocking" is greyed out
Carrier variants (Straight Talk / TracFone / Verizon prepaid) often lock this behind **~60 days
of active service** and/or a carrier unlock. There is no software bypass — the toggle un-greys
itself once the carrier releases it. If you bought it unlocked/retail this won't apply.

---

## 2. Back up first (so a mistake is recoverable, not fatal)

Unlocking the bootloader **factory-resets the phone** and shows a scary boot warning forever after
(harmless). Before that:

```bash
# Pull whatever is already on it via adb (photos, etc.)
mkdir -p ~/moto_fogona_backup && cd ~/moto_fogona_backup
adb pull /sdcard/ ./sdcard_backup/     # user files only; not a full image
```

Also **download the exact stock firmware** for your build now, from the Lolinet mirror
(`mirrors.lolinet.com/firmware/moto/fogona/`). You need it for two reasons: to extract
`init_boot.img`, and to reflash to stock if anything goes wrong. Match the build number under
**Settings → About phone → Build number**.

> Full-image safety-net note: without a custom recovery you can't take a full nandroid backup, so
> the stock firmware ZIP *is* your recovery image. Keep it.

---

## 3. Unlock the bootloader (official Motorola flow)

```bash
adb reboot bootloader          # phone enters the bootloader
fastboot devices               # confirm fastboot sees it (should now, thanks to §1.2)
fastboot oem get_unlock_data
```

`get_unlock_data` prints several lines. **Concatenate them into ONE string** (strip the
`(bootloader)` prefixes and spaces). Then:

1. Go to **Motorola's official bootloader unlock page**, sign in, paste the string, and check
   eligibility. If eligible, Motorola emails/returns a **unlock key**.
2. Apply it:

```bash
fastboot flashing unlock       # follow on-screen: Volume to select, Power to confirm
# older prompt variant, if the above is rejected:
# fastboot oem unlock <KEY_FROM_MOTOROLA>
```

The phone wipes and reboots. Re-run §1.1 (debugging + OEM toggles reset on wipe).

---

## 4. Root with Magisk (patch `init_boot`, not `boot`)

1. **Get Magisk 27.0 APK** onto the phone and install it (`adb install Magisk-v27.0.apk`).
2. **Extract `init_boot.img`** from the stock firmware ZIP you downloaded in §2 and copy it to the
   phone:
   ```bash
   adb push init_boot.img /sdcard/Download/
   ```
3. In **Magisk → Install → Select and Patch a File →** pick `/Download/init_boot.img`. Magisk
   writes `magisk_patched-<rand>.img` to `/sdcard/Download/`.
4. Pull it back and flash it:
   ```bash
   adb pull /sdcard/Download/magisk_patched-*.img ./
   adb reboot bootloader
   fastboot flash init_boot magisk_patched-*.img
   # If you see "Preflash validation failed":
   fastboot reboot fastboot        # drops into fastbootd
   fastboot flash init_boot magisk_patched-*.img
   fastboot reboot
   ```
5. First boot is slow — normal. Open Magisk; it should report installed. Root confirmed.

> **Why `init_boot`:** this generation keeps the ramdisk in a dedicated `init_boot` partition.
> Patching `boot` will not give root (and can boot-loop). If Magisk's **Ramdisk = Yes** but a
> separate `init_boot` exists, `init_boot` is still the correct target here.

---

## 5. Turn it into the "ants" appliance (kiosk lockdown)

Per the overview: **stay on rooted Android + kiosk** (a full Linux distro like postmarketOS is not
practical on fogona today). Goal: boots to landscape, one big **ants** tile, nothing else a
6-year-old can wander into.

**Recommended path — Fully Kiosk + a launcher lock:**
1. Install your **Ant Explorer APK** (`adb install AntExplorer.apk`).
2. Install **Fully Kiosk Browser/App** (it can run a native app in kiosk) *or* **Nova Launcher**
   locked down. For a single native APK, the cleanest is a lightweight **home-app lock**:
   - Set Ant Explorer (or a minimal launcher) as **Home** app.
   - **Lock task / screen pinning:** Settings → Security → *App pinning* ON, then pin Ant Explorer.
     This alone stops most 6-year-old escapes without any extra software.
3. **Force landscape system-wide** and hide chrome:
   ```bash
   adb shell settings put system user_rotation 1       # 90° landscape
   adb shell settings put system accelerometer_rotation 0
   # Hide status + nav bars (immersive), reversible:
   adb shell settings put global policy_control immersive.full=*
   ```
4. **Magisk modules (optional, nice-to-have):** debloat, and a battery/thermal tweak for long
   sessions. Add an ad/host block module only if you use any web view.
5. **Storage for video stars:** drop a fast microSD in and keep the trimmed MP4s there (see
   `STRATEGY_STAR_ANT_DOCUMENTARIES.md`); the app reads them offline.

**Un-kiosk for maintenance:** unpin (Back+Overview), or
`adb shell settings put global policy_control null*` to restore bars.

---

## 6. Fast recovery (if a step goes wrong)

- **Soft-brick / bootloop:** reflash the matching stock firmware ZIP with Motorola's flow (or
  `fastboot` the individual images from the ZIP). This is why §2 said keep the firmware.
- **Lost root after an OTA:** OTAs overwrite `init_boot`; just re-patch and re-flash (§4).
- **adb stops seeing it again:** replug, re-accept the trust dialog, `adb kill-server &&
  adb start-server`. The udev rule from §1.2 is permanent.

---

## 7. The whole thing in ten commands (once toggles are on and firmware is downloaded)

```bash
# udev (one time)
sudo tee /etc/udev/rules.d/51-android.rules >/dev/null <<<'SUBSYSTEM=="usb", ATTR{idVendor}=="22b8", MODE="0660", GROUP="plugdev", TAG+="uaccess"'
sudo udevadm control --reload-rules && sudo udevadm trigger && sudo usermod -aG plugdev "$USER"
adb kill-server && adb start-server && adb devices -l   # accept trust prompt on phone
adb reboot bootloader && fastboot oem get_unlock_data   # -> Motorola portal -> key
fastboot flashing unlock                                # wipes; re-enable toggles after
# (patch init_boot.img in Magisk on device, pull it back)
adb reboot bootloader && fastboot flash init_boot magisk_patched-*.img && fastboot reboot
adb install AntExplorer.apk
```

That's the machine. Next docs build the world it runs.
