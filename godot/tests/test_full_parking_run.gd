extends SceneTree
## Bounded source-authored 2-1 input progression regression, NOT difficulty QA.
## Only movement/jump/down/aim/shoot/special inputs advance the run. The sole
## assist is invulnerability. Never edit actors, health, positions, geometry,
## waves, timers, power, pickups or completion. The lift's own teleport is real.
## Use fresh HOME/XDG paths in /tmp; each housemate also gets a fresh save.
const SaveStore = preload("res://src/save_store.gd")
const DT := 1.0 / 60.0
const MAX_TICKS := 36000
const EXPECTED_WAVES := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
const WAVE_AT := [500, 1500, 3000, 4300, 5600, 6880, 8200, 9700, 11900, 13300, 15262]
const NUMERIC_SPAWNS := [1720, 3320, 4520, 6120, 8420, 9920, 12720, 14120]
const ENEMY_COUNTS := {"rush": 21, "throw": 11, "cart": 10, "flat": 5, "drone": 3, "big": 2}
const RECEIPTS := [[80, 482], [3920, 269], [12120, 269]]
var failures: Array[String] = []
var debug_run := false

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	if not game.has_method("step"):
		printerr("Parking input run: main script did not load")
		game.free()
		quit(1)
		return
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/test_support.gd").silence(game)
	var characters: Array = game.CHARACTERS
	var args := OS.get_cmdline_user_args()
	if "--jp-only" in args: characters = ["jp"]
	for arg in args:
		if arg.begins_with("--character="):
			var selected := arg.trim_prefix("--character=")
			if selected not in game.CHARACTERS:
				printerr("Unknown housemate: ", selected)
				game.queue_free()
				await process_frame
				quit(1)
				return
			characters = [selected]
	debug_run = "--trace" in args
	var passed := true
	for character in characters:
		if not run_character(game, character): passed = false
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)

func check(condition: bool, message: String) -> void:
	if not condition and message not in failures: failures.append(message)

func source_equal(actual: Variant, expected: Variant) -> bool:
	# JSON numbers deserialize as floats; Godot's nested Array equality is
	# type-strict. Compare numeric values without weakening source structure.
	if actual is Array and expected is Array:
		if actual.size() != expected.size(): return false
		for i in range(actual.size()):
			if not source_equal(actual[i], expected[i]): return false
		return true
	if (actual is int or actual is float) and (expected is int or expected is float):
		return absf(float(actual) - float(expected)) < 0.00001
	return actual == expected

func run_character(game, character: String) -> bool:
	failures.clear()
	game.character = character
	game.save = {"schema": 1, "receipts": {}}
	check(SaveStore.write_save(game.save) == OK, "fresh isolated save failed")
	check(not SaveStore.read_save().get("cleared", {}).get("2-1", false), "stale parking clear")
	check(game.load_level("2-1"), "2-1 did not load")
	check(game.has_method("is_native_supported") and game.is_native_supported(), "2-1 is still a preview")
	check(not game._native_world_one(), "parking was incorrectly dispatched through World 1")
	check(game.player == Vector2(300, 482) and game.camera == Vector2.ZERO, "source starting position changed")
	check(game.level.w == 16000 and game.view_width() == 738, "source width/view changed")
	check(source_equal(game.level.solids, [[-400, 16400, 482]]) and game.level.plats.size() == 13, "source parking surfaces changed")
	check(source_equal(game.level.receipts, RECEIPTS) and game.receipts.size() == 3, "source receipt coordinates changed")
	check(source_equal(game.level.scenes, [[7600, "lift", "Ground floor", "Take the lift down!"]]), "source lift changed")
	check(game.level.check == 7700 and game.level.start == 300, "source checkpoint/start changed")
	check(game.movement_skills.skills.is_empty() and game.abilities.skills.is_empty(), "run inherited movement skills")
	check(game.combat.waves.size() == 11, "expected all eleven source waves")
	if not failures.is_empty():
		printerr("Parking input run [", character, "]: FAIL ", failures)
		return false
	for i in range(11):
		check(game.combat.waves[i].at == WAVE_AT[i], "wave trigger changed: %d" % i)
		check(game.combat.waves[i].group == game.level.waves[i].g, "solo wave group differs from imported source: %d" % i)
	var source_geometry := JSON.stringify(game.level)
	var started: Array[int] = []
	var completed: Array[int] = []
	var collected: Array[int] = []
	var seen_enemies: Array = []
	var numeric_spawns: Array[int] = []
	var seen_trolleys: Array = []
	var seen_coin_positions: Array[Vector2] = []
	var ordinary_damage := false
	var specials := 0
	var jumps := 0
	var falls := 0
	var aim_frames := 0
	var down_frames := 0
	var ticks := 0
	var ending_frame := -1
	var wipe_start := -1
	var wipe_mid := -1
	var wipe_end := -1
	var wipe_motion := 0.0
	var checkpoint_frame := -1
	var boss_seen := false
	var consumed := 0
	var numeric_dispatched := 0
	for frame in range(MAX_TICKS):
		ticks = frame + 1
		game.invincible = 999 # Explicit sole progression assist, never enemy damage.
		var controls := controls_for(game, frame, wipe_start)
		var position_before: Vector2 = game.player
		var elapsed_before: float = game.elapsed
		var scene_before: int = game.world_two.scene_index
		var wipe_before: bool = game.world_two.wiping
		var active_before: String = game.abilities.active
		var grounded_before: bool = game.grounded
		var hp_before: Array = []
		for enemy in game.enemies: hp_before.append([enemy, enemy.hp])
		var indices: Array[int] = []
		for wave in game.combat.waves: indices.append(wave.index)
		var only_normal: bool = game.abilities.active.is_empty() and not controls.get("special", false) and game.abilities.effects.is_empty() and game.bullets.all(func(b): return b.enemy or b.get("kind", "") == character)
		game.step(DT, controls)
		if active_before.is_empty() and not game.abilities.active.is_empty():
			specials += 1
			check(game.abilities.active == character, "activated another housemate's special")
		if grounded_before and not game.grounded and game.velocity.y < 0: jumps += 1
		if controls.get("aim", false): aim_frames += 1
		if controls.get("down", false): down_frames += 1
		for pair in hp_before:
			if only_normal and pair[0].hp < pair[1]: ordinary_damage = true
		boss_seen = boss_seen or game.boss != null
		if position_before.y > game.level.fall and game.player.y < position_before.y - 100: falls += 1
		check(absf(game.player.x - position_before.x) < 20 or scene_before != game.world_two.scene_index, "unexpected player teleport outside the source lift")
		if game.world_two.scene_index == 0:
			check(game.player.x <= 7600.01, "player crossed closed scene boundary")
			check(game.camera.x <= 7162.01, "camera showed the ground-floor scene too early")
			check(not game.world_two.checkpoint_hit, "checkpoint healed before the source lift")
		if game.world_two.wiping and wipe_start < 0:
			wipe_start = frame
			# The wave pass can finish the sixth wave on this very update.
			check(game.combat.waves.slice(0, 6).all(func(w): return w.started and w.done) and game.combat.waves.slice(6).all(func(w): return not w.started), "lift started before all six preceding waves cleared")
			check(game.player.x >= 7550 and game.player.x <= 7600, "lift started outside source entry interval")
			check(game.world_two.wipe_kind == "lift" and game.world_two.wipe_label == "Ground floor", "incorrect source wipe")
		if wipe_before:
			check(absf(game.elapsed - elapsed_before - DT) < 0.0001, "simulation was paused during the source wipe")
			if scene_before == 0 and game.world_two.scene_index == 0: wipe_motion += absf(game.player.x - position_before.x)
		if scene_before != game.world_two.scene_index:
			wipe_mid = frame
			check(scene_before == 0 and game.world_two.scene_index == 1, "unexpected scene transition")
			check(game.world_two.wipe_elapsed >= 1.43 and game.world_two.wipe_elapsed < 1.43 + DT + 0.0001, "lift midpoint is not source 1.43 seconds")
			check(game.player == Vector2(8020, 482) and game.grounded, "source lift did not land at (8020,482)")
			check(game.camera == Vector2(7860, 0) and game.camera_speed == 0, "source lift camera reset changed")
			check(game.velocity == Vector2.ZERO and game.bullets.is_empty(), "source lift did not clear momentum/projectiles")
			check(not game.world_two.checkpoint_hit, "checkpoint ran after end-of-frame wipe callback")
		if wipe_before and not game.world_two.wiping:
			wipe_end = frame
			check(game.world_two.scene_index == 1 and game.world_two.wipe_elapsed >= 2.17, "visual wipe did not finish at source duration")
		if game.world_two.checkpoint_hit and checkpoint_frame < 0:
			checkpoint_frame = frame
			check(wipe_mid >= 0 and frame == wipe_mid + 1, "checkpoint must trigger on first update after source callback")
			check(game.hearts == 3, "checkpoint did not leave player at full hearts")
		for i in range(11):
			var wave: Dictionary = game.combat.waves[i]
			if wave.started and i not in started: started.append(i)
			if wave.done and i not in completed:
				completed.append(i)
				check(wave.index == wave.group.size(), "wave completed before all authored entries dispatched")
				if debug_run: print("Parking wave ", i, " done frame=", frame, " player=", game.player)
			for entry_index in range(indices[i], wave.index):
				consumed += 1
				var entry: Array = wave.group[entry_index]
				if entry[1] is int or entry[1] is float:
					numeric_dispatched += 1
					var matching := false
					for enemy in game.enemies:
						if enemy not in seen_enemies and enemy.kind == entry[2] and absf(enemy.p.x - float(entry[1])) < 10:
							matching = true
							numeric_spawns.append(int(entry[1]))
					check(matching, "numeric source spawn missing/misplaced at %s" % entry[1])
		for enemy in game.enemies:
			if enemy not in seen_enemies:
				seen_enemies.append(enemy)
				if enemy.kind == "big": check(enemy.big and enemy.max_hp == 24 and enemy.hw == 58 and enemy.hh == 186, "security bot is not source solo24HP geometry")
				if enemy.kind == "drone": check(enemy.max_hp == 2 and not enemy.get("fly", false), "drone incorrectly uses World1 flyer contract")
				if enemy.kind == "cart": check(enemy.max_hp == 2, "cart bot has incorrect source health")
		for entity in game.world_two.entities:
			if entity.k == "trolley" and entity not in seen_trolleys:
				seen_trolleys.append(entity)
				check(absf(entity.v.x) >= 360 and absf(entity.v.x) <= 440, "trolley speed differs from source")
		for coin in game.coins:
			if not coin.get("keep", false): continue
			# Newly authored coins are created after the pickup pass, so age=.3
			# observes their original row position before attraction can move them.
			if absf(coin.age - 0.3) < 0.00001 and coin.p not in seen_coin_positions: seen_coin_positions.append(coin.p)
			if coin.rest: check(coin.age <= 2.0001, "resting authored coin lost source keep-age cap")
		for i in range(3):
			if game.receipts[i].taken and i not in collected:
				collected.append(i)
				check(absf(game.player.x - RECEIPTS[i][0]) < 42, "receipt collected outside actual horizontal contact")
				check(game.player.y > RECEIPTS[i][1] - 30 and game.player.y - game.character_height() < RECEIPTS[i][1], "receipt used World1 vertical pickup geometry")
				if i == 0: check(game.camera.x == 0 and started.is_empty(), "behind-start receipt was not collected before advancing camera")
		if game.world_two.end_time > 0 and ending_frame < 0:
			ending_frame = frame
			check(completed == EXPECTED_WAVES, "timed exit started before all waves cleared")
			check(game.camera.x >= 15260, "timed exit started before source end")
		if debug_run and frame % 1800 == 0: print("Parking trace [", character, "] frame=", frame, " p=", game.player, " camera=", game.camera.x, " receipts=", collected, " enemies=", game.enemies.filter(func(e): return e.state != "pop"))
		if game.mode in ["clear", "over"]: break
	var exit_ticks := ticks - 1 - ending_frame if ending_frame >= 0 else -1
	check(game.mode == "clear", "bounded input route did not clear")
	check(started == EXPECTED_WAVES and completed == EXPECTED_WAVES, "all eleven waves did not start and finish in source order")
	check(consumed == 52 and seen_enemies.size() == 52, "not all52 solo authored enemies actually spawned")
	check(numeric_dispatched == 8 and numeric_spawns == NUMERIC_SPAWNS, "not all8 numeric source spawns were observed")
	check(seen_enemies.filter(func(e): return e.kind == "big").size() == 2, "did not encounter both actual security bots")
	check(seen_enemies.filter(func(e): return e.kind == "drone").size() == 3, "did not encounter all3 barcode drones")
	for kind in ENEMY_COUNTS:
		check(seen_enemies.filter(func(e): return e.kind == kind).size() == ENEMY_COUNTS[kind], "source enemy count changed: " + kind)
	check(not boss_seen, "parking invented a separate boss objective")
	check(collected == [0, 1, 2], "did not collect all three actual source receipts")
	check(specials > 0 and jumps >= 2 and ordinary_damage and aim_frames > 0 and down_frames > 0, "missing real special/jump/down/aim/ordinary damage coverage")
	check(falls == 0, "route relied on fall-safe recovery")
	check(wipe_start >= 0 and wipe_mid > wipe_start and wipe_end > wipe_mid and wipe_motion > 10, "lift/input simulation coverage missing")
	check(checkpoint_frame == wipe_mid + 1, "source checkpoint was not observed")
	check(seen_trolleys.size() == 15, "did not observe all15 source runaway trolleys")
	var spawners: Array = game.world_two.entities.filter(func(e): return e.k == "tspawn")
	check(spawners.size() == 4 and spawners.all(func(e): return e.on and e.done == e.n), "not all source trolley batches completed")
	check(game.world_two.coins_done.size() == 13 and seen_coin_positions.size() == 73, "not all13 authored coin rows/73 coins appeared once")
	check(authored_coin_positions_match(game.level.hz, seen_coin_positions), "authored coin coordinates/arc differ from source")
	check(exit_ticks == 155, "source 2.6-second exit timing changed")
	check(JSON.stringify(game.level) == source_geometry, "runtime/test mutated source geometry")
	check(game.movement_skills.skills.is_empty() and game.abilities.skills.is_empty(), "unearned movement skills appeared")
	check(game.save.get("cleared", {}).get("2-1", false), "native clear missing in memory")
	var persisted: Dictionary = SaveStore.read_save()
	check(persisted.get("cleared", {}).get("2-1", false), "native clear missing after disk reload")
	check(persisted.get("receipts", {}).get("2-1", []) == [0, 1, 2], "all receipts missing after disk reload")
	var passed := failures.is_empty()
	print("Parking input run [", character, "]: ", "PASS" if passed else "FAIL", " ticks=", ticks, " waves=", completed.size(), "/11 enemies=", seen_enemies.size(), "/52 receipts=", collected, " numeric=", numeric_spawns.size(), "/8 trolleys=", seen_trolleys.size(), "/15 authored_coins=", seen_coin_positions.size(), "/73 jumps=", jumps, " specials=", specials, " aim=", aim_frames, " down=", down_frames, " lift=", wipe_start, "/", wipe_mid, "/", wipe_end, " checkpoint=", checkpoint_frame, " exit_ticks=", exit_ticks, " player=", game.player, " mode=", game.mode)
	if not passed:
		printerr("Parking failures [", character, "]: ", failures)
		printerr("Remaining live enemies: ", game.enemies.filter(func(e): return e.state != "pop"))
	return passed

func authored_coin_positions_match(hazards: Array, positions: Array[Vector2]) -> bool:
	var expected := 0
	for h in hazards:
		if h[0] != "coins": continue
		for i in range(int(h[4])):
			var fraction := float(i) / float(h[4] - 1) if h[4] > 1 else 0.5
			var point := Vector2(lerpf(h[1], h[2], fraction), float(h[3]) - sin(PI * float(i) / maxf(1, h[4] - 1)) * float(h[5]))
			if not positions.any(func(p): return p.distance_to(point) < 0.002): return false
			expected += 1
	return positions.size() == expected

func controls_for(game, frame: int, wipe_start: int) -> Dictionary:
	var controls := {"left": false, "right": false, "jump": false, "down": false, "aim": false, "shoot": true, "special": false}
	# Demonstrate real left/right input continues under the closed lift wipe.
	if game.world_two.wiping and game.world_two.scene_index == 0:
		controls.left = (frame - wipe_start) < 25
		controls.right = not controls.left
		return controls
	var target: Dictionary = {}
	for enemy in game.enemies:
		if enemy.state == "pop": continue
		if target.is_empty() or absf(enemy.p.x - game.player.x) < absf(target.p.x - game.player.x): target = enemy
	if not target.is_empty():
		var dx: float = target.p.x - game.player.x
		if game.grounded and game.on_platform:
			# Fight ordinary robots from their floor, rather than shooting above
			# them from a car roof. This uses the public down+jump drop control.
			controls.down = true
			controls.jump = not game.jump_held
		elif target.kind == "drone" or target.p.y < game.player.y - 130:
			controls.aim = true
			# The source has a straight-up standing shot. Chase to just beneath
			# the drone, then release direction to shoot vertically.
			controls.right = dx > 24
			controls.left = dx < -24
		else:
			if game.grounded and frame % 120 == 0: controls.down = true
			# A direction tap changes facing without manufacturing player state.
			if game.face != (1 if dx >= 0 else -1):
				controls.right = dx >= 0
				controls.left = dx < 0
		if game.abilities.meter >= 1: controls.special = true
		return controls
	var target_x: float = game.level.w - 40
	var receipt_index := -1
	for i in range(game.receipts.size()):
		if not game.receipts[i].taken:
			receipt_index = i
			target_x = float(RECEIPTS[i][0])
			break
	var dx := target_x - float(game.player.x)
	controls.right = dx > 3
	controls.left = dx < -3
	# The body overlaps the elevated receipt during an ordinary ground jump.
	# No car/van platform, skill card or upward position edit is necessary.
	if receipt_index > 0 and absf(dx) < 25 and game.grounded and not game.jump_held:
		controls.jump = true
	return controls
