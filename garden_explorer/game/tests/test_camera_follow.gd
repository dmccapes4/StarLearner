extends RefCounted
## Camera soft-follows and can pan.

func run() -> TestAssert:
	var t := TestAssert.new("CameraFollow")
	var host := Node2D.new()
	var cam := CameraFollow.new()
	host.add_child(cam)
	var target := Node2D.new()
	host.add_child(target)
	target.global_position = Vector2(100, 50)
	cam.set_follow_target(target)
	t.approx(cam.global_position.x, 100.0, 0.1, "snap on set_follow_target")
	target.global_position = Vector2(200, 50)
	for i in 30:
		cam._process(1.0 / 60.0)
	t.gt(cam.global_position.x, 100.0, "camera lerps toward target")
	cam.begin_pan_to(Vector2(400, 80), 0.5)
	t.ok(cam.is_panning(), "pan mode")
	for i in 60:
		cam._process(1.0 / 60.0)
	t.approx(cam.global_position.x, 400.0, 20.0, "pan arrives near dest")
	host.free()
	return t
