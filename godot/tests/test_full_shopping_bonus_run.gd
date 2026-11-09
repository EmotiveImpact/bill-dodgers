extends SceneTree
## Source-authored 2-S input progression, NOT unassisted difficulty QA.
## Invulnerability is the sole assist. No actor/geometry/wave/timer/power edits,
## no direct damage, no earned skills, no forced pickups or synthetic clear.
## A separately labelled idle fixture verifies that timer100000 is dormant.
const SaveStore = preload("res://src/save_store.gd")
const DT := 1.0 / 60.0
const MAX_TICKS := 12000
const RECEIPTS := [[2000, 362], [5300, 362], [8200, 482]]
const STALLS := [700, 1600, 2500, 3400, 4300, 5200, 6100, 7000, 7900]
const WAVE_AT := [2000, 5200]
const GROUPS := [[[0, "r", "rush"], [900, "r", "rush"]], [[0, "r", "cart"], [800, "r", "rush"]]]
var failures: Array[String] = []
var debug_run := false

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	if not game.has_method("step"):
		printerr("Shopping bonus input run: main script did not load")
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
	var passed := run_dormant_timer_fixture(game)
	for character in characters:
		if not run_character(game, character): passed = false
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)

func check(condition: bool, message: String) -> void:
	if not condition and message not in failures: failures.append(message)

func source_equal(actual: Variant, expected: Variant) -> bool:
	# JSON numbers deserialize as floats, including nested wave/geometry arrays.
	if actual is Array and expected is Array:
		if actual.size() != expected.size(): return false
		for i in range(actual.size()):
			if not source_equal(actual[i], expected[i]): return false
		return true
	if (actual is int or actual is float) and (expected is int or expected is float):
		return absf(float(actual) - float(expected)) < 0.00001
	return actual == expected

func fresh_stage(game, character: String) -> void:
	game.character = character
	game.save = {"schema": 1, "receipts": {}}
	check(SaveStore.write_save(game.save) == OK, "fresh isolated save failed")
	check(not SaveStore.read_save().get("cleared", {}).get("2-S", false), "stale bonus clear")
	check(game.load_level("2-S"), "2-S did not load")
	check(game.is_native_supported() and game._native_world_two(), "2-S is a preview or wrong runtime")
	check(game.player == Vector2(300, 482) and game.camera == Vector2.ZERO, "source starting position changed")
	check(game.level.w == 9000 and game.view_width() == 738, "source stage/view width changed")
	check(game.level.timer == 100000, "dormant source timer metadata changed")
	check(source_equal(game.level.solids, [[-400, 9400, 482]]) and game.level.plats.is_empty(), "source surfaces changed")
	check(source_equal(game.level.receipts, RECEIPTS) and game.receipts.size() == 3, "source receipt coordinates changed")
	check(source_equal(game.level.stalls, STALLS), "all nine source stalls are required")
	check(source_equal(game.level.crates, [[4500, 472, "split"]]), "source split crate changed")
	check(game.crates.size() == 1 and game.crates[0].p == Vector2(4500, 482) and game.crates[0].hp == 3 and game.crates[0].give == "split", "actual source crate missing or incorrect")
	check(game.level.hz.size() == 22 and game.level.hz.all(func(h): return h[0] == "coins"), "source must have exactly22 coin rows and no damage hazards")
	check(game.world_two.surfaces(game).size() == 1 and game.world_two.entities.is_empty(), "decorative stalls became collision/hazard entities")
	check(game.movement_skills.skills.is_empty() and game.abilities.skills.is_empty(), "run inherited earned skills")
	check(game.combat.waves.size() == 2, "expected both source waves")
	if game.combat.waves.size() == 2:
		for i in range(2):
			check(game.combat.waves[i].at == WAVE_AT[i], "wave trigger changed: %d" % i)
			check(source_equal(game.combat.waves[i].group, GROUPS[i]), "solo authored wave group changed: %d" % i)
	check(game.level.get("scenes", []).is_empty() and not game.level.has("check"), "invented scene/checkpoint objective")

func run_dormant_timer_fixture(game) -> bool:
	# NONPROGRESSION FIXTURE: remain at the start for105 simulated seconds.
	# This does not count as a completed route and does not edit any clock.
	failures.clear()
	fresh_stage(game, "jp")
	if failures.is_empty():
		for frame in range(6300):
			game.step(DT, {})
			check(game.mode == "play", "dormant timer ended an idle stage")
		check(game.elapsed > 100 and game.world_two.elapsed > 100, "idle fixture did not pass100 seconds")
		check(game.player == Vector2(300, 482) and game.camera == Vector2.ZERO, "idle fixture moved player/camera")
		check(game.combat.waves.all(func(w): return not w.started) and game.enemies.is_empty(), "idle fixture bypassed distance triggers")
		check(game.world_two.end_time == 0 and not game.world_two.clear_reported and game.boss == null, "idle timer created an exit/boss objective")
		check(game.score == 0 and game.items.is_empty() and game.world_two.entities.is_empty(), "idle timer created an unearned reward or hazard")
		check(not game.save.get("cleared", {}).get("2-S", false) and not SaveStore.read_save().get("cleared", {}).get("2-S", false), "idle timer wrote a clear")
	var passed := failures.is_empty()
	print("Shopping bonus dormant-timer NONPROGRESSION fixture: ", "PASS" if passed else "FAIL", " elapsed=", game.elapsed, " mode=", game.mode)
	if not passed: printerr("Dormant-timer fixture failures: ", failures)
	return passed

func run_character(game, character: String) -> bool:
	failures.clear()
	fresh_stage(game, character)
	if not failures.is_empty():
		printerr("Shopping bonus input run [", character, "]: FAIL ", failures)
		return false
	var source_geometry := JSON.stringify(game.level)
	var started: Array[int] = []
	var completed: Array[int] = []
	var collected: Array[int] = []
	var crossed_stalls: Array[int] = []
	var seen_enemies: Array = []
	var seen_coin_positions: Array[Vector2] = []
	var picked_authored := 0
	var ordinary_damage := false
	var crate_shot_damage := false
	var crate_broke := false
	var split_item_seen := false
	var split_collected := false
	var split_shots_seen := false
	var specials := 0
	var jumps := 0
	var down_frames := 0
	var aim_frames := 0
	var consumed := 0
	var ticks := 0
	var ending_frame := -1
	var last_wave_pop_frame := -1
	var exit_score := -1
	for frame in range(MAX_TICKS):
		ticks = frame + 1
		game.invincible = 999 # Explicit sole assist. Never damage/move a bot.
		var controls := controls_for(game, frame)
		var before: Vector2 = game.player
		var active_before: String = game.abilities.active
		var grounded_before: bool = game.grounded
		var crate_hp_before: int = game.crates[0].hp
		var coin_snapshot: Array = game.coins.filter(func(c): return c.get("keep", false))
		var hp_snapshot: Array = []
		for enemy in game.enemies: hp_snapshot.append([enemy, enemy.hp, enemy.state])
		var indices: Array[int] = []
		for wave in game.combat.waves: indices.append(wave.index)
		var only_normal: bool = game.abilities.active.is_empty() and not controls.special and game.abilities.effects.is_empty() and game.bullets.all(func(b): return b.enemy or b.get("kind", "") == character)
		if game.mode == "play": exit_score = game.score + game.coins.size()
		game.step(DT, controls)
		if active_before.is_empty() and not game.abilities.active.is_empty():
			specials += 1
			check(game.abilities.active == character, "activated another housemate's special")
		if grounded_before and not game.grounded and game.velocity.y < 0: jumps += 1
		if controls.down: down_frames += 1
		if controls.aim: aim_frames += 1
		for snapshot in hp_snapshot:
			if only_normal and snapshot[0].hp < snapshot[1]: ordinary_damage = true
			if snapshot[2] != "pop" and snapshot[0].state == "pop" and started.size() == 2: last_wave_pop_frame = frame
		if only_normal and game.crates[0].hp < crate_hp_before: crate_shot_damage = true
		if game.crates[0].broken: crate_broke = true
		for item in game.items:
			if item.give == "split": split_item_seen = true
		if game.power == "split": split_collected = true
		if game.power == "split" and game.bullets.filter(func(b): return not b.enemy and b.get("kind", "") == character and absf(b.v.y) > 100).size() >= 2: split_shots_seen = true
		for coin in coin_snapshot:
			if coin.get("dead", false): picked_authored += 1
		check(absf(game.player.x - before.x) < 20 and game.player.y <= game.level.fall, "unexpected teleport/fall recovery")
		check(game.world_two.surfaces(game).size() == 1 and not game.on_platform, "stall created a surface")
		check(game.boss == null and game.world_two.entities.is_empty() and not game.world_two.wiping, "invented bonus boss/hazard/scene")
		for stall in STALLS:
			if before.x < stall + 135 and game.player.x >= stall + 135 and stall not in crossed_stalls: crossed_stalls.append(stall)
		for i in range(2):
			var wave: Dictionary = game.combat.waves[i]
			if wave.started and i not in started:
				started.append(i)
				check(game.camera.x >= WAVE_AT[i] - 2, "wave started before its source camera trigger")
			if wave.done and i not in completed:
				completed.append(i)
				check(wave.index == wave.group.size(), "wave skipped an authored entry")
				check(not game.enemies.any(func(e): return e.state != "pop"), "wave completed with a living enemy")
				if i == 1: check(last_wave_pop_frame >= 0 and frame == last_wave_pop_frame + 1, "last wave did not complete on the update after final enemy death")
				if debug_run: print("Shopping bonus wave ", i, " done frame=", frame, " player=", game.player)
			for entry_index in range(indices[i], wave.index):
				var due := float(wave.group[entry_index][0]) / 1000.0
				check(wave.t >= due and wave.t <= due + DT + 0.00001, "authored enemy dispatch delay changed")
			consumed += wave.index - indices[i]
		for enemy in game.enemies:
			if enemy not in seen_enemies:
				seen_enemies.append(enemy)
				check(enemy.spawn_side == "r", "solo bonus introduced a co-op/alternate-side spawn")
				check(enemy.max_hp == (2 if enemy.kind == "cart" else 3), "source enemy health changed")
		for coin in game.coins:
			if not coin.get("keep", false): continue
			# Late-created coins retain age=.3 before the first pickup pass.
			if absf(coin.age - 0.3) < 0.00001 and coin.p not in seen_coin_positions: seen_coin_positions.append(coin.p)
			if coin.rest: check(coin.age <= 2.0001, "authored resting coin lost the keep-age cap")
		for i in range(3):
			if game.receipts[i].taken and i not in collected:
				collected.append(i)
				check(absf(game.player.x - RECEIPTS[i][0]) < 42, "receipt collected without horizontal contact")
				check(game.player.y > RECEIPTS[i][1] - 30 and game.player.y - game.character_height() < RECEIPTS[i][1], "receipt collected without source body overlap")
		if game.world_two.end_time > 0 and ending_frame < 0:
			ending_frame = frame
			check(completed == [0, 1] and game.camera.x >= 8260, "exit started before source distance/wave conditions")
		if debug_run and frame % 1200 == 0: print("Shopping bonus trace [", character, "] frame=", frame, " p=", game.player, " camera=", game.camera.x, " receipts=", collected, " waves=", completed, " live=", game.enemies.filter(func(e): return e.state != "pop").size(), " power=", game.power)
		if game.mode in ["clear", "over"]: break
	var exit_ticks := ticks - 1 - ending_frame if ending_frame >= 0 else -1
	check(game.mode == "clear", "bounded ordinary-input route did not clear")
	check(started == [0, 1] and completed == [0, 1] and consumed == 4, "both waves/all4 solo entries did not run")
	check(seen_enemies.size() == 4 and seen_enemies.filter(func(e): return e.kind == "rush").size() == 3 and seen_enemies.filter(func(e): return e.kind == "cart").size() == 1, "actual source enemy inventory changed")
	check(seen_enemies.all(func(e): return e.state == "pop") and game.pop_count == 4, "enemy abandonment substituted for actual kills")
	check(collected == [0, 1, 2], "did not collect all three actual receipts")
	check(crossed_stalls == STALLS, "did not traverse all nine noncolliding stalls")
	check(game.world_two.coins_done.size() == 22 and seen_coin_positions.size() == 128, "not all22 authored coin rows/128 coins appeared once")
	check(authored_coin_positions_match(game.level.hz, seen_coin_positions), "authored coin coordinates/arcs differ from source")
	check(picked_authored > 0, "no actual authored coin pickup observed")
	check(crate_shot_damage and crate_broke and split_item_seen and split_collected and split_shots_seen, "real crouch-shot crate/split item/powered firing sequence missing")
	check(specials > 0 and jumps > 0 and ordinary_damage and down_frames > 0 and aim_frames > 0, "missing real special/jump/down/aim/ordinary damage input coverage")
	check(exit_ticks == 155, "source2.6-second exit timing changed")
	check(game.score == exit_score, "clear did not bank the actual remaining coins exactly once")
	check(JSON.stringify(game.level) == source_geometry, "runtime/test mutated imported source")
	check(game.movement_skills.skills.is_empty() and game.abilities.skills.is_empty(), "unearned skills appeared")
	check(game.save.get("cleared", {}).get("2-S", false), "actual clear missing in memory")
	var persisted: Dictionary = SaveStore.read_save()
	check(persisted.get("cleared", {}).get("2-S", false), "actual clear missing after disk reload")
	check(persisted.get("receipts", {}).get("2-S", []) == [0, 1, 2], "receipts missing after disk reload")
	check(persisted.get("kitty", 0) == game.score, "actual banked reward missing after disk reload")
	check(persisted.get("skills", []).is_empty(), "save contains unearned skills")
	var banked_score: int = game.score
	var banked_save := JSON.stringify(persisted)
	for frame in range(180): game.step(DT, {})
	check(game.score == banked_score and JSON.stringify(SaveStore.read_save()) == banked_save, "post-clear updates duplicated reward/save")
	var passed := failures.is_empty()
	print("Shopping bonus input run [", character, "]: ", "PASS" if passed else "FAIL", " ticks=", ticks, " waves=", completed.size(), "/2 enemies=", seen_enemies.size(), "/4 receipts=", collected, " stalls=", crossed_stalls.size(), "/9 authored_coins=", seen_coin_positions.size(), "/128 picked=", picked_authored, " split=", split_collected, " jumps=", jumps, " specials=", specials, " aim=", aim_frames, " down=", down_frames, " exit_ticks=", exit_ticks, " score=", game.score, " player=", game.player, " mode=", game.mode)
	if not passed:
		printerr("Shopping bonus failures [", character, "]: ", failures)
		printerr("Remaining live enemies: ", game.enemies.filter(func(e): return e.state != "pop"))
	return passed

func authored_coin_positions_match(hazards: Array, positions: Array[Vector2]) -> bool:
	var expected := 0
	for h in hazards:
		for i in range(int(h[4])):
			var fraction := float(i) / float(h[4] - 1) if h[4] > 1 else 0.5
			var point := Vector2(lerpf(h[1], h[2], fraction), float(h[3]) - sin(PI * float(i) / maxf(1, h[4] - 1)) * float(h[5]))
			if not positions.any(func(p): return p.distance_to(point) < 0.002): return false
			expected += 1
	return positions.size() == expected

func controls_for(game, frame: int) -> Dictionary:
	var controls := {"left": false, "right": false, "jump": false, "down": false, "aim": false, "shoot": true, "special": false}
	var target: Dictionary = {}
	for enemy in game.enemies:
		if enemy.state == "pop": continue
		if target.is_empty() or absf(enemy.p.x - game.player.x) < absf(target.p.x - game.player.x): target = enemy
	if not target.is_empty():
		var dx: float = target.p.x - game.player.x
		if game.face != (1 if dx >= 0 else -1):
			controls.right = dx >= 0
			controls.left = dx < 0
		if game.abilities.meter >= 1: controls.special = true
		return controls
	# The crate is low: standing shots pass over it, crouching is genuine input.
	if not game.crates[0].broken and game.player.x > 4290 and game.player.x < 4500:
		if game.face != 1: controls.right = true
		else: controls.down = true
		return controls
	for item in game.items:
		if item.give != "split": continue
		controls.right = item.p.x - game.player.x > 3
		controls.left = item.p.x - game.player.x < -3
		return controls
	var target_x: float = game.level.w - 40
	for i in range(game.receipts.size()):
		if not game.receipts[i].taken:
			target_x = RECEIPTS[i][0]
			break
	var dx := target_x - float(game.player.x)
	controls.right = dx > 3
	controls.left = dx < -3
	# Collect elevated samples by normal jumps, away from the low crate.
	if game.grounded and not game.jump_held and frame % 95 == 0 and (game.player.x < 4000 or game.player.x > 4700): controls.jump = true
	# Brief upward/diagonal shots while travelling, never an alternate damage path.
	if frame % 120 < 12: controls.aim = true
	return controls
