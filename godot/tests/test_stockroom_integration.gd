extends SceneTree
## Focused actual-host fixtures. Full source traversal is a separate suite.
const StockroomRenderer = preload("res://src/stockroom_renderer.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)
func stand(game, position: Vector2, camera_x: float) -> void:
	game.player = position
	game.camera = Vector2(camera_x, 0)
	game.camera_speed = 0
	game.camera_lock = null
	game.velocity = Vector2.ZERO
	game.grounded = true
	game.on_platform = false
func advance(game, seconds: float, controls: Dictionary = {}) -> void:
	while seconds > 0.000000001:
		var dt := minf(seconds, 0.01)
		game.step(dt, controls)
		seconds -= dt
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/test_support.gd").silence(game)
	game.save = {"schema": 1, "receipts": {}, "skills": []}
	game.load_level("2-3")
	check(game._native_world_two() and game.supermarket_renderer is StockroomRenderer, "Stockroom selects its native policy and dedicated painter")
	check(game.combat.waves.size() == 11 and game.world_two.surfaces(game).size() == 32, "All eleven waves and thirteen solid/nineteen platform surfaces load")
	check(game.world_two.unsupported_hazards.is_empty() and game.world_two.hazard_controller.gates.is_empty(), "Belts/drops/coins are active without inherited aisle gates")
	var original := JSON.stringify(game.level)
	check(game.world_two.camera_cap(game) == 8292, "Goods lift uses source120px scene view instead of default300")
	check(game._land(9150, 430, 460) == 452 and game._land(9310, 400, 430) == 422, "Both static chained pallets support actual landing")
	check(game._land(9150, 430, 460, true) == INF and game._land(9240, 400, 700) == INF, "Dropping through pallet exposes real loading-bay gap")
	check(game.floor_at(11620, -100) == 2 and game.skill_floor_below(11620, -100) == 2, "Highest rack supports source top2 and skill probes")
	check(game._wall_clamp(10480, 10520, 482) == 10486 and game.ability_inside_wall(Vector2(11000, 400)), "Tall source rack blocks side entry and ordinary projectiles")
	for wave in game.combat.waves: wave.at = INF
	stand(game, Vector2(4450, 122), 4000)
	game.step(0.01, {})
	check(is_equal_approx(game.player.x, 4450.8) and game.grounded, "Elevated positive belt carries grounded player without input")
	stand(game, Vector2(7500, 242), 7100)
	game.step(0.01, {})
	check(is_equal_approx(game.player.x, 7499.3) and game.grounded, "Negative belt uses authored direction and height")
	game.world_two.scene_index = 1
	stand(game, Vector2(11800, 122), 11400)
	game.step(0.01, {})
	check(is_equal_approx(game.player.x, 11801) and game.grounded, "Upper mezzanine belt retains source100px/s")
	game.load_level("2-3")
	stand(game, Vector2(8860, 482), 8292)
	for wave in game.combat.waves:
		if wave.at <= 8292: wave.started = true; wave.done = true; wave.index = wave.group.size()
	game.hearts = 1
	game.invincible = 999
	game.step(0, {})
	check(game.world_two.wiping and game.world_two.scene_index == 0 and game.world_two.wipe_label == "Top floor", "Real goods-lift gate starts the original named scene")
	check(not game.world_two.checkpoint_hit, "Checkpoint is still beyond closed-lift camera cap")
	advance(game, 1.42)
	check(game.world_two.scene_index == 0, "Goods lift cannot callback before1.43 seconds")
	advance(game, 0.01)
	check(game.world_two.scene_index == 1 and game.player == Vector2(8910, 482), "Source sceneLand0 and landing_y476 retain loading-bay entrance rather than teleport420px")
	check(game.camera == Vector2(8710, 0) and game.camera_speed == 0, "Goods-lift callback uses source200px camera offset")
	check(not game.world_two.checkpoint_hit and game.hearts == 1, "Checkpoint remains next-frame phase after lift callback")
	game.step(0.01, {})
	check(game.world_two.checkpoint_hit and game.hearts == 3, "Actual next-frame checkpoint tops up hearts")
	check(JSON.stringify(game.level) == original, "Belts/lift never modify authored geometry or metadata")
	game.load_level("2-1")
	check(game.world_two.scene_policy.is_empty() and game.world_two.camera_cap(game) == 7162, "Reloading parking restores default scene view without stockroom settings")
	game.load_level("2-2")
	check(game.world_two.scene_policy.is_empty() and game.world_two.camera_cap(game) == 9962, "Aisle retains its default scene contract")
	game.queue_free()
	await process_frame
	print("Stockroom main integration: ", checks, " checks, ", failures.size(), " failures (focused fixtures)")
	quit(0 if failures.is_empty() else 1)
