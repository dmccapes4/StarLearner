extends Node
## Autoload signal bus.

signal world_tapped(world_pos: Vector2)
signal player_path_requested(world_pos: Vector2)
signal player_arrived()
signal zone_tapped(zone_id: String, zone_kind: String)
signal hamburger_pressed()
signal star_menu_visibility_changed(open: bool)
signal star_collected(star_id: String)
signal star_revealed(star_id: String)
## Locked / unrevealed tile: pan camera + gold outline to the action zone.
signal star_reveal_requested(star_id: String)
signal intro_done()

signal shed_opened()
signal shed_closed()
signal seed_selected(plant_id: String)
signal seed_cleared()
signal plant_planted(bed_id: String, slot: int, plant_id: String)
signal plant_uprooted(bed_id: String, slot: int, plant_id: String)
signal plant_watered(bed_id: String, slot: int, plant_id: String, stage: String)
signal plant_stage_changed(bed_id: String, slot: int, plant_id: String, stage: String)
signal plant_harvested(plant_id: String, total: int)
signal tool_changed(tool_id: String)
signal season_changed(season_id: String)
signal animal_tapped(animal_id: String)
