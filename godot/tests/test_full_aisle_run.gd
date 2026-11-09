extends SceneTree
## Input-only 2-2 Aisle seven progression, NOT difficulty or device QA.
## Invulnerability is the sole assist. The controller may only supply ordinary
## move/jump/down/aim/shoot/special inputs; all gameplay state is observed only.
const SaveStore = preload("res://src/save_store.gd")
const DT := 1.0 / 60.0
const MAX_TICKS := 36000
const EXPECTED_WAVES := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
const WAVE_AT := [400, 1250, 2800, 4800, 6800, 7800, 9900, 11000, 12600, 14462]
const ENEMY_COUNTS := {"rush": 19, "throw": 11, "drone": 4, "cart": 4, "flat": 3, "big": 2}
const RECEIPTS := [[3700, 246], [8300, 246], [12880, 246]]
const ISLANDS := [[900, 1400], [3600, 4150], [5200, 5700], [7000, 7500], [8100, 8500], [11100, 11500], [12500, 12950]]
const GATES := [[2500, 482, 560, 0], [4500, 482, 560, 1], [6500, 482, 560, 2], [9200, 482, 560, 3], [9700, 482, 560, 4], [12000, 482, 560, 5], [14000, 482, 560, 6]]
const PLATES := [[1900, 482, 0], [5950, 482, 2], [8750, 482, 3], [9450, 482, 4], [13450, 482, 6]]
const BUTTONS := [[4370, 152, 1], [11650, 372, 5]]
var failures: Array[String] = []
var debug_run := false
var route_step := 0
var seen_shelves: Array[int] = []

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	if not game.has_method("step"):
		printerr("Aisle input run: main script did not load")
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
	if actual is Array and expected is Array:
		if actual.size() != expected.size(): return false
		for i in range(actual.size()):
			if not source_equal(actual[i], expected[i]): return false
		return true
	if (actual is int or actual is float) and (expected is int or expected is float):
		return absf(float(actual) - float(expected)) < 0.00001
	return actual == expected

func source_rows(level: Dictionary, kind: String) -> Array:
	var rows: Array = []
	for hazard in level.hz:
		if hazard[0] == kind: rows.append(hazard.slice(1))
	return rows

func run_character(game, character: String) -> bool:
	failures.clear()
	route_step = 0
	seen_shelves.clear()
	game.character = character
	game.save = {"schema": 1, "receipts": {}}
	check(SaveStore.write_save(game.save) == OK, "fresh isolated save failed")
	check(not SaveStore.read_save().get("cleared", {}).get("2-2", false), "stale aisle clear")
	check(game.load_level("2-2"), "2-2 did not load")
	check(game.is_native_supported() and game._native_world_two(), "2-2 is still a preview or has the wrong runtime")
	check(game.player == Vector2(300, 482) and game.camera == Vector2.ZERO, "source starting position changed")
	check(game.level.w == 15200 and game.view_width() == 738, "source width/view changed")
	check(source_equal(game.level.solids, [[-400, 15600, 482]]) and game.level.plats.size() == 14, "source aisle surfaces changed")
	check(source_equal(game.level.islands, ISLANDS), "source seven island shelves changed")
	var expected_platforms: Array = []
	for island in ISLANDS:
		expected_platforms.append([island[0] + 6, island[1] - 6, 364])
		expected_platforms.append([island[0] + 6, island[1] - 6, 246])
	check(source_equal(game.level.plats, expected_platforms), "source two-tier shelf geometry changed")
	check(source_equal(game.level.receipts, RECEIPTS) and game.receipts.size() == 3, "source receipt coordinates changed")
	check(source_equal(game.level.scenes, [[10400, "door", "Frozen foods", "Through the cold doors!"]]), "source frozen-foods door changed")
	check(game.level.check == 10500 and game.level.start == 300, "source checkpoint/start changed")
	check(source_equal(source_rows(game.level, "gate"), GATES), "source seven gates changed")
	check(source_equal(source_rows(game.level, "plate"), PLATES), "source five plates changed")
	check(source_equal(source_rows(game.level, "button"), BUTTONS), "source two shot buttons changed")
	check(source_equal(source_rows(game.level, "drops"), [[5000, 8000, 1700, "box"], [11000, 13600, 2300, "icicle"]]), "source falling-stock zones changed")
	check(source_equal(source_rows(game.level, "ice"), [[10800, 13700, 482]]), "source icy floor changed")
	check(game.movement_skills.skills.is_empty() and game.abilities.skills.is_empty(), "run inherited movement skills")
	check(game.combat.waves.size() == 10, "expected all ten source waves")
	if not failures.is_empty():
		printerr("Aisle input run [", character, "]: FAIL ", failures)
		return false
	var hazards = game.world_two.hazard_controller
	check(hazards.gates.size() == 7 and hazards.plates.size() == 5 and hazards.buttons.size() == 2, "source hazard entities missing")
	check(game.world_two.unsupported_hazards.is_empty(), "aisle still has unsupported hazards")
	for i in range(10):
		check(game.combat.waves[i].at == WAVE_AT[i], "wave trigger changed: %d" % i)
		check(game.combat.waves[i].group == game.level.waves[i].g, "solo group differs from source: %d" % i)
	var source_geometry := JSON.stringify(game.level)
	var started: Array[int] = []
	var completed: Array[int] = []
	var collected: Array[int] = []
	var activated_plates: Array[int] = []
	var activated_buttons: Array[int] = []
	var passed_gates: Array[int] = []
	var seen_enemies: Array = []
	var seen_drops: Array = []
	var fallen_drops: Array = []
	var seen_coin_positions: Array[Vector2] = []
	var ordinary_damage := false
	var specials := 0
	var jumps := 0
	var falls := 0
	var aim_frames := 0
	var down_frames := 0
	var ice_frames := 0
	var ticks := 0
	var ending_frame := -1
	var wipe_start := -1
	var wipe_mid := -1
	var wipe_end := -1
	var wipe_motion := 0.0
	var checkpoint_frame := -1
	var boss_seen := false
	var consumed := 0
	for frame in range(MAX_TICKS):
		ticks = frame + 1
		game.invincible = 999 # Explicit sole progression assist.
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
		var only_normal: bool = game.abilities.active.is_empty() and not controls.special and game.abilities.effects.is_empty() and game.bullets.all(func(b): return b.enemy or b.get("kind", "") == character)
		game.step(DT, controls)
		if active_before.is_empty() and not game.abilities.active.is_empty():
			specials += 1
			check(game.abilities.active == character, "activated another housemate's special")
		if grounded_before and not game.grounded and game.velocity.y < 0: jumps += 1
		if controls.aim: aim_frames += 1
		if controls.down: down_frames += 1
		if position_before.x > 10800 and position_before.x < 13700 and grounded_before and absf(position_before.y - 482) < 4: ice_frames += 1
		for pair in hp_before:
			if only_normal and pair[0].hp < pair[1]: ordinary_damage = true
		boss_seen = boss_seen or game.boss != null
		if position_before.y > game.level.fall and game.player.y < position_before.y - 100: falls += 1
		check(absf(game.player.x - position_before.x) < 20 or scene_before != game.world_two.scene_index, "unexpected teleport outside the source door")
		if game.world_two.scene_index == 0:
			check(game.player.x <= 10400.01, "player crossed closed scene boundary")
			check(game.camera.x <= 9962.01, "camera showed frozen foods too early")
			check(not game.world_two.checkpoint_hit, "checkpoint triggered before source door")
		if game.world_two.wiping and wipe_start < 0:
			wipe_start = frame
			check(game.combat.waves.slice(0, 7).all(func(w): return w.started and w.done) and game.combat.waves.slice(7).all(func(w): return not w.started), "door started before seven preceding waves cleared")
			check(game.player.x >= 10350 and game.player.x <= 10400, "door started outside source entry interval")
			check(game.world_two.wipe_kind == "door" and game.world_two.wipe_label == "Frozen foods", "incorrect source wipe")
		if wipe_before:
			check(absf(game.elapsed - elapsed_before - DT) < 0.0001, "simulation paused during source door wipe")
			if scene_before == 0 and game.world_two.scene_index == 0: wipe_motion += absf(game.player.x - position_before.x)
		if scene_before != game.world_two.scene_index:
			wipe_mid = frame
			check(scene_before == 0 and game.world_two.scene_index == 1, "unexpected scene transition")
			check(game.world_two.wipe_elapsed >= 1.43 and game.world_two.wipe_elapsed < 1.43 + DT + 0.0001, "door midpoint is not source 1.43 seconds")
			check(game.player == Vector2(10820, 482) and game.grounded, "source door did not land at (10820,482)")
			check(game.camera == Vector2(10660, 0) and game.camera_speed == 0, "source door camera reset changed")
			check(game.velocity == Vector2.ZERO and game.bullets.is_empty(), "source door did not clear momentum/projectiles")
			check(not game.world_two.checkpoint_hit, "checkpoint ran after end-of-frame callback")
		if wipe_before and not game.world_two.wiping:
			wipe_end = frame
			check(game.world_two.scene_index == 1 and game.world_two.wipe_elapsed >= 2.17, "visual wipe ended before source duration")
		if game.world_two.checkpoint_hit and checkpoint_frame < 0:
			checkpoint_frame = frame
			check(wipe_mid >= 0 and frame == wipe_mid + 1, "checkpoint did not trigger first update after callback")
			check(game.hearts == 3, "checkpoint did not leave full hearts")
		for i in range(10):
			var wave: Dictionary = game.combat.waves[i]
			if wave.started and i not in started: started.append(i)
			if wave.done and i not in completed:
				completed.append(i)
				check(wave.index == wave.group.size(), "wave finished before every entry dispatched")
				if debug_run: print("Aisle wave ", i, " done frame=", frame, " player=", game.player)
			consumed += wave.index - indices[i]
			if debug_run and wave.index > indices[i]: print("Aisle dispatch wave=", i, " entries=", wave.group.slice(indices[i], wave.index), " frame=", frame, " camera=", game.camera, " player=", game.player)
		for enemy in game.enemies:
			if enemy not in seen_enemies:
				seen_enemies.append(enemy)
				if debug_run: print("Aisle spawn ", enemy.kind, " frame=", frame, " p=", enemy.p)
				if enemy.kind == "big": check(enemy.big and enemy.max_hp == 24 and enemy.hw == 58 and enemy.hh == 186, "security bot lost source solo24HP geometry")
				if enemy.kind == "drone": check(enemy.max_hp == 2 and not enemy.get("fly", false), "barcode drone has World1 contract")
				if enemy.kind == "cart": check(enemy.max_hp == 2, "cart bot source health changed")
		for plate in hazards.plates:
			if plate.on:
				check(game.grounded and absf(game.player.x - plate.x) < 46 and absf(game.player.y - plate.y) < 6, "plate activated without actual grounded contact")
				if int(plate.id) not in activated_plates:
					activated_plates.append(int(plate.id))
					if debug_run: print("Aisle plate ", plate.id, " frame=", frame, " player=", game.player)
		for button in hazards.buttons:
			if button.hit > 0 and int(button.id) not in activated_buttons:
				activated_buttons.append(int(button.id))
				check(button.hit <= 0.3 and button.hit >= 0.3 - DT - 0.0001, "shot button lacks source impact flash")
				if debug_run: print("Aisle button ", button.id, " frame=", frame, " player=", game.player)
		for gate in hazards.gates:
			if gate.held: check(absf(gate.timer - 5.2) < 0.0001, "solo plate hold is not source5.2 seconds")
			if gate.open > 0:
				check(int(gate.id) in activated_plates or int(gate.id) in activated_buttons, "gate opened without a real switch activation")
			if position_before.x < gate.x + 65 and game.player.x >= gate.x + 65 and int(gate.id) not in passed_gates:
				passed_gates.append(int(gate.id))
				check(gate.open > 0.55 and gate.q.row[2] == 5482, "crossed closed source shelf gate")
				if debug_run: print("Aisle passed gate ", gate.id, " frame=", frame)
		for i in range(game.level.islands.size()):
			var shelf: Array = game.level.islands[i]
			if game.grounded and absf(game.player.y - 246) < 0.1 and game.player.x >= shelf[0] + 6 and game.player.x <= shelf[1] - 6 and i not in seen_shelves: seen_shelves.append(i)
		for entity in game.world_two.entities:
			if entity.k != "drop": continue
			if entity not in seen_drops:
				seen_drops.append(entity)
				check(entity.kind in ["box", "icicle"] and absf(entity.warn - 0.95) < 0.0001, "falling stock kind/warning changed")
				check(entity.vy == 0 and absf(entity.p.y - (game.view_top() - 80)) < 0.0001, "drop skipped actual warning/spawn position")
			if entity.vy > 0 and entity not in fallen_drops:
				fallen_drops.append(entity)
				check(entity.t >= 0.95 - 0.0001, "stock fell before source warning elapsed")
		for coin in game.coins:
			if not coin.get("keep", false): continue
			if absf(coin.age - 0.3) < 0.00001 and coin.p not in seen_coin_positions: seen_coin_positions.append(coin.p)
			if coin.rest: check(coin.age <= 2.0001, "resting authored coin lost keep-age cap")
		for i in range(3):
			if game.receipts[i].taken and i not in collected:
				collected.append(i)
				check(absf(game.player.x - RECEIPTS[i][0]) < 42, "receipt collected outside actual horizontal contact")
				check(game.player.y > RECEIPTS[i][1] - 30 and game.player.y - game.character_height() < RECEIPTS[i][1], "receipt lost World2 vertical contact bounds")
				if debug_run: print("Aisle receipt ", i, " frame=", frame, " player=", game.player)
		if game.world_two.end_time > 0 and ending_frame < 0:
			ending_frame = frame
			check(completed == EXPECTED_WAVES, "exit started before all waves cleared")
			check(game.camera.x >= 14460, "exit started before source endpoint")
		if debug_run and frame % 900 == 0: print("Aisle trace [", character, "] frame=", frame, " route=", route_step, " p=", game.player, " camera=", game.camera.x, " receipts=", collected, " live=", enemy_summary(game))
		if game.mode in ["clear", "over"]: break
	var exit_ticks := ticks - 1 - ending_frame if ending_frame >= 0 else -1
	check(game.mode == "clear", "bounded input route did not clear")
	check(started == EXPECTED_WAVES and completed == EXPECTED_WAVES, "all ten waves did not start/finish in order")
	check(consumed == 43 and seen_enemies.size() == 43, "not all43 authored enemies actually spawned")
	for kind in ENEMY_COUNTS:
		check(seen_enemies.filter(func(e): return e.kind == kind).size() == ENEMY_COUNTS[kind], "source enemy count changed: " + kind)
	check(seen_enemies.all(func(e): return e.state == "pop" and e.hp <= 0), "an authored enemy escaped instead of being defeated")
	check(not boss_seen, "aisle invented a separate boss objective")
	check(collected == [0, 1, 2], "did not collect all three actual source receipts")
	check(activated_plates == [0, 2, 3, 4, 6], "did not activate all five actual plates in route order")
	check(activated_buttons == [1, 5], "did not shoot both actual buttons in route order")
	check(passed_gates == [0, 1, 2, 3, 4, 5, 6], "did not pass all seven opened shelf gates")
	check([1, 4, 6].all(func(i): return i in seen_shelves), "did not climb actual receipt/high-button shelves")
	check(specials > 0 and jumps >= 6 and ordinary_damage and aim_frames > 0 and down_frames > 0, "missing actual special/jump/down/aim/ordinary damage coverage")
	check(falls == 0, "route relied on fall-safe recovery")
	check(wipe_start >= 0 and wipe_mid > wipe_start and wipe_end > wipe_mid and wipe_motion > 10, "source door/input simulation coverage missing")
	check(checkpoint_frame == wipe_mid + 1, "source checkpoint not observed")
	for kind in ["box", "icicle"]:
		check(seen_drops.any(func(e): return e.kind == kind) and fallen_drops.any(func(e): return e.kind == kind), "did not see real warning and fall: " + kind)
	check(ice_frames > 100 and not hazards.ice_velocity.is_empty(), "actual frozen-floor movement was not exercised")
	check(game.world_two.coins_done.size() == 12 and seen_coin_positions.size() == 70, "not all12 rows/70 authored coins appeared once")
	check(authored_coin_positions_match(game.level.hz, seen_coin_positions), "authored coin positions/arcs differ from source")
	check(exit_ticks == 155, "source2.6-second exit timing changed")
	check(JSON.stringify(game.level) == source_geometry, "runtime/test mutated imported source data")
	check(game.movement_skills.skills.is_empty() and game.abilities.skills.is_empty(), "unearned movement skills appeared")
	check(game.save.get("cleared", {}).get("2-2", false), "real clear missing in memory")
	var persisted: Dictionary = SaveStore.read_save()
	check(persisted.get("cleared", {}).get("2-2", false), "real clear missing after disk reload")
	check(persisted.get("receipts", {}).get("2-2", []) == [0, 1, 2], "receipts missing after disk reload")
	var passed := failures.is_empty()
	print("Aisle input run [", character, "]: ", "PASS" if passed else "FAIL", " ticks=", ticks, " waves=", completed.size(), "/10 enemies=", seen_enemies.size(), "/43 receipts=", collected, " plates=", activated_plates, " buttons=", activated_buttons, " gates=", passed_gates, " authored_coins=", seen_coin_positions.size(), "/70 drops=", seen_drops.size(), " shelves=", seen_shelves, " jumps=", jumps, " specials=", specials, " aim=", aim_frames, " down=", down_frames, " ice=", ice_frames, " door=", wipe_start, "/", wipe_mid, "/", wipe_end, " checkpoint=", checkpoint_frame, " exit_ticks=", exit_ticks, " player=", game.player, " mode=", game.mode)
	if not passed:
		printerr("Aisle failures [", character, "]: ", failures)
		printerr("Remaining live enemies: ", enemy_summary(game))
	return passed

func enemy_summary(game) -> Array:
	var summary: Array = []
	for enemy in game.enemies:
		if enemy.state != "pop": summary.append([enemy.kind, enemy.p, enemy.hp, enemy.state])
	return summary

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

func walk_toward(game, controls: Dictionary, target_x: float, tolerance: float = 4) -> void:
	var dx := target_x - float(game.player.x)
	# Countersteer through ordinary left/right input when crossing the icy
	# floor. This predicts braking only; it never edits actual ice momentum.
	if game.grounded and game.player.x > 10800 and game.player.x < 13700 and absf(game.player.y - 482) < 4:
		var momentum: float = game.world_two.hazard_controller.ice_velocity.get(game.get_instance_id(), 0.0)
		dx -= momentum * 0.3
	controls.right = dx > tolerance
	controls.left = dx < -tolerance

func plate_gate(game, controls: Dictionary, id: int) -> bool:
	var hazards = game.world_two.hazard_controller
	var gate: Dictionary = hazards.gates.filter(func(g): return int(g.id) == id)[0]
	if game.player.x > gate.x + 70: return true
	var plate: Dictionary = hazards.plates.filter(func(p): return int(p.id) == id)[0]
	var time_to_cross := maxf(0, gate.x + 80 - game.player.x) / 270.0 + 0.35
	walk_toward(game, controls, gate.x + 95 if gate.timer > time_to_cross else plate.x)
	return false

func climb_shelf(game, controls: Dictionary, x: float, shelf_index: int, receipt_index: int) -> bool:
	if shelf_index in seen_shelves and game.receipts[receipt_index].taken: return true
	walk_toward(game, controls, x)
	if absf(game.player.x - x) < 22 and game.grounded and game.player.y > 246.1 and not game.jump_held:
		controls.jump = true
	return false

func button_gate(game, controls: Dictionary, id: int) -> bool:
	var hazards = game.world_two.hazard_controller
	var gate: Dictionary = hazards.gates.filter(func(g): return int(g.id) == id)[0]
	if game.player.x > gate.x + 70: return true
	var enough_time: bool = gate.timer > maxf(0, gate.x + 80 - game.player.x) / 270.0 + 0.4
	if enough_time:
		walk_toward(game, controls, gate.x + 95)
	elif id == 1:
		# Normal standing shots from the actual upper shelf hit y152 for all
		# six authored character heights. Do not replace this with a hook call.
		walk_toward(game, controls, 4050)
		if game.grounded and game.player.y > 246.1 and not game.jump_held: controls.jump = true
		if game.face < 0: controls.right = true; controls.left = false
	else:
		walk_toward(game, controls, 11550)
		if game.grounded and game.on_platform:
			controls.down = true
			controls.jump = not game.jump_held
		if game.face < 0: controls.right = true; controls.left = false
	return false

func controls_for(game, frame: int, wipe_start: int) -> Dictionary:
	var controls := {"left": false, "right": false, "jump": false, "down": false, "aim": false, "shoot": true, "special": false}
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
			controls.down = true
			controls.jump = not game.jump_held
		elif target.kind == "drone" or target.p.y < game.player.y - 130:
			controls.aim = true
			walk_toward(game, controls, target.p.x, 24)
		else:
			if game.grounded and frame % 120 == 0: controls.down = true
			if game.face != (1 if dx >= 0 else -1):
				controls.right = dx >= 0
				controls.left = dx < 0
			# A green button also absorbs shots fired back toward an enemy.
			# Walk past it instead of endlessly reactivating the shelf gate.
			for button in game.world_two.hazard_controller.buttons:
				if button.x > minf(game.player.x, target.p.x) and button.x < maxf(game.player.x, target.p.x) and absf(game.player.y - game.character_height() * 0.53 - button.y) < 30:
					controls.down = false
					walk_toward(game, controls, button.x + signf(dx) * 90)
		if game.abilities.meter >= 1: controls.special = true
		return controls
	match route_step:
		0:
			if plate_gate(game, controls, 0): route_step += 1
		1:
			if climb_shelf(game, controls, 3700, 1, 0): route_step += 1
		2:
			if button_gate(game, controls, 1): route_step += 1
		3:
			if plate_gate(game, controls, 2): route_step += 1
		4:
			if climb_shelf(game, controls, 8300, 4, 1): route_step += 1
		5:
			if plate_gate(game, controls, 3): route_step += 1
		6:
			if plate_gate(game, controls, 4): route_step += 1
		7:
			if game.world_two.scene_index == 1: route_step += 1
			else: walk_toward(game, controls, 10400)
		8:
			if button_gate(game, controls, 5): route_step += 1
		9:
			if climb_shelf(game, controls, 12870, 6, 2): route_step += 1
		10:
			# The original spawnBot consumes an entry if the ground is outside
			# its vertical camera window. Descend by actual down+jump before
			# advancing to camera12600, so the final shelf cannot skip a bot.
			walk_toward(game, controls, 12870)
			if game.grounded and game.on_platform:
				controls.down = true
				controls.jump = not game.jump_held
			if game.grounded and absf(game.player.y - 482) < 1 and game.camera.y > -60: route_step += 1
		11:
			if plate_gate(game, controls, 6): route_step += 1
		_:
			walk_toward(game, controls, game.level.w - 40)
	return controls
