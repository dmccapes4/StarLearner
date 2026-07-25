#!/usr/bin/env python3
"""Effort simulation: how much player work does a full 24-plot garden take
in one 180 s season, under the real GardenState mechanics?

Mirrors game/scripts/sim/GardenState.gd exactly:
  - per-plot water: thirsty -> waters+=1, thirst_cd = max(1.5, thirst_interval)
  - stage advance needs waters >= need AND stage_time >= min seconds
  - on advance: waters=0, stage_time=0, thirsty=true (except grown)

Player agent: walks the real iso map (105 px/s), greedy nearest-actionable-bed
policy, fixed per-action interaction overhead (prompt open + tile tap).

Compares:
  layouts : fast_mono / bed_mono / bed_mixed / slow_mono
  watering: per_plot (current) vs per_bed (one action waters the whole bed)

Usage: python3 tools/sim_plot_effort.py [--overhead 1.2] [--json out.json]
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SEEDS = json.loads((ROOT / "game" / "data" / "seeds.json").read_text())
SEASON_SEC = 180.0  # overridden by --season
WALK_SPEED = 105.0
DT = 0.05

TILE_W, TILE_H = 64.0, 32.0


def tile_to_world(tx: float, ty: float) -> tuple[float, float]:
    return ((tx - ty) * TILE_W * 0.5, (tx + ty) * TILE_H * 0.5)


BED_TILES = [(0, 0), (3, 0), (6, 0), (0, 3), (3, 3), (6, 3)]
SLOT_OFFS = [(-0.35, -0.25), (0.35, -0.25), (-0.35, 0.25), (0.35, 0.25)]
BED_HALF = (1.05, 0.8)
SHED_DOOR = tile_to_world(-7 + 2.0, 2)  # east side of shed, door approach
SPAWN = tile_to_world(2, 4)

PLANTS = {p["id"]: p for p in SEEDS["plants"]}

STAGES = ["seed", "sprout", "growing", "grown"]


def waters_needed(stage: str, p: dict) -> int:
    return {
        "seed": max(1, int(p.get("waters_to_sprout", 2))),
        "sprout": max(1, int(p.get("waters_to_growing", 2))),
        "growing": max(1, int(p.get("waters_to_grown", 2))),
    }[stage]


def secs_needed(stage: str, p: dict) -> float:
    return {
        "seed": max(0.5, float(p.get("seconds_seed", 6.0))),
        "sprout": max(0.5, float(p.get("seconds_sprout", 8.0))),
        "growing": max(0.5, float(p.get("seconds_growing", 10.0))),
    }[stage]


def total_waters(p: dict) -> int:
    return sum(waters_needed(s, p) for s in ("seed", "sprout", "growing"))


class Slot:
    def __init__(self, pid: str, pos: tuple[float, float]):
        self.pid = pid
        self.pos = pos
        self.stage = "seed"
        self.waters = 0
        self.stage_time = 0.0
        self.thirsty = True
        self.cd = 0.0
        self.harvested = False
        self.planted = False  # planting happens in-sim
        self.grown_at: float | None = None

    @property
    def plant(self) -> dict:
        return PLANTS[self.pid]

    def tick(self, dt: float) -> None:
        if not self.planted or self.harvested or self.stage == "grown":
            return
        self.stage_time += dt
        if not self.thirsty:
            self.cd -= dt
            if self.cd <= 0.0:
                self.thirsty = True
                self.cd = 0.0
        self.try_advance()

    def water(self) -> bool:
        if not self.planted or self.stage == "grown" or not self.thirsty:
            return False
        self.waters += 1
        self.thirsty = False
        self.cd = max(1.5, float(self.plant.get("thirst_interval", 5.0)))
        self.try_advance()
        return True

    def try_advance(self) -> None:
        while self.stage != "grown":
            if self.waters < waters_needed(self.stage, self.plant):
                return
            if self.stage_time < secs_needed(self.stage, self.plant):
                return
            self.stage = STAGES[STAGES.index(self.stage) + 1]
            self.waters = 0
            self.stage_time = 0.0
            self.thirsty = self.stage != "grown"
            self.cd = 0.0


def dist(a: tuple[float, float], b: tuple[float, float]) -> float:
    return math.hypot(a[0] - b[0], a[1] - b[1])


def make_layout(name: str) -> list[list[str]]:
    """6 beds x 4 plot plant ids."""
    spring_fast = ["lettuce", "pea", "radish", "spinach"]
    spring_med = ["carrot", "cabbage", "strawberry"]
    spring_slow = ["onion"]
    if name == "fast_mono":
        return [["lettuce"] * 4 for _ in range(6)]
    if name == "slow_mono":
        return [["onion"] * 4 for _ in range(6)]
    if name == "bed_mono":
        kinds = ["lettuce", "pea", "radish", "carrot", "cabbage", "onion"]
        return [[k] * 4 for k in kinds]
    if name == "bed_mixed":
        kinds = spring_fast + spring_med + spring_slow  # 8 spring species
        return [[kinds[(b * 4 + s) % len(kinds)] for s in range(4)] for b in range(6)]
    raise SystemExit(f"unknown layout {name}")


def simulate(layout_name: str, per_bed_water: bool, overhead: float) -> dict:
    layout = make_layout(layout_name)
    beds: list[list[Slot]] = []
    for b, tile in enumerate(BED_TILES):
        row = []
        for s, off in enumerate(SLOT_OFFS):
            tx = tile[0] + off[0] * BED_HALF[0]
            ty = tile[1] + off[1] * BED_HALF[1]
            row.append(Slot(layout[b][s], tile_to_world(tx, ty)))
        beds.append(row)

    t = 0.0
    pos = SPAWN
    stats = {
        "walk_sec": 0.0, "idle_sec": 0.0, "act_sec": 0.0,
        "taps": 0, "water_actions": 0, "plot_waters": 0, "plant_actions": 0,
        "harvest_actions": 0, "shed_trips": 0, "bed_visits": 0,
    }

    def advance_time(dt: float, kind: str) -> None:
        nonlocal t
        steps = max(1, int(round(dt / DT)))
        for _ in range(steps):
            t += DT
            stats[kind] += DT
            for row in beds:
                for sl in row:
                    sl.tick(DT)

    def walk_to(target: tuple[float, float]) -> None:
        nonlocal pos
        d = dist(pos, target)
        if d > 1.0:
            advance_time(d / WALK_SPEED, "walk_sec")
        pos = target

    def act(n_taps: int = 2) -> None:
        # prompt opens + player taps action tile (aim/decide)
        stats["taps"] += n_taps
        advance_time(overhead, "act_sec")

    # ---- Phase 1: plant everything (seed stays in hand per species) ----
    species_order: list[str] = []
    for row in layout:
        for pid in row:
            if pid not in species_order:
                species_order.append(pid)
    for pid in species_order:
        walk_to(SHED_DOOR)
        stats["shed_trips"] += 1
        stats["taps"] += 3  # tap shed, prompt "Seeds", tap seed tile
        advance_time(overhead * 1.5, "act_sec")
        for b, row in enumerate(beds):
            for sl in row:
                if sl.pid == pid and not sl.planted:
                    walk_to(sl.pos)
                    act()
                    sl.planted = True
                    stats["plant_actions"] += 1

    plant_done = t

    # ---- Phase 2: caretaker loop ----
    while t < SEASON_SEC:
        if all(sl.harvested for row in beds for sl in row):
            break
        # nearest bed with actionable slots
        best, best_d = -1, 1e18
        for b, row in enumerate(beds):
            actionable = any(
                (sl.planted and not sl.harvested and (sl.thirsty or sl.stage == "grown"))
                for sl in row)
            if actionable:
                d = dist(pos, tile_to_world(*BED_TILES[b]))
                if d < best_d:
                    best, best_d = b, d
        if best < 0:
            advance_time(DT, "idle_sec")  # wait for a thirst/stage event
            continue
        row = beds[best]
        walk_to(tile_to_world(*BED_TILES[best]))
        stats["bed_visits"] += 1
        # harvest all grown (always per-plot: prompt per plot)
        for sl in row:
            if t >= SEASON_SEC:
                break
            if sl.planted and not sl.harvested and sl.stage == "grown":
                walk_to(sl.pos)
                act()
                sl.harvested = True
                stats["harvest_actions"] += 1
        # water
        if per_bed_water:
            thirsty = [sl for sl in row if sl.planted and not sl.harvested and sl.thirsty]
            if thirsty and t < SEASON_SEC:
                act()  # one prompt: "Water bed"
                stats["water_actions"] += 1
                for sl in thirsty:
                    if sl.water():
                        stats["plot_waters"] += 1
        else:
            for sl in row:
                if t >= SEASON_SEC:
                    break
                if sl.planted and not sl.harvested and sl.thirsty:
                    walk_to(sl.pos)
                    act()
                    stats["water_actions"] += 1
                    if sl.water():
                        stats["plot_waters"] += 1

    for row in beds:
        for sl in row:
            if sl.stage == "grown" and sl.grown_at is None:
                sl.grown_at = t

    grown = sum(1 for row in beds for sl in row if sl.stage == "grown" or sl.harvested)
    harvested = sum(1 for row in beds for sl in row if sl.harvested)
    stage_counts: dict[str, int] = {}
    for row in beds:
        for sl in row:
            key = "harvested" if sl.harvested else sl.stage
            stage_counts[key] = stage_counts.get(key, 0) + 1
    return {
        "layout": layout_name,
        "watering": "per_bed" if per_bed_water else "per_plot",
        "overhead": overhead,
        "finished_at": round(t, 1),
        "plant_phase_sec": round(plant_done, 1),
        "grown_or_harvested": grown,
        "harvested": harvested,
        "stage_counts": stage_counts,
        **{k: (round(v, 1) if isinstance(v, float) else v) for k, v in stats.items()},
    }


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--overhead", type=float, default=1.2,
                    help="seconds of human overhead per prompt action")
    ap.add_argument("--season", type=float, default=180.0,
                    help="season length in seconds (use large value for unbounded)")
    ap.add_argument("--json", type=str, default="")
    args = ap.parse_args()
    global SEASON_SEC
    SEASON_SEC = args.season

    results = []
    for layout in ("fast_mono", "bed_mono", "bed_mixed", "slow_mono"):
        for per_bed in (False, True):
            results.append(simulate(layout, per_bed, args.overhead))

    # Theoretical per-plant numbers
    theory = {}
    for pid in ("lettuce", "carrot", "onion"):
        p = PLANTS[pid]
        iv = float(p.get("thirst_interval", 5.0))
        tmin = 0.0
        for st in ("seed", "sprout", "growing"):
            tmin += max(secs_needed(st, p), (waters_needed(st, p) - 1) * iv)
        theory[pid] = {"waters": total_waters(p), "min_grow_sec": round(tmin, 1)}

    print(f"season={SEASON_SEC:.0f}s  overhead={args.overhead}s/action  walk={WALK_SPEED:.0f}px/s")
    print("\nper-plant theory (waters to grown, min wall time if watered instantly):")
    for pid, v in theory.items():
        print(f"  {pid:8s} {v['waters']} waters  {v['min_grow_sec']}s min")
    hdr = ("layout      watering  done@s  plant@s  harvested  taps  waters  "
           "walk_s  act_s  idle_s  bed_visits")
    print("\n" + hdr)
    for r in results:
        print(f"{r['layout']:11s} {r['watering']:9s} {r['finished_at']:6.1f} "
              f"{r['plant_phase_sec']:7.1f} {r['harvested']:6d}/24   "
              f"{r['taps']:4d} {r['water_actions']:6d} {r['walk_sec']:7.1f} "
              f"{r['act_sec']:6.1f} {r['idle_sec']:6.1f} {r['bed_visits']:6d}")
        if r["harvested"] < 24:
            print(f"{'':21s} season ended: {r['stage_counts']}")

    if args.json:
        Path(args.json).write_text(json.dumps({"theory": theory, "results": results}, indent=1))
        print(f"\njson → {args.json}")


if __name__ == "__main__":
    main()
