# Advanced concepts — the "big kid ideas" track

A separate, **unlockable tutorial track** that plants the *intuitions* behind
calculus and differential equations without any of the notation. These are the
mental pictures you actually used when tutoring — rates, accumulation,
bottlenecks, equilibrium — stripped down to something a 6-year-old can *watch,
poke, and narrate back*.

Design rules for this track:

1. **No symbols, no formulas on screen.** Everything is a picture that moves.
2. **One idea per scene.** Each scene isolates a single intuition.
3. **She controls one knob.** A slider or a +/− that changes the picture in
   real time, so cause→effect is felt, not told.
4. **The math is in the motion.** Faster/slower, taller/shorter, filling/emptying —
   the derivative/integral is the *animation*, never a number she has to compute.
5. **Unlock, don't gate.** These live behind a "🚀 Big Kid Ideas" badge on the
   main card so they feel like a reward, not a harder tab.

---

## The ice cream shop — my honest verdict

**The full problem as you wrote it is too complicated for the game — but the
*idea* underneath it is one of the best on this whole list.** Here's the split:

### What's too much
The way you posed it is a genuine **queueing-theory / stochastic optimization**
problem:
- customers arrive at frequency `f(t)` (a *time-varying* Poisson-ish arrival rate),
- service time is a *distribution* (55% one scoop, 35% two, 10% three → a mixture),
- two **coupled** service stages (scoopers, then a cashier) → a two-stage queue
  network where the *slower stage sets the throughput*,
- and the goal is a **cost optimization** (minimize wait **and** idle staff).

That's a legit college problem (M/G/c queues, Little's Law, Erlang-C). No
6-year-old is solving it, and even *visualizing* the optimum honestly requires a
simulation with randomness she can't reason about. If we showed the "right"
answer she'd have to take it on faith — which breaks rule #4.

### What's gold
Buried in it are **three** clean, gut-level intuitions that are absolutely
worth building — just isolate them:

1. **Rate in vs. rate out (the core of every ODE).**
   A tank/line fills when *in > out* and drains when *out > in*. This is
   literally `dQ/dt = in − out`. The ice cream line **is** the tank.

2. **The bottleneck sets the pace.**
   Two stages in series: the *slowest* one decides how fast customers actually
   leave. Add a scooper when scooping is the jam; add a cashier when the register
   is the jam. Adding staff to the *fast* stage does nothing — a delicious,
   surprising lesson.

3. **More isn't free (the optimization gut-check).**
   Too few staff → line explodes (angry customers). Too many → workers stand
   around (wasted money). "Just right" is a *balance*. That's the intuition of a
   minimum / an optimum, felt as "the line stays short AND nobody's idle."

### Recommended build: **"Keep the Line Happy"** (simplified ice cream shop)
Make it a **sandbox toy**, not a word problem:

- A shop with a **customer line** on the left, a **scooping station**, and a
  **register**. Customers walk in on a timer (she can nudge a "busy / quiet"
  slider = `f(t)`).
- Two big **+ / −** dials: **# scoopers** and **# cashiers** (say 1–4 each).
- The line **grows and shrinks live** as she changes the dials. A little
  😀/😐/😡 face on the line shows how happy customers are (wait time).
- A **coin meter** ticks *down* for every idle worker → "extra staff costs money."
- **Win state:** hold the line short *and* keep coins from draining for ~20s.
  No numbers to compute — she *feels* the balance.
- Narration surfaces the three intuitions as they happen:
  *"The line is growing — you need another scooper!"* …
  *"Now everyone's standing around — that's wasting money."* …
  *"The register is the slow part — a scooper won't help!"*

This keeps the whole flavor of your problem (staffing, rates, cost) and quietly
teaches rate-in/rate-out, bottlenecks, and optimization — while staying a game.
**Verdict: build the simplified sandbox; keep the "solve for optimal staffing"
math as a hidden model that drives the faces/coins, never as something she sees.**

---

## The rest of the "Big Kid Ideas" track (from your tutoring toolkit)

Ordered easiest → deepest. Each is a candidate scene; all obey the design rules.

| # | Scene (working title) | Intuition (the real concept) | Her knob | The picture that moves |
|---|---|---|---|---|
| 1 | **Filling the Tub** | rate → accumulation (∫), and rate-in/rate-out (ODE) | faucet + drain sliders | water level rises/falls; a "how much water" bar fills as the *area* under the flow |
| 2 | **Steep Hill Racer** | slope = steepness = speed (the derivative) | drag to shape a hill | a ball rolls: steeper = faster. Flat = stops. "Speed is how steep it is." |
| 3 | **Bunnies!** | exponential growth (dP/dt = kP) | "how many babies each" | bunnies double and double — watch it go from cute to *whoa* |
| 4 | **Keep the Line Happy** | rate in vs out, bottleneck, optimum | # scoopers / # cashiers | ice cream line grows/shrinks; faces + coin meter (see above) |
| 5 | **Cooling Cocoa** | approach to equilibrium (Newton's cooling) | start temperature | steam eases off; a bar drifts toward "room temp" fast then slow |
| 6 | **See-Saw Balance** | equilibrium / stability | slide the weights | tips and settles; "balanced" is where it rests. Nudge → does it come back? |
| 7 | **Pizza Slices → Circle** | limits / "infinitely many tiny pieces" (the integral idea) | # of slices slider | more, thinner slices rearrange into a rectangle → area of a circle, felt |

### Why this set
- **Tub, Bunnies, Cocoa** are the three canonical first-order ODE shapes
  (linear accumulation, exponential growth, exponential decay-to-equilibrium) —
  the exact three pictures a diff-eq student should carry in their head.
- **Hill Racer** and **Pizza Slices** are the derivative and integral as
  *geometry* (slope, area) — no limits notation, just motion.
- **See-Saw** and **Line Happy** are stability and optimization — the "why do we
  care" payoff.

### Build order recommendation
1. **Filling the Tub** first — it's the simplest, most tactile, and it's the
   literal foundation ("stuff changes at a rate; it piles up") that every other
   scene reuses.
2. **Bunnies!** next — highest wow-factor, trivial to animate (just spawn + scale).
3. **Keep the Line Happy** third — most game-like, reuses the tub's rate-in/out
   engine with a queue instead of water.

Everything here can be built with the tools already in the project:
generated flat-vector sprites (`tools/key_sprite.py`), `Tween`-driven motion,
the crash-safe `Narrator`, and a single slider/dial per scene. No new tech.

---

## Deferred: the ice-cream *flavor inventory* problem

A second, much simpler ice-cream idea (deferred while we finish the basics —
blocks + story problems):

> The scooper must request more ice cream **before a flavor runs out**. Four
> tubs — Vanilla, Chocolate, Chocolate Chip, Mint Chocolate Chip — start with
> amounts (a1..a4). After one hour, sales have deducted (d1..d4) from each.
> What is each flavor's **rate** of sale? **How many hours** until each runs
> out? Next hour starts with new amounts and new deductions — how did the rates
> change? What does the rate look like computed **across both hours** from the
> original amounts?

Why it's a keeper: it is exactly a **slope / rate-of-change / linear
extrapolation** problem (`hours left = amount ÷ rate`), the two-hour follow-up
introduces **average vs. instantaneous rate** (the heart of the derivative),
and it visualizes perfectly — four tub gauges draining at different speeds,
"order more!" flags when a projected run-out crosses the hour line. It slots
into the track as a natural step between **Filling the Tub** (rate → level)
and **Keep the Line Happy** (rates + decisions). Unlike the staffing version,
everything is deterministic and computable by a kid: one subtraction (the
deduction), one division (hours left).

---

## Status
- [ ] Filling the Tub
- [ ] Steep Hill Racer
- [ ] Bunnies! (exponential)
- [ ] Keep the Line Happy (simplified ice cream shop)
- [ ] Ice-cream flavor inventory (rates + run-out projection)
- [ ] Cooling Cocoa
- [ ] See-Saw Balance
- [ ] Pizza Slices → Circle
