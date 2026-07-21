extends Node2D
## Small role glyph near the player ant (Phase 1: nurse droplet).

var _glyph: Polygon2D
var _follow: Node2D

func _ready() -> void:
	_glyph = Polygon2D.new()
	_glyph.color = Color(0.35, 0.55, 0.95, 0.95)
	_glyph.polygon = PackedVector2Array([
		Vector2(0, -8), Vector2(5, -2), Vector2(3, 6), Vector2(0, 9), Vector2(-3, 6), Vector2(-5, -2),
	])
	add_child(_glyph)
	visible = false
	Events.role_changed.connect(_on_role_changed)

func set_follow(target: Node2D) -> void:
	_follow = target

func _process(_delta: float) -> void:
	if _follow != null and is_instance_valid(_follow):
		global_position = _follow.global_position + Vector2(0, -22)

func _on_role_changed(role: int) -> void:
	visible = role != AntEnums.Role.NONE
	if visible:
		_glyph.color = AntEnums.role_color(role)
		modulate.a = 1.0
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2(1.25, 1.25), 0.12)
		tw.tween_property(self, "scale", Vector2.ONE, 0.12)
