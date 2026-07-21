extends Node2D
## One nest chamber: floor visual + walkable polygon for NavGraph.

@export var chamber_id: int = 0
@export var chamber_name: String = "nursery"
@export var floor_color: Color = Color(0.45, 0.32, 0.22)
@export var edge_color: Color = Color(0.28, 0.18, 0.12)

@onready var walkable_poly: Polygon2D = $Walkable
@onready var floor_poly: Polygon2D = $Floor

func _ready() -> void:
	if floor_poly:
		floor_poly.color = floor_color
	if walkable_poly:
		walkable_poly.color = Color(floor_color.r * 1.08, floor_color.g * 1.05, floor_color.b * 0.95, 0.35)

func to_nav_node() -> NavGraph.ChamberNode:
	var node := NavGraph.ChamberNode.new()
	node.id = chamber_id
	node.name = chamber_name
	var poly: PackedVector2Array = PackedVector2Array()
	if walkable_poly and walkable_poly.polygon.size() >= 3:
		for p in walkable_poly.polygon:
			poly.append(to_global(p))
	node.walkable = poly
	if poly.size() >= 3:
		var min_v := poly[0]
		var max_v := poly[0]
		for p in poly:
			min_v = min_v.min(p)
			max_v = max_v.max(p)
		node.world_rect = Rect2(min_v, max_v - min_v)
	else:
		node.world_rect = Rect2(global_position - Vector2(400, 220), Vector2(800, 440))
	return node
