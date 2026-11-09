extends SceneTree
const Save = preload("res://src/save_store.gd")
const Skills = preload("res://src/movement_skills.gd")
const TEST_SAVE := "user://skill-integration-save.json"
var failures: Array[String] = []
var checks := 0
var game

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: " + label)

func _initialize() -> void: call_deferred("run")

func clean_stage(id: String, unlocked: Array = []) -> void:
	game.save = {"schema": 1, "receipts": {}, "skills": unlocked.duplicate()}
	game.character = "jp"
	check(game.load_level(id, false), "Load " + id)
	game.combat.waves.clear()
	if game._native_world_one(): game.combat.checks.clear()
	elif game._native_world_two(): game.world_two.checkpoint_hit = true
	game.enemies.clear()
	game.bullets.clear()
	game.coins.clear()
	game.crates.clear()
	game.receipts.clear()
	game.boss = null
	game.camera_lock = null
	game.player = Vector2(400, 482)
	game.camera = Vector2.ZERO
	game.velocity = Vector2.ZERO
	game.grounded = true
	game.jump_held = false
	game.hurt_lock = 0
	game.invincible = 0

func flat_fixture() -> void:
	# Intentional deterministic terrain fixture, not a claim about authored maps.
	game.level = game.level.duplicate(true)
	game.level.solids = [[-400, 4000, 482]]
	game.level.plats = []
	game.level.fall = 2000
	if game._native_world_two():
		game.world_two.reset(game)
		game.world_two.hazards.clear()
		game.world_two.entities.clear()
		game.world_two.checkpoint_hit = true
	elif game._native_world_three():
		game.world_three.reset(game)
		game.world_three.checkpoint_done = true
	elif game._native_world_four():
		game.world_four.reset(game)
	elif game._native_world_five():
		game.world_five.reset(game)

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/test_support.gd").silence(game)
	var dirty := {"schema": 1, "receipts": {}, "skills": ["slide", "dash", "dash", "super", "double-jump", "wall-jump", "ground-pound", "god-mode", 7, null, {"skill": "dash"}]}
	check(Save.write_save(dirty, TEST_SAVE) == OK, "Write isolated malformed skill fixture")
	var restored: Dictionary = Save.read_save(TEST_SAVE)
	check(restored.skills == ["slide", "dash", "super", "double-jump", "wall-jump", "ground-pound"], "Save canonical skills sanitized and deduplicated")
	game.save = restored
	game.load_level("1-1", false)
	check(game.movement_skills.skills == restored.skills and game.abilities.skills == restored.skills, "Main restores skill and super state from sanitized save")
	Save.write_save({"schema": 1, "receipts": {}, "skills": "all"}, TEST_SAVE)
	check(Save.read_save(TEST_SAVE).get("skills", []).is_empty(), "Malformed skills field cannot unlock all")
	DirAccess.remove_absolute(TEST_SAVE)
	for stage in Skills.CARDS:
		clean_stage(stage)
		check(game.movement_skills.skills.is_empty() and game.abilities.skills.is_empty(), stage + " entry does not grant skills")
		var position: Vector2 = Skills.CARDS[stage].p
		game.player = position
		game.camera = Vector2(maxf(0, position.x - 300), position.y - 482)
		game.grounded = false
		game.step(0.0, {})
		if game.is_native_supported():
			var expected: String = Skills.CARDS[stage].skill
			check(game.movement_skills.skills == [expected] and game.save.skills == [expected] and game.movement_skills.card_collected, stage + " native stage earns and saves its actual placed card")
		else:
			check(game.movement_skills.skills.is_empty() and game.save.skills.is_empty() and not game.movement_skills.card_collected, stage + " preview cannot earn even at actual source card")
	# Host gameplay controls, using a quiet actual street start for World 1 slide.
	clean_stage("1-1", ["slide"])
	game.player = Vector2(400, game.floor_at(400, 400))
	for i in range(10): game.step(1.0 / 60, {"right": true})
	game.step(1.0 / 60, {"right": true, "down": true})
	check(game.movement_skills.slide_remaining > 0.38 and game.velocity.x > 600, "Main run then down activates World 1 slide")
	check(game.crouching and game.invincible >= 0.06, "Main slide retains crouch and source invulnerability")
	game.hurt_player(game.player.x + 100)
	check(game.hearts == 3, "World 1 slide normal invulnerability blocks real damage path")
	# Use actual combat spawn dictionaries to verify flags and direct pop bookkeeping.
	for kind in ["mini", "fly", "rush"]: game.combat.spawn(game, "r", kind)
	var big: Dictionary = game.enemies[0]
	var flyer: Dictionary = game.enemies[1]
	var rush: Dictionary = game.enemies[2]
	check(big.big and not big.fly and flyer.fly and not flyer.big, "Spawn carries source big/fly flags for skill filtering")
	big.p = game.player
	flyer.p = game.player
	rush.p = game.player
	rush.hp = 3
	var old_big_hp: int = big.hp
	var pops: int = game.pop_count
	# Exercise the integrated owned-world late hook without enemy movement first.
	game.movement_skills.late_step(game, "crouch")
	check(big.hp == old_big_hp - 1 and is_equal_approx(big.p.x, game.player.x + 30), "World 1 slide big enemy one direct damage and 30px shove")
	check(flyer.hp == 2, "World 1 slide excludes source fly flag")
	check(rush.state == "pop" and game.pop_count == pops + 1 and game.coins.size() >= 4, "World 1 slide direct kill credits pop and drops")
	check(big.flash == 0.09, "Direct slide hit uses 90ms flash")
	game.skill_slide_hit(rush, 3, 30)
	check(game.pop_count == pops + 1, "Direct slide cannot credit popped enemy twice")
	# Shared air jump through actual main step, with explicit fixture terrain.
	clean_stage("3-1", ["double-jump"])
	flat_fixture()
	game.step(0.016, {"jump": true})
	check(not game.grounded and not game.movement_skills.double_jumped, "Main normal jump does not consume double jump")
	for i in range(8): game.step(0.016, {})
	game.step(0.016, {"jump": true})
	check(game.movement_skills.double_jumped and game.velocity.y == -860, "Main fresh airborne jump invokes shared double jump")
	game.step(0.016, {})
	game.step(0.016, {"jump": true})
	check(game.velocity.y > -860, "Main repeated airborne jump cannot consume twice")
	clean_stage("2-1", ["double-jump"])
	flat_fixture()
	game.player.y = 200
	game.grounded = false
	game.step(0.016, {"jump": true})
	check(game.movement_skills.double_jumped and is_equal_approx(game.velocity.y, -860 + game.GRAVITY * 0.016), "World 2 integrated jump happens before gravity")
	# Dash button, double tap, protection and input mapping.
	clean_stage("3-1", ["dash"])
	flat_fixture()
	game.step(0.016, {"dash": true})
	check(game.velocity.x == 1100 and game.movement_skills.blocks_damage(), "Main dash button starts shared impulse/protection")
	game.hurt_player(game.player.x + 100)
	check(game.hearts == 3, "Main shared dash blocks real hurt path")
	game.step(0.3, {})
	game.hurt_player(game.player.x + 100)
	check(game.hearts == 2, "Dash damage protection expires")
	clean_stage("4-1", ["dash"])
	flat_fixture()
	game.step(0.01, {"right": true})
	game.step(0.1, {})
	game.step(0.1, {"right": true})
	check(game.velocity.x == 1100 and is_equal_approx(game.invincible, 0.26), "World 4 actual main double-tap dash and invulnerability")
	game.touches[77] = "dash"
	check(game._held("dash"), "Main dash touch routes to held control")
	game.touches.clear()
	check(game.buttons.has("dash"), "Earned dash exposes touch button")
	clean_stage("3-1")
	check(not game.buttons.has("dash"), "Unearned dash hides touch button")
	# Shared and owned wall-jump use actual solid clamps.
	for stage in ["3-1", "5-1"]:
		clean_stage(stage, ["wall-jump"])
		flat_fixture()
		game.level.solids.append([500, 600, 100])
		if game._native_world_three(): game.world_three._add_surface([500, 600, 100], false)
		elif game._native_world_five(): game.world_five._surfaces.append({"row":[500,600,100],"plat":false})
		game.player = Vector2(486, 300)
		game.grounded = false
		game.velocity = Vector2.ZERO
		game.step(0.016, {"right": true, "jump": true})
		var expected := Vector2(-550, -950) if stage == "3-1" else Vector2(-220, -960 + game.GRAVITY * 0.016)
		check(game.velocity.is_equal_approx(expected), stage + " wall jump uses correct phase/impulses")
	# Source World 5 excludes even a solid-wall collision at the camera margin.
	clean_stage("5-1", ["wall-jump"])
	flat_fixture()
	game.level.solids.append([500, 600, 100])
	game.world_five._surfaces.append({"row":[500,600,100],"plat":false})
	game.player = Vector2(486, 300)
	game.camera.x = 455
	game.grounded = false
	game.step(0.016, {"right": true, "jump": true})
	check(game.velocity.y > 0 and game.velocity.x == 0, "World 5 camera-margin collision does not grant wall jump")
	# Ground pound through actual main descent, landing, combat damage and ring.
	clean_stage("3-1", ["ground-pound"])
	flat_fixture()
	game.player.y = 200
	game.grounded = false
	game.step(0.016, {"down": true})
	check(game.movement_skills.ground_pounding and game.velocity.y == 1400, "Main fresh down starts pound")
	game.combat.spawn(game, "r", "rush")
	var target: Dictionary = game.enemies.back()
	target.p = Vector2(game.player.x + 100, 482)
	for i in range(20): game.step(0.016, {})
	check(game.grounded and not game.movement_skills.ground_pounding, "Main pound actually lands on collision surface")
	check(target.state == "pop" and game.pop_count == 1, "Main pound shockwave credits combat pop")
	check(not game.movement_skills.effects.is_empty(), "Integrated pound exposes ring effect")
	# Shared slide protection is checked before Maya's alternating-hit counter.
	game.character = "maya"
	game.abilities.reset("maya")
	game.movement_skills.slide_remaining = 0.2
	game.invincible = 0
	game.hurt_player(game.player.x + 100)
	check(game.hearts == 3, "Shared slide blocks damage before Maya counter")
	game.movement_skills.slide_remaining = 0
	game.hurt_player(game.player.x + 100)
	check(game.hearts == 2, "Protected hit did not consume Maya first-hit counter")
	game.movement_skills.ground_pounding = true
	game._game_over()
	check(not game.movement_skills.ground_pounding, "Main death cancels pounding")
	print("Skill integration: %d checks, %d failures" % [checks, failures.size()])
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
