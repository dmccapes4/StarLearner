extends Node
## Root scene wiring for Garden Explorer.

@onready var world: Node2D = $World
@onready var tap_router: Node = $TapRouter

func _ready() -> void:
	var cam := world.get_node_or_null("CameraFollow") as Camera2D
	if tap_router and cam and tap_router.has_method("set_camera"):
		tap_router.call("set_camera", cam)
	var farm := world.get_node_or_null("FarmMap") as FarmMap
	var beds := farm.bed_count() if farm else 0
	var art_ok := false
	if world.get("sprites") != null:
		art_ok = world.sprites.available
	var n_stars := 0
	if world.get("star_db") != null:
		n_stars = world.star_db.star_ids().size()
	print("Garden Explorer Phase 6 — VO + save (%d beds, %d stars, sprites=%s)." % [
		beds, n_stars, art_ok])
	print("Hamburger ★ · shed · water/harvest · seasons · animals · ElevenLabs VO.")
