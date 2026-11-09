extends SceneTree
## Focused main/combat integration, not a whole-level traversal. Fixtures place
## actors at source coordinates to isolate collision and objective contracts.
var failures: Array[String] = []
var checks := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: ", label)

func _initialize() -> void: call_deferred("run")

func no_waves(game) -> void:
	# Keep actual source data untouched while suppressing unrelated spawns in a
	# narrowly scoped collision fixture. This is never used as progression proof.
	for wave in game.combat.waves: wave.at = INF

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/test_support.gd").silence(game)
	game.save = {"schema": 1, "receipts": {}, "skills": []}
	game.character = "jp"
	game.load_level("1-2")
	check(game._native_world_one() and game.combat.waves.size() == 11 and game.world_one.crumbles.size() == 12, "Main enables real rooftop combat and dynamic slate state")
	check(game.boss == null and game.crates.size() == 6, "Rooftops starts with source crates and no Jar Thief")
	game.step(1.0 / 60, {})
	game.step(1.0 / 60, {"jump": true})
	for i in range(60): game.step(1.0 / 60, {})
	check(game.grounded and game.on_platform and game.player.y == 345, "Ordinary input jumps from courtyard and lands on reachable fire escape")
	check(game.camera.y < 0, "Native camera follows upward fire escape motion")
	# Actual main landing and down+jump must include dynamic slates.
	game.load_level("1-2")
	no_waves(game)
	game.camera = Vector2(5400, -674)
	game.player = Vector2(5700, -224)
	game.velocity = Vector2(0, 100)
	game.grounded = false
	game.invincible = 999
	game.step(0.016, {})
	check(game.grounded and game.on_platform and game.player.y == -222, "Main descending player lands on dynamic slate as a one-way platform")
	game.jump_held = false
	game.step(0.016, {"down": true, "jump": true})
	check(not game.grounded and game.drop_time > 0 and game.player.y > -222, "Down+jump passes through slate instead of reattaching")
	game.world_one.reset(game)
	game.player = Vector2(5700, -222)
	game.velocity = Vector2.ZERO
	game.drop_time = 0
	game.grounded = true
	game.on_platform = true
	for i in range(40): game.step(0.016, {})
	check(game.world_one.crumbles[0].fall == 0 and game.grounded, "Actual scene leaves slate solid before650ms")
	game.step(0.011, {})
	check(game.world_one.crumbles[0].fall > 0 and not game.grounded and game.velocity.y == 50, "Actual scene collapse releases player after combat and pickups")
	check(game._land(5700, -230, -220) == INF, "Native projectile/coin/player landing wrapper excludes fallen slate")
	game.step(0.016, {})
	check(not game.grounded and game.player.y > -222, "Following frame falls through removed slate without fake floor")
	var paused_fall: float = game.world_one.crumbles[0].fall
	game.mode = "paused"
	game.step(10, {})
	check(game.world_one.crumbles[0].fall == paused_fall, "Pause freezes actual scene crumble state")
	game.load_level("1-1")
	check(game.world_one.crumbles.is_empty() and game._land(5700, -230, -220) == INF, "Switching levels removes old rooftop slate collisions")
	game.load_level("1-2")
	check(game.world_one.crumbles.all(func(q): return q.t == 0 and q.fall == 0), "Rooftop reload resets every triggered slate")
	# Real combat spawning and early-return hop execution.
	no_waves(game)
	game.camera = Vector2(850, -604)
	game.player = Vector2(1300, -152)
	game.combat.spawn(game, "r", "rush")
	var enemy: Dictionary = game.enemies.back()
	enemy.p = Vector2(1570, -152)
	enemy.segment = game.level.solids[1]
	enemy.entered = true
	enemy.stop = 0
	game.player.x = 1900
	game.camera.x = 1400
	game.combat._update_enemies(0.016, game)
	check(enemy.has("hop") and enemy.hop.finish == Vector2(1737, -92), "Combat routes edge robot into source roof-gap hop")
	var start: Vector2 = enemy.p
	var duration: float = enemy.hop.duration
	game.combat._update_enemies(duration / 2, game)
	check(enemy.p.x > start.x and enemy.p.y < -152, "Combat advances hop arc instead of ordinary segment clamp")
	game.combat._update_enemies(duration / 2, game)
	check(not enemy.has("hop") and enemy.p == Vector2(1737, -92), "Actual combat lands gap hop on destination segment")
	game.enemies.clear()
	game.camera = Vector2(4400, -694)
	game.player = Vector2(5000, -242)
	game.combat.spawn(game, "r", "rush")
	enemy = game.enemies.back()
	enemy.p = Vector2(4510, -242)
	enemy.segment = game.level.solids[8]
	enemy.entered = true
	game.world_one.chimney_step(game)
	check(enemy.has("hop") and enemy.hop.finish.x == 4671, "Scene hook schedules source chimney hop against actual roof data")
	game.enemies.clear()
	game.grounded = false
	game.player = Vector2(5800, 800)
	game.combat.spawn(game, "r", "fly")
	enemy = game.enemies.back()
	check(enemy.base_y <= -432 and enemy.base_y >= -472, "Combat flyer spawn uses midpoint roof despite player falling")
	# The source bobs flyers and creates Bailiff volleys after projectiles.
	# These cases detect a one-frame reordering, not merely final coordinates.
	game.load_level("1-2")
	no_waves(game)
	game.camera = Vector2(1150, -634)
	game.player = Vector2(1300, -152)
	game.combat.spawn(game, "r", "fly")
	enemy = game.enemies.back()
	enemy.p = Vector2(1450, -362)
	enemy.base_y = -362.0
	enemy.fly_time = 0.0
	enemy.entered = true
	enemy.stop = 150.0
	enemy.cd = 100.0
	game.bullets.append({"p": Vector2(1450, -361), "v": Vector2.ZERO, "life": 1.0, "enemy": false, "damage": 1})
	game.step(0.1, {})
	check(enemy.hp == 2 and enemy.p.y > -361 and game.bullets.size() == 1, "Flyer collision uses pre-bob feet during projectile update")
	game.step(0, {})
	check(enemy.hp == 1 and game.bullets.is_empty(), "Following frame sees flyer new bob position for projectile hit")
	game.enemies.clear()
	game.combat.spawn(game, "r", "mini")
	enemy = game.enemies.back()
	enemy.p = Vector2(1450, -152)
	enemy.segment = game.level.solids[1]
	enemy.entered = true
	enemy.stop = 150.0
	enemy.cd = 100.0
	enemy.volley = 0.001
	game.step(0.016, {})
	check(game.bullets.size() == 3 and game.bullets.all(func(b): return b.p.y == -352 and b.life == 20), "Bailiff scene volley remains at muzzle until next frame")
	game.step(0.016, {})
	check(game.bullets.size() == 3 and game.bullets.all(func(b): return b.p.y < -352 and b.life < 20), "New volley bills start moving on following projectile pass")
	# Fall recovery uses live safe roof rather than a Continue checkpoint below.
	game.load_level("1-2")
	no_waves(game)
	game.player = Vector2(5000, -242)
	game.camera = Vector2(4700, -694)
	game.grounded = true
	game.on_platform = false
	game.step(0.016, {})
	check(game.world_one.safe_position == Vector2(5000, -242), "Main stores latest solid-roof fall-safe position")
	game.player = Vector2(5700, 1000)
	game.grounded = false
	game.invincible = 999
	game._fall_off()
	check(game.player.y == -242 and game.grounded and game.hearts == 2 and game.velocity == Vector2.ZERO, "Main gap recovery returns to roof and applies source forced fall damage")
	# End objective uses real wave controller, honors delayed spawns, then
	# grants a native clear/save only after the source non-boss end delay.
	game.load_level("1-2")
	game.camera = Vector2(19184, -834)
	game.player = Vector2(19600, -382)
	game.grounded = true
	game.invincible = 999
	game.combat.tick(0.016, game)
	check(game.world_one.end_time == 0 and game.mode == "play" and game.boss == null, "Reaching last roof cannot clear outstanding waves or spawn Jar Thief")
	game.enemies.clear()
	for wave in game.combat.waves:
		wave.started = true
		wave.done = true
	game.scene_objective(0.016)
	check(game.world_one.end_time > 0 and game.mode == "play" and game.boss == null, "Finished source waves start non-boss rooftop end banner")
	game.scene_objective(2.582)
	check(game.mode == "play" and not game.save.get("cleared", {}).get("1-2", false), "End banner cannot save completion early")
	game.scene_objective(0.002)
	check(game.mode == "clear" and game.save.cleared["1-2"] and game.boss == null, "Rooftops clears and persists after2.6seconds without a boss")
	var banked: int = game.save.kitty
	game.scene_objective(10)
	check(game.save.kitty == banked, "Repeated objective call cannot bank a clear twice")
	game.load_level("4-1")
	check(not game._native_world_one() and game.mode == "play" and game.boss == null, "Holiday loads its own family without an invented entry boss")
	game.level_id = "7-1" # Explicit invalid-run fixture, not an unported catalog stage.
	game._complete_level()
	check(not game.save.cleared.get("7-1", false), "Unknown run cannot acquire a false completion record")
	game.queue_free()
	await process_frame
	print("World 1 main integration: ", checks, " checks, ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
