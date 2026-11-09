extends SceneTree
## Focused actual-main integration contracts, NOT whole-level progression proof.
## Fixtures suppress unrelated waves and place actors to isolate source ordering.
const Save = preload("res://src/save_store.gd")
var failures: Array[String] = []
var checks := 0
var game

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)

func _initialize() -> void: call_deferred("run")

func clean(stage: String, who: String = "jp") -> void:
	game.save = {"schema": 1, "receipts": {}, "skills": []}
	game.character = who
	check(game.load_level(stage), "Load actual main " + stage)
	game.invincible = 999
	# Keep authored group/checkpoint/crate data; only inhibit unrelated spawning.
	for wave in game.combat.waves: wave.at = INF

func arena(who: String = "jp") -> void:
	clean("1-6", who)
	game.camera = Vector2(float(game.level.w) - game.view_width(), 0)
	game.player = Vector2(game.camera.x + 100, float(game.meta.ground))
	game.start_boss()
	game.boss.state.x = float(game.level.w) - 250
	game.boss.state.state = "walk"
	game.boss.state.next = 999.0
	game.boss.state.lid = 1.0
	game.boss.state.lid_t = 999.0
	game.boss.drain_events()
	game.crates.clear()

func helper(at: Vector2, hp: int = 8) -> Dictionary:
	game.combat.spawn(game, "r", "rush")
	var enemy: Dictionary = game.enemies.back()
	enemy.p = at
	enemy.hp = hp
	enemy.entered = true
	enemy.speed = 0.0
	enemy.stop = 999.0
	enemy.cd = 999.0
	return enemy

func crate_at(at: Vector2) -> Dictionary:
	var crate := {"p": at, "hp": 3, "broken": false, "hit": 0.0, "give": "split"}
	game.crates.append(crate)
	return crate

func bin_at(at: Vector2) -> Dictionary:
	var bin := {"x": at.x, "y": at.y, "vx": 0.0, "vy": 0.0, "roll": true, "rot": 0.0, "hp": 2, "t": 0.0}
	game.boss.state.bins.append(bin)
	return bin

func shot(at: Vector2, damage: int = 1) -> Dictionary:
	var bullet := {"p": at, "v": Vector2(1, 0), "life": 20.0, "enemy": false, "damage": damage}
	game.bullets.append(bullet)
	return bullet

func checkpoint_contracts() -> void:
	var counts := {"1-4": [10, 2, 5], "1-5": [14, 1, 3], "1-S": [4, 0, 1], "1-6": [2, 1, 2]}
	for stage in counts:
		clean(stage)
		check(game._native_world_one() and game.boss == null, stage + " is native without premature boss")
		check([game.combat.waves.size(), game.combat.checks.size(), game.crates.size()] == counts[stage], stage + " loads authored waves/checkpoints/crates")
		check(game.movement_skills.skills.is_empty(), stage + " entry does not grant skills")
		if game.combat.checks.is_empty(): continue
		var checkpoint: Dictionary = game.combat.checks[0]
		game.camera.x = checkpoint.x - game.view_width() * 0.5 - 0.01
		game.hearts = 1
		game.combat.tick(0, game)
		check(not checkpoint.hit and game.hearts == 1, stage + " checkpoint waits for camera midpoint")
		game.camera.x += 0.01
		game.combat.tick(0, game)
		check(checkpoint.hit and game.hearts == 2, stage + " checkpoint heals to two, not full")
		game.hearts = 1
		game.combat.tick(0, game)
		check(game.hearts == 1, stage + " checkpoint is one-shot")
		checkpoint.hit = false # Reuse only the trigger fixture to test max(), not progression.
		game.hearts = 3
		game.combat.tick(0, game)
		check(game.hearts == 3, stage + " checkpoint never lowers healthy player")

func tiny_speed_contracts() -> void:
	var speeds: Dictionary = {}
	for stage in ["1-4", "1-5"]:
		clean(stage)
		var values: Array = []
		for i in range(16):
			game.combat.spawn(game, "r", "tiny")
			var enemy: Dictionary = game.enemies.back()
			values.append(enemy.speed)
			check(enemy.hp == 1 and enemy.scale == 0.6, stage + " tiny retains oneHP and60percent scale")
		speeds[stage] = values
		var extra := 190.0 if stage == "1-5" else 0.0
		check(values.all(func(value): return value >= 190 + extra and value <= 230 + extra), stage + " tiny uses source base speed plus auto-scroll speed")
	for i in range(16):
		check(is_equal_approx(speeds["1-5"][i] - speeds["1-4"][i], 190), "Tiny same-seed stage speed difference is exactly190px/s")

func continue_contracts() -> void:
	for stage in ["1-4", "1-5", "1-S", "1-6"]:
		clean(stage)
		game.camera = Vector2(1200, -45)
		game.player = Vector2(1500, 410)
		game.velocity = Vector2(-75, 300)
		game.grounded = false
		game.checkpoint = Vector2(900, 482)
		game.score = 37
		game.pop_count = 4
		game.elapsed = 13.5
		game.camera_lock = 1280.0
		game.combat.waves[0].started = true
		game.combat.waves[0].t = 0.7
		game.combat.waves[0].index = 1
		if not game.combat.checks.is_empty(): game.combat.checks[0].hit = true
		helper(Vector2(1700, 482))
		game.crates[0].hp = 2
		game.receipts[0].taken = true
		game.save.receipts[stage] = [0]
		game.add_coins(Vector2(1700, 400), 2)
		shot(Vector2(1750, 400))
		game.world_one.next_coin = 2100
		game.world_one.coin_pattern = 2
		game.abilities.active = "mei"
		game.abilities.remaining = 1.3
		if stage == "1-6":
			game.start_boss()
			game.boss.state.hp = 143
			game.boss.state.state = "throw"
			game.boss.state.t = 0.3
			game.boss.state.pending_throw = true
			game.boss.state.called[0] = true
			game.boss.state.waves.append({"x": 1800.0, "vx": 450.0, "t": 0.2})
			bin_at(Vector2(1700, 442))
			game.boss.state.rain.append({"x": 1800.0, "y": 200.0, "vy": 300.0, "t": 0.1, "k": 0})
		var before := {"position": game.player, "velocity": game.velocity, "camera": game.camera, "lock": game.camera_lock,
			"checkpoint": game.checkpoint, "waves": game.combat.waves.duplicate(true), "checks": game.combat.checks.duplicate(true),
			"enemies": game.enemies.duplicate(true), "crates": game.crates.duplicate(true), "bullets": game.bullets.duplicate(true),
			"coins": game.coins.duplicate(true), "receipts": game.receipts.duplicate(true)}
		var boss_before: Dictionary = {} if game.boss == null else game.boss.state.duplicate(true)
		game.hearts = 0
		game._game_over()
		game.step(10, {"right": true, "shoot": true})
		check(game.mode == "over" and game.elapsed == 13.5, stage + " knockout freezes gameplay")
		game._continue_level()
		check(game.mode == "play" and game.hearts == 3 and game.invincible == 2.5, stage + " Continue restores source health and invulnerability")
		check(game.player == before.position and game.velocity == before.velocity and not game.grounded, stage + " Continue preserves position and motion")
		check(game.camera == before.camera and game.camera_lock == before.lock and game.checkpoint == before.checkpoint, stage + " Continue preserves camera/lock/checkpoint")
		check(game.combat.waves == before.waves and game.combat.checks == before.checks, stage + " Continue preserves original wave and checkpoint flags")
		check(game.enemies == before.enemies and game.crates == before.crates and game.bullets == before.bullets and game.coins == before.coins, stage + " Continue preserves combat and pickups")
		check(game.receipts == before.receipts and game.save.receipts[stage] == [0] and game.score == 37 and game.pop_count == 4, stage + " Continue preserves receipts/score/pop count")
		check(game.abilities.active == "mei" and game.abilities.remaining == 1.3 and game.world_one.next_coin == 2100 and game.world_one.coin_pattern == 2, stage + " Continue preserves ability and secret coin state")
		if game.boss != null: check(game.boss.state == boss_before, "Continue preserves Binman phase/lid/calls/timers/waves/bins/rain")
		game.hearts = 2
		game._continue_level()
		check(game.hearts == 2, stage + " repeated Continue while playing cannot heal")

func card_and_preview_contracts() -> void:
	clean("1-4")
	game.player = Vector2(8497, 482)
	game.camera = Vector2(8197, 0)
	game.step(0, {})
	check(game.movement_skills.card_collected and game.save.skills == ["slide"], "Actual park card position earns Slide")
	check(game.abilities.skills == ["slide"] and Save.read_save().skills == ["slide"], "Park card persists through actual save adapter and abilities")
	game.save = Save.read_save()
	game.load_level("1-6")
	check(game.movement_skills.skills == ["slide"] and game.abilities.skills == ["slide"], "Earned park Slide survives stage reload")
	game.load_level("1-4")
	game.player = Vector2(8497, 482)
	game.camera = Vector2(8197, 0)
	for wave in game.combat.waves: wave.at = INF
	game.step(0, {})
	check(game.save.skills == ["slide"], "Revisiting actual park card does not duplicate unlock")
	clean("4-4")
	game.player = Vector2(5700, -358)
	game.camera = Vector2(5400, -840)
	game.step(0, {})
	check(game.is_native_supported() and game._native_world_four() and game.save.skills.is_empty(), "World 4 uses its own card position, not the Big top card fixture")
	game.level_id = "7-4" # Explicit unknown-ID guard fixture, not an authored stage.
	game._complete_level()
	check(game.mode == "play" and not game.save.get("cleared", {}).has("7-4") and not game.save.get("cleared", {}).has("4-4"), "Unknown stage cannot falsely clear")

func boss_entry_contracts() -> void:
	clean("1-6")
	game.camera.x = float(game.level.w) - game.view_width()
	game.scene_objective(0)
	check(game.boss == null, "Binman approach cannot skip original unfinished waves")
	# Deliberate completed-wave fixture. Whole-run progression has another suite.
	for wave in game.combat.waves: wave.started = true; wave.done = true
	game.scene_objective(0)
	check(game.boss != null and game.boss.state.hp == 260 and game.boss.state.max == 260, "Completed approach starts native solo Binman with260HP")
	check(game.boss.state.state == "enter" and game.boss.state.x == float(game.level.w) + 200 and game.boss.state.fy == float(game.meta.ground), "Binman starts at source entry with intentional finite floor repair")
	check(game.boss.state.called == [false, false, false] and game.boss.state.bins.is_empty() and game.boss.state.rain.is_empty() and not game.boss.state.has("jar"), "Binman initial state is clean and has no jar")
	game.boss.state.hp = 10
	game.boss.state.called[0] = true
	bin_at(Vector2(3700, 442))
	game.load_level("1-6")
	check(game.boss == null and game.bullets.is_empty(), "New 1-6 attempt discards old boss and shots")
	game.start_boss()
	check(game.boss.state.hp == 260 and game.boss.state.called == [false, false, false] and game.boss.state.bins.is_empty(), "New encounter resets health, calls and hazards")

func ghost_collision_contracts() -> void:
	arena()
	var bx: float = game.boss.state.x
	var enemy := helper(Vector2(bx, 430))
	var crate := crate_at(Vector2(bx, 392))
	var bin := bin_at(Vector2(bx, 362))
	game.face = -1
	game.damage_boss(5)
	check(game.boss.state.hp == 260 and enemy.hp == 8 and game.bullets.size() == 1, "Boss ability queues a shot rather than bypassing collision")
	check(game.bullets[0].ghost and game.bullets[0].v.x > 0 and game.bullets[0].p == Vector2(bx, 362), "Invisible boss zap points toward target, not facing")
	game.step(0, {})
	check(enemy.hp == 3 and enemy.p.x == bx + 6 and game.boss.state.hp == 260, "Helper intercepts ability zap before Binman and gets target-direction shove")
	check(crate.hp == 3 and bin.hp == 2 and game.bullets.is_empty(), "Helper consumes zap before crate and late bin pass without recursion")
	game.enemies.clear()
	game.boss.state.lid = 0
	game.damage_boss(99)
	game.step(0, {})
	check(game.boss.state.hp == 260 and crate.hp == 3 and bin.hp == 2 and game.bullets.is_empty(), "Closed Binman lid consumes ghost before overlapping crate/bin")
	game.boss.state.lid = 1
	game.damage_boss(99)
	game.step(0, {})
	check(game.boss.state.hp == 259 and crate.hp == 3 and bin.hp == 2, "Open lid takes one regardless of ability damage and precedes crate/bin")
	game.crates.clear()
	game.boss.state.bins.clear()
	crate = crate_at(Vector2(bx - 190, 482))
	bin = bin_at(Vector2(bx - 190, 452))
	game.hit_crate(crate, 9)
	check(crate.hp == 3 and game.bullets.size() == 1, "Crate ability also queues a ghost")
	game.step(0, {})
	check(crate.hp == 2 and bin.hp == 2 and game.bullets.is_empty(), "Crate consumes ghost for one damage before late bin")
	game.crates.clear()
	game.ability_free_zap(Vector2(bin.x, bin.y), -1)
	game.step(0, {})
	check(bin.hp == 1 and game.bullets.is_empty(), "Unintercepted invisible free zap reaches late Binman bin pass")
	game.ability_free_zap(Vector2(bin.x, bin.y), 1)
	game.step(0, {})
	check(game.boss.state.bins.is_empty() and game.coins.size() == 2, "Second ghost destroys bin and credits source two coins")
	# Ordinary impacts call combat directly, never the ghost-producing host helper.
	var target := helper(Vector2(bx - 220, 482), 5)
	shot(target.p - Vector2(0, 56), 2)
	game.step(0, {})
	check(target.hp == 3 and game.bullets.is_empty(), "Ordinary robot impact is immediate and does not recursively queue ghost")
	game.enemies.clear()
	crate = crate_at(Vector2(bx - 220, 482))
	shot(crate.p - Vector2(0, 30), 9)
	game.step(0, {})
	check(crate.hp == 2 and game.bullets.is_empty(), "Ordinary crate impact is immediate and still only one damage")
	game.crates.clear()
	target = helper(Vector2(game.player.x - 60, 482), 5)
	game.face = 1
	game.damage_enemy(target, 2)
	check(target.hp == 5 and game.bullets[0].v.x < 0, "Enemy ability waits for shot pass and aims left despite right-facing player")
	game.step(0, {})
	check(target.hp == 3 and target.p.x == game.player.x - 66 and game.bullets.is_empty(), "Enemy ability target direction survives actual collision adapter")

func ghost_expiry_contracts() -> void:
	arena()
	var point := Vector2(game.camera.x + 280, 260)
	game.ability_free_zap(point, -1)
	game.step(0.07, {})
	check(game.bullets.size() == 1 and is_equal_approx(game.bullets[0].ghost_age, 0.07), "Uncollided ghost lives through exact70ms boundary")
	game.step(0.001, {})
	check(game.bullets.is_empty(), "Uncollided ghost expires after70ms")
	game.ability_free_zap(point, 1)
	game.bullets[0].ghost_age = 0.069
	var bin := bin_at(point)
	game.step(0.002, {})
	check(bin.hp == 1 and game.bullets.is_empty(), "Ghost crossing70ms can still hit late bin before expiry")
	arena("theo")
	point = Vector2(game.camera.x + 280, 350)
	bin = bin_at(point)
	# An explicit stationary ball fixture isolates the source after-boss fx pass.
	game.abilities.effects.append({"kind": "ball", "p": point, "v": Vector2.ZERO, "age": 0.0, "life": 3.6, "spin": 0.0, "free": 0.0, "boss_next": 0.0, "floor": 482.0, "trail": []})
	game.step(0, {})
	check(bin.hp == 2 and game.bullets.size() == 1 and game.bullets[0].ghost, "Theo late free ball zap is queued after current boss-bin pass")
	game.step(0, {})
	check(bin.hp == 1 and game.bullets.is_empty(), "Theo late free ball zap reaches bin on next frame only")

func ghost_viewport_contracts() -> void:
	clean("1-6")
	game.camera = Vector2(100, -180)
	game.player = Vector2(400, 482)
	game.crates.clear()
	# No enemies/boss/crates: this isolates the source strict viewport filter.
	var edges := [
		{"name": "left", "point": Vector2(game.camera.x - 40, 250), "inward": Vector2.RIGHT},
		{"name": "right", "point": Vector2(game.camera.x + game.view_width() + 40, 250), "inward": Vector2.LEFT},
		{"name": "top", "point": Vector2(400, game.view_top() - 60), "inward": Vector2.DOWN},
		{"name": "bottom", "point": Vector2(400, game.camera.y + 580), "inward": Vector2.UP},
	]
	for edge in edges:
		for offset in [-0.01, 0.0, 0.01]:
			game.bullets.clear()
			game.ability_free_zap(edge.point + edge.inward * offset, 1)
			game.step(0, {})
			check(game.bullets.size() == (1 if offset > 0 else 0), "Ghost strict %s viewport bound at inward offset %s" % [edge.name, offset])
	# With a real Binman, filtering must happen before the later bin pass.
	# Shift the camera vertically so bottom-edge shots are above solid ground.
	arena()
	game.camera.y = -180
	edges = [
		{"name": "left", "point": Vector2(game.camera.x - 40, 250), "inward": Vector2.RIGHT},
		{"name": "right", "point": Vector2(game.camera.x + game.view_width() + 40, 250), "inward": Vector2.LEFT},
		{"name": "top", "point": Vector2(game.camera.x + 280, game.view_top() - 60), "inward": Vector2.DOWN},
		{"name": "bottom", "point": Vector2(game.camera.x + 280, game.camera.y + 580), "inward": Vector2.UP},
	]
	for edge in edges:
		for offset in [-0.01, 0.0, 0.01]:
			game.boss.state.bins.clear()
			game.boss.state.waves.clear()
			var point: Vector2 = edge.point + edge.inward * offset
			var bin := bin_at(point)
			game.ability_free_zap(point, 1)
			game.step(0, {})
			check(bin.hp == (1 if offset > 0 else 2) and game.bullets.is_empty(), "Strict %s viewport filter precedes late bin at inward offset %s" % [edge.name, offset])

func ama_and_defeat_contracts() -> void:
	arena("ama")
	game.abilities.meter = 1
	game.step(0, {"special": true})
	check(game.boss.state.hp == 258 and game.boss.state.dizzy == 0 and game.bullets.is_empty(), "Ama applies transient double damage before boss clears dizzy that frame")
	shot(Vector2(game.boss.state.x, 362), 99)
	game.step(0, {})
	check(game.boss.state.hp == 257, "Subsequent ordinary hit no longer gets Ama double damage")
	arena("ama")
	game.boss.state.lid = 0
	game.abilities.meter = 1
	game.step(0, {"special": true})
	check(game.boss.state.hp == 260 and game.boss.state.dizzy == 0, "Ama cannot bypass closed lid")
	arena()
	game.boss.state.hp = 1
	var bx: float = game.boss.state.x
	var target := helper(Vector2(bx - 200, 482), 3)
	shot(Vector2(bx, 362))
	var later := shot(target.p - Vector2(0, 56))
	game.step(0, {})
	check(game.boss.state.state == "down" and target.state == "pop" and target.hp == 3, "Final boss impact kills helper immediately before later shot is processed")
	check(later.life > 0 and game.bullets.has(later) and game.pop_count == 0, "Later shot passes newly popped helper without false hit or player pop credit")
	check(game.mode == "play" and game.bus_departure == game.elapsed + 1.5 and not game.boss.state.has("jar"), "Binman defeat schedules bus and does not demand Jar Thief pickup")
	check(not game.save.get("cleared", {}).has("1-6"), "Boss final hit alone cannot bank early clear")
	game.step(2.6, {})
	check(game.mode == "play", "Binman direct clear waits strictly beyond2.6seconds")
	game.step(0.001, {})
	check(game.mode == "clear" and game.save.cleared.get("1-6", false), "Actual main receives direct Binman timed clear without jar")
	check(Save.read_save().cleared.get("1-6", false), "Native Binman completion persists through save adapter")
	var kitty: int = game.save.kitty
	game.step(10, {})
	game._complete_level()
	check(game.save.kitty == kitty, "Completed Binman cannot bank twice")

func clear_race_fixture(timer: float) -> void:
	arena()
	for checkpoint in game.combat.checks: checkpoint.hit = true
	game.boss.state.hp = 1
	shot(Vector2(game.boss.state.x, float(game.meta.ground) - 120))
	game.step(0, {})
	check(game.boss.state.state == "down", "Race fixture defeats boss through actual main projectile pass")
	game.boss.state.t = timer
	game.hearts = 1
	game.invincible = 0
	game.score = 7
	game.save.kitty = 100
	game._save_progress()

func lethal_hazard(kind: String) -> Dictionary:
	if kind == "bin":
		var bin := bin_at(game.player + Vector2(40, -40))
		bin.vx = -300.0
		return bin
	if kind == "rain":
		var rain := {"x": game.player.x, "y": game.player.y - 70, "vy": 0.0, "t": 0.0, "k": 0}
		game.boss.state.rain.append(rain)
		return rain
	var bullet := shot(game.player - Vector2(0, 60))
	bullet.enemy = true
	bullet.v = Vector2.ZERO
	return bullet

func hazard_consumed(kind: String, hazard: Dictionary) -> bool:
	if kind == "bin": return hazard.hp == 0
	if kind == "rain": return hazard.get("dead", false)
	return hazard.life <= 0

func lethal_clear_race_contracts() -> void:
	for kind in ["bin", "rain", "bill"]:
		clear_race_fixture(2.6)
		var expected_kitty: int = 100 + game.score + game.coins.size()
		var hazard := lethal_hazard(kind)
		game.step(1.0 / 60, {})
		check(hazard_consumed(kind, hazard) and game.invincible > 0, "Clear-frame lethal " + kind + " really hits and is consumed")
		check(game.mode == "clear" and game.boss._cleared and game.save.get("cleared", {}).get("1-6", false), "Source clear beats global knockout on lethal " + kind + " frame")
		check(game.hearts == 1, "Source clear revives lethal " + kind + " victim with one heart")
		check(game.save.kitty == expected_kitty and Save.read_save().get("kitty", -1) == expected_kitty and Save.read_save().get("cleared", {}).get("1-6", false), "Lethal " + kind + " clear banks and persists exactly one reward")
		game._continue_level()
		game.step(3, {})
		game._complete_level()
		check(game.mode == "clear" and game.save.kitty == expected_kitty and Save.read_save().get("kitty", -1) == expected_kitty, "Repeated Continue/step/clear cannot double-bank lethal " + kind + " clear")
		game.load_level("1-6")
		game.hearts = 1
		game.invincible = 0
		game.hurt_player(game.player.x + 10)
		check(game.mode == "over", "Outside-step damage is immediate after lethal " + kind + " clear/reload")
		# A lethal hit before the finish threshold must still knock out normally.
		clear_race_fixture(1.0)
		hazard = lethal_hazard(kind)
		game.step(1.0 / 60, {})
		check(game.mode == "over" and game.hearts == 0 and hazard_consumed(kind, hazard), "Early lethal " + kind + " still produces normal knockout")
		check(not game.boss._cleared and not game.save.get("cleared", {}).has("1-6") and game.save.kitty == 100, "Early lethal " + kind + " cannot latch or bank boss clear")
		var frozen_timer: float = game.boss.state.t
		game.step(3, {})
		check(game.mode == "over" and game.boss.state.t == frozen_timer, "Early lethal " + kind + " knockout freezes boss timer")
		game._continue_level()
		check(game.mode == "play" and game.hearts == 3 and game.invincible == 2.5, "Continue revives early lethal " + kind + " victim")
		for i in range(110): game.step(1.0 / 60, {})
		check(game.mode == "clear" and game.boss._cleared and game.save.get("cleared", {}).get("1-6", false), "Continue after early lethal " + kind + " can finish Binman")
		var kitty: int = game.save.kitty
		check(kitty == 100 + game.score and Save.read_save().get("kitty", -1) == kitty, "Continued " + kind + " attempt banks and saves once")
		game._complete_level()
		game._continue_level()
		game.step(3, {})
		check(game.save.kitty == kitty and Save.read_save().get("kitty", -1) == kitty, "Continued " + kind + " clear cannot bank again")

func zero_heart_pickup_contracts() -> void:
	arena("mei") # No JP pre-hit passive magnet in this late-pickup fixture.
	game.hearts = 1
	game.invincible = 0
	game.score = 0
	game.coins.clear()
	for checkpoint in game.combat.checks: checkpoint.hit = false
	var center: Vector2 = game.player - Vector2(0, game.character_height() * 0.4)
	var near_coin := {"p": center, "v": Vector2.ZERO, "age": 1.0, "rest": true}
	var magnet_coin := {"p": center + Vector2(75, 0), "v": Vector2.ZERO, "age": 1.0, "rest": true}
	game.coins.append(near_coin)
	game.coins.append(magnet_coin)
	var magnet_start: Vector2 = magnet_coin.p
	for give in ["heart", "split"]:
		game.items.append({"p": center, "vy": 0.0, "give": give, "age": 1.0, "rest": true})
	var receipt: Dictionary = game.receipts[0]
	receipt.position = game.player - Vector2(0, 60)
	game._save_progress()
	var lethal := lethal_hazard("bill")
	var later := lethal_hazard("bill")
	game.step(1.0 / 60, {})
	check(lethal.life <= 0 and game.hearts == 0 and game.mode == "over", "Lethal projectile reaches zero hearts before deferred pickup phase")
	check(game.combat.checks[0].hit and game.hearts == 0, "Same-frame source checkpoint records flag but cannot revive zero-heart player")
	check(game.items.size() == 2 and game.power.is_empty(), "Zero-heart player cannot collect heart or weapon item")
	check(game.coins.size() == 2 and game.score == 0 and magnet_coin.p == magnet_start, "Zero-heart player cannot collect or magnetize late coins")
	check(not receipt.taken and game.save.receipts.get("1-6", []).is_empty() and Save.read_save().receipts.get("1-6", []).is_empty(), "Zero-heart player cannot collect or persist same-frame receipt")
	check(later.life > 0 and game.bullets.has(later), "Later hostile shot does not collide with already-down player")
	game._continue_level()
	game.step(0, {})
	check(game.hearts == 3 and game.items.is_empty() and game.power == "split", "Continue restores living heart/item pickup eligibility")
	check(game.coins.size() == 1 and receipt.taken and game.score == 6, "Continue restores living coin and receipt pickup eligibility")
	check(Save.read_save().receipts.get("1-6", []) == [0], "Only living post-Continue receipt gets persisted")

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/test_support.gd").silence(game)
	checkpoint_contracts()
	tiny_speed_contracts()
	continue_contracts()
	card_and_preview_contracts()
	boss_entry_contracts()
	ghost_collision_contracts()
	ghost_expiry_contracts()
	ghost_viewport_contracts()
	ama_and_defeat_contracts()
	lethal_clear_race_contracts()
	zero_heart_pickup_contracts()
	game.queue_free()
	await process_frame
	print("Street expansion integration: %d checks, %d failures (focused fixtures, not whole runs)" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
