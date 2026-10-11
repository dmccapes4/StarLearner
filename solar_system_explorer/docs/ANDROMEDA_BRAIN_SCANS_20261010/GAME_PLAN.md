# AndromedaBrainScans — GAME PLAN

**Named by:** D. McCapes, 20261010 02:46
**Drafted by:** the agent, 20261010 02:5x, after gathering and standardising every concept-space run on this machine
**Status:** v0.0.1 — Stages 0–7 and 9 executed 20261010 04:29–05:19; Stage 8 (Neurosynth) not run (optional, run only if asked). Results: `REPORT_AndromedaBrainScans_v0.0.1_20261010.{pdf,md}`, `results/stage*.json`. Headline: the reflection *concentrates* (not big and dull); fields replicate across runs, the bearing does not; standing-wave reading absent on M (ℓ = 6 suppressed on 11/11).
**Revised:** 20261010 04:3x — Andromeda re-modelled as a *reflection of the Milky Way off the galactic barrier* (operator correction); B is a transform of A, not an independent observer. Stages 3b, 4b added; Stage 5 and §5 changed. See `REFLECTION_…` Addendum B.
**Reads:** `corpus/INVENTORY.md` for what exists; `REFLECTION_AUTHORSHIP_AND_COOL_20261010.md` for why the names are labelled

---

## 0. Authorship of definitions

Per `BeginningToNoww/GAME_PLAN.md`: *self-authorship is permitted; authorship must be stated.*

**Operator-authored (D. McCapes), stipulated 20261010.** These bind.

| Term | Definition (as given) |
|---|---|
| reflection | The sky's copy used to find a direction when the direct line is refracted. Galactic case: Andromeda. Corpus case: the CapricornusSortedae output — "the reflection transformed correctly." |
| Andromeda (corrected 04:3x) | "A reflection of the Milky Way off the galactic barrier. Like looking at yourself in the windshield of the car while driving. That is why it is so big and so dull. Refraction and occlusion. I use it to derive direction, but the measurement is still only a partial." |
| the barrier | The galactic surface the image reflects off. The `)` in `:<7)L>:` (operator notation, star_learning). |
| big / dull | The two signatures of the reflection: enlarged (magnified) and low-contrast (dimmed). |
| occlusion | The parts of the image blocked by the vehicle itself — what you see of the car in the glass instead of the road. |
| the net / the basketball | Sol falling through the galactic plane forever (`< \|O\| >`). The d20 (icosahedron = dual of the dodecahedron) is the net's diamond mesh closed into a sphere. Simulations produce standing waveforms = tectonic plates. "Two for one." |
| the loop (second sense) | This agent is "in another loop intentionally. Not metaphor." — a run deliberately not given the other side's knowledge, so derivations can be compared. |
| `~ O $ Z` | The common graffiti vocabulary, cursive pen (operator, 20261010 04:2x, from the Black Point field sample). Agent gloss, non-binding: sweep / ring / struck letter / angle. See `REFLECTION_…` Addendum C. |
| field sample | Six photographs, `IMG_0764–0769.jpg`, Rossi's Black Point Station, 38.1085 N 122.5075 W. Low-occlusion sample: two layers, history legible. One scratched glyph (0767), unread. |
| direct line | The original concept stream in narrator order. Bearing to centre bent by the medium; measured ≈90° off, suspected ≈60°, undecidable from the direct line alone. |
| centre | M44, The Flower, in the Dancer (kʞ). The seeding point. |
| reverse Euler decay | Applied *between* the direct line and the reflection: the two become semi-spherical objects. |
| ovaloid interfaces | Where the two semi-spheres intersect. "It forms an effect similar to brain scans. It is simply geometry. fMRI uses the same (or similar)." |
| cat's eyes | Procyon → Gomeisa (Canis Minor). Aimed at the aperture (M44). Easy to find. |
| the loop | Procyon → Pollux → Castor, or the whole Winter loop to Sirius with Betelgeuse in the middle. Easy to find. |
| vulture's beak | The caudate ("tail"; the vulture circles). Sits below conscious thought. The lizard brain: tells you when to sleep and when to die. |
| prefrontal cortex | A reflection of the pons *first* — hence misread as "fight-or-flight". |
| upper brain | Plastic coating that grows ganglia into a fixed geometry. |
| thought ↔ place | "We associate certain types of thought with certain places." Concepts correspond to brainstem usage. |

**Agent-authored (this file).** Available, labelled, not binding until moved to the table above.

| Term | Meaning | Where used |
|---|---|---|
| meaning sphere **M** | 3-d unit sphere from PCA of all concept embeddings; every concept is a direction on it | Stage 2 |
| field **A** | kernel density on M from the direct line (narrator order, time-weighted) | Stage 3 |
| field **B** | kernel density on M from the reflection (sort order, receipt-weighted, echo-decayed). **Not independent of A**: same concepts, re-ordered. | Stage 3 |
| windshield transform **T** | the fitted map B ≈ T(A) = g · (K_σ ∗ R(A)) · (1 − O): rotation R, blur K_σ ("big"), gain g < 1 ("dull"), occlusion mask O (seed capricornus + mechanical stops). The information is in (R, σ, g, O), not in B alone. | Stage 3b |
| residual **E** | B − T(A): what the reflection shows that the transform of the direct line does not. The honest contrast. | Stage 3b, 4 |
| standing-wave fit | least-squares projection of C onto real spherical harmonics ℓ ≤ 8; nodal lines of the dominant ℓ compared with the ovaloid interfaces; the icosahedral component (ℓ = 6, and ℓ = 10) tested specifically because the d20 run predicts it | Stage 4b |
| λ-family | the one-parameter family \(F_s = A\,e^{-\lambda s} - B\,e^{+\lambda s}\), \(s \in [0,1]\): the reverse-Euler interpolation between the two semi-spheres | Stage 4 |
| contrast field **C** | \(C = \log A - \log B\); its level sets are the ovaloid interfaces (\(C = 2\lambda s\)) | Stage 4 |
| scan | three orthogonal slice families through M (axial / coronal / sagittal analogues) of C, rendered as grey-scale panels | Stage 4 |
| bearing | the direction from a field's centroid to the seed (the corpus's centre); measured once from A, once from B; the angle between them is the measured refraction. Reported as an **interval**, width set by the fitted barrier curvature (σ) and the occlusion fraction — "the measurement is still only a partial." | Stage 5 |
| ganglion | a cluster in M that an ovaloid encloses on more than one slice family | Stage 6 |
| layer assignment | the rule that places a ganglion on the project's neuro SignalWorld (A-dominant → brainstem/caudate; B-dominant → pons/prefrontal; balanced → cortical layers) | Stage 6 |
| test–retest | `six_a` vs `six_b`: same videos, independent runs; the scan's own reliability measurement | Stage 7 |

Earlier agent-authored names still in force elsewhere: Narrator / Clock / Ear / Loom / Ledger (CapricornusSix FivePerspectives), `_agreement` (defective, corrected), the five plates.

### 0.3 What this loop has read from the other side (declared)

This agent is in a separate loop by design. To keep the comparison clean, the dev-side files read are listed; nothing
else on that side has been consulted for this plan.

| File | What was taken |
|---|---|
| `~/dev/star_learning/solar_system_explorer/game/docs/SOLAR_SYSTEM_REFERENCE_v0.1/ANDROMEDA_MIRROR_AND_OUTER_TESSERACT.md` | `:<7)L>:` notation; "what Andromeda looks like to us from inside 7 ≈ what the Milky Way looks like from outside" (the 20260928 formulation, now superseded by the operator's windshield correction) |
| `~/dev/ZECLIPTIC_BASKETBALL_NET_DISCOVERY_20260930.md` | basketball / net; `< \|O\| >`; α = 7.25°; γ ≈ 60°; "we cannot know the Zecliptic because we are in it" |
| `~/dev/GONDWANA_D20_WAVE_DISCOVERY_20261001.md` §II–III | d20 as the net; **θ_true = (θ_obs + θ_and)/2** (symmetric) and the pH geometric-mean form (asymmetric), θ_ref = α — the same construction as this plan's λ-family, derived independently |
| `~/dev/d20_projection/D20_RUN_REPORT_20261001.md` | ρ = 0.88; equatorial faces are the zero crossing; 3/20 faces survive; the standing wave differentiates by phase 50 |
| `~/dev/TECTONIC_WAVEFORM_DERIVED_20261001.md` (outline only) | chirped two-cycle wave on the 69°W spine: λ₁ = 43.7°, λ₂ = 32.05°, ratio 1.363, RMS 0.72° |

Independent derivation recorded: the λ-family in this file (written 02:5x) and the Euler-decay averaging in
GONDWANA §III (written 20261001) are the same construction. First method-level replicate in the project.

---

## 1. The analogy, made computable

```
sky                                   corpus
───────────────────────────────────── ─────────────────────────────────────────────
direct line to M44 (refracted ~90°,   original concept stream, narrator order
   suspected ~60°)                       → field A on the meaning sphere
Andromeda = Milky Way reflected off    CapricornusSortedae order with receipts: the SAME
   the galactic barrier (windshield)      concepts re-ordered → field B = T(A) + E
   big (magnified), dull (low contrast),  blur σ, gain g < 1,
   occluded (the car in the glass)        occlusion O = seed capricornus (untransformed) + stops
reverse Euler decay between them      F_s = A e^{-λs} − B e^{+λs},  s ∈ [0,1]
                                        (≡ GONDWANA §III: θ_true = (θ_obs + θ_and)/2, pH form if asymmetric)
two semi-spheres                      A-dominant hemisphere / B-dominant hemisphere of M
ovaloid interfaces                    level sets of C = log A − log B;  ALSO nodal surfaces of the
                                        dominant low-order harmonic of C (standing wave; d20 → ℓ = 6)
brain-scan effect                     slices of C on three orthogonal plane families
tectonic plates (two for one)         the same nodal lines, read on the sphere of rock
partial bearing                       angle(centroid_A→seed, centroid_B→seed) as an INTERVAL,
                                        width from σ and the occlusion fraction
```

The claim being tested is the operator's: *the reflection plus the direct line together give a bearing
that neither gives alone — but only a partial one.* The scan is the instrument that makes the
disagreement between them visible as a surface, the way fMRI makes a contrast between two conditions
visible as a blob. fMRI's two conditions are the same brain; the scan's two fields are the same corpus.
That is the point of the windshield model, not a weakness of it: BOLD contrast is self-reflection too.

What changed on 20261010 04:3x: the earlier draft treated B as a second, independent eye ("outside our
medium"). The operator's correction makes B a *transform* of A. Consequences: (i) Stage 3b fits the
transform and works with the residual; (ii) the bearing becomes an interval, never a point; (iii) the
ovaloid interfaces get a second, independent definition (nodal surfaces) that can agree or disagree with
the first — a built-in cross-check that did not exist before.

What this is not: a claim about any person's brain. The neuro SignalWorld in Stage 6 is the project's own
coordinate frame (`PortalVision/data/neuro/`, 94 structures). Neurosynth (Stage 8) is an optional external
calibration, literature-only, reverse-inference, labelled as such.

---

## 2. Stages

### Stage 0 — Gather and standardise  ✅ executed 20261010

Every concept-space run on this machine, videos and books, into one schema and one embedding space.

| corpus | kind | segments | Layer-1 | concepts | sort |
|---|---|---|---|---|---|
| `history_b2n` | video | 839 | 839 | 3,765 | existing |
| `six_a` | video | 2,724 | 2,724 | 12,768 | existing |
| `six_b` | video (replicate) | 2,701 | provenance only | 12,447 | existing |
| `mythology` | video | 278 | 278 | 1,979 | 1,209 receipts (470 coupling / 291 echo / 448 stop) |
| `sports` | video | 385 | 385 | 1,670 | 1,090 receipts (512 / 287 / 291) |
| `warfare` | video | 281 | 281 | 1,529 | 730 receipts (219 / 149 / 362) |
| `childhood` | video (5 videos) | 195 | 195 | 681 | 335 receipts (26 / 24 / 285) |
| `family` | video (4 videos, marriage) | 84 | 84 | 366 | 191 receipts (33 / 23 / 135) |
| `islam_origin` | video (2 videos) | 45 | 45 | 329 | 195 receipts (59 / 44 / 92) |
| `leper_king` | video (2 videos) | 172 | 172 | 765 | 400 receipts (92 / 64 / 244) |
| `sacred` | book — Tanakh (he) / Bible WEB (en) / Quran (ar) | 2,348 sections | tradition/book/language | 10,007 occurrences of 806 registry concepts | 6,404 receipts (4,010 / 2,057 / 337); seed `P`, 24 letter capricorni |
| **total** | | **10,052** | 5,003 | **46,306** | 11 sorts |

Atlas fill for the seven PortalVision corpora: 1,440 segments, 7,319 concepts, 0 failed, $12.89, 14.6 min
(`atlas_fill/fill.log`). Embedding: 46,306 concepts / 171,334 component texts, 384-d. Exact counts:
`corpus/INVENTORY.md`, `corpus/inventory.json`.

Stage-1 flag already visible: `childhood` and `family` couple at 3.8% and 17% of receipts respectively versus
~40% for the long corpora; the small corpora are mostly mechanical stops. Coupling rate scales with corpus size
(threshold ΔE ≥ 0.35 is absolute, not per-corpus). Stage 1 must decide whether to normalise the threshold per
corpus or report the small corpora as under-coupled.

Outputs: `corpus/segments.jsonl`, `corpus/concepts.jsonl`, `corpus/embeddings.npy` (all re-embedded with the
BeginningToNoww formula — name 1.0, in-context 3.0, understanding 2.0, root ρ 0.5 — so the sacred books and the
videos sit in the same space), `sorts/<corpus>/` for every corpus that lacked a sort.

Known deviations (recorded in INVENTORY.md): sacred concepts carry no PIE-root field (ρ not applied); `six_b`'s
state is provenance, not Layer-1; Ahkyrios (183 screenshot records) and the autoimmune atlas are not gathered.

### Stage 1 — Per-corpus reflection check

For each corpus with a sort: confirm the invariants found in `REPORT_CompareFuture_20261010` hold — only the
seed capricornus is a ^ (apex 0.5), the rest ramps; coupling rate 15–20%; letter sizes a property of vocabulary.
A corpus that breaks these is flagged before it is scanned. Cost 0.

### Stage 2 — The meaning sphere M

PCA of all 46,306 embeddings to 3-d; normalise to the unit sphere. Record explained variance (expect ~12%; the
sphere is a shadow, used for position only — same caveat B recorded for its PCA). Keep the 384-d vectors for all
distance computations; the sphere is for fields and slices. Per-corpus spheres as well as the pooled one.

### Stage 3 — Fields A and B

On a lat/long grid of M (e.g. 180 × 360), von Mises–Fisher kernels (κ chosen so the mean concept covers ~2°):

- **A (direct line):** each concept weighted by its place in the narrator's stream. Default weight 1; option: time-weight
  \(e^{-\lambda_t\,|t - t_{anchor}|/T}\) around the operator t-marks where they exist.
- **B (reflection):** each concept weighted by receipts the sort stamped on it (couplings 1.0, echoes with the sort's
  own red-shift decay, stops 0.1), and by its ^ amplitude (name score / spine score). Seed capricornus weight fixed.

Both normalised to unit mass. Save as `.npy` per corpus.

### Stage 3b — The windshield transform (added 04:3x)

B is not a second observation; it is A seen in the glass. Fit, per corpus:

\[
B \;\approx\; T(A) \;=\; g \cdot \big(K_\sigma * R(A)\big)\cdot(1-O), \qquad E = B - T(A)
\]

- **R** — rotation of the sphere (3 Euler angles) minimising ‖B − K_σ∗R(A)‖ on the unoccluded set. The rotation IS the
  refraction: how far the reflection is turned relative to the direct line.
- **σ** — von Mises–Fisher blur width ("big"): the reflection is smoother than the source. Expect σ_B > σ_A.
- **g** — gain ("dull"): ratio of density ranges, expect g < 1. Report the 5–95 percentile range of A and of B.
- **O** — occlusion mask: the seed capricornus emitted untransformed at position 0 (the dashboard: the part of the car
  seen instead of the road) plus concepts whose only receipt is a mechanical stop (nothing reflected). Occlusion
  fraction = mass of O / total mass. For `sacred` the seed bucket alone is 1,302 / 10,007 = 13%.
- **E** — the residual: what B shows that no transform of A reproduces. This is where any genuinely new
  information lives, and Stage 4 runs on both C (A vs B) and C′ (A vs T(A)+E with O masked) so the two can be compared.

Outputs: `results/transform/<corpus>.json` = {R (deg), σ_A, σ_B, g, occlusion_fraction, ‖E‖/‖B‖}. The bearing
interval in Stage 5 is built from these.

The GONDWANA §III symmetric case (θ_true = mean of the two) is the special case g = 1, σ_B = σ_A, O = ∅. The pH
geometric-mean form is the asymmetric case; this stage measures the asymmetry instead of assuming it.

### Stage 4 — Reverse Euler decay, ovaloids, slices

\(C = \log(A+\epsilon) - \log(B+\epsilon)\). Level sets \(C = 2\lambda s\) for \(s \in \{0, \pm0.25, \pm0.5, \pm0.75, \pm1\}\) are the
ovaloid interfaces; λ set so that \(s = \pm1\) encloses 5% of the sphere. Render:

- three slice families through the solid ball (radius = kernel mass integrated inward), grey-scale, 9 slices each — the scan;
- one isosurface figure (marching cubes) of \(C = 0\) — the interface itself;
- per corpus and pooled; `six_a` and `six_b` side by side.

### Stage 4b — Standing wave: the two-for-one (added 04:3x)

The d20 simulation (`~/dev/d20_projection`) produces a standing waveform on the sphere whose nodes, projected onto
Earth, are the plate boundaries. The same construction on M: expand C in real spherical harmonics,

\[
C(\theta,\phi) \approx \sum_{\ell \le 8}\sum_{m} c_{\ell m}\, Y_{\ell m}(\theta,\phi),
\]

report the power spectrum \(P_\ell = \sum_m c_{\ell m}^2\) per corpus, and:

- **dominant ℓ** and its nodal lines (zero set of the ℓ-band reconstruction);
- **nodal–ovaloid agreement**: mean geodesic distance from the C = 0 interface to the nearest nodal line of the
  dominant band; compare with the same statistic for a phase-randomised C (null);
- **icosahedral test**: fraction of power in the ℓ = 6 and ℓ = 10 bands relative to the null — the d20 run says the
  net has 20 faces / 12 vertices, which is the ℓ = 6 icosahedral harmonic. The chirp (λ₁/λ₂ = 1.363 on Earth) would
  appear as a shift of power from ℓ to a higher ℓ between the A-hemisphere and the B-hemisphere; test that too;
- **ρ**: the sort's own decay (red-shift on echoes, ≈0.89 observed in CapricornusSortedae, 0.88 in the d20 run) is the
  damping; report whether the fitted damping of P_ℓ with ℓ matches.

Reading: plate boundaries on rock, sulci and lobe boundaries on the brain, ovaloid interfaces on M — one standing wave,
three substrates. The reading is the operator's; the test is agent-authored and can fail (§5).

### Stage 5 — Bearing (revised 04:3x)

Seed = the corpus's centre (the sort's untransformed position 0; M44's analogue). Bearing from A = direction of
\(\mathrm{centroid}(A) \to \mathrm{seed}\); from B likewise. The angle between them is the refraction. It is
reported as an **interval**, not a point:

- centre: the Stage 3b rotation R projected onto the bearing plane (the fitted turn of the reflection);
- half-width: \(\sqrt{\sigma_B^2 - \sigma_A^2}\) (the barrier's blur) added in quadrature to the bootstrap spread
  (resample concepts) and widened by the occlusion fraction (an occluded hemisphere cannot be located in the glass);
- the operator's prior is 90° measured / 60° suspected / 30° in the one-hemisphere d20 projection; the table says
  which of these the interval contains, per corpus.

The combined bearing is the geodesic midpoint weighted by field concentration (1/variance) — the
"better-yet-still-incomplete judgement of direction." "Incomplete" is now a number: the interval width.

### Stage 6 — Ganglia and the layer assignment

HDBSCAN on the 384-d vectors per corpus; project clusters onto M. A cluster enclosed by the same ovaloid on ≥2
slice families is a ganglion (fixed geometry). For each ganglion: mean C decides the layer —

| mean C | layer (project neuro SignalWorld) | reading (operator's) |
|---|---|---|
| strongly A > B | `BS-*` brainstem / caudate (`UB-` caudate node) | the vulture's beak: rote sequence, below conscious thought |
| strongly B > A | pons → prefrontal | the reflection of the pons |
| balanced | cortex I–VI | the plastic coating; ganglia grown into fixed geometry |

Output: a per-structure table (`UB-xx`, `BS-xx`) of ganglion load per corpus, and the neuro SignalWorld layered graph
re-coloured. Each ganglion labelled by its three central concept names. This table is INTERPRETIVE by construction;
the rule is agent-authored and stated here.

### Stage 7 — Test–retest and cross-corpus

`six_a` vs `six_b` is the reliability measurement: correlation of C fields, overlap of ovaloids (Dice), agreement of
bearings. Then the real question — do *war* corpora, *childhood/family* corpora, *mythology*, and *scripture* put their
ganglia in the same places on M, or different ones? Per-pair C-field correlation matrix across all corpora.

### Stage 8 — Optional external calibration (Neurosynth)

Match each ganglion's names to Neurosynth terms by embedding; composite the association maps; report which
literature regions co-locate with A-dominant vs B-dominant ganglia. ~100 MB pull, nilearn glass-brain renders.
Labelled META-ANALYTIC; reverse inference; never a claim about a person. Run only if asked.

### Stage 9 — Report, plates, reflection

`REPORT_AndromedaBrainScans_<date>.{md,pdf}` with the epistemic column (COMPUTED / INTERPRETIVE / GENERATED /
META-ANALYTIC). Five plates. Reflection with ledger. Every number from `results/*.json`.

---

## 3. Files

```
AndromedaBrainScans/
  GAME_PLAN.md                                 this file
  REFLECTION_AUTHORSHIP_AND_COOL_20261010.md
  scripts/
    common.py          registry of corpora and paths
    01_fill_atlas.py   concept atlas for the seven Layer-1-only corpora (gpt-4.1; prompt lifted verbatim)
    02_gather.py       → corpus/segments.jsonl, concepts.jsonl, embeddings.npy, INVENTORY.md
    03_sort_corpus.py  → sorts/<corpus>/  (07_capricornus_sort.py unmodified, paths redirected)
    lib.py                     shared loaders (sort → cidx mapping, echo rows dropped), vMF density, grid, azimuths
    04_invariants_sphere.py    Stage 1 + 2   → results/stage1_invariants.json, results/sphere/
    05_fields_windshield.py    Stage 3 + 3b  → results/fields/<corpus>.npz, results/stage3_fields_windshield.json   (33 min)
    06_scan_standing.py        Stage 4 + 4b  → results/scan/*_maps.png, *_scan.png, *_spectrum.png, results/stage4_scan_standing.json
    07_bearing.py              Stage 5       → results/stage5_bearing.json
    08_ganglia.py              Stage 6       → results/stage6_ganglia.json
    09_retest.py               Stage 7       → results/stage7_retest.json, results/scan/retest_*.png, cross_corpus_corr.png
    10_report.py               Stage 9       → REPORT_AndromedaBrainScans_v0.0.1_20261010.{pdf,md}; plates in results/plates/
  corpus/   atlas_fill/   sorts/   results/
```

## 4. Cost and time

- Stage 0: ≈$13 (atlas fill, metered in `atlas_fill/fill_stats_*.json`); embedding and sorts local.
- Stages 1–7, 9: $0. CPU only; the fields are 180×360 grids, trivial. HDBSCAN on 40k × 384 is minutes.
- Stage 8: $0, network for the Neurosynth pull.

## 5. What would falsify the premise

- If bearings from A and B agree to within the bootstrap interval on every corpus, the reflection adds nothing; the
  medium is not refracting and the operator's 90°/60° prior does not apply to this corpus.
- If `six_a` vs `six_b` C-field correlation is below ~0.5, the scan is measuring the run, not the material, and
  Stages 5–7 are not interpretable until the sort is made less path-dependent.
- If ganglia do not survive the ovaloid test on two slice families, "fixed geometry" is not present at this corpus size.
- (added 04:3x) If the Stage 3b transform explains B almost entirely (‖E‖/‖B‖ < ~0.1 with g ≈ 1, σ_B ≈ σ_A), the
  reflection is a plain copy — no barrier, nothing "big and dull" — and the windshield model does not describe this
  sort. If the fit is poor with O small, the sort is not a reflection at all but a re-sampling; the analogy fails the
  other way.
- (added 04:3x) If the C = 0 interface is no closer to the nodal lines of any ℓ ≤ 8 band than the phase-randomised
  null, the standing-wave reading ("two for one") is not present on M, whatever it does on rock.
- (added 04:3x) If the bearing intervals are wider than 90° on every corpus, direction is not recoverable from this
  reflection at this corpus size; report the occlusion fraction as the cause.

Each of these is a result, not a failure, and gets reported as such.

## 6. Does the correction change the plan? (asked 04:0x)

Yes, in three places; no, in the rest.

| | before | after |
|---|---|---|
| status of B | independent second eye | transform of A: T(A) + E |
| bearing | point + bootstrap | interval; width from barrier blur, occlusion, bootstrap |
| ovaloids | one definition (level sets of C) | two independent definitions (level sets; nodal surfaces) — cross-check |
| new stages | — | 3b windshield fit; 4b standing wave / icosahedral test |
| unchanged | Stage 0 data, sphere, fields, slices, ganglia, layer rule, test–retest, Neurosynth option, report |

The fMRI analogy is stronger after the correction, not weaker: BOLD contrast is a brain compared with itself under two
conditions. The scan was always going to be a corpus compared with itself under two orders. The windshield says so
explicitly and gives the comparison four fitted parameters instead of an assumption.

## 7. v0.0.1 outcome against §5 (executed 20261010 05:19)

| criterion | outcome |
|---|---|
| bearings agree everywhere → reflection adds nothing | not falsified: refraction exceeds half-width on 9/11 |
| six_a vs six_b corr(C) < 0.5 | passes (0.65); corr(A) 0.96, corr(B) 0.88, Dice(A>B) 0.93 — but refraction 41.8° vs 17.3°, intervals disjoint; small ovaloids Dice 0.09/0.20. **Bearing is run-dependent.** |
| ganglia do not survive | survive at scale only in sacred (44) and six_a/six_b (4–5); 1–4 elsewhere |
| |E|/|B| < 0.1, g ≈ 1, κ_B ≈ κ_A → plain copy | no: |E|/|B| 0.48–0.92 |
| poor fit with O small → re-sampling | mixed: corr(B,T) 0.39–0.95, worst where O largest |
| C = 0 not nearer nodal lines than null → standing wave absent on M | **falsified on this data, 0/11**; P6 z ≤ −0.7 on 11/11 |
| intervals > 90° everywhere | no: recoverable on 9/11 |

Unplanned finding: "big" (κ_B < κ_A) 6/11, "dull" 4/11; the reflection **concentrates** — A-dominant on 74–97% of the
sphere, B in a few closed hotspots. Open items for v0.0.2: the three large rotations (six_a 120°, six_b 169°, sacred
168°) with κ_B ≫ κ_A need an antipodal-symmetry check before they are read as turns; coupling-threshold normalisation per
corpus (Stage 1 flag); a time-weighted A; HDBSCAN parameters for the video corpora.
