# Ant Explorer — logic tests

Headless GDScript suite covering Phase 0/1 sim logic (brood, nurses, roles, nav).
UX is out of scope here.

## Run

From `star_learning/ant_explorer/game/`:

```bash
godot --headless -s res://tests/run_tests.gd
```

Or:

```bash
godot --headless --path /home/dylanmccapes/dev/star_learning/ant_explorer/game -s res://tests/run_tests.gd
```

Exit code `0` = pass, `1` = fail.

## Suites

| File | Covers |
|------|--------|
| `test_ant_enums.gd` | caste/brood/role helpers |
| `test_iso_util.gd` | tile ↔ world |
| `test_pathing.gd` | NavGraph + Pathing |
| `test_ant_state.gd` | path / reset |
| `test_save_game.gd` | SaveGame blob + Save autoload |
| `test_brood.gd` | feed, stages, pupate, eclose, destiny, eggs |
| `test_colony_roles.gd` | player nurse role, tend larva |
| `test_nurse_fsm.gd` | NPC nurse feed/JH/move/egg + auto ticks |
| `test_trail_marker.gd` | trail icon hit-test |
| `test_lifecycle.gd` | destiny paths + 2‑min budget |
| `test_sim_clock.gd` | tick ≠ frame |
| `test_map_pathing.gd` | 12-zone map, BFS tunnels, 1 star/room |
| `test_garden_economy.gd` | deposits, tend, decay, forager deposit |
| `test_forager_fsm.gd` | cut→haul loop, soldier patrol |
| `test_invaders.gd` | swarm→shake→flee, no colony deaths |
