extends SceneTree
## Micro-probe: is PathFollow3D.global_position fresh right after setting
## progress_ratio, in the same nesting FlyScene uses (SubViewport)?

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var host := SubViewportContainer.new()
	var vp := SubViewport.new()
	host.add_child(vp)
	root.add_child(host)
	var world := Node3D.new()
	vp.add_child(world)
	var path := Path3D.new()
	world.add_child(path)
	var follow := PathFollow3D.new()
	follow.loop = false
	follow.rotation_mode = PathFollow3D.ROTATION_ORIENTED
	path.add_child(follow)

	var c := Curve3D.new()
	for i in 33:
		c.add_point(Vector3(i * 10.0, 0.0, 0.0))
	path.curve = c
	follow.progress_ratio = 0.0

	print("-- same-frame writes/reads (no await) --")
	for r in [0.5, 0.9, 0.1]:
		follow.progress_ratio = r
		print("  set %.2f -> pos %.1f" % [r, follow.global_position.x])

	await process_frame
	print("-- after a frame --")
	follow.progress_ratio = 0.7
	print("  set 0.70 -> pos %.1f" % follow.global_position.x)

	print("-- new curve assigned, then set/read (mirrors begin_flight) --")
	var c2 := Curve3D.new()
	for i in 33:
		c2.add_point(Vector3(0.0, 0.0, i * 20.0))
	path.curve = c2
	follow.progress_ratio = 0.25
	print("  set 0.25 on new curve -> pos %s" % follow.global_position)
	await process_frame
	follow.progress_ratio = 0.25
	print("  next frame, set 0.25 -> pos %s" % follow.global_position)
	quit()
