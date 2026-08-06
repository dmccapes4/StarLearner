# Research: Child-accessible Free Flight controls

**Purpose.** Before changing Free Flight input, survey research, accessibility guidance, and commercial precedents for how children (and motor-diverse players) fly / steer on handheld devices — especially when they will not hold the phone in a “sim” posture.

**Status.** Research complete. Free Flight now ships **tap-only** controls (planet seek + directional taps + interactive stick + stop/cruise) — see `PlaygroundScene.gd` / APK 0.28.

**Related.** [`RESEARCH_MOTO_G_PLAY_2024_SENSORS_AND_KID_MOTION.md`](RESEARCH_MOTO_G_PLAY_2024_SENSORS_AND_KID_MOTION.md) (hardware + kid accel limits); Free Flight code in `game/scripts/PlaygroundScene.gd`.

**Playtest that triggered this (parent + daughter, Ant Phone).**

| Observation | Implication |
|-------------|-------------|
| Struggled with tilt / lift-lower gear scheme | Motion controls demand posture + dual-axis skill she did not want to invest |
| Did **not** want to hold the device straight in front of her | Any scheme that assumes a fixed “flight deck” grip will fight play style |
| Instinct: **tap the joystick image** as if it were a control | Affordances lied: cartoon stick reads as interactive; motion-only stick is confusing |
| **Tap-to-planet worked excellently** — small far targets easier for her fingers than for adult thick fingers | Destination selection is the strongest kid-native control we already have |
| Still thought the playground was cool | Core fantasy (being in space among planets) succeeded; controls are the bottleneck |

---

## 1. Verdict in one page

Industry accessibility guidance and child-HCI research converge on the same pattern our playtest already showed:

1. **Motion / tilt / gesture must be optional**, not the only path to key actions ([Xbox Accessibility Guideline 107: Input](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/107); [Game Accessibility Guidelines — digital vs gesture](https://gameaccessibilityguidelines.com/ensure-that-all-key-actions-can-be-carried-out-by-digital-controls-pad-keys-presses-with-more-complex-input-eg-analogue-speech-gesture-not-required-and-included-only-as-supplementary-al/)).
2. **Provide a simpler scheme** (or assist mode) so play does not require simultaneous precision axes ([GAG — simpler controls](https://gameaccessibilityguidelines.com/ensure-controls-are-as-simple-as-possible-or-provide-a-simpler-alternative/); [GAG — assist modes](https://gameaccessibilityguidelines.com/include-assist-modes-such-as-auto-aim-and-assisted-steering/)).
3. **Children’s “intuitive” controls are discovered by watching kids**, not by adult design intuition — and they often differ from what designers assumed ([Höysniemi et al., CACM 2005](https://cacm.acm.org/research/childrens-intuitive-gestures-in-vision-based-action-games/)).
4. Our daughter’s winning behavior maps cleanly to a known commercial pattern: **TouchDrive / destination choice** (Asphalt 9) and **assist steering** (Mario Kart), not to full manual flight ([GameAccess — Asphalt 9](https://gameaccess.info/asphalt-9-legends-1-3-button-racing/); [GAG — assist modes / Mario Kart anecdote](https://gameaccessibilityguidelines.com/include-assist-modes-such-as-auto-aim-and-assisted-steering/)).

**Highest-leverage option space for Free Flight (ranked for a ~6yo who won’t “hold it straight”):**

| Priority | Option | Why it fits the playtest |
|----------|--------|---------------------------|
| P0 | **Destination-first flight** (tap planet → seek / autopilot; empty space cancels) | Already loved; aligns with TouchDrive + single-pointer guidance |
| P0 | **Honest joystick affordance** — either make the HUD stick touch-driven, or stop drawing a stick | She already voted with her finger |
| P1 | **Kid / assist mode**: auto cruise + tap destinations + optional on-screen speed buttons | Same fantasy, fewer axes; matches Asphalt / Mario Kart assist philosophy |
| P1 | **Posture-agnostic play**: usable flat on lap / table; no required “in front of face” hold | Directly addresses refusal to hold straight |
| P2 | Keep **tilt + lift** as adult / challenge mode | Research: tilt can be fun and preferred by some, but has a learning cost and posture demand |
| P3 | Outside-the-box: voice cues, parent co-pilot, planet carousel, “follow the tour” rails | Expand later if P0–P1 still leave friction |

---

## 2. What child HCI says about “flying” controls

### 2.1 Kids invent the gestures — designers were wrong

Höysniemi, Hämäläinen, Turkki & Rouvi studied vision-based action games for ages ~4–9 (*QuiQui’s Giant Bounce*). For a **flying** character, adults first assumed “flap both hands = up, flap one hand = steer.” Kids could fly up, but sideways control frustrated them. Video showed the modal kid gesture was **lean sideways while flapping**. After the game matched that, kids spent ~34% less time on the level and were less frustrated ([Children’s Intuitive Gestures in Vision-Based Action Games — CACM](https://cacm.acm.org/research/childrens-intuitive-gestures-in-vision-based-action-games/); [ACM DL](https://dl.acm.org/doi/10.1145/1039539.1039568)).

They also used **Wizard of Oz** sessions: kids believe they control the game while an adult maps their motions — gather natural gestures *before* locking sensor code. Transitions and recovery time matter; young kids need rest between gross-motor bursts (they note ~4-minute rest intervals for 5–6yo flapping flight).

**Transfer to Free Flight.** Our daughter’s “tap the joystick picture” *is* her Wizard-of-Oz vote. Adult-designed lift/lower + tip-to-steer assumes a flight-sim posture she rejects. Destination taps are her natural mapping for “go there.”

### 2.2 Tilt can feel great — and still be the wrong default for kids

Gilbertson et al. built *Tunnel Run*, a 3D mobile driving game with **no buttons**, tilt-only vs traditional pad. Players found tilt fun and said they would not have played that genre otherwise ([Using “tilt” as an interface… — ACM CIE](https://dl.acm.org/doi/10.1145/1394021.1394031)).

Constantin & MacKenzie compared tilt **position-control** vs **velocity-control** in a maze: position was ~16% faster, but **10/12 adults preferred velocity** because it felt more natural ([YorkU write-up](https://www.yorku.ca/mack/ieeegem2014a.html)). Medryk & MacKenzie (cited there) found touch more accurate than tilt in a Pong-like task, yet some players preferred tilt for engagement — and tilt showed a larger learning effect.

**Transfer.** Tilt as *optional spice* is well supported. Tilt as *required* for a first session with a young child is not — especially when the child refuses the grip that makes tilt readable. Our Ant Phone also lacks a listed gyro ([sensor research](RESEARCH_MOTO_G_PLAY_2024_SENSORS_AND_KID_MOTION.md)), so we already lean on gravity tilt + linear accel; that is less forgiving of casual posture than a fused IMU.

### 2.3 Posture and fine control are linked — but kids won’t “stabilize for you”

Flatters et al. measured postural stability and manual dexterity in 278 children ages 3–11. Posture and hand skill are functionally linked (a stable platform supports precise hand work), yet after age correction posture explained only **1–10%** of manual-performance variance — gross and fine systems are partly independent ([The relationship between a child’s postural stability and manual dexterity](https://link.springer.com/article/10.1007/s00221-014-3947-4)).

**Transfer.** Asking a child to hold a phone “straight out” while also producing clean tip + lift gestures stacks two demands. If she prefers a lap / low / angled hold, the design should treat that as valid, not as user error.

---

## 3. Accessibility standards (directly applicable)

### 3.1 Xbox Accessibility Guideline 107 — Input

[XAG 107](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/107) is unusually concrete for mobile flying games. Relevant extracts:

- **Analog / motion alternatives:** anywhere analog is primary, offer single-press digital equivalents for the same tasks.
- **Gyro / tilt explicitly listed** among “challenging input types” to avoid *or* provide alternatives for (alongside prolonged holds, multi-finger gestures, rapid taps).
- **Asphalt 9 cited as exemplar:** control options include **TouchDrive**, **tap to steer**, and **tilt to steer**, with automatic acceleration available so players can avoid prolonged holds.
- **Mobile touch targets:** default ≥ ~15 mm on phones; adjustable size/position; inactive padding around controls.
- **Portrait + landscape:** support both — relevant for mounted / lap / wheelchair play, and for kids who won’t hold landscape-out.
- **Simplified schemes:** reduce number of controls (e.g. CoD Mobile “simple” auto-fire; Fortnite fire-mode choices).
- **Critical:** if motion is default, **digital alternative must exist**.

### 3.2 Game Accessibility Guidelines

From the [full list](https://gameaccessibilityguidelines.com/full-list/) and related pages:

| Guideline | Level | Relevance to Free Flight |
|-----------|-------|---------------------------|
| [Ensure controls are as simple as possible, or provide a simpler alternative](https://gameaccessibilityguidelines.com/ensure-controls-are-as-simple-as-possible-or-provide-a-simpler-alternative/) | Basic / Motor | Dual-axis tip + discrete lift gears is cognitively and motorically heavy for a first play |
| [Ensure key actions via digital controls; analogue/gesture only supplementary](https://gameaccessibilityguidelines.com/ensure-that-all-key-actions-can-be-carried-out-by-digital-controls-pad-keys-presses-with-more-complex-input-eg-analogue-speech-gesture-not-required-and-included-only-as-supplementary-al/) | Intermediate | Tip + lift should not be the only way to turn / change speed |
| [Include assist modes (auto-aim, assisted steering)](https://gameaccessibilityguidelines.com/include-assist-modes-such-as-auto-aim-and-assisted-steering/) | Intermediate | Parent testimonial for Mario Kart Auto Drive: a young motor-impaired child could play with family — directly analogous |
| Large, well-spaced virtual controls | Basic | On-screen speed / turn buttons if we go touch |
| Interactive elements should look interactive | Intermediate (cognitive) | Joystick *image* that does nothing violates this |
| Practice without failure / sandbox | Intermediate | Free Flight already is a sandbox — good |
| Adjust sensitivity / game speed | Basic | Soften tip gain; slower autopilot cruise for kids |

---

## 4. Games that already solve “I don’t want full manual flight”

### 4.1 Asphalt 9 — TouchDrive / tap / tilt triad

Asphalt 9 exposes three schemes: **TouchDrive**, **tap to steer**, **tilt to steer**, with auto-acceleration options ([XAG 107](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/107)). SpecialEffect’s GameAccess notes TouchDrive enables **auto turning and acceleration** while the player still chooses **route markers**, drift, and boost — playable with roughly **1–3 buttons** ([Asphalt 9 Legends \| Controls — GameAccess](https://gameaccess.info/asphalt-9-legends-1-3-button-racing/)).

**Free Flight analogue.**

| Asphalt | Free Flight |
|---------|-------------|
| TouchDrive path choice | Tap planet / POI → seek |
| Auto accel | Default cruise / auto throttle |
| Tap to steer | On-screen L/R or drag-look |
| Tilt to steer | Current tip (optional advanced) |
| Boost / drift as optional buttons | On-screen “faster / slower” gear buttons |

### 4.2 Mario Kart Auto Drive / assist

GAG’s assist-modes page quotes a parent: Auto Drive let a 4-year-old with hemiparesis steer with one hand while the game handled the rest ([assist modes](https://gameaccessibilityguidelines.com/include-assist-modes-such-as-auto-aim-and-assisted-steering/)). Assist is not “less game” — it is **access to the same fantasy**.

### 4.3 Infinite Flight — dual scheme for “serious” flying

Infinite Flight documents **Touch** (two on-screen sticks: roll/pitch and rudder/throttle) and **Tilt**, plus autopilot and external controllers ([Flight Controls guide](https://infiniteflight.com/guide/getting-started-guide/pilot-user-interface/flight-controls); community threads debating on-screen vs tilt). Even a hardcore sim refuses to ship tilt-only.

### 4.4 Pattern summary

Successful accessible / kid-friendly mobile motion games almost always ship **at least two of:**

1. Destination / route / autopilot selection  
2. On-screen digital controls  
3. Motion as optional  

Free Flight currently emphasizes (3) for continuous flight and already has a strong (1) for planets. The gap is **(2)** and making **(1) the primary kid path**.

---

## 5. Option catalog (research → design space)

No commitment to implement; options for a later decision. Grouped by how they answer the playtest.

### A. Destination-first / “solar TouchDrive” (strongly supported)

**Idea.** Primary loop: pick where to go; ship flies there; player enjoys the view. Secondary: cancel, retarget, optional fine steer.

- Already validated in playtest (far planet taps).
- Matches Asphalt TouchDrive + XAG “simplified schemes.”
- Small fingers can be an *advantage* for distant pixels (observed).

**Variants.**

| Variant | Player action | Ship behavior |
|---------|---------------|---------------|
| A1 Seek (current) | Tap body | Autopilot toward body |
| A2 Visit + tour | Tap or carousel | Visit, slow orbit, VO fact, then idle |
| A3 Route cards | Tap “Mars” / “Sun” chips | Same as seek, larger targets |
| A4 Follow rails | Start tour | Scripted path; tap to hop next stop |

### B. Honest virtual joystick / touch flight (matches her instinct)

**Idea.** If the UI shows a stick, the stick must move under a finger.

| Variant | Notes |
|---------|-------|
| B1 Virtual stick = pitch/yaw (or roll/yaw) | Classic mobile flyer; posture-free |
| B2 Split: left look/steer, right throttle | Infinite Flight Touch model |
| B3 Stick = speed only; tip optional | Matches “tap the stick to change speed” instinct |
| B4 Discrete pad under stick art | Up = faster gear, down = slower; left/right = tip substitute |

**Risk.** Occlusion of the sky; need large targets (≥15 mm) and padding ([XAG 107](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/107)).

**Affordances rule.** Either B\* or remove / redesign the joystick art so it no longer looks tappable ([GAG — interactive elements look interactive](https://gameaccessibilityguidelines.com/full-list/)).

### C. Assist / Kid mode (strongly supported by GAG + Mario Kart)

**Idea.** One settings tile: “Easy flight” / “Kid mode.”

Suggested defaults for that mode:

- Auto cruise on (or always moving slowly)
- Tip / lift **off** or greatly softened
- Tap-to-seek primary
- On-screen **Faster / Slower** (or none — fixed gentle speed)
- Optional gentle auto-level (horizon assist)

This is the accessibility-literature default answer: keep the world, reduce input complexity ([simpler controls](https://gameaccessibilityguidelines.com/ensure-controls-are-as-simple-as-possible-or-provide-a-simpler-alternative/); [assist modes](https://gameaccessibilityguidelines.com/include-assist-modes-such-as-auto-aim-and-assisted-steering/)).

### D. Posture-agnostic motion (if we keep any motion)

| Idea | Rationale |
|------|-----------|
| D1 Recalibrate rest to *current* hold (lap OK) | Don’t require “straight in front” |
| D2 Relative tip from last quiet pose | Reduces absolute posture demand |
| D3 Disable lift/lower in kid posture; tip-only or touch-only | Fewer axes |
| D4 Portrait support | XAG: mounted / alternate holds |

Note: accel-based lift/lower is especially posture-sensitive on a no-gyro Moto G Play ([sensor doc](RESEARCH_MOTO_G_PLAY_2024_SENSORS_AND_KID_MOTION.md)).

### E. Digital substitutes for every motion action (XAG / GAG intermediate)

| Motion today | Digital alternative |
|--------------|---------------------|
| Tip left/right | On-screen arrows / edge tap / drag |
| Lift / lower gears | `+` / `−` speed buttons or 3-speed strip |
| Cruise / stop | Toggle button |

### F. Outside the box (creative, lower priority)

| Idea | Precedent / rationale |
|------|------------------------|
| F1 **Voice / shout** for a fun action (boost, scan) | QuiQui fire-breath via shout ([Höysniemi](https://cacm.acm.org/research/childrens-intuitive-gestures-in-vision-based-action-games/)); never required ([GAG speech](https://gameaccessibilityguidelines.com/full-list/)) |
| F2 **Parent co-pilot** — Bluetooth / second touch / “help” hold | Shared control research + family play; parent tips while kid taps planets |
| F3 **Planet picker UI** (list / radial) instead of raycast | Larger targets; still destination-first |
| F4 **“Look where I look”** — face / ARKit (other devices) | Out of scope for Ant Phone camera-as-primary; optional later |
| F5 **One-thumb edge steering** — hold left half = turn left | Common casual mobile pattern; low cognition |
| F6 **Idle attract / auto tour** after N seconds of no input | Preserves wonder when stuck |
| F7 **WOz / playtest protocol** before locking next scheme | Höysniemi method: watch 2–3 kids, map instincts, *then* code |
| F8 **Haptic-only speed cues** with giant on-screen buttons | Reduces visual load; optional |

---

## 6. Mapping options → playtest friction

| Friction | Best-fit options |
|----------|------------------|
| Won’t hold phone straight | A, C, B, D1–D3, E |
| Taps joystick image | B1–B4 or remove stick art |
| Loves tapping planets | A1–A4 (lean in hard) |
| Struggles with tip + lift | C + E; demote motion to advanced |
| Still found it cool | Keep sandbox wonder; don’t add more tutorial gates |

---

## 7. Research gaps (honest)

- Few papers study **exactly** “6-year-old free-flight solar system on a phone.” We extrapolate from flying avatars (Höysniemi), tilt driving (Gilbertson), tilt order-of-control (Constantin/MacKenzie), motor accessibility standards (XAG/GAG), and commercial racing/sim precedents.
- “Thick fingers can’t hit far planets” vs “small fingers can” is an informal Fitts/target-size observation from this playtest — worth preserving as a design constraint (keep generous hit pads / magnetism), not as a published finding.
- We did not run a new controlled study; recommendations are **hypothesis-grade**, ready for a short second playtest with 1–2 schemes max (Höysniemi: don’t ship three conflicting metaphors at once).

---

## 8. Suggested decision path (when you choose to change code)

1. **Decide the primary metaphor for kid sessions:** destination-first (A) vs touch-stick (B) vs assist hybrid (C). Research + playtest point to **A+C**, with B if we keep stick art.
2. **Run one short WOz / paper-prototype session:** show two HUDs (planet chips vs real stick); see what she reaches for first.
3. **Keep adult motion mode**, but stop requiring it for the playground to feel complete.
4. **Affordances pass:** every decorative control either works or is redesigned so it doesn’t invite taps.
5. Re-read [`RESEARCH_MOTO_G_PLAY_2024_SENSORS_AND_KID_MOTION.md`](RESEARCH_MOTO_G_PLAY_2024_SENSORS_AND_KID_MOTION.md) before investing further in lift/lower polish for kids — hardware + posture may cap that path.

---

## Sources

- [Xbox Accessibility Guideline 107: Input](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/107) (updated Mar 2026)
- [Game Accessibility Guidelines — Full list](https://gameaccessibilityguidelines.com/full-list/)
- [Ensure controls are as simple as possible, or provide a simpler alternative](https://gameaccessibilityguidelines.com/ensure-controls-are-as-simple-as-possible-or-provide-a-simpler-alternative/)
- [Ensure key actions via digital controls; complex input supplementary](https://gameaccessibilityguidelines.com/ensure-that-all-key-actions-can-be-carried-out-by-digital-controls-pad-keys-presses-with-more-complex-input-eg-analogue-speech-gesture-not-required-and-included-only-as-supplementary-al/)
- [Include assist modes such as auto-aim and assisted steering](https://gameaccessibilityguidelines.com/include-assist-modes-such-as-auto-aim-and-assisted-steering/)
- [Asphalt 9 Legends \| Controls — GameAccess / SpecialEffect](https://gameaccess.info/asphalt-9-legends-1-3-button-racing/) (Mar 2019; updated Aug 2022)
- [Höysniemi et al. — Children’s Intuitive Gestures in Vision-Based Action Games (CACM)](https://cacm.acm.org/research/childrens-intuitive-gestures-in-vision-based-action-games/) (Jan 2005)
- [ACM DL — Höysniemi et al. 10.1145/1039539.1039568](https://dl.acm.org/doi/10.1145/1039539.1039568)
- [Gilbertson et al. — Using “tilt” as an interface… (ACM CIE)](https://dl.acm.org/doi/10.1145/1394021.1394031) (Nov 2008)
- [Constantin & MacKenzie — Tilt-Controlled Mobile Games: Velocity vs Position](https://www.yorku.ca/mack/ieeegem2014a.html) (IEEE GEM 2014)
- [Flatters et al. — Child postural stability and manual dexterity](https://link.springer.com/article/10.1007/s00221-014-3947-4) (Experimental Brain Research, 2014)
- [Infinite Flight — Flight Controls](https://infiniteflight.com/guide/getting-started-guide/pilot-user-interface/flight-controls) (updated Apr 2026)
- Internal playtest notes (parent + daughter Free Flight session) and [`RESEARCH_MOTO_G_PLAY_2024_SENSORS_AND_KID_MOTION.md`](RESEARCH_MOTO_G_PLAY_2024_SENSORS_AND_KID_MOTION.md)
