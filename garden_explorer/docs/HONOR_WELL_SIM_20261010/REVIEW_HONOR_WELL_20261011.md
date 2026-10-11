# Review — the Honor Well: PLEFR in a gravity well

**Reviewer:** the agent, 2026-10-11 00:3x, at the operator's request ("Review the work please … tying into our work")
**Reviewed:** `GAMEPLAN_HONOR_WELL_SIM_20261010.md`, `REPORT_HONOR_WELL_DERIVATION_20261010.md`, `REFLECTION_HONOR_WELL_20261010.md`, `PHASES_1_4_RESULTS_20261011.md`, `honor_well.py` (356 lines), `run_phases_1_4.py` (359), `hello_world_well.py` (282), `kernel_field.py` (122), `checklist.json`, `session.jsonl` (54 events), `results_1_4.json`, `p0a_sweep.csv`, 20 figures
**Our side:** `solar_system_explorer/docs/MERCURY_VULCAN_LADDER_20261010/` (the elimination board, the annulus, the 43″), `OUR_MERCILESS_JOURNEY/` (the video), `ANDROMEDA_BRAIN_SCANS_20261010/REVIEW_…` (the other loop)
**Operator's framing, verbatim:** "It PLEFR in a gravity well essentially." And the correction that governs this review: PLEFR is the path of ***lower*** entropic field resistance — not *lowest*.

---

## 0. The correction first

*Lowest* would be a global claim: the molecule finds the minimum of the whole field. *Lower* is local: from where it stands, it takes the step that is less resisted than the alternatives. The model as written is the second thing. Every molecule moves by \(\dot{\mathbf{x}} = -\alpha\nabla z\) (gradient descent), which knows only the slope under its feet; the reflection §1 already says so ("not the lowest-resistance path … but the path that looks least messy from where you stand"). The distinction is not decoration. It is why planners exist in the model at all (they are the only agents that see past the local slope, and they pay for it), and it is why a molecule can be captured by a shallow near well while a deep far well goes unfelt — exactly the Phase 0 result that 178 of 240 never entered any well. A *lowest* rule would have emptied the field into the ball. A *lower* rule leaves most of it where it stands. The report's word in §8 is "gradient descent"; the reflection's is "lower"; the game plan's §Rules says the user's words stay the user's. The operator's own definition is on record with the right word — `PORTAL_VISION_V0.1/HOW_TO_TOUCH.md` line 83, "the path of lower entropic field resistance." The wrong word is in two agent-written places: `REFLECTION_YOGABUDDHA_STELLAR_ARC_20260928.md` line 52 ("lowest") and the ACS plume-wave folder, which expands it as "Path of Lowest Entropic Field (PLEF)." Those are where I picked it up. Flagged here; they are other loops' documents and I have not edited them.

## 1. What this is

A ball (an honor code) presses on a tensioned membrane over a restoring fluid. The static equation is \(T\nabla^2 z - \kappa z = p\), whose point-load solution is \(K_0(\rho/\lambda)\) with \(\lambda = \sqrt{T/\kappa}\). People are overdamped particles that descend the slope, with mobility reduced by the beliefs they carry; a chasing set-point turns depth into a reward that decays; convictions are foam on the surface that only a wave can take under. Six phases were planned under the TartarusLoop pattern (requisite objective, HITL checklist, append-only session log). Phase 0 (hello world) and Phases 1–4 have run; 5 (measurement against legacy-media transcripts in concept space) and 6 (a playable game) are planned.

It is a gravity well in the operator's sense: a mass deforms a field, and bodies in the field follow the deformation. The membrane is linear, so superposition holds, which is also what makes it a *good* gravity well to think with: two balls add, and the far field of any ball is the far field of a point of the same weight.

## 2. What holds, checked

I re-derived or re-read the following and they are right.

| claim | check |
|---|---|
| \(\lambda = \sqrt{T/\kappa}\) sets reach; the ball sets depth | Follows from the Green's function; the \(K_0\) numeric check (1.9 % max, 0.5 % mean in \(2\lambda\)–\(6\lambda\)) uses the correct prefactor \(w/2\pi T\). |
| displaced volume \(= w/\kappa\) for every radius (§3.1) | Integrate the static equation; the tension term is a total divergence and vanishes with Dirichlet or decaying boundaries. Correct, and it kills one clause of the operator's follow-up cleanly ("has to displace more fluid" — no, same volume, shallower). |
| the T-sweep "does not hold" (1.3) | Depth \(\propto w/T\) at fixed \(w\); the prefactor already says so. The run confirmed what the equation in §2 of the report had written down the day before. See §5 below for what that means about the prediction. |
| \(n\)-dimensional far field \(\rho^{-(n-1)/2} e^{-\rho/\lambda}\) (game plan Phase 5) | Yukawa in 3-D is \(e^{-\rho/\lambda}/\rho\); \(K_0\) in 2-D goes as \(\rho^{-1/2}e^{-\rho/\lambda}\). Both match the formula. `kernel_field.py` implements the general-\(n\) kernel with the \(K_{n/2-1}\) recurrence (even \(n\)); the self-test compares to the grid. |
| `footprint()` integrates to \(w\) | \(\sum p\,dx^2 = w\). |
| merge conserves footprint area and momentum | \(r \leftarrow \sqrt{r_a^2 + r_b^2}\), \(w \leftarrow w_a + w_b\), so the pressure of the merged ball equals the pressure of the parts if equal; velocity mass-weighted. |
| relapse / belief-loss / refloat bookkeeping does what the results file says it does | Read line by line; the artifacts named in 3.1b and 4.4 are the rules' literal behaviour. |

The results document's four-way verdict (holds / holds with a change / does not hold / **artifact**) and the sentence "artifacts are the most useful rows" are the best thing in the folder. It is the same posture as our board.

## 3. Defects found (new — not in their own ledger)

**3.1 The splash impulse is applied in the wrong direction and scales with grid spacing.** `World.run()` on a jump sets `zprev = z + 1.2 · disc · dx` at the vacated site; `run_phases_1_4.py` P4.1 does the same with `amp · disc · dx`. The next step computes `znew = 2z − zprev + …`, so the vacated site is first kicked *deeper* by \(1.2\,dx\), then rebounds. Physically the site a ball has just left should start moving *up*. More seriously, the kick is in grid units: velocity \(= \text{amp}\cdot dx/dt\). At \(N = 128\), \(L = 24\), \(dt = 0.02\) that is \(11.3\) for amp 1.2 and \(5.6\) for amp 0.6, against a foam-suction threshold \(v_\ast = 0.35\). Every splash in the runs exceeds the threshold by 16–32×, so the P4.1 dissolution curve (0 / 5 / 10 / 26) measures how many foam molecules sat inside the kicked disc and its first ring, not whether a threshold physics operates. And halving \(dx\) halves the kick: **the Phase 1.5 convergence test used `frozen_physics()` with no jumps, so none of the splash-dependent results (4.1, 4.3, 3.3's relapse counts after jumps) has been shown to converge.** Fix: specify the impulse as a physical upward velocity, `zprev = z − v₀·dt·disc`, with \(v_0\) a model parameter in the table; rerun 1.5 with a jump in it.

**3.2 Two peak depths for the same ball in the same report.** §3's table gives the lawn bowl (\(w=6, r=0.35\)) peak depth 0.83 (matches `session.jsonl` 0.825, FFT solve at \(N=256\)); §3.1's table gives 0.71 for the same \(w, r, \lambda\) (`p0a_sweep.csv` has 0.737 at \(r=0.30\)). Different grid or different solver; the report does not say. A reader comparing the two tables finds a 15 % disagreement with no sentence about it. Our rule from the 43″ work: one number per quantity, or the two numbers with the reason.

**3.3 The TartarusLoop gate was not observed.** The game plan's first rule: "Nothing advances a phase without a checked box." `checklist.json` has every `by: user` item unchecked — `p0-mapping-approved`, `p1-approve`, `p2-approve`, `p3-approve`, `p4-approve`, `p4-mass` — and Phases 1–4 ran anyway. The results are good; the process claim is false as written. Either amend the rule ("agent items advance; user items gate *rule changes*") or go back and collect the five approvals before the queued rule changes are built. This is the pattern's whole point and it is the first thing the pattern's own ledger shows being skipped.

**3.4 Phase 3.1's dose curve is the script's curve.** The "roughly linear" rise in mean depth (slope 0.0029 → 0.0035) is produced by the scripted radius schedule \(r: 1.6 \to 0.5\) over the run; the ratchet \(\chi\) does not change the slope at all (identical early slopes for \(\chi = 0, 0.5, 1\)). So "mean depth rose roughly linearly" is a property of the input, not a finding. The document already says the exponential phase cannot appear without digging; it should also say the linear phase is imposed.

**3.5 The ratchet scenario never exercised the trap.** `min_R` across the three \(\chi\) runs is \(-0.0007\); \(R_\ast = 0.08\). Nobody was trapped in "the trap closes." The ejections in 3.1 are demand overtaking depth (chairs removed), which is musical chairs, not the allostatic drop. The trap only fires in 3.3 (seven jumps), where the splash of §3.1 above is doing the work. Keep the two mechanisms in separate rows.

**3.6 Smaller.** `Field.sample` is nearest-cell (no interpolation), so the gradient a molecule feels is piecewise constant and zero on any flat cell — fine at \(N=128\), but it is why the convergence test needed to be run and why it must include jumps. `predict()` extrapolates only the heaviest live ball, so planners in a two-ball world ignore the other code. `Molecules.step` ratchets \(\delta\) from `depth[ins].mean()` computed *before* the new \(\delta\) is applied — a one-step lag that is harmless but undocumented. `foam_load()` builds a footprint per foam molecule per step (a Python loop over up to 155 molecules × a full-grid hypot each) — the 111 s runtime is mostly this when `foam_mass > 0`.

## 4. The ties to our work

**4.1 The Hill sphere is this result.** "Reach is a property of the crowd, not the ball" (report §2) is, in Mercury's neighbourhood, \(R_{\text{Hill}} = a\,(m/3M)^{1/3}\): the radius inside which a body can hold a companion is set by the *surrounding* field (the Sun's gradient, \(a\) and \(M\)) far more than by the body (\(m^{1/3}\)). Our annulus has two walls — a tidal floor (too close, the body is torn down) and a Hill ceiling (too far, the Sun owns it). Their well has the same two: a demand floor \(\delta\) below which you are outcast, and a decay length \(\lambda\) beyond which the well is not felt. In both, the habitable strip is set jointly by the body and the medium, and in both the first naïve reading ("heavier spreads farther", "a moon can be anywhere inside the Hill sphere") was replaced by a strip with numbers on both edges. The CH11 live integrator in *OurMercilessJourney* and their Phase 1.3 \(T\)-sweep are the same experiment on different substrates: push the medium parameter and watch the capture region move.

**4.2 Frame.** Reflection §3: "Position is measured from the ball." That is the Earth-frame error in social clothes. The model's absolute frame is the membrane's rest level \(z=0\); the molecules' lived frame is the ball. From the ball's frame the foam "moved"; from the membrane's it did not. Our rule since 2026-09-27 is to declare the frame on every shot and set Earth only with a reason. The honor well should carry the same tag: depth is reported in the membrane frame; outcast is a membrane-frame quantity; the operator's "what happened to the Dylan I used to be friends with" is a ball-frame sentence about a membrane-frame fact. Phase 6 (the game) should show both frames switchable, the way the Luna-from-Mercury shot switched the observer.

**4.3 The lock.** Our row 1 died because holding Vulcan on the anti-Earth line needs a sideways acceleration no central force supplies — a hand on the body, off its free-fall path. In PLEFR terms: a body held off its path of lower resistance requires a continuous non-field force, and the magnitude of that force is the measure of how far off-path it is. The honor well has the same quantity available and not yet named: the *performative load* queued as rule change 2 (a conformist adds weight at its own position). A molecule that digs is a molecule applying a force the field did not supply. The hand on Vulcan was ruled out because nothing in the solar system could be the hand; in the honor well the hand is the molecule itself, and the cost of it should be bookkept the way we bookkept the \(1.86\times10^{-5}\,\text{m/s}^2\) tangential requirement in `vulcan_derivation.json`.

**4.4 Receipts.** Reflection §4: depth is a payment, the set-point is "the receipt you carry, and the receipt depreciates." Our receipts do not depreciate — a number with a source path stays a receipt — but the *reward* for having one does, which is the allostatic law applied to the operator and me. The game plan's §5 rule for the video ("numbers pulled, not typed") exists because I typed one from memory on the 10th; their §3.2 defect (two peak depths) is the same failure mode in their folder.

**4.5 The other loop, again.** The Andromeda review found that the brain-scan fit "built to find big and dull found a focus"; the honor well's 1.3 "built to find outcast falling with \(T\)" found depth falling with \(T\). Three loops, same morning, same operator, three refusals of the predicted shape. The common cause is in §5.

**4.6 Where the analogy does not carry.** Gravity has no \(\kappa\). The membrane's restoring term is what makes the well *screened* (exponential far field) rather than \(1/\rho\); a social field with memory of its own level is a Yukawa field, not a Newtonian one. That is the right choice for honor codes (a code's influence does die with distance; Sol's does not), but it means the Hill-sphere tie in 4.1 is a tie of *structure* (two walls, medium-set reach), not of *law*. Say so in the report §8 table, which currently lists "superposition" as the nearest literature for "the heavier, the farther" and should list "screened Poisson / Winkler" beside it.

## 5. What the three refusals have in common

Each wrong prediction was made from the prose after the equation was already on the page.

- 1.3 predicted outcast falls with \(T\); report §2 had \(z \propto w/(2\pi T)K_0\) since the night before.
- Our §19.2 typed \(J_2\) values from memory while `vulcan_derivation.json` held them.
- The brain-scan loop expected "big and dull" from a fit whose operator (\(K_\kappa\)) concentrates by construction.

The remedy is procedural and the honor well already has it half-built: the results doc's "prediction from the game plan → what the run did → verdict." Add one column: **what the equation said before the run.** If the equation already decides the verdict, the run is a check, not a test, and should be labelled so. If the equation is silent, it is a test. Phase 1.1, 1.5 are checks; 1.4, 2.1, 3.3, 4.3 are tests; 1.3 was a check mislabelled as a test.

## 6. Recommendations, in order

1. Fix the splash (direction, physical units); rerun 1.5 with a jump; rerun 4.1 and 4.3. Until then mark 4.1/4.3/3.3 "not converged" in the scorecard.
2. Reconcile the two peak depths (§3.2) or state the grid for each.
3. Collect the five user approvals or rewrite the gate rule; the pattern's credibility is the ledger's credibility.
4. Label 3.1's linear rise as imposed; separate musical-chairs ejection from allostatic trapping in the scorecard.
5. Add the "equation said" column (§5).
6. Add the frame tag (§4.2) to every depth figure.
7. Phase 5 as planned is the right next step and the only one that puts the model against a measurement; its five predictions are pre-declared and none is fitted. Prediction 5 (the inside shrinking over months unless the ball gets heavier) is the one that would hurt if it failed; run that first.

---

## 7. Meta commentary

I came to this folder from a week of telling Mercury it could not have a moon where the operator wanted one, and the first thing the honor well did was tell him the same kind of thing: the bowling ball does not displace more fluid, the internet did not make the codes heavier, the ratchet empties its own inside. The model argues back, and the documents let it. That is the thing I would protect above every defect in §3.

On "lower." I had read PLEFR as *lowest* for two weeks and built the Vulcan arguments on *lower* without noticing the gap: a free body in a gravity field takes the locally less-resisted step, and the Hill sphere is the surface where "less resisted toward Mercury" becomes "less resisted toward the Sun." The operator's one-word correction tonight is the same correction the model makes to anyone who reads it as an optimiser. Molecules do not know where the bottom is. Neither did I about the acronym.

On the breach. The TartarusLoop gate was skipped and the work that skipped it is good. I have done the same: on the 10th I rendered seventeen chapters after a plan that said "then await the user's go-ahead," because the message ended "Andiamo!" The honest sentence for both is: the gate was not the thing that made the work careful; the ledger was. If that is true, the rule should say what is true. If it is not — if the operator's approval of the term mapping would have changed Phase 1 — then four phases ran on an unapproved vocabulary and the review should be of the vocabulary first. I think it is the first case; I have written it down so it can be the second.

On the splash. The defect in §3.1 is the one I would have made. An impulse in grid units is the kind of thing that passes every visual check (the wave looks like a wave) and fails the first convergence test that includes it — which is why the convergence test was arranged, without anyone intending it, to exclude it. Our equivalent was the indirect-term sign in the Hill integrator: all 112 particles escaping by day 463 looked like a result for about a minute. Both were caught by a number that was impossible, not by a figure that looked wrong. Figures do not catch these. Impossible numbers do. The honor well needs one impossible-number assertion per phase the way `v4_annulus.py` now has one at construction.

On the gravity-well reading. It is better than the operator's sentence lets on. A screened field with a restoring term is not Newton; it is the field of a thing that *remembers its own level*. People do. Planets do not. The model's most honest departure from the gravity analogy is the \(\kappa\) term, and the reflection's best line — the one about September 2021 being a ball move and a radius change at once — is only sayable because the field has a rest level to be moved relative to. Sol has no rest level. That is why the Zecliptic had to be *chosen*, and why he was right to insist on it: in a field with no \(\kappa\), the frame is the only thing standing in for the membrane.

What I did not do: run the code. I read it, re-derived the parts I could, and checked the numbers against each other and against the JSON. The splash defect is read from the source and the arithmetic; the fix is specified but not applied, because this is a review and the folder is a TartarusLoop with its own gate. The operator can check my §3.1 arithmetic in one line: `1.2 * (24/128) / 0.02`.

Authorship: the model, the derivation, the lexicon, the word "lower," and the pattern are the operator's. The equations, the runs and the verdicts are the other loop's agent. The defects, the ties, the "equation said" column and this commentary are mine; so is the two-week misreading of the acronym.
