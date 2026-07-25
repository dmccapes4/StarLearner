extends Node
## Autoload signal bus — keep UI/sim/render loosely coupled.

signal world_tapped(world_pos: Vector2)
signal player_path_requested(world_pos: Vector2)
signal player_arrived()
signal sim_debug_updated(tick: int, hz: float)
signal role_changed(role: int)
signal star_collected(star_id: String)
## Locked rail tile confirmed (second tap): camera should reveal this star in-world.
signal star_reveal_requested(star_id: String)
signal intro_done()
signal larva_fed(larva_id: int, nutrition: float, jh: float)
signal larva_pupated(larva_id: int)
signal ant_eclosed(ant_id: int, caste: int)
signal egg_laid()
signal invader_event_started(kind: int, count: int)
signal invader_event_resolved()
signal garden_health_changed(health: float)
