extends SceneTree
## Bounded real-input progression soak, NOT a difficulty or device playtest.
## Invulnerability is the only gameplay assist. Actors, shots, health, waves,
## phases, timers and completion are changed only by the native game's step().
## Run with isolated HOME/XDG paths, like scripts/verify-native.sh.
const MAX_TICKS := 60000
const DT := 1.0 / 60.0
const SaveStore = preload("res://src/save_store.gd")
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	if not game.has_method("step"):
		printerr("Binman input soak: native main script did not load")
		game.free()
		quit(1)
		return
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/test_support.gd").silence(game)
	var passed := true
	var characters: Array = game.CHARACTERS
	# A short focused command is useful while integrating the native scene.
	if "--jp-only" in OS.get_cmdline_user_args(): characters = ["jp"]
	for character in characters:
		if not run_character(game, character): passed = false
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)

func check(condition: bool, message: String) -> void:
	if not condition and message not in failures: failures.append(message)

func run_character(game, character: String) -> bool:
	failures.clear()
	game.character = character
	game.save = {"schema": 1, "receipts": {}}
	# Setup cannot inherit another character's persisted clear.
	check(SaveStore.write_save(game.save) == OK, "fresh isolated save failed")
	check(not SaveStore.read_save().get("cleared", {}).get("1-6", false), "stale saved clear")
	check(game.load_level("1-6"), "level did not load")
	check(game._native_world_one(), "1-6 is not wired as native gameplay")
	check(game.combat.waves.size() == 2, "expected two source approach waves")
	if game.combat.waves.size() == 2:
		check(source_group_matches(game.combat.waves[0].group, [[0, "r", "rush"], [600, "r", "throw"], [1300, "l", "rush"], [2000, "r", "fly"]]), "first approach wave differs from source")
		check(source_group_matches(game.combat.waves[1].group, [[0, "r", "flat"], [500, "r", "rush"], [1000, "l", "rush"], [1700, "r", "fly"], [2400, "r", "throw"]]), "second approach wave differs from source")
	if not failures.is_empty():
		printerr("Binman input soak [", character, "]: FAIL ", failures)
		return false
	var ticks := 0
	var specials := 0
	var jumps := 0
	var aim_frames := 0
	var shot_frames := 0
	var movement_frames := 0
	var boss_started := -1
	var boss_down := -1
	var phases: Array[int] = []
	var attacks: Array[String] = []
	var started: Array[int] = []
	var completed: Array[int] = []
	var timeline: Array[String] = []
	var helpers: Array[Dictionary] = []
	var helper_kinds: Array[String] = []
	var airborne_bin_seen := false
	var rolling_bin_seen := false
	var shockwave_seen := false
	var recycling_seen := false
	var recycling_types: Array[int] = []
	var closed_lid_hits := 0
	var ordinary_damage_seen := false
	var previous_hp := -1
	var previous_y: float = game.player.y
	var falls := 0
	for frame in range(MAX_TICKS):
		ticks = frame + 1
		game.invincible = 999 # Explicit progression assist, never enemy damage.
		var controls := controls_for(game, jumps)
		var closed_shots := closed_lid_candidates(game, controls)
		var hp_before: int = game.boss.state.hp if game.boss != null else -1
		var ordinary_only: bool = game.abilities.active.is_empty() and not controls.get("special", false) and game.abilities.effects.is_empty() and game.bullets.all(func(b): return b.enemy or b.get("kind", "") == character)
		var was_active: String = game.abilities.active
		var was_grounded: bool = game.grounded
		game.step(DT, controls)
		if was_active.is_empty() and not game.abilities.active.is_empty(): specials += 1
		if was_grounded and not game.grounded and game.velocity.y < 0: jumps += 1
		if controls.get("aim", false): aim_frames += 1
		if controls.get("shoot", false): shot_frames += 1
		if controls.get("left", false) or controls.get("right", false): movement_frames += 1
		if previous_y > 800 and game.player.y < previous_y - 100: falls += 1
		previous_y = game.player.y
		for i in range(game.combat.waves.size()):
			var wave: Dictionary = game.combat.waves[i]
			if wave.started and i not in started:
				started.append(i)
				timeline.append("fight:%d" % (i + 1))
			if wave.done and i not in completed:
				completed.append(i)
				timeline.append("done:%d" % (i + 1))
		if game.boss != null:
			var boss: Dictionary = game.boss.state
			check(game.boss.get_script().resource_path == "res://src/binman.gd", "unexpected Jar Thief or another boss")
			check(not boss.has("jar"), "Binman created a fake jar objective")
			if not boss.has("phase") or not boss.has("bins") or not boss.has("rain"):
				check(false, "boss does not expose native Binman encounter state")
				break
			check(boss.max == 260, "solo Binman max HP differs from source 260")
			if boss_started < 0:
				boss_started = frame
				timeline.append("binman")
				check(completed.size() == 2, "boss appeared before both approach waves finished")
				check(boss.hp == 260, "boss did not enter at the source 260 HP")
				check(game.camera.x >= game.level.w - game.view_width() - 2, "boss appeared before end arena")
			if previous_hp >= 0: check(boss.hp <= previous_hp, "boss HP increased during the run")
			previous_hp = int(boss.hp)
			if int(boss.phase) not in phases: phases.append(int(boss.phase))
			if boss.state != "down":
				var fraction: float = float(boss.hp) / boss.max
				check(boss.phase == (1 if fraction > 0.66 else 2 if fraction > 0.33 else 3), "phase does not match actual source HP thresholds")
				check(not boss.called[0] or fraction < 0.66, "first helper pair called before the real HP threshold")
				check(not boss.called[1] or fraction < 0.33, "second helper pair called before the real HP threshold")
			if boss.state in ["throw", "roll", "slam"] and boss.state not in attacks: attacks.append(boss.state)
			for enemy in game.enemies:
				if enemy.state != "pop" and enemy not in helpers:
					helpers.append(enemy)
					helper_kinds.append(enemy.kind)
			for bin in boss.bins:
				if bin.roll: rolling_bin_seen = true
				else: airborne_bin_seen = true
			for wave in boss.waves:
				if not wave.get("bin", false): shockwave_seen = true
			if boss.rain.size() == 5: recycling_seen = true
			for item in boss.rain:
				if int(item.k) not in recycling_types: recycling_types.append(int(item.k))
			for shot in closed_shots:
				if shot.life <= 0:
					closed_lid_hits += 1
					check(boss.hp == hp_before, "closed-lid ordinary shot changed boss HP")
			if ordinary_only and hp_before > boss.hp and hp_before >= 0: ordinary_damage_seen = true
			if boss.state == "down" and boss_down < 0:
				boss_down = frame
				timeline.append("down")
				check(boss.hp <= 0, "boss down before health exhausted")
				check(not game.enemies.any(func(e): return e.state != "pop"), "boss defeat did not clear helpers")
				# Source bins persist after defeat and immediately rebuild their
				# zero-velocity markers; only actual slam waves are cleared.
				check(not boss.waves.any(func(w): return not w.get("bin", false)), "boss defeat did not clear shockwaves")
			if boss_down >= 0 and frame - boss_down < 155: check(game.mode == "play", "Binman clear happened before the source down delay")
		if game.mode in ["clear", "over"]: break
	var exit_ticks := ticks - 1 - boss_down if boss_down >= 0 else -1
	check(game.mode == "clear", "normal gameplay did not clear before the tick bound")
	check(started == [0, 1] and completed == [0, 1], "not every approach wave started and completed in order")
	check(timeline == ["fight:1", "done:1", "fight:2", "done:2", "binman", "down"], "approach/boss/defeat ordering differs")
	check(boss_started >= 0 and boss_down > boss_started, "missing real Binman encounter and defeat")
	check(phases == [1, 2, 3], "all three actual HP phases were not exercised")
	check("throw" in attacks and "roll" in attacks and "slam" in attacks, "missing source attack states")
	check(helper_kinds == ["rush", "throw", "flat", "rush"], "both source solo helper pairs did not appear")
	check(airborne_bin_seen and rolling_bin_seen, "missing thrown or rolling bins")
	check(shockwave_seen and recycling_seen and recycling_types.size() == 3, "missing shockwaves or five-piece recycling rain")
	check(closed_lid_hits > 0, "no closed-lid ordinary shot consumption observed")
	check(ordinary_damage_seen, "ordinary shots did not damage the open boss")
	check(specials > 0 and jumps > 0 and aim_frames > 0 and shot_frames > 0 and movement_frames > 0, "missing normal control coverage")
	check(falls == 0, "player fell out of the flat source arena")
	check(exit_ticks >= 155 and exit_ticks <= 157, "source direct 2.6-second down-to-clear timing differs")
	check(game.save.get("cleared", {}).get("1-6", false), "in-memory native clear missing")
	check(SaveStore.read_save().get("cleared", {}).get("1-6", false), "native clear did not persist through save reload")
	if game.boss != null: check(game.boss.state.called[0] and game.boss.state.called[1], "source threshold helpers were not called")
	var passed := failures.is_empty()
	print("Binman input soak [", character, "]: ", "PASS" if passed else "FAIL", " ticks=", ticks, " waves=", completed.size(), "/2 phases=", phases, " helpers=", helper_kinds, " attacks=", attacks, " airborne_bins=", airborne_bin_seen, " rolling_bins=", rolling_bin_seen, " shockwaves=", shockwave_seen, " recycling=", recycling_seen, " lid_clangs=", closed_lid_hits, " specials=", specials, " jumps=", jumps, " aim_frames=", aim_frames, " exit_ticks=", exit_ticks, " mode=", game.mode)
	if not passed:
		printerr("Binman failures [", character, "]: ", failures)
		printerr("Timeline: ", timeline, " player=", game.player, " camera=", game.camera, " enemies=", game.enemies.filter(func(e): return e.state != "pop"))
		printerr("Boss: ", game.boss.state if game.boss != null else {})
	return passed

func source_group_matches(actual: Array, expected: Array) -> bool:
	# JSON numbers load as floats; nested Array equality also compares types.
	if actual.size() != expected.size(): return false
	for i in actual.size():
		if actual[i].size() != 3: return false
		if float(actual[i][0]) != float(expected[i][0]) or actual[i][1] != expected[i][1] or actual[i][2] != expected[i][2]: return false
	return true

func controls_for(game, jumps: int) -> Dictionary:
	var controls := {"left": false, "right": true, "shoot": true}
	var target: Dictionary = {}
	for enemy in game.enemies:
		if enemy.state == "pop": continue
		if target.is_empty() or absf(enemy.p.x - game.player.x) < absf(target.p.x - game.player.x): target = enemy
	var facing_x: float = game.player.x + 1
	if not target.is_empty():
		var dx: float = target.p.x - game.player.x
		facing_x = target.p.x
		controls.right = dx > 220
		controls.left = dx < -220
		if target.kind == "tiny": controls.down = true
		if target.kind == "fly":
			controls.aim = true
			controls.right = dx > 30
			controls.left = dx < -30
	elif game.boss != null:
		var boss: Dictionary = game.boss.state
		var dx: float = boss.x - game.player.x
		facing_x = boss.x
		controls.right = dx > 220
		controls.left = dx < -220
		# Keep room to see and shoot incoming bins, using ordinary movement.
		# This also leaves player shots in flight for the closed-lid observer.
		if absf(dx) < 180:
			controls.right = dx < 0
			controls.left = dx >= 0
		if boss.state == "down":
			# The real clear must require only time, not walking to an invented jar.
			return {}
		# A normal jump responds to an incoming shockwave or rolling-bin marker.
		if game.grounded and not game.jump_held:
			for wave in boss.waves:
				if absf(wave.x - game.player.x) < 105: controls.jump = true
	elif jumps == 0 and game.grounded and not game.jump_held:
		controls.jump = true
	# Facing is changed only through movement input.
	if game.face != (1 if facing_x >= game.player.x else -1) and not (game.boss != null and target.is_empty() and absf(facing_x - game.player.x) < 180):
		controls.right = facing_x >= game.player.x
		controls.left = facing_x < game.player.x
	if game.abilities.meter >= 1: controls.special = true
	return controls

func closed_lid_candidates(game, controls: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if game.boss == null or not game.abilities.active.is_empty() or controls.get("special", false) or not game.abilities.effects.is_empty(): return result
	var boss: Dictionary = game.boss.state
	if boss.state in ["enter", "down"] or boss.lid >= 0.6: return result
	# Exclude lingering special shots so HP cannot change for an unrelated hit.
	if game.bullets.any(func(b): return not b.enemy and b.get("kind", "") != game.character): return result
	for shot in game.bullets:
		if shot.enemy or shot.life <= DT or shot.get("dead", false) or shot.get("homing", false) or shot.get("damage", 1) != 1: continue
		var next: Vector2 = shot.p + shot.v * DT
		if absf(next.x - boss.x) > 104 or next.y < boss.fy - 299 or next.y > boss.fy - 1: continue
		# Enemy movement precedes projectile collision. A generous exclusion keeps
		# this observation unambiguous without intercepting the engine's hit call.
		var obstructed := false
		for enemy in game.enemies:
			if enemy.state != "pop" and enemy.p.x > minf(shot.p.x, next.x) - 90 and enemy.p.x < maxf(shot.p.x, next.x) + 90: obstructed = true
		if not obstructed: result.append(shot)
	return result
