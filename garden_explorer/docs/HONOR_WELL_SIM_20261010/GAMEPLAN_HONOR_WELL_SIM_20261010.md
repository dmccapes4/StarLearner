# Game plan — Honor Well simulation

**Date:** 2026-10-10  
**Pattern:** TartarusLoop. Requisite objective, HITL `checklist.json` approval per phase, `session.jsonl` as the run log. Nothing advances a phase without a checked box.  
**Requisite objective:** a simulation in which an honor code (a ball) deforms a social field (a fluid mattress), molecules (people) move on it by rules that encode beliefs, convictions, planning and crowd pressure, and the allostatic reward bookkeeping reproduces the trap the user described; with every rule traceable to a line in the derivation and every claim in the derivation either reproduced, modified, or marked open.  
**Stack:** numpy + matplotlib (+ pillow for the engraving). No engine. The whole thing must stay readable in one file per phase so the rules can be audited.  
**Companion:** `REPORT_HONOR_WELL_DERIVATION_20261010.md` has the equations; `REFLECTION_HONOR_WELL_20261010.md` has the why.

---

## Phase 0 — hello world? (done, this session)

**Objective:** one ball, centre of a square field with "hello world?" engraved; test the lawn-bowl/bowling-ball claim; one short dynamic episode with all four molecule kinds.

Delivered in `hello_world_well.py`:
- static membrane-on-foundation solve by FFT; three radii at one weight; logistic fit; sweeps of \(w\) and \(r\); capture radius versus demand \(\delta\).
- damped-wave dynamics; ball settles → drifts → shrinks → jumps; 240 molecules; allostatic set-points; outcast count; foam sunk by wave speed.
- `session.jsonl` with every static case, capture radius, splash, foam sinking, and the final counts.

**Findings to carry forward** (detail in the report §3, §7): reach is a medium property (\(\lambda = \sqrt{T/\kappa}\)); broad ball = shallow and wide, narrow ball = deep and small, which one "captures more" depends on \(\delta\); wall slope \(Dk \sim w/r\) is the user's \(k\); foam only sinks at the splash; planners reach deepest and fall furthest; most of a low-cohesion field never feels the well.

**Checklist (Phase 0):**
- [x] static solver matches the analytic \(K_0\) far field (checked visually on the profiles; a numeric check is Phase 1 item 1)
- [x] engraving held stationary (it is a load, not a free deformation)
- [x] wave equation's rest state equals the static solution (\(c^2 = T\))
- [x] foam does not sink in the absence of waves
- [ ] user approves the term mapping in report §8 (HITL)

## Phase 1 — make the field honest

**Objective:** verify the numerics and expose every parameter.

1. Numeric check: point-load profile against \(K_0(\rho/\lambda)\) to <2% beyond \(2\lambda\).
2. Non-periodic boundaries (the current FFT solve is periodic; the field should have an **edge**, because "the edges are safe but isolated" needs a real edge). Use a damped sponge layer or a Dirichlet solve.
3. Expose \(T, \kappa, \gamma\) as a `Medium` dataclass; run a \(T\)-sweep and report capture area and outcast fraction against \(T\). Prediction to test: outcast fraction falls as \(T\) rises.
4. Regional cohesion: \(T(x,y)\) as a map (clans, churches, workplaces as high-\(T\) patches). Prediction: wells propagate along high-\(T\) corridors and stop at low-\(T\) gaps.
5. Resolution/timestep convergence: halve `dx` and `DT`, confirm the outcast and reward curves do not move.

**Checklist (Phase 1):** `checklist.json` → `phase1`.

## Phase 2 — the ball has physics

**Objective:** balls move by rules instead of a script.

1. Ball state \((\mathbf{p}, \dot{\mathbf{p}}, r, w)\). Inertia \(\propto w\), drag \(\propto r\) ("bowling balls become more static").
2. Ball is pushed by the crowd: net force from molecules on the floor pushing the wall (crowd propulsion acting *on the code*). Prediction: a heavy crowd on one side rolls the ball that way — the code follows the mass.
3. Radius changes as a process: \(\dot r = f(\text{crowd density at floor}, \text{external shock})\). Government = slow \(\dot r\); influencer = fast \(\dot r\).
4. Multiple balls; pairwise interaction: rival codes repel at close range, aligned codes merge (sum of loads). Keep it to two balls first.
5. Splash model: impulse magnitude \(\propto w \cdot |\Delta \mathbf{p}|\); rebound at the vacated site.

## Phase 3 — the trap closes

**Objective:** make \(\delta\) a social variable so the dose escalates.

1. \(\delta(t) = \delta_0 + \chi \cdot \overline{d}_{\text{in}}(t)\): the demand is relative to how deep the insiders already are. Prediction: mean depth follows the user's linear-then-exponential curve; reward follows a logistic decay; the first ball change after saturation drops reward sharply below zero.
2. Per-molecule \(\eta_i\) (tolerance rate) drawn from a distribution; fast-tolerance molecules escalate first and are first ejected.
3. Record "gas station" events: a molecule with \(R_i < -R_\ast\) that re-enters a well within \(\tau\) steps. Count relapse rates by kind.
4. Belief loss: a surface molecule that has been on the floor for \(\tau_b\) steps drops one anchor (\(b_i \leftarrow b_i - 1\)), gaining mobility. This is the model's version of "dive deep to swim faster." Prediction: long conformity converts planners into deep swimmers, which are then the fastest to relocate when the ball jumps.

## Phase 4 — foam

**Objective:** give convictions a physics that can be falsified.

1. Foam buoyancy \(\beta_f\): the depth a foam molecule can be pushed to before it pops back. Dissolution if held under for \(\tau_f\) steps.
2. Foam mass (user decision, report §10 item 2): weightless vs. slight.
3. Foam aggregation: foam molecules near each other stick (rafts). Prediction: rafts at the edge are stable; a raft in the middle is broken by the first splash.
4. Foam re-formation: a sunk molecule whose set-point stays unmet for \(\tau_r\) steps and whose \(b_i = 0\) may re-float as foam with a single new conviction (the "Aslama" cycle: surrender → reconstruction → a new fixed point).

## Phases 1–4 — run 2026-10-11

See `PHASES_1_4_RESULTS_20261011.md` for verdicts and `checklist.json` for item notes. Rule changes queued from that pass: demand relaxation \(\mu\); molecules can dig (performative load); refloat requires a real deficit; crowd-force-on-ball per capita vs per footprint (user decision); compare societies at \(w \propto T\).

## Phase 5 — measurement against the world (revised 2026-10-11: legacy media in concept space)

**Objective:** replace the abstract square field with a concept space built the BeginningToNoww way, put the three nightly legacy-media shows on it as balls, and measure \(w, r, \mathbf{p}(t)\) from data rather than scripting them.

**Base space.** The field's base coordinates become concept space. BeginningToNoww's pipeline (`scripts/03_embed.py`: sentence-transformers, 384-d, `embeddings.npy` + `concept_index.jsonl`, with the ρ root-weighting) is reused as is; CapricornusSix's sort supplies the ordering. Project the 384-d space to \(n = 2\) or \(3\) base dimensions for the membrane (PCA or UMAP fitted on the atlas, then applied to the media so the axes are the atlas's, not the media's). Depth \(z\) stays a separate axis above the base, so the simulation is an \(n\)-dimensional membrane with one height dimension, exactly as now with \(n=2\).

**Balls from transcripts.** For each show (MSNBC, CNN, FOX primetime; one anchor show each, same hour) and each night:
- embed each segment; the night's cloud of segment embeddings projected to the base space;
- \(\mathbf{p}(t)\) = cloud centroid (where the code sits that night);
- \(r(t)\) = cloud spread (√trace of the covariance): topic breadth is footprint radius;
- \(w(t)\) = audience (Nielsen P2+ for the hour, or a proxy such as YouTube/clip views if Nielsen is not available);
- camp = network (rivals repel; same-network shows merge if they overlap).
A jump is a night whose centroid moves more than a threshold in one step: that is a splash and its ring is predicted.

**Molecules.** Options, cheapest first: (a) synthetic population seeded on the atlas distribution (`concept_distribution.png`) with the Phase 3 rules; (b) viewer comments or call-in transcripts embedded the same way, so molecule positions are measured too.

**Predictions to check against the measured balls** (no fitting):
1. Nights when a show's \(r\) shrinks should coincide with its centroid moving less (narrow = deep = static), and with higher churn in the comment population (chairs removed).
2. Rival balls should keep a separation that scales with \(w_a w_b\); same-network shows should converge.
3. The heaviest ball should be pushed by the mass: its centroid should lag and follow the comment-population centroid, not lead it.
4. A splash night should be followed by a measurable spike in comments that change position (foam sucked under), concentrated in a ring between the old and new centroids.
5. Over months the demand ratchet predicts the inside shrinking: a declining share of the comment population within the capture radius of each ball, unless the ball gets heavier.

**On dimensions and the math** (the user's question). The derivatives are the same in any \(n\): the Laplacian becomes \(\sum_i \partial_i^2\), the FFT solve is unchanged, molecules still descend \(\nabla z\), the allostatic rules do not see dimension at all. What changes is the Green's function and therefore the geometry of capture. In 2-D a point load gives \(K_0(\rho/\lambda)\); in 3-D it is the Yukawa form \(e^{-\rho/\lambda}/\rho\); in \(n\) dimensions the far field falls as \(\rho^{-(n-1)/2} e^{-\rho/\lambda}\), steeper with every added axis, while the volume a capture radius encloses grows as \(\rho^n\) and the volume of the whole space grows faster still. So a ball of the same weight in a higher-dimensional concept space holds a vanishing *fraction* of the space: wells get lonelier as dimensions are added. That is the curse of dimensionality stated for honor codes, and it is the reason to project to 2–3 base dimensions before putting balls down, which is what BeginningToNoww already does when it sorts to a waveform. The calculus is unchanged; what the calculus means is not.

Original observables kept as secondary checks: home-run scramble, crowd surfing (foam moved by hands), concert surge, spiral-of-silence surveys.

**Extension 2026-10-11 (operator request).** Scope widened to Daily Wire (Shapiro, Walsh) and Candace Owens, with the Owens / Daily Wire split and the "horseshoe right" (Shapiro's term) as the measured event; PyTorch infrastructure confirmed (torch 2.14 cu130, RTX 3060, `.venv-stone`); dimensions fixed at 384 stored → 32 processing → 8 state graph → 2 physics base, nested. The first 8-D run (`kernel_field.py`) showed the membrane kernel becomes a spike above \(n\approx 4\) (five orders of magnitude lost within one λ at \(n=8\)), which is why 8-d measures and 2-d simulates. Full plan, schema, dated receipts, and week-one steps: `PHASE5_NEXT_STEPS_20261011.md`. The operator's bias statement, verbatim, and how it is operationalised as an *operator molecule* on the same map: `OPERATOR_BIAS_STATEMENT_20261011.md`.

## Phase 6 — the game

**Objective:** make it playable so the user and his daughter can push the ball.

- Pygame or a notebook widget: drag the ball, scroll to change radius, click to drop a new ball, watch molecules and foam, see the reward and outcast meters.
- "hello world?" stays engraved on the first level.

## Files

```
HONOR_WELL_SIM_20261010/
  GAMEPLAN_HONOR_WELL_SIM_20261010.md     this file
  REPORT_HONOR_WELL_DERIVATION_20261010.md
  REFLECTION_HONOR_WELL_20261010.md
  hello_world_well.py                      Phase 0
  checklist.json                           HITL gates per phase
  session.jsonl                            run log (append-only; archive with timestamp before any reset)
  p0a_sweep.csv
  figures/
```

## Parameters to keep in one place (Phase 1 will move them to a dataclass)

| symbol | name | Phase 0 value | meaning |
|---|---|---|---|
| \(T\) | cohesion | 3.0 | neighbour coupling |
| \(\kappa\) | restoring | 1.0 | pull back to own level |
| \(\gamma\) | damping | 1.2 | wave decay |
| \(\delta\) | demand | 0.25 | depth required to count as inside |
| \(\eta\) | tolerance rate | 0.02 | set-point chase |
| \(v_\ast\) | foam suction speed | 0.35 | wave speed that sinks foam |
| \(c_b\) | anchor drag | 0.35 | mobility loss per belief |
| \(\Delta\) | planner horizon | 60 steps | how far ahead planners look |

## Rules of the loop

- Every phase ends with a run, a figure, a `session.jsonl` segment, and a checked box in `checklist.json` approved by the user.
- A claim from the derivation is never silently dropped. It is reproduced, modified with the modification stated, or marked open in the report's §9 table.
- The user's words stay in the user's words. The math is labelled as the agent's.
