extends SceneTree
## Actual-main 4-6 input routes. Invulnerability is the sole gameplay assist.
## No teleporting, fabricated wave completion, direct boss damage or clear.
const SaveStore = preload("res://src/save_store.gd")
const DT := 1.0 / 60.0
const MAX_TICKS := 36000
const ROUTE := [Vector2(60, 482), Vector2(1100, 362), Vector2(1480, 362), Vector2(2400, 482), Vector2(3060, 412), Vector2(3300, 342), Vector2(3700, 342), Vector2(5100, 482)]
var failures: Array[String] = []
var trace := false
var route_step := 0
var saw_throw := false
var saw_charge := false

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok and label not in failures: failures.append(label)

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	if not game.has_method("step"):
		printerr("Captain route: main failed to load")
		game.free()
		quit(1)
		return
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/test_support.gd").silence(game)
	var characters: Array = game.CHARACTERS
	for arg in OS.get_cmdline_user_args():
		if arg == "--trace": trace = true
		if arg.begins_with("--character="):
			var selected := arg.trim_prefix("--character=")
			if selected not in game.CHARACTERS:
				printerr("Unknown housemate: ", selected)
				game.queue_free()
				await process_frame
				quit(1)
				return
			characters = [selected]
	var passed := true
	for character in characters:
		if not run_character(game, character): passed = false
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)

func walk(game, controls: Dictionary, x: float, tolerance := 3.0) -> void:
	controls.left = x < game.player.x - tolerance
	controls.right = x > game.player.x + tolerance

func face_target(game, controls: Dictionary, x: float) -> void:
	if game.face != (1 if x >= game.player.x else -1):
		controls.right = x >= game.player.x
		controls.left = x < game.player.x

func navigate(game, controls: Dictionary, point: Vector2) -> void:
	walk(game, controls, point.x)
	if not game.grounded or game.jump_held: return
	var direction := 1 if point.x >= game.player.x else -1
	for row in game.level.solids:
		if row[2] >= game.player.y - 6: continue
		var distance: float = ((row[0] if direction > 0 else row[1]) - game.player.x) * direction
		if distance >= 0 and distance < 65 and absf(point.x - game.player.x) > distance: controls.jump = true

func controls_for(game) -> Dictionary:
	var c := {"left": false, "right": false, "jump": false, "down": false, "aim": false, "shoot": true, "special": false}
	if game.boss != null:
		var b: Dictionary = game.boss.state
		if b.state == "down":
			var jar: Dictionary = game.world_four.captain.jar
			walk(game, c, float(jar.p.x) if not jar.is_empty() else game.camera.x + game.view_width() / 2)
			c.shoot = false
			return c
		# Stand at normal shot range; turn by input only. Wait for one real
		# phase2 charge before finishing so the route observes its attack cycle.
		var destination: float = b.x - 220 if b.x > game.camera.x + game.view_width() / 2 else b.x + 220
		walk(game, c, clampf(destination, game.camera.x + 50, game.camera.x + game.view_width() - 50), 10)
		if absf(destination - game.player.x) < 16:
			c.left = false
			c.right = false
			face_target(game, c, b.x)
		c.shoot = (int(b.phase) == 1 and (saw_throw or int(b.hp) > 72)) or (int(b.phase) >= 2 and (saw_charge or int(b.hp) > 35))
		if b.state == "enter": c.shoot = false
		if game.grounded and not game.jump_held:
			for wave in b.wave:
				if absf(wave.x - game.player.x) < 90: c.jump = true
		return c
	if route_step < ROUTE.size():
		var goal: Vector2 = ROUTE[route_step]
		if game.grounded and absf(game.player.x - goal.x) < 12 and absf(game.player.y - goal.y) < 2:
			route_step += 1
			if trace: print("Captain waypoint=", route_step, " p=", game.player)
		if route_step < ROUTE.size(): navigate(game, c, ROUTE[route_step])
	else: navigate(game, c, Vector2(5520, 482))
	# Reach the starting receipt before fighting or moving the camera.
	if route_step == 0: return c
	var targets: Array = []
	for enemy in game.enemies:
		if enemy.state != "pop": targets.append({"x": enemy.p.x, "y": enemy.p.y, "kind": "bot"})
	for foe in game.world_four.foes.entries:
		if not foe.dead and game.world_four.foes.hittable(foe): targets.append({"x": foe.x, "y": foe.y, "kind": foe.kind})
	var target: Dictionary = {}
	for candidate in targets:
		if absf(candidate.y - game.player.y) > 70: continue
		if absf(candidate.x - game.player.x) > 450: continue
		if target.is_empty() or absf(candidate.x - game.player.x) < absf(target.x - game.player.x): target = candidate
	if not target.is_empty() and game.grounded:
		c.left = false
		c.right = false
		c.jump = false
		face_target(game, c, target.x)
		c.down = target.kind in ["jet", "ring"] and not c.left and not c.right
	if game.abilities.meter >= 1: c.special = true
	return c

func run_character(game, character: String) -> bool:
	failures.clear()
	route_step = 0
	saw_throw = false
	saw_charge = false
	game.character = character
	game.save = {"schema": 1, "receipts": {}}
	check(SaveStore.write_save(game.save) == OK, "fresh isolated save failed")
	check(game.load_level("4-6"), "4-6 failed to load")
	check(game.is_native_supported() and game._native_world_four(), "4-6 native gate is not wired; not bypassed")
	if not failures.is_empty(): printerr(failures); return false
	check(game.player == Vector2(300, 482) and game.camera == Vector2.ZERO, "incorrect original spawn/camera")
	check(game.level.w == 5712 and game.level.solids.size() == 7 and game.level.plats.is_empty(), "incorrect source geometry inventory")
	check(game.combat.waves.size() == 4 and game.level.cfg.sets.size() == 1, "source four-wave/Bailiff inventory differs")
	var planned := 0
	for i in game.combat.waves.size():
		var wave: Dictionary = game.combat.waves[i]
		planned += wave.group.size()
		check(wave.at == [500, 1700, 2900, 4000][i] and JSON.stringify(wave.group) == JSON.stringify(game.level.waves[i].g), "Source wave trigger/order/delay/side/kind differs")
	check(planned == 17 and game.movement_skills.skills.is_empty(), "wrong solo entries or inherited unearned skills")
	var imported := JSON.stringify(game.meta)
	var ticks := 0
	var jumps := 0
	var falls := 0
	var specials := 0
	var consumed := 0
	var started: Array = []
	var completed: Array = []
	var phases: Array = []
	var states: Array = []
	var crew: Array = []
	var seen_foes: Array = []
	var killed_foes: Array = []
	var retired_foes: Array = []
	var masked_bot_contacts := 0
	var masked_foe_contacts := 0
	var masked_boss_contacts := 0
	var masked_wave_contacts := 0
	var masked_bill_contacts := 0
	var bailiff_seen := false
	var bailiff_defeated := false
	var ordinary_damage := false
	var boss_damage := 0
	var boss_started := -1
	var boss_down := -1
	var jar_spawn := -1
	var jar_pickup := -1
	var pause_checked := false
	var wave_seen := false
	for frame in MAX_TICKS:
		ticks = frame + 1
		game.invincible = 999 # Only assist; every damage mechanism still runs.
		var c := controls_for(game)
		var p0: Vector2 = game.player
		var grounded0: bool = game.grounded
		var active0: String = game.abilities.active
		var hp0: int = game.boss.state.hp if game.boss != null else -1
		var indices: Array = []
		for wave in game.combat.waves: indices.append(wave.index)
		var bots0: Array = []
		for enemy in game.enemies: bots0.append([enemy, enemy.hp])
		var bullets0: Array = game.bullets.duplicate()
		game.step(DT, c)
		if grounded0 and not game.grounded and game.velocity.y < 0: jumps += 1
		if p0.y > game.level.fall - 50 and game.player.y < p0.y - 100:
			falls += 1
			if trace: print("Captain fall frame=", frame, " from=", p0, " to=", game.player, " camera=", game.camera, " route=", route_step)
		if active0.is_empty() and not game.abilities.active.is_empty(): specials += 1
		for pair in bots0:
			if pair[0].hp < pair[1]: ordinary_damage = true
		for i in game.combat.waves.size():
			var w: Dictionary = game.combat.waves[i]
			consumed += w.index - indices[i]
			if w.started and i not in started: started.append(i)
			if w.done and i not in completed:
				completed.append(i)
				check(w.index == w.group.size(), "wave completed before all entries consumed")
		for foe in game.world_four.foes.entries:
			if foe not in seen_foes:
				seen_foes.append(foe)
				if boss_started >= 0: crew.append(foe.kind)
			if foe.kind == "bailiff":
				bailiff_seen = true
				check(foe.max == 34, "Bailiff solo HP is not34")
				if foe.dead: bailiff_defeated = true
			if not foe.dead and foe.kind in ["bailiff", "ring"]:
				var width := 66 if foe.kind == "bailiff" else 38
				var height := 200 if foe.kind == "bailiff" else 60
				if absf(game.player.x - foe.x) < width and game.player.y > foe.y - height and game.player.y < foe.y + (10 if foe.kind == "bailiff" else 0): masked_foe_contacts += 1
		for foe in seen_foes:
			if foe.dead and foe not in killed_foes: killed_foes.append(foe)
			elif not foe.dead and foe not in game.world_four.foes.entries and foe not in retired_foes: retired_foes.append(foe)
		for enemy in game.enemies:
			if enemy.state != "pop" and absf(enemy.p.x - game.player.x) < 44 and game.player.y > enemy.p.y - 95 and game.player.y < enemy.p.y + 24: masked_bot_contacts += 1
		for bill in bullets0:
			if not bill.enemy or not bill.get("dead", false): continue
			var top: float = game.player.y - game.character_height() * (0.56 if game.crouching else 0.86)
			if absf(bill.p.x - game.player.x) < 26 and bill.p.y > top and bill.p.y < game.player.y: masked_bill_contacts += 1
		check(game.world_four.end_time == 0, "Ordinary timed exit activated in Captain jar finale")
		check(absf(game.player.x - p0.x) < 25 or falls > 0, "Unexpected horizontal teleport")
		if game.boss != null:
			var b: Dictionary = game.boss.state
			if boss_started < 0:
				boss_started = frame
				check(completed == [0, 1, 2, 3] and consumed == 17 and game.camera.x >= 4972, "Captain started before actual four-wave/end approach")
				check(b.hp == 90 and b.max == 90, "Captain did not enter at original90HP")
			check(b.fy == b.y and is_finite(float(b.fy)), "Native repaired ability feet unsynchronized/nonfinite")
			if b.phase not in phases: phases.append(b.phase)
			if b.state not in states: states.append(b.state)
			if b.state == "throw": saw_throw = true
			if b.state == "charge": saw_charge = true
			if not b.wave.is_empty(): wave_seen = true
			if hp0 >= 0: boss_damage += maxi(0, hp0 - int(b.hp))
			if b.state == "charge" and absf(game.player.x - (b.x + b.dir * 60)) < 60 and game.player.y > 362: masked_boss_contacts += 1
			for wave in b.wave:
				if absf(wave.x - game.player.x) < 26 and game.player.y > 452: masked_wave_contacts += 1
			if b.state == "down" and boss_down < 0:
				boss_down = frame
				check(b.hp <= 0 and game.mode == "play" and game.world_four.captain.jar.is_empty(), "Boss death bypassed actual jar objective")
				check(b.called.get("a", false) and b.called.get("b", false) and b.called.get("c", false), "Captain missing source threshold crew")
			var jar: Dictionary = game.world_four.captain.jar
			if not jar.is_empty():
				if jar_spawn < 0:
					jar_spawn = frame
					check(b.t > 1.8 and frame - boss_down >= 108 and jar.t <= DT + 0.000001, "Wrong down-to-jar delay or newborn jar phase")
				if jar.t <= 0.6: check(not jar.got and game.mode == "play", "Premature jar-age collection")
				if jar.got and jar_pickup < 0:
					jar_pickup = frame
					check(jar.t > 0.6 and absf(game.player.x - jar.p.x) < 50 and game.mode == "clear", "Clear not caused by actual age-gated horizontal jar pickup")
			if b.phase == 2 and not pause_checked:
				pause_checked = true
				var snapshot := var_to_str([game.player, game.camera, game.world_four.elapsed, b, game.combat.waves, game.bullets])
				game._pause()
				for i in 30: game.step(DT, {"right": true, "shoot": true})
				check(var_to_str([game.player, game.camera, game.world_four.elapsed, b, game.combat.waves, game.bullets]) == snapshot, "Pause advanced live Captain encounter")
				game._resume()
		if trace and frame % 600 == 0: print("Captain ", character, " frame=", frame, " route=", route_step, " p=", game.player, " cam=", game.camera, " waves=", completed, " boss=", [game.boss.state.hp, game.boss.state.state] if game.boss != null else [], " foes=", game.world_four.foes.entries.map(func(f): return [f.kind, f.get("hp", 0), f.x, f.y]))
		if game.mode != "play": break
	check(game.mode == "clear", "Actual route did not collect jar before tick bound")
	check(started == [0, 1, 2, 3] and completed == [0, 1, 2, 3] and consumed == 17, "Incomplete four waves/seventeen solo entries")
	check(bailiff_seen and bailiff_defeated and game.world_four.set_done.has("bailiff"), "Authored Bailiff set not fought and defeated")
	check(ordinary_damage and boss_damage >= 90, "Missing real ordinary-enemy/boss projectile damage")
	check(phases == [1, 2, 3] and saw_throw and saw_charge and wave_seen, "Captain phase/throw/charge/splash route coverage incomplete")
	check(crew == ["jet", "jet", "ring", "jet"], "Source solo Captain crew order differs")
	check(boss_started >= 0 and boss_down > boss_started and jar_spawn > boss_down and jar_pickup > jar_spawn, "Missing actual boss/down/jar/collection sequence")
	check(game.receipts.all(func(r): return r.taken) and game.receipt_score == 15, "All three original receipts were not collected with source£5 rewards")
	check(falls == 0 and jumps >= 2 and pause_checked, "Geometry/pause route coverage failed")
	check(JSON.stringify(game.meta) == imported, "Gameplay mutated original imported metadata")
	check(game.save.get("cleared", {}).get("4-6", false) and SaveStore.read_save().get("cleared", {}).get("4-6", false), "Clear not saved in memory and on disk")
	var passed := failures.is_empty()
	print("Captain input route [", character, "]: ", "PASS" if passed else "FAIL", " ticks=", ticks, " waves=", completed.size(), "/4 entries=", consumed, " phases=", phases, " states=", states, " crew=", crew, " receipts=", game.receipts.filter(func(r): return r.taken).size(), "/3 jumps=", jumps, " falls=", falls, " specials=", specials, " foe_kills=", killed_foes.size(), " foe_retirements=", retired_foes.size(), " masked_contacts=[bot:", masked_bot_contacts, ",foe:", masked_foe_contacts, ",boss:", masked_boss_contacts, ",wave:", masked_wave_contacts, ",bill:", masked_bill_contacts, "] jar_frames=", [boss_down, jar_spawn, jar_pickup], " mode=", game.mode)
	if not passed: printerr("Captain failures [", character, "]: ", failures, " player=", game.player, " camera=", game.camera, " route=", route_step)
	return passed
