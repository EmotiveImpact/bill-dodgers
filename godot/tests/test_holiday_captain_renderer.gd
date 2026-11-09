extends SceneTree
const Painter = preload("res://src/holiday_captain_renderer.gd")
const Captain = preload("res://src/holiday_captain.gd")
var assertions := 0
var failures := 0

class Host extends Node2D:
	var level_id := "4-6"
	var level: Dictionary = {}
	var meta: Dictionary = {}
	var images: Dictionary = {}
	var sheets: Dictionary = {}
	var camera := Vector2(4974.25, -90.35)
	var camera_lock := 0.0
	var status := ""
	var elapsed := 0.0
	var boss = null
	var font: Font = load("res://assets/fonts/silk.woff2")
	var painter
	var runtime: Dictionary = {}
	var draw_count := 0
	func view_width() -> float: return 738
	func view_top() -> float: return camera.y + 540 - 540 / 1.3
	func sfx(_key: String) -> void: pass
	func add_coins(_position: Vector2, _count: int) -> void: pass
	func _draw() -> void:
		if painter == null: return
		painter.draw_boss(self, runtime)
		painter.draw_jar(self, runtime)
		draw_count += 1

func check(value: bool, label: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error(label)

func close(value: float, expected: float, label: String) -> void:
	check(absf(value - expected) < 0.0001, label)

func tagged(commands: Array, tag: String) -> Array:
	return commands.filter(func(c): return c.tag == tag)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var h := Host.new()
	h.meta = JSON.parse_string(FileAccess.get_file_as_string("res://content/levels/4-6.json"))
	h.level = h.meta.level
	h.sheets.thief = load("res://assets/sprites/thief-sheet.png")
	var original_pixels: PackedByteArray = h.sheets.thief.get_image().get_data()
	var original_metadata := var_to_str(h.meta)
	var painter := Painter.new()
	var captain := Captain.new()
	captain.reset(h)
	captain.start(h)
	captain.boss.x = 5450.37
	captain.boss.y = 522.61
	captain.boss.fy = 522.61
	captain.boss.state = "drift"
	h.boss = captain
	h.runtime = {"captain": captain, "elapsed": 0.0}
	h.painter = painter
	check(painter.supports("4-6") and not painter.supports("3-6") and not painter.supports("4-1"), "Captain-only renderer dispatch")
	for id in ["4-1", "4-2", "4-3", "4-4", "4-5", "4-6", "4-S"]:
		var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/levels/" + id + ".json"))
		check(not metadata.sheets.has("captain") and not metadata.sheets.has("jetbot"), "Authored procedural fallback rather than fictional sheets: " + id)
	check(h.sheets.thief.get_size() == Vector2(462 * 6, 282 * 3), "Original thief sheet dimensions")
	var source := FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../game/4-1/index.html"))
	for anchor in ["g.ellipse(0, -60, 150, 60", "g.ellipse(-10, -78, 110, 30", "g.quadraticCurveTo(-190, -170, -150, -250)", "g.arc(-140, -262, 30", "g.fillRect(64, -126, 16, 20)", "g.fillRect(60, -132, 24, 8)", "10 * f, -96, -f, 0.5, 1, b.flash > 0", "b.t - 2600) / 1200", "22 + Math.sin(levelT / 90) * 4", "wx - 8 - i * 9 * Math.sign(w.vx)", "jarIcon(x, y, 1, 2)"]:
		check(source.contains(anchor), "Actual source drawing anchor: " + anchor)
	var commands := painter.build_boss(h, h.runtime)
	check(commands.size() == 14 and tagged(commands, "captain_rider").size() == 1, "Complete nine-shape flamingo/rider/four-piece hat")
	var b: Dictionary = captain.boss
	var body: Dictionary = tagged(commands, "captain_flamingo_body")[0]
	check(body.local_center == Vector2(0, -60) and body.local_radius == Vector2(150, 60), "Source flamingo ellipse size and anchor")
	var expected_origin := Vector2(h.camera.x + Painter.source_round(b.x - h.camera.x), Painter.source_round(b.y) + h.camera.y - Painter.source_round(h.camera.y))
	check(body.transform.origin.is_equal_approx(expected_origin), "Fractional camera and snapped outer translation")
	check(body.points[0].is_equal_approx(expected_origin + Vector2(150, -60)), "Source first body ellipse point")
	var neck: Dictionary = tagged(commands, "captain_flamingo_neck")[0]
	check(neck.points.size() == 33 and neck.width == 28, "Quadratic neck samples and28px stroke")
	check(neck.points[0].is_equal_approx(expected_origin + Vector2(-110, -80)) and neck.points[-1].is_equal_approx(expected_origin + Vector2(-150, -250)), "Source neck endpoints")
	check(tagged(commands, "captain_flamingo_head")[0].local_center == Vector2(-140, -262), "Source flamingo head placement")
	check(tagged(commands, "captain_valve_cap")[0].local_rect == Rect2(60, -132, 24, 8), "Gold valve dimensions")
	check(tagged(commands, "captain_hat_crown")[0].local_rect == Rect2(-16, -372, 52, 24), "Captain hat is separately anchored above thief")
	var rider: Dictionary = tagged(commands, "captain_rider")[0]
	check(rider.animation == "run" and rider.frame == 0 and rider.source == Rect2(0, 0, 462, 282), "Idle fallback deliberately uses run0, not invented bob animation")
	check(rider.rect == Rect2(-221, -375, 462, 282) and rider.flip_h and rider.alpha == 1, "Rider source feet/top/halfwidth and facing")
	check(tagged(commands, "captain_valve_glow").is_empty(), "No valve sparkle before phase3")
	for face in [-1, 1]:
		b.face = face
		b.state = "rear"
		b.t = 0.2
		var pose := Painter.captain_pose(b)
		close(pose.rotation, -0.09 if face < 0 else 0.09, "Rear angular sign and half-rear timing")
		close(pose.bob, sin(0.2 / 0.3) * 6, "Source bob uses300ms clock")
		commands = painter.build_boss(h, h.runtime)
		var outer := Transform2D(pose.rotation, Vector2.ONE, 0, Vector2(expected_origin.x, Painter.source_round(b.y + pose.bob) + h.camera.y - Painter.source_round(h.camera.y)))
		var shape := outer * Transform2D(0, Vector2(pose.mirror, 1), 0, Vector2.ZERO)
		check(tagged(commands, "captain_flamingo_eye")[0].points[0].is_equal_approx(shape * Vector2(-150, -272)), "Mirror and rear rotation combine around boss origin")
		check(tagged(commands, "captain_rider")[0].flip_h == (face < 0), "Rider separately faces authored direction")
		b.t = 1.0
		close(absf(Painter.captain_pose(b).rotation), 0.18, "Rear angle saturates at0.18rad")
		b.state = "throw"
		for frame in 4:
			b.t = frame * 0.16
			rider = tagged(painter.build_boss(h, h.runtime), "captain_rider")[0]
			check(rider.animation == "throw" and rider.frame == frame and rider.source == Rect2(frame * 462, 282, 462, 282), "All source throw crops and faces")
		b.t = 3.0
		check(Painter.captain_pose(b).frame == 3, "Throw frame clamps to source3")
	b.state = "rear"
	b.t = 0.4
	b.phase = 3
	b.face = -1
	b.sink = 0.5
	h.runtime.elapsed = 0.135
	commands = painter.build_boss(h, h.runtime)
	var glow: Dictionary = tagged(commands, "captain_valve_glow")[0]
	var pose := Painter.captain_pose(b)
	check(glow.center.is_equal_approx(Vector2(b.x + 70 * pose.scale, b.y + pose.bob - 120 * pose.scale + h.camera.y - Painter.source_round(h.camera.y))), "Valve ring stays unsnapped and outside rear rotation")
	close(glow.radius, 22 + sin(1.5) * 4, "Valve sparkle uses level clock90ms")
	check(glow.width == 3, "Valve highlight source stroke3")
	b.state = "down"
	b.sink = 1.0
	for row in [[2.6, 1.0], [3.2, 0.5], [3.8, 0.0], [5.0, 0.0]]:
		b.t = row[0]
		pose = Painter.captain_pose(b)
		close(pose.alpha, row[1], "Source2600–3800ms fade")
		check(pose.bob == 0 and pose.scale == 0.65 and pose.animation == "run" and pose.frame == 0, "Down fallback keeps run0, no bob,65percent scale")
		commands = painter.build_boss(h, h.runtime)
		close(tagged(commands, "captain_flamingo_body")[0].colour.a, row[1], "Flamingo fades")
		check(tagged(commands, "captain_rider")[0].alpha == 1 and tagged(commands, "captain_valve_glow").is_empty(), "Source fallback rider overrides fade; down hides sparkle")
	b.state = "charge"
	b.t = 0.1
	b.sink = 0.0
	b.wave = [{"x": 5300.7, "vx": -400.0, "t": 0.1}, {"x": 5400.7, "vx": 400.0, "t": 0.0}]
	commands = painter.build_boss(h, h.runtime)
	var waves := tagged(commands, "captain_splash_wave")
	check(waves.size() == 8 and tagged(commands, "captain_splash_wave_base").size() == 2, "Four white bars and one blue base per splash wave")
	close(waves[0].rect.position.x, h.camera.x + Painter.source_round(5300.7 - h.camera.x) - 8, "Wave x snaps relative camera")
	close(waves[0].rect.position.y, 482 - 12 - 24 - sin(2) * 3 + h.camera.y - Painter.source_round(h.camera.y), "Source splash wave heights and animation")
	check(waves[0].rect.size == Vector2(14, 24) and waves[3].rect.size == Vector2(14, 12), "Source wave bar widths/heights")
	check(waves[1].rect.position.x > waves[0].rect.position.x and waves[5].rect.position.x < waves[4].rect.position.x, "Wave foam trails against travel direction")
	check(commands[-1].tag == "captain_splash_wave_base", "Waves follow entire boss rendering")
	check(painter.build_jar(h, h.runtime).is_empty(), "No jar before runtime creates it")
	captain.jar = {"p": Vector2(5343.7, 452), "v": Vector2.ZERO, "t": 0.21, "got": false}
	var jar_commands := painter.build_jar(h, h.runtime)
	var jar_center := Vector2(5343.7, 452 + sin(1.5) * 2 + h.camera.y - Painter.source_round(h.camera.y))
	check(tagged(jar_commands, "captain_jar_glow")[0].center.is_equal_approx(jar_center + Vector2(0, -4)), "Holiday jar unsnapped center and140ms bob")
	check(tagged(jar_commands, "captain_jar_glass")[0].rect == Rect2(jar_center + Vector2(-28, -32), Vector2(56, 60)), "Source full-size holiday pot glass")
	check(tagged(jar_commands, "captain_jar_coin_detail").size() == 6, "Holiday pot retains six source coin marks")
	captain.jar.got = true
	jar_commands = painter.build_jar(h, h.runtime)
	check(tagged(jar_commands, "captain_jar_glow").is_empty(), "Collected pot stays drawn without glow")
	close(tagged(jar_commands, "captain_jar_lid")[0].rect.position.y, 408 + h.camera.y - Painter.source_round(h.camera.y), "Collected pot stops bobbing")
	h.elapsed = h.runtime.elapsed
	check(painter.build_boss(h) == painter.build_boss(h, h.runtime), "Host boss fallback resolves actual Captain object")
	check(painter.build_jar(h) == painter.build_jar(h, h.runtime), "Independent jar resolves through Captain object")
	var before_boss := var_to_str(b)
	var before_jar := var_to_str(captain.jar)
	seed(810)
	var next_random := randf()
	seed(810)
	for i in 3:
		check(painter.build_boss(h, h.runtime) == painter.build_boss(h, h.runtime), "Repeated boss builders are deterministic")
		check(painter.build_jar(h, h.runtime) == painter.build_jar(h, h.runtime), "Repeated jar builders are deterministic")
	check(randf() == next_random and var_to_str(b) == before_boss and var_to_str(captain.jar) == before_jar and var_to_str(h.meta) == original_metadata, "Builders preserve gameplay RNG, runtime, jar and metadata")
	root.add_child(h)
	await process_frame
	var frames_drawn := 0
	for state in ["drift", "rear", "throw", "charge", "down"]:
		for face in [-1, 1]:
			for flash in [false, true]:
				b.state = state
				b.face = face
				b.flash = 0.08 if flash else 0.0
				b.t = 3.2 if state == "down" else 0.32
				b.sink = 1.0 if state == "down" else 0.0
				h.queue_redraw()
				await process_frame
				h.notification(CanvasItem.NOTIFICATION_DRAW)
				frames_drawn += 1
	check(h.draw_count >= frames_drawn and frames_drawn == 20, "Twenty actual CanvasItem callbacks cover states/faces/flashes and jar hooks")
	check(not painter._festival_variants.is_empty(), "Actual flash texture path exercised")
	check(h.sheets.thief.get_image().get_data() == original_pixels and var_to_str(h.meta) == original_metadata, "Affine draws and flash variants do not alter original art or metadata")
	var before_draw := var_to_str(b)
	h.notification(CanvasItem.NOTIFICATION_DRAW)
	check(var_to_str(b) == before_draw and var_to_str(captain.jar) == before_jar, "CanvasItem draws never mutate simulation state")
	h.level_id = "4-1"
	check(painter.build_boss(h, h.runtime).is_empty() and painter.build_jar(h, h.runtime).is_empty(), "No Captain artwork leaks into other stages")
	painter.clear_cache()
	check(painter._festival_variants.is_empty() and painter._filtered_textures.is_empty(), "Reset clears temporary flash/filter resources")
	h.painter = null
	h.boss = null
	h.runtime.clear()
	h.images.clear()
	h.sheets.clear()
	h.queue_free()
	await process_frame
	print("Holiday Captain renderer: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures else 0)
