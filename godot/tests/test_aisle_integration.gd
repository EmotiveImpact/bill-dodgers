extends SceneTree
## Real-host focused fixtures, not traversal or difficulty proof.
const AisleRenderer = preload("res://src/aisle_renderer.gd")
const ShoppingRenderer = preload("res://src/shopping_street_renderer.gd")
const SaveStore = preload("res://src/save_store.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)
func fresh(game, id: String = "2-2", who: String = "jp") -> void:
	game.character = who
	game.load_level(id)
	for wave in game.combat.waves: wave.at = INF # Explicit encounter isolation.
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
func test_fresh_face_and_crouch_power(game) -> void:
	for id in ["1-1", "2-2", "2-S"]:
		fresh(game, id)
		game.step(0.01, {"left": true})
		check(game.face == -1, "%s movement genuinely changes facing" % id)
		fresh(game, id)
		check(game.face == 1 and not game.crouching, "%s fresh replay resets facing and stance" % id)
		game.power = "split"
		game.power_time = 10
		game.step(0, {"down": true, "aim": true, "shoot": true})
		check(game.bullets.map(func(b): return b.v) == [Vector2(780, 0), Vector2(741, -200), Vector2(741, 120)], "%s crouch plus aim retains forward split spread" % id)
		fresh(game, id)
		game.power = "debit"
		game.power_time = 10
		game.step(0, {"down": true, "aim": true, "shoot": true})
		check(game.bullets.size() == 1 and game.bullets[0].v == Vector2(780, 0) and game.bullets[0].homing, "%s crouch plus aim keeps one homing debit shot" % id)
		fresh(game, id)
		game.power = "split"
		game.power_time = 10
		game.step(0, {"down": true, "right": true, "aim": true, "shoot": true})
		check(game.bullets.map(func(b): return b.v) == [Vector2(780, 0), Vector2(741, -200), Vector2(741, 120)], "%s simultaneous crouch direction and aim still use forward spread" % id)
		game.face = -1
		game.mode = "over"
		game.hearts = 0
		game._continue_level()
		check(game.face == -1, "%s Continue preserves facing rather than fresh-reset behavior" % id)

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/test_support.gd").silence(game)
	game.save = {"schema": 1, "receipts": {}, "skills": []}
	fresh(game)
	check(game._native_world_two() and game.supermarket_renderer is AisleRenderer, "Aisle uses native W2 runtime and dedicated original-art painter")
	var hz = game.world_two.hazard_controller
	check(hz.gates.size() == 7 and hz.plates.size() == 5 and hz.buttons.size() == 2, "All source gate/pad/button controllers exist")
	check(game.world_two.unsupported_hazards.is_empty(), "No aisle schema is left inert")
	check(game.world_two.surfaces(game).size() == 22 and game.level.solids.size() == 1, "Seven live gate surfaces augment 15 immutable authored surfaces")
	var original := JSON.stringify(game.level)
	check(game.ability_inside_wall(Vector2(2500, 400)) and game._wall_clamp(2450, 2500, 482) == 2452, "Closed gate blocks actual player and ability geometry")
	stand(game, Vector2(1900, 482), 1600)
	advance(game, 0.2)
	check(hz.plates[0].on and hz.gates[0].held and is_equal_approx(hz.gates[0].timer, 5.2), "Standing on actual plate holds gate with source solo timer")
	check(hz.gates[0].open < 0.55 and game.ability_inside_wall(Vector2(2500, 400)), "Gate remains blocking before source 55 percent threshold")
	advance(game, 0.02)
	check(hz.gates[0].open > 0.55 and not game.ability_inside_wall(Vector2(2500, 400)) and game._wall_clamp(2450, 2500, 482) == 2500, "Gate opens every actual collision query on late update")
	check(game.floor_at(2500, -100) == 482 and game.skill_floor_below(2500, -100) == 482, "Open gate no longer masks floor or skill probes")
	check(JSON.stringify(game.level) == original, "Live gate motion never modifies source META")
	fresh(game)
	hz = game.world_two.hazard_controller
	stand(game, Vector2(4300, 246), 3900)
	game.bullets.append({"p": Vector2(4370, 152), "v": Vector2.ZERO, "life": 1.0, "enemy": false, "damage": 99})
	game.step(0, {})
	check(hz.buttons[0].hit == 0.3 and hz.gates[1].timer == 6.5 and game.bullets.is_empty(), "Actual projectile hook consumes high-button shot and starts matching gate timer")
	check(hz.gates[1].open == 0 and game.ability_inside_wall(Vector2(4500, 400)), "Shot timer alone does not move collision before late gate update advances")
	advance(game, 0.22)
	check(hz.gates[1].open > 0.55 and not game.ability_inside_wall(Vector2(4500, 400)), "High button opens source gate through ordinary frame order")
	fresh(game, "2-2", "mei")
	game.world_two.scene_index = 1 # Focused frozen-floor fixture, not route proof.
	stand(game, Vector2(11800, 482), 11200)
	game.world_two.checkpoint_hit = true
	game.step(0.01, {"right": true})
	check(is_equal_approx(game.player.x, 11800 + (270 + 40 * 0.01 / 0.9) * 0.01 + 270 * 0.12 * 0.01), "Mei terrain base uses ice interpolation, then separate passive nudge")
	game.step(0.01, {})
	check(game.player.x > 11803.4, "Released ice input retains source momentum")
	var velocity: float = game.world_two.hazard_controller.ice_velocity[game.get_instance_id()]
	game.step(0.01, {"jump": true})
	check(not game.grounded and game.world_two.hazard_controller.ice_velocity[game.get_instance_id()] > 0, "Fresh jump preserves ice state into airborne physics")
	game.step(0.01, {})
	check(game.world_two.hazard_controller.ice_velocity[game.get_instance_id()] < velocity, "Airborne momentum approaches ordinary input without instant reset")
	fresh(game)
	stand(game, Vector2(5300, 482), 5000)
	game.invincible = 999
	advance(game, 1.71)
	check(game.world_two.entities.any(func(e): return e.k == "drop" and e.kind == "box" and e.t < e.warn), "Actual late update creates warned box in occupied source zone")
	hz = game.world_two.hazard_controller
	var before := JSON.stringify([hz.gates, hz.plates, hz.buttons, hz.drop_counters, hz.ice_velocity, game.world_two.entities])
	game.mode = "pause"
	game.step(10, {"right": true})
	check(before == JSON.stringify([hz.gates, hz.plates, hz.buttons, hz.drop_counters, hz.ice_velocity, game.world_two.entities]), "Pause freezes hazard warning, gate timers and momentum")
	game.mode = "over"
	game.hearts = 0
	game._continue_level()
	check(game.mode == "play" and game.hearts == 3 and before == JSON.stringify([hz.gates, hz.plates, hz.buttons, hz.drop_counters, hz.ice_velocity, game.world_two.entities]), "Continue preserves hazards, warning and momentum instead of resetting stage")
	fresh(game)
	hz = game.world_two.hazard_controller
	check(hz.drop_counters.is_empty() and hz.ice_velocity.is_empty() and game.world_two.entities.is_empty() and hz.gates.all(func(g): return g.open == 0 and g.timer == 0), "Explicit fresh replay clears leaked source drop counters and all live gate state")
	fresh(game, "2-S")
	check(game._native_world_two() and game.supermarket_renderer is ShoppingRenderer, "Bonus street selects its native runtime and painter")
	check(game.world_two.hazard_controller.gates.is_empty() and game.world_two.unsupported_hazards.is_empty() and game.world_two.entities.is_empty(), "Bonus does not inherit aisle gates, drops or invented fridge")
	advance(game, 101)
	check(game.mode == "play" and game.world_two.end_time == 0 and not game.save.get("cleared", {}).get("2-S", false), "Dormant 100-second metadata does not grant clear or game-over")
	check(game.world_two.coins_done.size() > 0, "Bonus uses real authored persistent coin rows")
	game.save.cleared = {"2-2": true, "2-S": true, "7-1": true}
	SaveStore.write_save(game.save, "user://aisle-allowlist-fixture.json")
	var loaded := SaveStore.read_save("user://aisle-allowlist-fixture.json")
	check(loaded.cleared.has("2-2") and loaded.cleared.has("2-S") and not loaded.cleared.has("7-1"), "Shared save capability accepts integrated stages and strips unknown-level forged clear")
	test_fresh_face_and_crouch_power(game)
	game.queue_free()
	await process_frame
	print("Aisle and shopping main integration: ", checks, " checks, ", failures.size(), " failures (focused fixtures)")
	quit(0 if failures.is_empty() else 1)
