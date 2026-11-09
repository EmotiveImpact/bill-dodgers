extends SceneTree
## CPU-party progression soak; reuses the certified solo route driver.
## Bounded progression runs through the original 1-4, 1-5 and 1-S layouts.
## Invulnerability is the ONLY gameplay assist. This is not difficulty QA.
## No teleports, direct damage, spawned enemies, skipped waves or forced clear.
## Run with isolated HOME/XDG paths, as in scripts/verify-native.sh.
const DT := 1.0 / 60.0
const MAX_TICKS := 60000
const SaveStore = preload("res://src/save_store.gd")
const STAGES := {"1-4": {"width": 14400, "waves": 10, "speed": 0}, "1-5": {"width": 40000, "waves": 14, "speed": 190}, "1-S": {"width": 22000, "waves": 4, "speed": 250}}
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition and message not in failures: failures.append(message)

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/test_support.gd").silence(game)
	var passed := true
	var characters: Array = ["jp"] if "--jp-only" in OS.get_cmdline_user_args() else game.CHARACTERS
	for character in characters:
		if not selected_character().is_empty() and character != selected_character(): continue
		game._show_menu()
		game.character = character
		game.configure_party("cpu", mate_for(game, character))
		game.save = {"schema": 1, "receipts": {}}
		# Setup only: each character must earn a new card and all three clears.
		if SaveStore.write_save(game.save) != OK:
			printerr("Could not initialize isolated save")
			passed = false
			break
		for stage in STAGES:
			if stage != "1-4": game.save = SaveStore.read_save()
			if not run_stage(game, stage): passed = false
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)

func run_stage(game, stage: String) -> bool:
	failures.clear()
	check(game.load_level(stage), "stage failed to load")
	check(game._native_world_one(), "stage is still a layout preview")
	check(game.level.w == STAGES[stage].width, "source width changed")
	check(game.combat.waves.size() == STAGES[stage].waves, "source wave count changed")
	check(is_equal_approx(float(game.level.get("auto", 0)) * 1000, STAGES[stage].speed), "source auto-scroll speed changed")
	if stage == "1-4":
		check(Vector2(game.level.card[0], game.level.card[1]) == Vector2(8497, 442), "source slide-card position changed")
		check(not game.movement_skills.has_skill("slide"), "fresh park run already has slide")
	else:
		check(game.movement_skills.has_skill("slide"), "earned slide did not survive disk reload")
	if stage == "1-5": check(game.level.obs.size() == 52 and game.level.solids.size() == 53, "expected all 52 alley obstacles")
	if stage == "1-S": check(game.level.coins and game.level.plats.size() == 17, "source bonus coins/awnings missing")
	if not failures.is_empty():
		printerr("Street CPU pair [", stage, "/", game.character, "]: FAIL ", failures)
		return false
	check(game.party_session.active and game.party_session.runtime.actors.size() == 2, "CPU pair did not activate")
	check(game.party_session.runtime.actors[1].cpu, "mate is not using source CPU")
	for i in game.combat.waves.size():
		check(game.combat.waves[i].group.size() == game.level.waves[i][1].size() + 1, "source party wave addition missing")
	var geometry_before := JSON.stringify(game.level)
	var obstacles: Array = game.level.solids.filter(func(row): return float(row[2]) < float(game.meta.ground))
	var crossed: Array[int] = []
	var jumped_over: Array[int] = []
	var started: Array[int] = []
	var done: Array[int] = []
	var native_coins: Array = []
	var native_collected := 0
	var rows_checked := 0
	var ticks := 0
	var jumps := 0
	var specials := 0
	var cpu_specials: Dictionary = {}
	var cpu_down_frames := 0
	var cpu_deaths := 0
	var cpu_revives := 0
	var cpu_clear_rescue := false
	var slides := 0
	var aim_frames := 0
	var duck_frames := 0
	var forward_wave_frames := 0
	var exit_started := -1
	var score_before_clear := 0
	var card_collected := false
	var card_position := Vector2.ZERO
	var boss_seen := false
	for frame in range(MAX_TICKS):
		ticks = frame + 1
		for actor in game.party_session.runtime.actors: actor.invincible = 999
		game.invincible = 999 # Explicit progression assist, never enemy damage.
		var controls := controls_for(game, frame)
		var previous_player: Vector2 = game.player
		var previous_camera: float = game.camera.x
		var previous_pattern: int = game.world_one.coin_pattern
		var previous_active: String = game.abilities.active
		var previous_grounded: bool = game.grounded
		var previous_slide: float = game.movement_skills.slide_remaining
		var previous_card: bool = game.movement_skills.has_skill("slide")
		var was_fighting: bool = game.combat.waves.any(func(w): return w.started and not w.done)
		if controls.get("aim", false): aim_frames += 1
		if controls.get("down", false): duck_frames += 1
		score_before_clear = game.score
		var cpu_down_before: bool = game.party_session.runtime.actors[1].down
		var cpu_before: String = game.party_session.runtime.actors[1].abilities.active
		game.step(DT, controls)
		var cpu_down_after: bool = game.party_session.runtime.actors[1].down
		if cpu_down_after: cpu_down_frames += 1
		if not cpu_down_before and cpu_down_after: cpu_deaths += 1
		if cpu_down_before and not cpu_down_after:
			if game.mode == "clear": cpu_clear_rescue = true
			else: cpu_revives += 1
		var cpu_after: String = game.party_session.runtime.actors[1].abilities.active
		if cpu_before.is_empty() and not cpu_after.is_empty(): cpu_specials[cpu_after] = int(cpu_specials.get(cpu_after, 0)) + 1
		boss_seen = boss_seen or game.boss != null
		if previous_grounded and not game.grounded and game.velocity.y < 0: jumps += 1
		if previous_active.is_empty() and not game.abilities.active.is_empty(): specials += 1
		if previous_slide <= 0 and game.movement_skills.slide_remaining > 0: slides += 1
		check(game.player.y <= float(game.meta.ground) + 2, "fell through continuous source ground")
		check(game.camera.x + 0.01 >= previous_camera, "camera moved backward")
		if STAGES[stage].speed > 0:
			var expected: float = minf(float(game.level.w) - game.view_width(), previous_camera + STAGES[stage].speed * DT)
			check(game.camera.x + 0.01 >= expected, "forced scrolling stalled")
			check(game.camera_lock == null, "auto-scroll acquired an ordinary wave lock")
			if was_fighting and game.camera.x > previous_camera + 1: forward_wave_frames += 1
		for i in range(game.combat.waves.size()):
			var wave: Dictionary = game.combat.waves[i]
			if wave.started and i not in started:
				check(game.camera.x >= wave.at - 2, "wave started before source camera trigger")
				started.append(i)
			if wave.done and i not in done:
				check(wave.index == wave.group.size(), "wave finished without all source spawns")
				done.append(i)
		for i in range(obstacles.size()):
			var row: Array = obstacles[i]
			if previous_player.x <= row[1] and game.player.x > row[1]:
				if i not in crossed: crossed.append(i)
				if game.player.y <= float(row[2]) + 2 and i not in jumped_over: jumped_over.append(i)
		if stage == "1-4" and not previous_card and game.movement_skills.has_skill("slide"):
			card_collected = true
			card_position = game.player
			check(absf(game.player.x - 8497) < 42 and game.player.y > 442 - 120 and game.player.y - game.character_height() < 442, "slide unlocked away from source card")
			check(SaveStore.read_save().get("skills", []) == ["slide"], "actual card was not saved immediately")
		if stage == "1-S" and game.mode == "play":
			# Retain references to genuine spawned row coins, not a synthetic fixture.
			for coin in native_coins.duplicate():
				if coin in game.coins: continue
				if coin.age <= 11 and coin.p.x >= game.camera.x - 60 and coin.p.y <= game.level.fall:
					native_collected += 1
				native_coins.erase(coin)
			for pattern in range(previous_pattern, game.world_one.coin_pattern):
				var new_rows: int = game.world_one.coin_pattern - previous_pattern
				var row_index: int = pattern - previous_pattern
				var row_start: int = game.coins.size() - new_rows * 8 + row_index * 8
				check(row_start >= 0, "bonus row has fewer than eight coins")
				if row_start < 0: continue
				for i in range(8):
					var coin: Dictionary = game.coins[row_start + i]
					check(coin.p.is_equal_approx(bonus_coin_position(pattern, i, game.meta.ground)), "source bonus coin row/arc geometry changed")
					check(coin.rest and coin.v == Vector2.ZERO and is_equal_approx(coin.age, 0.26), "bonus row lost native spawn state")
					native_coins.append(coin)
				rows_checked += 1
		if exit_started < 0 and game.world_one.end_time > 0:
			exit_started = frame
			check(game.combat.waves.all(func(w): return w.done), "exit started before all waves finished")
			check(game.camera.x >= float(game.level.w) - game.view_width() - 2, "exit started before the source end of level")
		if game.mode in ["clear", "over"]: break
	var exit_ticks: int = ticks - 1 - exit_started if exit_started >= 0 else -1
	check(game.mode == "clear", "bounded input route did not clear")
	check(game.camera.x >= float(game.level.w) - game.view_width() - 2, "camera did not reach the source end of level")
	check(not boss_seen, "unexpected boss in timed-exit stage")
	check(started.size() == STAGES[stage].waves and done.size() == STAGES[stage].waves, "did not complete every source wave")
	check(exit_ticks == 155, "source 2.6-second exit timer changed")
	check(game.pop_count > 0 and specials > 0 and aim_frames > 0, "ordinary shooting/aim/power was not exercised")
	check(JSON.stringify(game.level) == geometry_before, "test/runtime mutated source level geometry")
	check(game.save.get("cleared", {}).get(stage, false), "native clear missing from memory")
	check(SaveStore.read_save().get("cleared", {}).get(stage, false), "native clear missing after disk reload")
	check(game.movement_skills.skills == ["slide"], "route acquired an unearned movement skill")
	if stage == "1-4":
		check(card_collected, "did not collect the actual park slide card")
		check(crossed.size() == obstacles.size(), "park route missed source solid props")
		check(jumps > 0, "park route never jumped")
	if stage == "1-5":
		check(crossed.size() == 52, "did not cross all 52 source alley obstacles")
		check(jumps >= 52 and jumped_over.size() >= 50, "alley route relied on wall-lift instead of ordinary jumps")
		check(slides > 0 and duck_frames > 0, "reloaded earned slide was not used through input")
	if stage == "1-S":
		check(rows_checked == 39 and game.world_one.coin_pattern == 39, "did not see all 39 native bonus coin rows")
		check(native_collected > 100 and score_before_clear > 100, "bonus coins were not actually collected before clear banking")
		check(jumps > 0, "bonus route never jumped for elevated coins")
	if STAGES[stage].speed > 0: check(forward_wave_frames > 60, "no continuous camera progress during live waves")
	check(game.party_session.runtime.actors.all(func(actor): return actor.hearts > 0 and not actor.down), "pair did not finish alive")
	check(game.party_session.runtime.actors[1].pop_count > 0, "CPU did not earn any owned robot pops")
	print("Street CPU pair [", stage, "/", game.character, "]: ", "PASS" if failures.is_empty() else "FAIL", " ticks=", ticks, " waves=", done.size(), "/", game.combat.waves.size(), " jumps=", jumps, " mate=", game.party_session.runtime.actors[1].character, " cpu_specials=", cpu_specials, " cpu_deaths=", cpu_deaths, " cpu_down_frames=", cpu_down_frames, " cpu_revives=", cpu_revives, " cpu_clear_rescue=", cpu_clear_rescue, " specials=", specials, " slides=", slides, " props=", crossed.size(), "/", obstacles.size(), " jumped_props=", jumped_over.size(), " rows=", rows_checked, " native_coins=", native_collected, " exit_ticks=", exit_ticks, " card=", card_position, " player=", game.player, " camera=", game.camera.x)
	if not failures.is_empty():
		printerr("Failures: ", failures, " remaining enemies=", game.enemies.filter(func(e): return e.state != "pop"))
	return failures.is_empty()

func bonus_coin_position(pattern: int, i: int, ground: float) -> Vector2:
	var y := ground
	match pattern % 4:
		0: y -= 40
		1: y -= 70 + sin(i / 7.0 * PI) * 170
		2: y -= 200
		3: y -= 40 + (i % 2) * 80
	return Vector2(700 + pattern * 560 + i * 46, y)

func controls_for(game, frame: int) -> Dictionary:
	var controls := {"right": true, "left": false, "jump": false, "shoot": true}
	var target: Dictionary = {}
	for enemy in game.enemies:
		if enemy.state == "pop": continue
		if target.is_empty() or absf(enemy.p.x - game.player.x) < absf(target.p.x - game.player.x): target = enemy
	if not target.is_empty():
		var dx: float = target.p.x - game.player.x
		controls.right = dx > 220
		controls.left = dx < -220
		if target.kind == "tiny": controls.down = true
		if target.kind == "fly" and target.p.y < game.player.y - 100:
			controls.aim = true
			controls.right = dx > 30
			controls.left = dx < -30
		if game.face != (1 if dx >= 0 else -1):
			controls.right = dx >= 0
			controls.left = dx < 0
		# Descend a hedge/urn before firing level shots at ground robots.
		if game.grounded and game.player.y < target.p.y - 40 and target.kind != "fly":
			controls.right = true
			controls.left = false
			controls.down = false
	if game.level_id == "1-5" and frame < 40:
		# This run loaded the park-earned card from the real saved file.
		controls.right = true
		controls.left = false
		controls.down = frame >= 16 and frame < 20
	# Jump from the approach to each real solid; no synthetic footholds.
	if game.grounded and not game.jump_held:
		var direction := 1 if controls.right else (-1 if controls.left else 0)
		if direction == 0 and game.level.get("auto", 0): direction = 1
		for row in game.level.solids:
			if row[2] >= game.player.y - 6: continue
			var distance: float = (float(row[0] if direction > 0 else row[1]) - game.player.x) * direction
			if direction != 0 and distance >= 0 and distance < 65:
				controls.jump = true
				controls.down = false
		if game.level_id == "1-S" and target.is_empty():
			# Follow the high portions of the native repeating coin patterns.
			var pattern := maxi(0, int(floor((game.player.x - 700) / 560)))
			var offset: float = game.player.x - (700 + pattern * 560)
			if pattern % 4 in [1, 2] and offset >= -20 and offset < 80: controls.jump = true
	if game.abilities.meter >= 1: controls.special = true
	return controls

func mate_for(game, character: String) -> String:
	if "--cycle-mates" in OS.get_cmdline_user_args():
		return game.CHARACTERS[(game.CHARACTERS.find(character) + 1) % game.CHARACTERS.size()]
	return "maya" if character != "maya" else "theo"

func selected_character() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--character="): return argument.trim_prefix("--character=")
	return ""
