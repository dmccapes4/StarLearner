# Research: Moto G Play (2024) sensors × six-year-old Free Flight motion

**Purpose.** Ground Free Flight accel / decel tuning (gear jerks, Cruise & Stop, joystick latch) in what the Ant Phone hardware can sense and what a ~6-year-old can reliably produce.

**Device under test.** Motorola Moto G Play (2024) — package target for Solar System Explorer playtests.

**Related code.** `game/scripts/PlaygroundScene.gd` (tilt, surge, joy latch); QA: `qa/run_flight_mechanics_suite.sh`.

---

## 1. Official hardware sensor list

Motorola Support lists these sensors for Moto G Play (2024):

- Accelerometer
- Proximity sensor
- Ambient light sensor
- Sensor hub
- Fingerprint sensor
- E-compass
- SAR sensor
- Barometer

Source: [Specifications — Moto G Play (2024) (Motorola Support)](https://en-us.support.motorola.com/app/answers/detail/a_id/177738/~/specifications--moto-g-play-%282024%29)

GSMArena’s catalog for the same model lists fingerprint, accelerometer, proximity, compass, barometer — again **no gyroscope**.

Source: [Motorola Moto G Play (2024) — GSMArena](https://www.gsmarena.com/motorola_moto_g_play_(2024)-12798.php)

### Design implication

| Sensor | Present? | How Free Flight uses it |
|--------|----------|-------------------------|
| Accelerometer | Yes | Gravity / tilt steering; linear surge for pull/push jerks and joy latch |
| Gyroscope | **Not on official list** | Do **not** depend on `Input.get_gyroscope()` for production feel |
| Magnetometer (e-compass) | Yes | Not used for flight |
| Barometer | Yes | Not used for flight |

Godot exposes `Input.get_accelerometer()` and `Input.get_gravity()` in **m/s²**. On this phone, gravity-vector tilt is the stable steering signal; surge is the residual along the “into the screen / pull toward self” axis after a quiet baseline.

---

## 2. What we do *not* know from the datasheet

Motorola and GSMArena do **not** publish:

- Accelerometer ASIC part number
- Full-scale range (±2g / ±4g / ±8g / ±16g)
- Output data rate (ODR) / noise density
- Whether Android’s fused gravity is hardware or software

Android’s public API reports range/resolution at runtime (`Sensor.getMaximumRange()`, `getResolution()`), but there is **no** public API to select full-scale range — that is firmware/driver fixed. Typical phone accel chips support selectable ±2g…±16g; many mid-range phones historically default near **±2g** per axis (community measurements on older Moto G class devices).

Sources:

- [Sensors overview (Android Developers)](https://developer.android.com/develop/sensors-and-location/sensors/sensors_overview) — units m/s²; capabilities queried at runtime
- [Android accelerometer max values (Stack Overflow discussion)](https://stackoverflow.com/questions/12739143/android-accelerometer-max-values) — notes common ±2g setups and inconsistent `getMaximumRange()` semantics on some Motos

**Working assumption for tuning (until a one-shot `dumpsys sensorservice` / Sensor Box capture on the Ant Phone):**

- Treat usable dynamic range for kid gestures as **well under 1g of extra linear accel** on top of gravity (~9.8 m/s²).
- Do not design for hard shakes or “floor the stick” peaks; design for gentle onset spikes that return to rest.

---

## 3. How Android motion maps into Godot Free Flight

```
phone accel (m/s², includes g)
        │
        ├─► low-pass gravity estimate  →  roll/pitch angles  →  tilt steering
        │      TILT_DEAD_RAD ≈ 0.035 rad (~2°)
        │      TILT_FULL_RAD ≈ 0.30 rad (~17°)
        │
        └─► residual along surge axis  →  jerk / joy latch
               quiet eps ≈ 0.18 (normalized surge units in game space)
               engage / backoff thresholds calibrated per child
```

Important physics fact for kids (and adults): **holding the phone at a fixed offset is not a sustained accelerometer “position.”** Once the shove stops, linear accel returns toward zero (plus gravity). That is why soft-hold throttle failed and why joystick mode **latches** a fixed accel/decel rate on onset, then clears only on a deliberate opposite return — not on quiet alone.

Constants of record (see suite asserts):

| Knob | Value | Kid-facing meaning |
|------|-------|--------------------|
| `TILT_FULL_RAD` | 0.30 rad | Full turn / pitch at ~17° — reachable without extreme wrist bend |
| `TILT_DEAD_RAD` | 0.035 rad | Hand tremor / resting wobble ignored |
| `JOY_RATE` | 12 u/s | Continuous speed ramp while latched |
| `JOY_BACKOFF_MIN` | 0.70 | Opposite spike must be strong — hold noise must not cancel |
| `JOY_SETTLE_IGN_S` | 0.65 s | Ignore “return” right after engage (onset settle) |
| `SURGE_JERK_*` | cal-derived | Gear / cruise jerks need a clear peak, then rest |

---

## 4. Six-year-old movement (what research says)

### Aiming and coordination

Children around age 6 still show developing feedforward control: aiming movements are often **slower, more curved, and less precisely timed** than adult reaches. Strategy and online correction are still maturing through middle childhood.

Source: [Development of feedforward control in children (Frontiers in Human Neuroscience, 2020)](https://www.frontiersin.org/journals/human-neuroscience/articles/10.3389/fnhum.2020.554378/full)

**Implication for Free Flight**

- Prefer **large, obvious gestures** (quick pull / push) over fine proportional holds.
- Aim gate (`GATE_HOLD_S` 0.8 s, `GATE_RADIUS_RAD` 0.26) should forgive wobble; skip on no-sensor desktop is fine for CI.
- Tutorial steps that require “hold still → shove → **return to rest**” match both physics and kid timing better than “hold at offset.”

### Wrist / arm acceleration magnitudes (wearables, not phones)

A pediatric ActiGraph study (ages 3–17, wrist accel, ±8g hardware, 30 Hz) reports day-long peak magnitude bands on the order of roughly **~1.7–2.2 g** (median-ish summary bands in the paper’s age tables — wear-time peaks, not game UI jerks). That confirms kids *can* produce multi-g spikes in free play, but **game gestures are intentional, smaller, and phone-mass-limited**.

Source: [Wrist-worn accelerometry in children and adolescents (Frontiers in Pediatrics, 2024)](https://www.frontiersin.org/journals/pediatrics/articles/10.3389/fped.2024.1361757/full)

**Implication**

- Do not set engage thresholds near adult “hard flick” peaks.
- Expect **noisier polarity** (tremor while “holding still”) → high backoff floor (`JOY_BACKOFF_MIN = 0.70`) and required opposite return during cal.
- Expect weaker / shorter jerks than an adult tester → cal clamps (`SURGE_ARM_MIN` / `SURGE_JERK_MIN`) matter more than fixed defaults.

### Practical kid-gesture model (for this game)

| Gesture | What the sensor sees | What the game should do |
|---------|----------------------|-------------------------|
| Rest / hold still | Near-gravity; surge ≈ 0 after baseline | Stay latched (joy) or wait for recenter (gears) |
| Quick pull | Short +surge spike, then settle | +1 gear / cruise / ACCEL latch |
| Quick push | Short −surge spike, then settle | −1 gear / stop / DECEL latch |
| Hold after shove | Spike gone; quiet | **Must not** reverse command |
| Deliberate return | Opposite spike ≥ backoff thr | Clear latch → READY |
| Gentle tilt ~10–17° | Stable gravity rotation | Steer; deadzone eats fidget |

---

## 5. Recommendations locked into production + QA

1. **No gyro dependency** for Free Flight on Moto G Play 2024.
2. **Onset + return-to-rest** is the kid-correct control language for throttle.
3. **Quiet alone never clears** a joy latch (asserted in `flight_mechanics` suite).
4. **Backoff threshold floor 0.70** so hold tremor cannot cancel ACCEL/DECEL.
5. **Tilt full ~17°** stays the steering budget; do not raise without playtest — larger angles fight small hands and landscape grip.
6. **Device verification (optional, next playtest):** on the Ant Phone, capture one `dumpsys sensorservice` (or a Sensor Box screenshot) for accel `maxRange` / `resolution` / vendor string and paste into an appendix here.

---

## 6. Sources

- [Specifications — Moto G Play (2024) (Motorola Support)](https://en-us.support.motorola.com/app/answers/detail/a_id/177738/~/specifications--moto-g-play-%282024%29)
- [Motorola Moto G Play (2024) — GSMArena](https://www.gsmarena.com/motorola_moto_g_play_(2024)-12798.php)
- [Sensors overview — Android Developers](https://developer.android.com/develop/sensors-and-location/sensors/sensors_overview)
- [Android accelerometer max values — Stack Overflow](https://stackoverflow.com/questions/12739143/android-accelerometer-max-values)
- [Development of feedforward control in children — Frontiers in Human Neuroscience (2020)](https://www.frontiersin.org/journals/human-neuroscience/articles/10.3389/fnhum.2020.554378/full)
- [Wrist-worn accelerometry in children and adolescents — Frontiers in Pediatrics (2024)](https://www.frontiersin.org/journals/pediatrics/articles/10.3389/fped.2024.1361757/full)
- Internal: `game/scripts/PlaygroundScene.gd`, `docs/QA_SUITE_PROCESS.md` (Star Learner shared process)
