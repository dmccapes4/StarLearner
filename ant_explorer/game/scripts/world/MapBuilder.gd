class_name MapBuilder
extends RefCounted
## Builds NavGraph + visual chamber nodes from data/map.json.

const MAP_PATH := "res://data/map.json"
const _TerrainCatalog := preload("res://scripts/render/TerrainCatalog.gd")
const OBJECTS_SHEET := "res://assets/tiles/sprout_lands/Objects/Mushrooms, Flowers, Stones.png"

var leaf_spots: Array = []  ## Vector2 world positions
var star_placements: Dictionary = {}  ## zone name -> {star_id, pos}
var trail_placements: Array = []  ## {role, zone, scale?, width?}
var _terrain: RefCounted

static func load_map_dict() -> Dictionary:
	if not FileAccess.file_exists(MAP_PATH):
		push_error("MapBuilder: missing %s" % MAP_PATH)
		return {}
	var txt := FileAccess.get_file_as_string(MAP_PATH)
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("MapBuilder: invalid JSON")
		return {}
	return parsed as Dictionary

func build(parent: Node2D) -> NavGraph:
	var data := load_map_dict()
	var graph := NavGraph.new()
	leaf_spots.clear()
	star_placements.clear()
	trail_placements.clear()
	_terrain = _TerrainCatalog.new()
	_terrain.bootstrap()
	if data.is_empty():
		return graph
	var chambers: Array = data.get("chambers", [])
	for c in chambers:
		var node := _make_chamber_node(c)
		graph.add_chamber(node)
		parent.add_child(_make_chamber_visual(node, c))
		if str(c.get("star", "")) != "":
			star_placements[node.name] = {
				"star_id": str(c["star"]),
				"pos": node.center,  ## refined after tunnels exist
			}
	for t in data.get("tunnels", []):
		graph.add_tunnel(str(t["a"]), str(t["b"]))
		_add_tunnel_visual(parent, graph, str(t["a"]), str(t["b"]))
	# Stars after tunnels so we can push them away from mouths (pupae trap).
	for zone_name in star_placements.keys():
		var ch_star := graph.get_chamber_by_name(zone_name)
		if ch_star == null:
			continue
		star_placements[zone_name]["pos"] = _star_pos_away_from_mouths(ch_star, graph)
	for ls in data.get("leaf_spots", []):
		var ch := graph.get_chamber_by_name(str(ls["zone"]))
		if ch == null:
			continue
		var off: Array = ls.get("offset", [0, 0])
		var p := ch.center + Vector2(float(off[0]), float(off[1]))
		p = ch.clamp_point(p)
		leaf_spots.append(p)
		parent.add_child(_make_leaf_pile(p, int(ch.id) + int(off[0])))
	# Fungus / "mold" piles where gardeners work and foragers drop leaves.
	for zone_name in ["garden_a", "garden_b", "hygiene"]:
		var gch := graph.get_chamber_by_name(zone_name)
		if gch == null:
			continue
		parent.add_child(_make_fungus_patch(gch))
	for tr in data.get("trails", []):
		trail_placements.append({
			"role": str(tr.get("role", "")),
			"zone": str(tr.get("zone", "")),
			"scale": float(tr.get("scale", 1.6)),
			"width": float(tr.get("width", 14.0)),
		})
	graph.set_default_by_name("nursery")
	return graph

func _make_chamber_node(c: Dictionary) -> NavGraph.ChamberNode:
	var node := NavGraph.ChamberNode.new()
	node.id = int(c["id"])
	node.name = str(c["name"])
	node.kind = str(c.get("kind", "hub"))
	node.star_id = str(c.get("star", ""))
	node.is_outdoor = node.kind == "outdoor"
	var center_a: Array = c["center"]
	var half_a: Array = c["half"]
	var center := Vector2(float(center_a[0]), float(center_a[1]))
	var half := Vector2(float(half_a[0]), float(half_a[1]))
	node.center = center
	node.world_rect = Rect2(center - half, half * 2.0)
	# Soft hex-ish walkable
	node.walkable = PackedVector2Array([
		center + Vector2(-half.x * 0.95, -half.y * 0.7),
		center + Vector2(half.x * 0.95, -half.y * 0.7),
		center + Vector2(half.x, 0),
		center + Vector2(half.x * 0.95, half.y * 0.7),
		center + Vector2(-half.x * 0.95, half.y * 0.7),
		center + Vector2(-half.x, 0),
	])
	return node

func _make_chamber_visual(node: NavGraph.ChamberNode, c: Dictionary) -> Node2D:
	var root := Node2D.new()
	root.name = "Chamber_%s" % node.name
	root.z_index = 0
	var col_a: Array = c.get("color", [0.4, 0.3, 0.2])
	var fallback_col := Color(float(col_a[0]), float(col_a[1]), float(col_a[2]))
	fallback_col = fallback_col.lerp(Color.WHITE, 0.35)
	var kind := str(c.get("kind", "hub"))
	var floor_info: Dictionary = _terrain.floor_for(kind) if _terrain else {}
	var tex: Texture2D = floor_info.get("texture") as Texture2D
	if tex != null:
		# Keep Sprout Lands pastel colors — do not multiply map.json browns onto tiles.
		var info := floor_info.duplicate()
		info["kind"] = kind
		_add_tile_floor(root, node, info)
	else:
		var floor := Polygon2D.new()
		floor.color = fallback_col
		floor.polygon = node.walkable
		root.add_child(floor)
	if kind in ["outdoor", "garden"]:
		_sprinkle_cozy_props(root, node)
	return root

func _add_tile_floor(parent: Node2D, node: NavGraph.ChamberNode, floor_info: Dictionary) -> void:
	var tex: Texture2D = floor_info.get("texture") as Texture2D
	if tex == null:
		return
	var mod: Color = floor_info.get("modulate", Color.WHITE)
	var tile_scale: float = float(floor_info.get("tile_scale", 4.0))
	var variants: Array = floor_info.get("variants", [])
	if variants.is_empty():
		variants = [tex]

	# Soft under-fill matching the pack palette (covers any edge gaps).
	var base := Polygon2D.new()
	base.color = Color(mod.r, mod.g, mod.b, 1.0).darkened(0.04)
	base.polygon = node.walkable
	base.z_index = 0
	parent.add_child(base)

	# Gentle dirt rim so chambers don't read as hard-cut rectangles on the void.
	var rim := Line2D.new()
	rim.width = 10.0
	rim.default_color = Color(0.40, 0.30, 0.20, 0.85)
	rim.points = node.walkable
	rim.closed = true
	rim.z_index = 2
	rim.begin_cap_mode = Line2D.LINE_CAP_ROUND
	rim.end_cap_mode = Line2D.LINE_CAP_ROUND
	rim.joint_mode = Line2D.LINE_JOINT_ROUND
	parent.add_child(rim)

	var layer := Node2D.new()
	layer.name = "FloorTiles"
	layer.z_index = 1
	parent.add_child(layer)

	# Global step-aligned grid (same as tunnels) — no sub-pixel seams, no overlap.
	# Every cell picks from the kind's weighted Mid pool (Grass/Moss/Flowers/…).
	var step := float(tex.get_width()) * tile_scale
	if step < 4.0:
		return

	var r := node.world_rect.grow(step * 0.5)
	var min_cx := int(floor(r.position.x / step))
	var max_cx := int(ceil(r.end.x / step))
	var min_cy := int(floor(r.position.y / step))
	var max_cy := int(ceil(r.end.y / step))
	var seed_x := int(node.center.x)
	var seed_y := int(node.center.y)

	for cy in range(min_cy, max_cy + 1):
		for cx in range(min_cx, max_cx + 1):
			var pos := Vector2((float(cx) + 0.5) * step, (float(cy) + 0.5) * step)
			if not Geometry2D.is_point_in_polygon(pos, node.walkable):
				continue

			var vi := _variant_index(cx, cy, variants.size(), seed_x, seed_y)
			var tile_tex: Texture2D = variants[vi] as Texture2D
			if tile_tex == null:
				tile_tex = tex

			var spr := Sprite2D.new()
			spr.texture = tile_tex
			spr.centered = true
			spr.scale = Vector2(tile_scale, tile_scale)
			spr.modulate = mod
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			spr.position = pos
			layer.add_child(spr)

func _variant_index(col_i: int, row: int, count: int, seed_x: int = 0, seed_y: int = 0) -> int:
	if count <= 0:
		return 0
	# Deterministic per-cell hash so floors stay stable across runs.
	var h: int = (col_i * 83492791) ^ (row * 50331653) ^ (seed_x * 2654435761) ^ (seed_y * 2246822519)
	return int(h & 0x7fffffff) % count

func _sprinkle_cozy_props(parent: Node2D, node: NavGraph.ChamberNode) -> void:
	if not ResourceLoader.exists(OBJECTS_SHEET):
		return
	var sheet: Texture2D = load(OBJECTS_SHEET) as Texture2D
	if sheet == null:
		return
	var props := Node2D.new()
	props.name = "CozyProps"
	props.z_index = 2
	parent.add_child(props)
	# 16×16 cells from the objects sheet (low density, walkable only).
	var regions: Array = [
		Rect2(0, 0, 16, 16),
		Rect2(16, 0, 16, 16),
		Rect2(32, 16, 16, 16),
		Rect2(48, 16, 16, 16),
		Rect2(64, 32, 16, 16),
	]
	var half := node.world_rect.size * 0.5
	var center := node.center
	for i in 6:
		var col_i := int(((i * 92837111) ^ int(center.x)) & 0x7fffffff) % 5
		var row := int(((i * 689287499) ^ int(center.y)) & 0x7fffffff) % 4
		var off := Vector2(
			(float(col_i) - 2.0) * half.x * 0.35,
			(float(row) - 1.5) * half.y * 0.35,
		)
		var pos := center + off
		if not Geometry2D.is_point_in_polygon(pos, node.walkable):
			continue
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = regions[i % regions.size()]
		var spr := Sprite2D.new()
		spr.texture = atlas
		spr.centered = true
		spr.scale = Vector2(2.5, 2.5)
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.position = pos
		spr.modulate = Color(1.0, 0.98, 0.94, 0.92)
		props.add_child(spr)

const TUNNEL_HALF_WIDTH := 60.0

func _add_tunnel_visual(parent: Node2D, graph: NavGraph, a: String, b: String) -> void:
	var ca := graph.get_chamber_by_name(a)
	var cb := graph.get_chamber_by_name(b)
	if ca == null or cb == null:
		return
	var edge := graph.tunnel_between(ca.id, cb.id)
	var pts: PackedVector2Array
	if edge != null and edge.waypoints.size() >= 2:
		pts = edge.waypoints
	else:
		pts = PackedVector2Array([ca.portal_toward(cb.center), cb.portal_toward(ca.center)])

	# Dark earth border under the tile band (below chamber floors).
	var border := Line2D.new()
	border.width = TUNNEL_HALF_WIDTH * 2.0 + 30.0
	border.default_color = Color(0.29, 0.21, 0.14, 1.0)  # darker rim frames tunnels on the void
	border.points = pts
	border.z_index = -2
	border.begin_cap_mode = Line2D.LINE_CAP_ROUND
	border.end_cap_mode = Line2D.LINE_CAP_ROUND
	border.joint_mode = Line2D.LINE_JOINT_ROUND
	parent.add_child(border)

	_add_tunnel_tiles(parent, pts)

func _add_tunnel_tiles(parent: Node2D, pts: PackedVector2Array) -> void:
	var info: Dictionary = _terrain.tunnel_floor() if _terrain else {}
	var tex: Texture2D = info.get("texture") as Texture2D
	if tex == null:
		# Pack missing: keep a plain dug-earth line so tunnels still read.
		var fill := Line2D.new()
		fill.width = TUNNEL_HALF_WIDTH * 2.0
		fill.default_color = _terrain.tunnel_color() if _terrain else Color(0.45, 0.32, 0.22)
		fill.points = pts
		fill.z_index = -1
		fill.begin_cap_mode = Line2D.LINE_CAP_ROUND
		fill.end_cap_mode = Line2D.LINE_CAP_ROUND
		fill.joint_mode = Line2D.LINE_JOINT_ROUND
		parent.add_child(fill)
		return

	var mod: Color = info.get("modulate", Color.WHITE)
	var tile_scale := float(info.get("tile_scale", 3.0))
	var variants: Array = info.get("variants", [])
	if variants.is_empty():
		variants = [tex]
	var step := float(tex.get_width()) * tile_scale
	if step < 4.0:
		return
	var layer := Node2D.new()
	layer.name = "TunnelTiles"
	layer.z_index = -1
	parent.add_child(layer)

	# Global-grid-aligned soil tiles within the tunnel band: matches chamber
	# floors, never overlaps itself, and chamber tiles cover the mouth overlap.
	var cells: Dictionary = {}
	for i in range(pts.size() - 1):
		var seg_a := pts[i]
		var seg_b := pts[i + 1]
		var samples := maxi(int(ceil(seg_a.distance_to(seg_b) / (step * 0.5))), 1)
		for s in range(samples + 1):
			var p := seg_a.lerp(seg_b, float(s) / float(samples))
			var cx := int(floor(p.x / step))
			var cy := int(floor(p.y / step))
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var cell := Vector2i(cx + dx, cy + dy)
					if cells.has(cell):
						continue
					var cpos := Vector2((float(cell.x) + 0.5) * step, (float(cell.y) + 0.5) * step)
					var closest := Geometry2D.get_closest_point_to_segment(cpos, seg_a, seg_b)
					if cpos.distance_to(closest) <= TUNNEL_HALF_WIDTH:
						cells[cell] = true

	for cell in cells:
		var vi := _variant_index(cell.x, cell.y, variants.size())
		var tile_tex: Texture2D = variants[vi] as Texture2D
		if tile_tex == null:
			tile_tex = tex
		var spr := Sprite2D.new()
		spr.texture = tile_tex
		spr.centered = true
		spr.scale = Vector2(tile_scale, tile_scale)
		spr.modulate = mod
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.position = Vector2((float(cell.x) + 0.5) * step, (float(cell.y) + 0.5) * step)
		layer.add_child(spr)

## Place the knowledge star opposite the average mouth pull so auto-transit
## pads don't sit on top of the discovery dwell zone (pupae / nursery).
func _star_pos_away_from_mouths(node: NavGraph.ChamberNode, graph: NavGraph = null) -> Vector2:
	var pull := Vector2.ZERO
	if graph != null:
		for tid in node.tunnel_ids:
			if tid < 0 or tid >= graph.tunnels.size():
				continue
			var edge: NavGraph.TunnelEdge = graph.tunnels[tid]
			var mouth: Vector2 = edge.mouth_a() if edge.a == node.id else edge.mouth_b()
			pull += mouth - node.center
	var half := node.world_rect.size * 0.5
	var pos: Vector2
	if pull.length_squared() > 1.0:
		pos = node.center - pull.normalized() * minf(half.x, half.y) * 0.42
	else:
		pos = node.center + Vector2(0, -half.y * 0.18)
	return node.clamp_point(pos)

func _atlas_sprite(sheet_path: String, region: Rect2, pos: Vector2, scale: float, z: int) -> Sprite2D:
	if not ResourceLoader.exists(sheet_path) and not FileAccess.file_exists(sheet_path):
		return null
	var sheet: Texture2D = load(sheet_path) as Texture2D
	if sheet == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = region
	var spr := Sprite2D.new()
	spr.texture = atlas
	spr.centered = true
	spr.scale = Vector2(scale, scale)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.position = pos
	spr.z_index = z
	return spr

func _make_leaf_pile(pos: Vector2, seed: int) -> Node2D:
	## Leaf-cutter forage markers — leafy bush tiles from the objects pack.
	var n := Node2D.new()
	n.name = "LeafPile"
	n.position = pos
	n.z_index = 3
	var bush_regions: Array = [
		Rect2(0, 32, 16, 16),
		Rect2(16, 32, 16, 16),
		Rect2(32, 32, 16, 16),
		Rect2(48, 32, 16, 16),
	]
	for i in 3:
		var reg: Rect2 = bush_regions[(seed + i * 3) % bush_regions.size()]
		var spr := _atlas_sprite(OBJECTS_SHEET, reg, Vector2((i - 1) * 14, (i % 2) * 6), 2.8, 3)
		if spr == null:
			continue
		spr.modulate = Color(0.85, 1.0, 0.80, 1.0)
		n.add_child(spr)
	if n.get_child_count() == 0:
		# Fallback polygon if the pack is missing.
		var leaf := Polygon2D.new()
		leaf.color = Color(0.35, 0.75, 0.30)
		leaf.polygon = PackedVector2Array([
			Vector2(0, -14), Vector2(10, -4), Vector2(8, 10), Vector2(0, 14), Vector2(-8, 10), Vector2(-10, -4)
		])
		n.add_child(leaf)
	return n

func _make_fungus_patch(ch: NavGraph.ChamberNode) -> Node2D:
	## Garden "mold" / fungus farm — mushroom clusters where gardeners tend.
	var root := Node2D.new()
	root.name = "FungusPatch_%s" % ch.name
	root.z_index = 3
	var mush_regions: Array = [
		Rect2(0, 0, 16, 16),
		Rect2(16, 0, 16, 16),
		Rect2(32, 0, 16, 16),
		Rect2(48, 0, 16, 16),
		Rect2(64, 0, 16, 16),
		Rect2(80, 0, 16, 16),
	]
	var offsets: Array = [
		Vector2(-90, -40), Vector2(70, -55), Vector2(-40, 60),
		Vector2(100, 45), Vector2(0, -10), Vector2(-110, 50),
	]
	for i in offsets.size():
		var p: Vector2 = ch.clamp_point(ch.center + offsets[i])
		var reg: Rect2 = mush_regions[i % mush_regions.size()]
		var spr := _atlas_sprite(OBJECTS_SHEET, reg, p, 3.2, 3)
		if spr == null:
			continue
		# Soft fungus tint — pale / lilac so it reads as garden mold, not red toadstools.
		spr.modulate = Color(0.92, 0.88, 1.0, 0.95) if i % 2 == 0 else Color(0.95, 0.98, 0.90, 0.95)
		root.add_child(spr)
	return root
