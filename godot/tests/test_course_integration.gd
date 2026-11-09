extends SceneTree
## Actual-host collision/camera fixtures, not complete authored runs.
const Bakery = preload("res://src/bakery_renderer.gd")
const Dash = preload("res://src/trolley_dash_renderer.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)
func fresh(game, id: String) -> void:
	game.character = "jp"
	game.save = {"schema": 1, "receipts": {}, "skills": []}
	game.load_level(id)
	for wave in game.combat.waves: wave.at = INF
func stand(game, p: Vector2, camera_x: float) -> void:
	game.player = p; game.camera = Vector2(camera_x, 0)
	game.camera_speed = 0; game.camera_lock = null
	game.velocity = Vector2.ZERO; game.grounded = true; game.on_platform = false
func advance(game, duration: float) -> void:
	while duration > 0.000000001:
		var dt := minf(duration, 0.01)
		game.step(dt, {})
		duration -= dt
func touch(game, index: int, action: String) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = game.buttons[action].get_center()
	event.pressed = true
	game._unhandled_input(event)
func test_card_touch_retention(game) -> void:
	for row in [["1-4", Vector2(8487, 442), "slide"], ["2-5", Vector2(8840, 232), "double-jump"]]:
		fresh(game, row[0])
		stand(game, row[1], row[1].x - 340)
		game.on_platform = row[0] == "2-5"
		touch(game, 71, "right")
		touch(game, 72, "shoot")
		check(game._held("right") and game._held("shoot") and game.touches.size() == 2, "%s actual touch events hold movement and fire" % row[0])
		game._physics_process(1.0 / 60)
		check(game.movement_skills.has_skill(row[2]) and game.save.skills.has(row[2]), "%s physical input frame earns authored card" % row[0])
		check(game.touches.size() == 2 and game._held("right") and game._held("shoot") and not game.jump_held, "%s card refresh retains held touch IDs and jump edge" % row[0])
		var x: float = game.player.x
		game._physics_process(1.0 / 60)
		check(game.player.x > x and game._held("shoot"), "%s stationary held fingers keep moving forward and firing after pickup" % row[0])
		game._resize() # Actual lifecycle/layout resize still releases controls.
		check(game.touches.is_empty() and not game._held("right") and game.jump_held, "%s real resize retains explicit input-release safety" % row[0])

func test_midpoint_knockout(game) -> void:
	for row in [["2-1", 7550, 7162, Vector2(8020, 482)], ["2-2", 10350, 9962, Vector2(10820, 482)], ["2-3", 8860, 8292, Vector2(8910, 482)], ["2-5", 9350, 8962, Vector2(9820, 370)]]:
		fresh(game, row[0])
		stand(game, Vector2(row[1], 482), row[2])
		for wave in game.combat.waves:
			wave.done = true; wave.started = true; wave.index = wave.group.size()
		game.invincible = 999
		game.step(0, {})
		advance(game, 1.42)
		game.hearts = 1
		game.invincible = 0
		game.bullets.append({"p": game.player + Vector2(0, -80), "v": Vector2.ZERO, "enemy": true, "life": 1.0, "gravity": 0.0})
		game.step(0.01, {})
		check(game.mode == "over" and game.hearts == 0 and game.world_two.scene_index == 0, "%s lethal midpoint bill requires Continue rather than implicit scene revival" % row[0])
		var elapsed: float = game.world_two.wipe_elapsed
		game.step(10, {})
		check(game.world_two.wipe_elapsed == elapsed and game.world_two.scene_index == 0, "%s pending callback freezes behind knockout screen" % row[0])
		game._continue_level()
		check(game.mode == "play" and game.world_two.scene_index == 0 and game.invincible == 2.5, "%s Continue restores source protection before pending callback" % row[0])
		game.step(0, {})
		check(game.world_two.scene_index == 1 and game.player == row[3] and game.mode == "play", "%s resumed pending callback executes once at authored destination" % row[0])

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/test_support.gd").silence(game)
	fresh(game, "2-4")
	check(game._native_world_two() and game.supermarket_renderer is Dash and game.level.ride == 30, "Dash has its native painter and source30px visual ride offset")
	check(game.world_two.unsupported_hazards.is_empty() and game.world_two.course_controller.speed == 200, "All dash schemas active and auto speed starts200")
	var start: Vector2 = game.player
	game.step(0.01, {})
	check(is_equal_approx(game.camera.x, 2) and game.camera_speed == 0 and game.player == start, "Auto camera advances without carrying or locking player")
	game.step(0.01, {"right": true})
	check(is_equal_approx(game.player.x, start.x + 2.7) and is_equal_approx(game.camera.x, 4), "Normal movement remains independent of scrolling")
	game.combat.waves[0].started = true # Explicit pre-existing-wave fixture.
	var previous: float = game.camera.x
	game.step(0.01, {})
	var expected := 200.0 + (120.0 - 200.0) * 0.01 / 0.7
	check(is_equal_approx(game.world_two.course_controller.speed, expected) and absf(game.camera.x - previous - expected * 0.01) < 0.001, "Camera uses source active-wave factor before current wave pass")
	fresh(game, "2-4")
	stand(game, Vector2(4884 - 738 * 0.4 + 0.1 + 300, 482), 4884 - 738 * 0.4 + 0.1)
	game.step(0.01, {})
	check(game.world_two.course_controller.boost and is_equal_approx(game.world_two.course_controller.speed, 200 + (310.0 - 200) * 0.01 / 0.7), "Camera probe activates source boost before interpolation")
	var state := [game.player, game.camera, game.elapsed, game.world_two.course_controller.speed, game.world_two.course_controller.boost]
	game._pause(); game.step(5, {"right": true})
	check(state == [game.player, game.camera, game.elapsed, game.world_two.course_controller.speed, game.world_two.course_controller.boost], "Real pause freezes auto camera, player and course clock")
	game._resume()
	game.mode = "over"; game.hearts = 0
	game._continue_level()
	check(game.mode == "play" and state == [game.player, game.camera, game.elapsed, game.world_two.course_controller.speed, game.world_two.course_controller.boost], "Continue restores health without resetting dash speed or location")
	fresh(game, "2-4")
	check(game.elapsed == 0 and game.world_two.course_controller.elapsed == 0 and game.world_two.course_controller.speed == 200 and not game.world_two.course_controller.boost, "Fresh dash resets both clock snapshot and speed")
	game.invincible = 999
	advance(game, 211)
	check(game.mode == "play" and not game.save.get("cleared", {}).get("2-4", false), "Par3:30 is not a time limit or reward and unfinished waves still gate clear")
	fresh(game, "2-5")
	check(game.supermarket_renderer is Bakery and game.world_two.unsupported_hazards.is_empty(), "Bakery selects source painter with all flames/belts/flour/blocks active")
	check(game.world_two.course_controller.speed == 0 and game.elapsed == 0 and game.world_two.course_controller.elapsed == 0, "Bakery inherits no automatic scroll or old source clock")
	stand(game, Vector2(1920, 482), 1600)
	game.elapsed = 0.49 # Collision clock fixture; no progression assertion.
	game.step(0.01, {})
	check(game.hearts == 2 and is_equal_approx(game.world_two.course_controller.flame_phase(game.level.hz[0]), 0.1), "Late flame uses current main clock, not lagging runtime clock")
	fresh(game, "2-5")
	stand(game, Vector2(12600, 482), 12200)
	game.world_two.scene_index = 1
	game.world_two.checkpoint_hit = true
	game.invincible = 2.5
	game.step(0.01, {})
	check(game.hearts == 3 and not game.grounded and game.velocity.y == -700, "Wet-block source rebound still applies during Continue invulnerability")
	fresh(game, "2-5")
	stand(game, Vector2(9350, 482), 8962)
	for wave in game.combat.waves:
		# Suppressed at values are intentionally replaced only in this scene fixture.
		wave.done = true; wave.started = true; wave.index = wave.group.size()
	game.invincible = 999
	game.step(0, {})
	check(game.world_two.wiping and game.world_two.wipe_label == "Shop floor", "Actual swing-door scene starts with original label")
	advance(game, 1.43)
	check(game.player == Vector2(9820, 370) and game.camera == Vector2(9660, 0), "Source default landing chooses highest deli surface at9820/370")
	check(not game.world_two.checkpoint_hit, "Swing-door callback precedes next-frame full-heal checkpoint")
	game.step(0.01, {})
	check(game.world_two.checkpoint_hit, "Bakery checkpoint follows actual door callback")
	test_card_touch_retention(game)
	test_midpoint_knockout(game)
	game.queue_free()
	await process_frame
	print("Course main integration: ", checks, " checks, ", failures.size(), " failures (focused fixtures)")
	quit(0 if failures.is_empty() else 1)
