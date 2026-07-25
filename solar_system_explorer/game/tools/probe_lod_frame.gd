extends SceneTree
## One-shot probe: reproduce the LOD math at a given trip fraction and print
## per-body distance / mode / world size / expected on-screen pixels.
##   godot --headless --path . -s res://tools/probe_lod_frame.gd

const FOV_V := 65.0
const VIEW_H := 600.0

func _init() -> void:
	var cfg := SolarFlyerConfig.load_default()
	var origin := SolarData.flyer_body_by_id("earth", cfg)
	var dest := SolarData.flyer_body_by_id("saturn", cfg)
	var ship0 := OrbitMath.body_pos(origin, 0.0)
	var standoff := OrbitMath.orbit_standoff(float(origin.get("hero_r", 2.0)))
	var route := OrbitMath.plot_route(ship0, dest, 0.0, cfg, standoff)
	var dur: float = float(route["duration"])
	var plen: float = float(route["path_len"])
	for u_time in [0.15, 0.40, 0.70]:
		var prog := OrbitMath.burn_progress(float(u_time), plen, cfg)
		var curve: Curve3D = route["curve"]
		var cam := curve.sample_baked(prog * curve.get_baked_length())
		var clock: float = float(u_time) * dur
		print("--- u_time=%.2f prog=%.2f clock=%.1fs cam=(%.0f, %.0f) ---" % [
			u_time, prog, clock, cam.x, cam.z])
		for b in SolarData.flyer_bodies(cfg):
			var pos := OrbitMath.body_pos(b, clock)
			var dist: float = cam.distance_to(pos)
			var hero: float = float(b.get("hero_r", 1.0))
			var tier: float = SolarData.icon_tier_for(b)
			var render_in := OrbitMath.render_in_dist(hero, cfg)
			var icon_w := OrbitMath.icon_world_size(dist, tier, cfg)
			var apparent := OrbitMath.apparent_size(dist, hero, cfg)
			var mesh_on: bool = bool(b.get("is_star", false)) or dist < render_in
			var scale_w: float = apparent
			if mesh_on and not bool(b.get("is_star", false)):
				var band0: float = render_in * 0.8
				var w: float = clampf((dist - band0) / maxf(render_in - band0, 0.001), 0.0, 1.0)
				scale_w = lerpf(apparent, icon_w, w)
			var world: float = (scale_w * 2.0) if mesh_on else icon_w
			var px: float = world / (2.0 * maxf(dist, 0.01) * tan(deg_to_rad(FOV_V * 0.5))) * VIEW_H
			print("  %-14s dist=%6.1f  render_in=%5.1f  %s  world=%5.2f  px=%5.1f" % [
				b["id"], dist, render_in, "MESH" if mesh_on else "icon", world, px])
	quit(0)
