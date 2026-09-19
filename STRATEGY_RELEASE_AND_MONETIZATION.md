# STRATEGY — Release to Family/Friends, then (maybe) Play Store Monetization

*How Star Learner grows from a one-off gift into a small fleet of gifted kiosks for
nieces and family friends — and what would actually be required to turn it into a
paid, publicly listed app. The single biggest blocker is **video licensing**: today's
"knowledge star" clips are trimmed from copyrighted YouTube documentaries, which is
defensible for a private family device and indefensible for a distributed or paid
product. This doc separates the two horizons, does an honest asset-by-asset license
audit, and lays out the "swap to free footage" path (which is mostly a matter of time).*

Related: [`README.md`](README.md) · [`NAMING.md`](NAMING.md) ·
[`ant_explorer/docs/KIOSK_APPLIANCE.md`](ant_explorer/docs/KIOSK_APPLIANCE.md) ·
[`ant_explorer/docs/STRATEGY_STAR_ANT_DOCUMENTARIES.md`](ant_explorer/docs/STRATEGY_STAR_ANT_DOCUMENTARIES.md) ·
[`ant_explorer/docs/BIBLIOGRAPHY.md`](ant_explorer/docs/BIBLIOGRAPHY.md)

---

## 0. TL;DR

| Horizon | What it is | Legal posture | Main work |
|---|---|---|---|
| **H1 — Family & friends** | Gift more locked-down phones (nieces, family friends) exactly like reef/cove | Private/personal use — reasonable at small scale, **do not publicly distribute the APK+footage** | Fleet provisioning + OTA + support; keep footage offline & credited |
| **H2 — Play Store, paid** | Star Learner becomes "just an app" anyone can install | Full commercial licensing required; **every third-party clip must be replaced** | Content re-sourcing (long pole), asset relicensing, Play kids-policy compliance, de-kiosk repackaging |

**H1 is a logistics problem. H2 is a content-licensing and compliance problem.** The
good news: the swap to free footage is source-agnostic (only each game's clip manifest
changes) and can be done incrementally, game by game, while H1 keeps shipping.

---

## 1. Why the current build is fine as a gift but not as a product

The "stars" format plays short documentary clips cut from copyrighted sources —
Deep Look/KQED, AntsCanada, BBC *Planet Ant*, National Geographic (see
[`BIBLIOGRAPHY.md`](ant_explorer/docs/BIBLIOGRAPHY.md)); Solar System Explorer uses a
YouTube clip-ingest pipeline as well. The project already documents this as
**"private family/educational use"** and prescribes: keep clips short, keep them
**offline** (never streamed, never re-hosted), and **credit every source in-app**.

That posture is a defensible personal-use corner **only** while:

- the footage never leaves the family device (no public APK download, no re-upload),
- the number of devices is tiny and gifted (not sold),
- clips stay short and attributed, and
- nothing is monetized off the back of the footage.

The moment money changes hands for the app, or the compiled app+footage is published
where strangers can get it, that corner disappears and each rights-holder (KQED, BBC,
Disney/NatGeo, individual creators) has a straightforward copyright claim. **Selling it
is the bright line.** Gifting a handful of locked devices to relatives is near that
line but on the tolerable side; a Play Store listing (free *or* paid) is clearly over it.

---

## 2. Horizon 1 — Family & friends fleet (nieces, family friends)

This is the natural next step and needs no content changes. It's the same appliance
model as reef/cove, multiplied.

### 2.1 What's already built and reusable
- **Kiosk lockdown**: device-owner enterprise lock-task (`com.dylan.star_learner`),
  landscape, immersive, no store/browser/notifications — proven on cove and reef.
- **Full deploy**: `tools/full_deploy.sh` builds+signs launcher+5 games, validates,
  and produces a SHA-256 bundle; `tools/full_deploy_245.sh` builds on 245 and publishes
  OTA staging.
- **OTA catalog growth** over the network — units keep getting new games/fixes after
  they're handed out.
- **Provisioning path**: unlock bootloader → Magisk root → set device owner →
  `enable_device_owner.sh` + `kiosk_on.sh`. (reef is currently the *account-removal,
  no-root* variant while it waits on OEM unlock; see §5.)

### 2.2 What to add for a multi-unit fleet
- **Per-unit identity & registry**: extend `tools/devices.sh` into a small fleet table
  (codename, serial, recipient, hub token, OTA channel, last-seen). Give each unit its
  own hub bearer token so one leaked token can be revoked without touching others.
- **Recipient-safe OTA channels**: a `stable` channel for gifted units and `staging`
  for reef/cove, so an experimental build never auto-lands on a niece's phone.
- **Zero-touch re-provision script**: one command that takes a fresh fogona from
  factory → fully locked Star Learner (unlock check, root, owner, deploy, validate,
  kiosk). Most pieces exist; wrap them into `tools/provision_unit.sh`.
- **Remote health/telemetry (privacy-safe)**: last-seen, app versions, free space,
  crash count — no child data. The hub already terminates ASR; add a tiny check-in.
- **Support kit for non-technical recipients**: printed one-pager (charging, Wi-Fi
  join for Language ASR, "it only plays games — that's on purpose"), plus a way for you
  to remotely help (ADB-over-network or a scheduled OTA).
- **Offline-first honesty**: only Language Explorer needs the network (ASR). Everything
  else must be 100% offline so a device in a car/rural home is still fully useful.

### 2.3 Licensing hygiene to adopt now (cheap, reduces risk)
- Keep the **attribution/credits block** visible in-app (already specified).
- Never post the APK bundle publicly; distribute by side-load to your own hardware only.
- Track, per game, which clips are third-party vs. owned/free — this becomes the H2
  worklist (see §4). Starting that ledger now makes H2 incremental instead of a wall.

---

## 3. Horizon 2 — Play Store & monetization ("then it would just be an app")

Publishing flips three switches at once: **content licensing**, **Google Play
child-app policy**, and **technical repackaging** away from the rooted-kiosk model.

### 3.1 Content licensing — the long pole
Every third-party asset must become one of: **owned**, **licensed for commercial
redistribution**, **Creative Commons with compatible terms (and correct attribution)**,
or **public domain**. This is not optional and not a grey area once the app is sold or
publicly listed. See the audit in §4 and the swap plan in §5.

### 3.2 Google Play policy for a child-directed educational app
Because the audience is young children, Star Learner falls under Play's strictest rules:
- **Designed for Families / "Teacher Approved"** program eligibility and review.
- **COPPA (US) + GDPR-K (EU)**: no collection of personal data from children without
  verifiable parental consent; the current offline design is an asset here.
- **Data Safety form + privacy policy** (required). Language ASR sends *audio* to your
  hub — that must be disclosed, minimized, ideally processed-and-discarded, and ideally
  made on-device or opt-in for a child-directed release.
- **Ads/IAP constraints**: child-directed apps have heavy restrictions on ads and
  behavioral targeting; a **paid app or family subscription** is cleaner than ads.
- **Account/permissions minimization**: no unnecessary permissions
  (`RECORD_AUDIO` only where Language needs it, clearly explained).

### 3.3 Technical repackaging (kiosk → installable app)
The current product *is a locked-down phone*. As a Play app it must run as a normal,
sandboxed app on someone else's device:
- Drop the device-owner/lock-task and root assumptions; make the launcher an optional
  "kiosk mode" the parent can enable (screen-pinning), not a requirement.
- Self-contained install: games either bundled or delivered via Play Asset Delivery
  (the current OTA-over-home-network mechanism won't exist for strangers).
- ASR hub must scale and be covered by the privacy policy, or move on-device.
- Signing, versioning, and store metadata (screenshots exist; need age rating,
  descriptions, localized listings for the EN/ES Language content).

### 3.4 Business-model options (rank later)
- **Hardware bundle** (sell the finished kiosk device) — closest to today's model,
  sidesteps some app-store friction, but you become a hardware vendor.
- **Paid app / one-time unlock** — simplest store model for a kids' app.
- **Family subscription** — recurring revenue for ongoing catalog growth; higher
  policy + support burden.
- Ads are discouraged for this audience; avoid.

---

## 4. Asset license audit (fill in before H2)

Track every game's dependencies. Status values: **OWN** (you made it),
**FREE** (CC0/public-domain/CC-BY with attribution), **LICENSED** (paid commercial
right secured), **BLOCKER** (third-party, no distribution right yet).

Concrete video inventory (counted in-repo, excluding `build/` and `docs/demo/` which
are your own screen recordings):

| Asset class | Current source (per repo) | H2 status | Action |
|---|---|---|---|
| **Ant star clips** (12 topics) | Deep Look/KQED, AntsCanada, BBC *Planet Ant*, NatGeo (YouTube) — `ant_explorer/docs/BIBLIOGRAPHY.md` | **BLOCKER** | Replace with CC/PD/own macro footage — hardest game |
| **Garden star clips** (~30: bugs, animals, growth stages) | third-party footage, `garden_explorer/docs/BIBLIOGRAPHY.md` + `tools/plant_media.tsv`/`stars.tsv` | **BLOCKER** | Nature/insect footage → CC-BY (iNaturalist/Wikimedia), PD, own macro |
| **Solar per-body openers** (11 bodies + belt) | NASA/mission footage (SDO, MESSENGER, Magellan, DSCOVR, Perseverance, Juno, Cassini, Voyager, New Horizons, Dawn) via YouTube; Psyche already pulls **direct from images-assets.nasa.gov (PD)**, Vesta from DLR | **PARTIAL — re-sourceable as PD** | Re-pull the same shots from **NASA/JPL/ESA direct** (public domain) instead of YouTube re-uploads |
| **Solar "explainer"** (plays under *every* body) | single YouTube channel: *VectorGlobe / @KnowtheWorld* | **BLOCKER** | Replace the connective explainer with own narration + owned animation/PD footage |
| **Math video** | **none in gameplay** (only `docs/demo` recordings = OWN) | **OWN / clear** | No clip re-sourcing needed; audit VO/art only |
| **Language video** | **none in gameplay** (only `docs/demo` recordings = OWN) | **OWN / clear** | No clip re-sourcing needed; audit VO/art only |
| **Narration (VO)** | ElevenLabs baked WAVs (all games) | **VERIFY LICENSE** | Confirm commercial-use tier + voice usage rights, or re-bake on a clearly-commercial voice |
| **Tileset — Sprout Lands** | credited in Ant README | **VERIFY LICENSE** | Confirm commercial license/purchase; free tiers are often non-commercial |
| **Kenney UI / fonts** | credited | **Likely FREE (CC0)** | Confirm each pack is CC0 |
| **Music** | `Music.gd` autoloads (Garden, etc.) | **AUDIT** | Confirm each track's license |
| **Fonts** | verify per game | **AUDIT** | Confirm OFL/commercial-ok |
| **ASR model/server** | self-hosted (`asr_server/server.py`) | **VERIFY MODEL LICENSE** | Confirm the speech model permits commercial use |

> Build this as a living `tools/asset_licenses.tsv` (one row per asset, with source URL
> and license) so H2 readiness is a checklist, not an archaeology dig.
>
> **Content-video reality:** only **3 of 5 games** carry third-party clips (Ant, Garden,
> Solar). Math and Language are already video-clean. Solar is a re-source (same NASA
> shots, pulled from PD origins) plus one explainer to remake; Ant and Garden need
> genuinely new footage.

---

## 5. The video swap — "switch to free videos, may just take time"

This is the crux and it's genuinely mostly *time*, not redesign: the pipeline is
source-agnostic (`build_stars.sh` reads a manifest of `id / start / end / url`), so
swapping footage = swapping manifest rows and re-cutting. Free/clearable sources:

- **Public domain (best, zero attribution risk):**
  - **NASA / ESA / JPL** imagery & video → Solar System Explorer (huge, gorgeous, PD).
  - **USGS, NOAA, US federal agencies** → nature/earth/weather content.
  - **Prelinger / Internet Archive** public-domain educational films.
- **Creative Commons (attribution, verify the specific license allows commercial +
  the specific clip is really CC):** Wikimedia Commons, some museum/university channels,
  CC-BY creators. Record license + author for each.
- **Own footage:** phone-macro of a local anthill, garden time-lapses, math
  manipulatives filmed on a table — royalty-free forever, and a nice "we filmed these
  together" story (already suggested in the bibliography).
- **Commissioned / stock with a commercial license:** last resort for gaps that PD/CC
  can't fill; budget a small amount per remaining star.

### Recommended order (fastest ROI first)
1. **Math + Language** → already video-clean (no third-party clips). Only need the VO /
   tileset / font / music audit; likely the first two games that can go distribution-ready.
2. **Solar System Explorer** → re-pull each body's opener from **NASA/JPL/ESA direct**
   (public domain — the manifest already does this for Psyche via images-assets.nasa.gov),
   then **remake the single VectorGlobe explainer** that plays under every body with your
   own narration + owned/PD animation. Mostly re-sourcing, not net-new footage.
3. **Garden Explorer** → ~30 bug/animal/growth clips; lean on CC-BY nature footage
   (iNaturalist, Wikimedia Commons), PD, and your own garden macro/time-lapse.
4. **Ant Explorer** → hardest (its whole reward layer is documentary clips). Mix CC-BY
   macro channels, PD, and your own filmed footage; expect this to take the longest.

Each game can graduate to "distribution-clean" independently. A game is H2-eligible only
once its row in `asset_licenses.tsv` has **zero BLOCKERs**.

---

## 6. Roadmap & decision gates

- **Now → H1**: keep gifting locked units (nieces, family friends) on the current
  private-use build. Add fleet registry, stable OTA channel, provisioning script,
  support one-pager. **No content changes needed.**
- **Parallel, low-urgency**: start `asset_licenses.tsv`; begin the **Solar → NASA/ESA**
  swap as the pilot for the clip-replacement workflow.
- **Gate to H2 (only if pursuing Play Store)**:
  1. All games' asset ledgers show zero BLOCKERs (footage, VO, tilesets, music, fonts,
     ASR model all OWN/FREE/LICENSED).
  2. Privacy policy + Data Safety written; ASR either on-device or opt-in+disclosed.
  3. De-kiosk repackaging done (optional screen-pinning, bundled/PAD assets, no root).
  4. Play Console set up; Designed-for-Families review passed.
  5. Business model chosen (lean: paid app or hardware bundle).

Reef's bootloader OEM-unlock is being watched by `tools/poll_oem_unlock.sh` on 245
(6-hour interval → `logs/oem_unlock_poll.log`, drops an `.UNLOCKED` marker when
eligible). That unblocks the *rooted* device-owner path for that unit; it is
independent of the licensing work above.

---

## 7. Open questions
- *(Resolved by in-repo audit:)* Math and Language ship **no** gameplay video; Garden
  **does** (~30 third-party clips). So §5's footage work is **Ant + Garden + Solar**.
- ElevenLabs: which plan baked the current VO, and does it grant commercial +
  redistribution rights for a paid app? If not, re-bake on a clearly-commercial voice.
- Sprout Lands tileset: which license tier is in use, and does it permit a commercial
  app? Same question for every music track.
- Which speech model backs the ASR server, and is its license commercial-friendly?
- Business model: hardware bundle vs. paid app vs. subscription — this shapes both the
  Play policy path and how much ongoing licensing/servers cost.
