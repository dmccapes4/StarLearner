extends RefCounted
## CameraFollow — soft-follow plus one-shot pan for the star reveal tour.

const CamScript := preload("res://scripts/render/CameraFollow.gd")

var _host: Node

func _init(host: Node) -> void:
	_host = host

func run() -> TestAssert:
	var t := TestAssert.new("CameraFollow")

	var cam: Camera2D = CamScript.new()
	_host.add_child(cam)

	var target := Node2D.new()
	_host.add_child(target)
	target.global_position = Vector2(100, 200)
	cam.call("set_follow_target", target)
	t.approx(cam.global_position.x, 100.0, 0.01, "follow snaps to target x")
	t.approx(cam.global_position.y, 200.0, 0.01, "follow snaps to target y")
	t.ok(not bool(cam.call("is_panning")), "not panning while following")

	var arrived := [false]
	cam.pan_arrived.connect(func() -> void: arrived[0] = true)
	cam.call("begin_pan_to", Vector2(500, 200), 0.05, true)  # short duration → arrives next frame
	t.ok(bool(cam.call("is_panning")), "begin_pan_to enters pan mode")
	cam._process(1.0)
	t.ok(arrived[0], "pan_arrived fires when close enough")
	t.approx(cam.global_position.x, 500.0, 0.5, "pan ends at destination")

	cam.call("resume_follow", target, true)
	t.ok(not bool(cam.call("is_panning")), "resume_follow leaves pan mode")
	t.approx(cam.global_position.x, 100.0, 0.01, "resume snap returns to target")

	cam.queue_free()
	target.queue_free()
	return t
