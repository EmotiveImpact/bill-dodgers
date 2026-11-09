extends SceneTree
## Explicit real-main seam fixtures, not input-route completion evidence.
const SaveStore = preload("res://src/save_store.gd")
const Boss = preload("res://src/festival_boss.gd")
var checks := 0
var failures: Array[String] = []
var game
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: ", label)
func near(a: float, b: float) -> bool: return absf(a - b) < 0.002
func fresh(who: String = "jp") -> void:
	game.character = who
	game.save = {"schema": 1, "receipts": {}, "skills": [], "kitty": 13}
	game.load_level("3-2")
	for wave in game.combat.waves: wave.at = INF
	game.step(0, {})
	game.coins.clear()
func stand(p: Vector2, camera_x: float) -> void:
	game.player = p; game.camera = Vector2(camera_x, 0)
	game.velocity = Vector2.ZERO; game.grounded = true; game.on_platform = false
	game.camera_speed = 0; game.camera_lock = null; game.hurt_lock = 0
	game.invincible = 0; game.jump_held = false; game.drop_time = 0
	game.world_three._standing_surface = {}; game._last_floor = p.y
func tick(seconds: float, controls: Dictionary = {}) -> void:
	while seconds > 0.00000001:
		var dt := minf(0.01, seconds); game.step(dt, controls); seconds -= dt
func hostile() -> Dictionary:
	return {"p": game.player - Vector2(0, 60), "v": Vector2.ZERO, "enemy": true, "gravity": 0.0, "life": 20.0}
func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game); game.set_physics_process(false)
	preload("res://tests/test_support.gd").silence(game)
	test_selection()
	test_camera()
	test_crowds_and_banners()
	test_squash()
	test_scene_and_lifecycle()
	test_exit()
	game.queue_free(); await process_frame
	print("Festival queue integration: ", checks, " checks; ", failures.size(), " failures (explicit host fixtures)")
	quit(0 if failures.is_empty() else 1)
func test_selection() -> void:
	fresh()
	check(game._native_world_three() and game.scene_runtime == game.world_three and game.combat == game.festival_combat, "Queue selects shared festival runtime/combat")
	check(game.festival_renderer == game.festival_queue_renderer and game.festival_renderer.supports("3-2"), "Queue selects dedicated painter")
	check(game.combat.waves.size() == 15 and game.combat.waves.reduce(func(total, w): return total + w.group.size(), 0) == 51, "Actual fifteen solo groups contain 51 dispatches")
	check(game.world_three.surfaces(game).size() == 47 and game.world_three.tents.is_empty(), "Authored 47 solid surfaces and no invented tents")
	check(game.receipts.map(func(r): return r.position) == [Vector2(6000, 272), Vector2(16500, 272), Vector2(25000, 262)], "Exact three receipt centers")
	game.load_level("3-1")
	check(game.festival_renderer == game.festival_field_renderer and game.world_three.stage_data.is_empty(), "Returning to field clears queue renderer and extension state")
	game.load_level("2-4")
	check(game._native_world_two() and game.world_two.course_controller.speed == 200, "Queue does not replace supermarket auto semantics")
	game.load_level("4-1"); game.level_id = "7-1"; game._complete_level()
	check(not game.is_native_supported() and game.mode == "play" and not game.save.get("cleared", {}).has("7-1"), "Unknown run ID cannot acquire a fabricated clear")
func test_camera() -> void:
	fresh(); game.player.x = 680; game.camera_speed = 91
	game.world_three.level_time = 1.79
	game.step(0.01, {})
	check(game.camera.x == 0 and game.camera_speed == 91, "Strict warmup has no follow recurrence or camV reset")
	game.step(0.001, {})
	check(near(game.camera.x, 0.14) and near(game.world_three.cam_dx, 0.14), "Crossing warmup frame uses 140 px/s and exact camera delta")
	fresh(); stand(Vector2(130, 482), 100); game.world_three.level_time = 3
	game.step(0.01, {})
	check(near(game.player.x, 130) and near(game.camera.x, 101.4), "Player clamp uses previous camera before auto movement")
	game.step(0.01, {})
	check(near(game.player.x, 131.4) and near(game.camera.x, 102.8), "Following base frame applies new left camera margin")
	fresh(); game.world_three.level_time = 3; game.boss = Boss.new()
	game.boss.reset({"name": "Fixture", "kind": "seller", "hp": 60, "mini": true, "cam": 900}, game.view_width(), 482, 1, 31, {}, false)
	game.step(0.01, {})
	check(game.camera.x == 0, "Real controller living state stops auto")
	game.boss.state.state = "down"; game.boss.state.t = 0
	game.step(0.01, {})
	check(near(game.camera.x, 1.4), "Real controller down state permits auto")
	fresh(); game.world_three.level_time = 3; game.hearts = 0
	game.step(0.01, {})
	check(game.mode == "over" and near(game.camera.x, 1.4), "Final down frame auto precedes global knockout")
func test_crowds_and_banners() -> void:
	for who in game.CHARACTERS:
		fresh(who)
		var source := JSON.stringify(game.meta)
		for row in game.level.solids:
			if row.size() < 4 or row[3].get("style", "") != "crowd": continue
			stand(Vector2(row[0] + 110, row[2]), row[0] - 100)
			var x: float = game.player.x
			game.step(0.01, {})
			check(near(game.player.x, x + 1.2) and game.grounded, who + " real-main solid crowd carries at 120 px/s")
		for row in game.level.duck:
			game.abilities.reset(who) # First eligible hit, isolated from Maya alternating-hit passive.
			game.hearts = 3; stand(Vector2((row[0] + row[1]) / 2, 482), row[0] - 250)
			game.step(0, {"down": true})
			check(game.hearts == 3 and game.player_animation == "crouch", who + " true crouch clears banner")
			game.step(0, {})
			check(game.hearts == 2 and game.hurt_lock > 0, who + " upright banner uses real damage path")
		check(JSON.stringify(game.meta) == source, who + " runtime leaves original metadata untouched")
	fresh(); var row: Array = game.level.duck[0]
	stand(Vector2(row[0], row[2] - 40), row[0] - 200)
	game.grounded = false; game.step(0, {})
	check(game.hearts == 3, "Exact feet lower boundary is safe")
	game.player.y += 0.01; game.step(0, {})
	check(game.hearts == 2, "Just-inside airborne banner damages")
	fresh(); stand(Vector2(row[0], 482), row[0] - 200)
	game.abilities.active = "maya"; game.abilities.remaining = 1; game.abilities.duration = 1
	game.step(0, {})
	check(game.hearts == 3, "Banner respects real Maya shield")
func test_squash() -> void:
	fresh(); game.world_three.surfaces(game).append({"row": [450, 550, 100], "plat": false})
	stand(Vector2(480, 482), 0); game.world_three.safe_position = Vector2(300, 482)
	game.invincible = 999
	game.step(0.016, {"jump": true, "shoot": true})
	check(near(game.player.x, 300) and game.hearts == 2 and near(game.velocity.x, 0), "Squash uses real fall recovery and removes ordinary invulnerability")
	check(not game.grounded and near(game.velocity.y, -980 + 3300 * 0.016), "Pre-squash cached lock still allows that base jump")
	check(game.cooldown > 0 and game.player_animation == "jump" and game.hurt_lock > 0, "Pre-squash lock permits fire/base pose while preserving fresh hurt lock")
	game.step(0.016, {"right": true})
	check(game.player_animation == "hit", "Next frame observes actual hurt lock")
	fresh(); stand(Vector2(2500, 800), 2200); game.grounded = false
	game.world_three.safe_position = Vector2(2470, 482); game.invincible = 999
	game.step(0.01, {})
	check(game.hearts == 2 and game.grounded and game.player.y <= 482 and game.velocity.x == 0, "Authored 782 fall threshold invokes real recovery")
func test_scene_and_lifecycle() -> void:
	fresh(); stand(Vector2(14300, 300), 14000); game.grounded = false
	game.velocity.y = -123; game.world_three.level_time = 5
	game.step(0, {})
	check(not game.world_three.wiping and not game.world_three.checkpoint_done, "Exact scene/checkpoint boundary does not trigger")
	game.player.x += 0.01; game.hearts = 1
	game.combat.waves[0].started = true; game.combat.waves[0].index = 0
	game.step(0, {})
	check(game.world_three.wiping and game.world_three.checkpoint_done and game.hearts == 3, "Auto iris ignores busy wave and restores real checkpoint health")
	game._pause(); var paused: Dictionary = game.world_three.snapshot(); game.step(10, {"right": true})
	check(game.world_three.snapshot() == paused and game.camera.x == 14000, "Pause freezes source clocks and pending iris")
	game._resume(); tick(1.42)
	var before_y: float = game.player.y; var before_v: float = game.velocity.y
	game.player.y = 250; game.velocity.y = -77; game.grounded = false
	game.step(0.01, {})
	check(game.camera.x == 15300 and game.world_three.wipe_midpoint_done, "Production iris applies callback at 1.43 seconds")
	check(near(game.player.y, 250 + (-77 + 33) * 0.01) and near(game.velocity.y, -44), "Auto scene translates x without non-auto floor teleport or vy reset")
	check(game.world_three.stage_data.events_done.is_empty(), "Destination event waits for next source late phase")
	game.step(0.01, {})
	check(game.world_three.stage_data.events_done == [0] and game.status.contains("Crowd surf!"), "Next late phase displays exact destination notice")
	var pending: Dictionary = game.world_three.snapshot(); game._game_over(); game.step(5, {})
	check(game.world_three.snapshot() == pending, "Knockout freezes iris without silently reviving")
	game._continue_level(); tick(0.8)
	check(game.mode == "play" and not game.world_three.wiping and game.world_three.checkpoint_done, "Continue resumes existing transition without restarting stage")
	game.load_level("3-2")
	check(not game.world_three.wiping and not game.world_three.checkpoint_done and game.world_three.stage_data.events_done.is_empty(), "Fresh replay clears all queue state")
	check(before_y > 0 and is_finite(before_v), "Transition fixture retained finite prior motion")
func test_exit() -> void:
	fresh(); stand(Vector2(29600, 482), 29260)
	game.world_three._scenes[1].done = true
	game.world_three.level_time = 300
	game.combat.new_bot(game, 29880, game.world_three.below(game, 29880, 480), "throw", {"entered": true, "speed": 0.0, "cd": 100.0})
	game.step(0, {})
	check(game.world_three.end_time > 0 and game.combat.waves.any(func(w): return not w.done) and not game.enemies.is_empty(), "Actual distance end permits unfinished waves and live robot")
	var x: float = game.camera.x
	tick(2.59)
	check(game.mode == "play" and near(game.camera.x, x), "Ending freezes auto and cannot settle before 2.6 seconds")
	game.invincible = 999; game.step(0.01, {})
	check(game.mode == "clear" and game.save.cleared.get("3-2", false), "Actual delayed exit banks and clears supported queue")
	check(near(game.world_three.stage_data.end_run, 2.6), "Runner clock includes final base clear frame")
	var saved: Dictionary = SaveStore.read_save(); var score: int = game.score
	game.step(30, {}); game._complete_level()
	check(SaveStore.read_save() == saved and game.score == score, "Clear cannot bank twice")
