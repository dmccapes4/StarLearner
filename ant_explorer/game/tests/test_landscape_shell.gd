extends RefCounted
## LandscapeShell — builds 6+6 rails, reflects Save, and drives the occlude →
## touch-to-reveal → auto re-occlude model plus double-tap-to-watch.
## Needs a host node (added to tree) so the shell's Controls / signals live.

const ShellScript := preload("res://scripts/ui/LandscapeShell.gd")
const Model := preload("res://scripts/ui/StarRailModel.gd")
const Layout := preload("res://scripts/ui/StarRailLayout.gd")

var _host: Node

func _init(host: Node) -> void:
	_host = host

func run() -> TestAssert:
	var t := TestAssert.new("LandscapeShell")

	var saved_stars: PackedStringArray = Save.stars_collected.duplicate()
	Save.stars_collected = PackedStringArray()

	var shell: CanvasLayer = ShellScript.new()
	_host.add_child(shell)  # triggers _ready → build()

	# Rails built with all 12 slots, and start OCCLUDED.
	t.eq(shell.tiles.size(), 12, "12 rail tiles built")
	for id in Layout.all_ids():
		t.ok(shell.tiles.has(id), "tile exists for %s" % id)
	t.ok(not shell.revealed, "rails occluded by default")

	# Fresh save → every tile undiscovered.
	shell.refresh()
	t.eq(shell.tiles["01_queen"].state, Model.TILE_UNDISCOVERED, "queen tile starts undiscovered")

	# While occluded, a tile tap only reveals (never fires an action).
	Save.stars_collected = PackedStringArray(["02_larvae"])
	var pre: String = shell._handle_tile_tap("02_larvae", 0.0)
	t.eq(pre, shell.ACT_REVEALED, "tile tap while occluded just reveals")
	t.ok(shell.revealed, "revealed after first touch")
	t.ok(not shell.video_arm.is_armed(), "reveal touch does not arm video")

	# Side touch while revealed keeps it up (resets timer).
	var kept: String = shell._handle_side_touch(0.2)
	t.eq(kept, shell.ACT_KEPT, "side touch while revealed keeps rails up")

	# Undiscovered tap (revealed) → arms "tap again to reveal" (3 s window).
	var g: String = shell._handle_tile_tap("11_architecture", 0.3)
	t.eq(g, shell.ACT_REVEAL_ARMED, "undiscovered tap arms reveal")
	t.ok(shell.reveal_arm.is_armed_for("11_architecture"), "reveal armed for tile")
	t.ok(not shell.video_arm.is_armed(), "undiscovered tap does not arm video")

	# Second tap within 3 s requests the camera reveal tour (and tucks rails).
	var g2: String = shell._handle_tile_tap("11_architecture", 1.0)
	t.eq(g2, shell.ACT_REVEAL_TOUR, "second undiscovered tap starts reveal tour")
	t.ok(not shell.reveal_arm.is_armed(), "reveal trigger clears arm")
	t.ok(not shell.revealed, "reveal tour tucks rails under soil")

	# After tour, rails are occluded — first touch only re-reveals.
	var reopen: String = shell._handle_tile_tap("11_architecture", 5.0)
	t.eq(reopen, shell.ACT_REVEALED, "tap while occluded re-reveals rails")

	# Slow second tap past 3 s re-arms instead of touring.
	var g3: String = shell._handle_tile_tap("11_architecture", 5.2)
	t.eq(g3, shell.ACT_REVEAL_ARMED, "first tap arms reveal again")
	var g4: String = shell._handle_tile_tap("11_architecture", 8.5)
	t.eq(g4, shell.ACT_REVEAL_ARMED, "tap after 3 s window re-arms, no tour")

	# Collected tile (revealed): first tap arms, second within 1 s triggers video.
	var r1: String = shell._handle_tile_tap("02_larvae", 1.0)
	t.eq(r1, shell.ACT_ARMED, "first collected tap arms")
	t.ok(shell.video_arm.is_armed_for("02_larvae"), "armed for the tile")
	var r2: String = shell._handle_tile_tap("02_larvae", 1.4)
	# No VideoPanel in the headless tree → play resolves as unavailable, but the
	# arm→trigger path still fired and cleared.
	t.eq(r2, shell.ACT_VIDEO_UNAVAILABLE, "second tap triggers video path")
	t.ok(not shell.video_arm.is_armed(), "trigger clears the arm")

	# Auto re-occlude after REVEAL_SECONDS with no interaction.
	shell.reveal(10.0)
	t.ok(shell.revealed, "revealed at t=10")
	shell.tick(10.0 + shell.REVEAL_SECONDS - 0.1)
	t.ok(shell.revealed, "still revealed just before timeout")
	shell.tick(10.0 + shell.REVEAL_SECONDS + 0.1)
	t.ok(not shell.revealed, "auto-occluded after timeout")

	# Interaction pushes the timeout out.
	shell.reveal(20.0)
	shell._handle_side_touch(24.0)  # bump → until 29
	shell.tick(26.0)
	t.ok(shell.revealed, "interaction extended the reveal window")
	shell.tick(29.5)
	t.ok(not shell.revealed, "occludes once the extended window lapses")

	# Collecting a star pops the matching rail tile to Collected.
	Save.stars_collected = PackedStringArray(["03_pupae"])
	Events.star_collected.emit("03_pupae")
	t.eq(shell.tiles["03_pupae"].state, Model.TILE_COLLECTED, "collected event pops tile")

	# Intro hold: reveal stays up regardless of the auto-occlude timer.
	shell.begin_intro_hold()
	t.ok(shell.revealed, "intro hold reveals rails")
	shell.tick(1000.0)  # way past any reveal window
	t.ok(shell.revealed, "intro hold suspends auto-occlude")
	shell.end_intro_hold()
	t.ok(not shell.revealed, "end_intro_hold tucks rails back")

	shell.queue_free()
	Save.stars_collected = saved_stars
	return t
