extends SceneTree
## Whole source W2 stages using the existing normal-input P1 drivers and source
## CompanionAI for P2. Invulnerability for BOTH actors is the only run assist.
## No positional, wave, geometry, HP, damage, objective, ability or AI mutations.
## Catch-up relocations are counted, never represented as successful pathfinding.
const Drivers = preload("res://tests/party_world_two_drivers.gd")
const SaveStore = preload("res://src/save_store.gd")
const DT := 1.0 / 60.0
const MAX_TICKS := 36000
const LEVELS := ["2-1", "2-2", "2-3", "2-4", "2-5", "2-6", "2-S"]
var failures: Array[String] = []
var results: Array = []
var game
var trace := false
func _initialize() -> void: call_deferred("run")
func driver_for(id: String):
	match id:
		"2-1": return Drivers.Parking.new()
		"2-2": return Drivers.Aisle.new()
		"2-3": return Drivers.Stockroom.new()
		"2-4": return Drivers.Trolley.new()
		"2-5": return Drivers.Bakery.new()
		"2-6": return Drivers.Checkout.new()
	return Drivers.Shopping.new()
func note_failure(reason: String) -> void:
	if reason not in failures: failures.append(reason)
func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/test_support.gd").silence(game)
	var stages: Array = LEVELS.duplicate()
	var mates: Array = ["maya"]
	var max_ticks := MAX_TICKS
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg == "--all-cpu": mates = game.CHARACTERS.duplicate()
		elif arg == "--trace": trace = true
		elif arg.begins_with("--level="): stages = [arg.trim_prefix("--level=")]
		elif arg.begins_with("--cpu="): mates = [arg.trim_prefix("--cpu=")]
		elif arg.begins_with("--max-ticks="): max_ticks = int(arg.trim_prefix("--max-ticks="))
		elif arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	var all_passed := true
	for cpu in mates:
		for id in stages:
			if id not in LEVELS or cpu not in game.CHARACTERS:
				printerr("Invalid stage or CPU identity: ", id, " / ", cpu)
				all_passed = false
				continue
			if not run_route(id, cpu, max_ticks): all_passed = false
	if not output.is_empty():
		var file = FileAccess.open(output, FileAccess.WRITE)
		if file == null: printerr("Could not write explicit result path: ", output); all_passed = false
		else: file.store_string(JSON.stringify(results, "\t"))
	game.queue_free()
	await process_frame
	print("W2 party full input routes: ", results.size(), " completed attempts; ", "PASS" if all_passed else "FAIL", ". Both-actor invulnerability, source CPU catch-up counted, no device/difficulty claim.")
	quit(0 if all_passed else 1)
func run_route(id: String, cpu: String, max_ticks: int) -> bool:
	failures.clear()
	game._show_menu()
	game.character = "maya" if cpu == "jp" else "jp" # Source requires distinct actors.
	var leader: String = game.character
	game.save = {"schema": 1, "receipts": {}, "skills": [], "seen": {}}
	if SaveStore.write_save(game.save) != OK: note_failure("fresh isolated save failed")
	if not game.configure_party("cpu", cpu) or not game.load_level(id) or not game.party_session.active:
		note_failure("pair did not load")
		return false
	var session = game.party_session
	var driver = driver_for(id)
	var imported := JSON.stringify(game.meta)
	var expected_waves: int = game.level.waves.size()
	var expected_enemies := 0
	for index in game.combat.waves.size():
		var source: Dictionary = game.level.waves[index]
		expected_enemies += source.g.size() + source.get("x", []).size()
		if game.combat.waves[index].group != source.g + source.get("x", []): note_failure("pair source wave group mismatch")
	var p1 = session.runtime.actors[0]
	var mate = session.runtime.actors[1]
	var wipe_start := -1
	var seen: Array = []
	var phases: Array = []
	var cpu_catchups := 0
	var cpu_jumps := 0
	var cpu_pad_frames := 0
	var cpu_solo_pad_frames := 0
	var cpu_pads: Array = []
	var cpu_shots := 0
	var seen_cpu_shots: Array = []
	var cpu_crates := 0
	var seen_cpu_crates: Array = []
	var cpu_deliveries := 0
	var cpu_receipt_steps: Array = []
	var cpu_phase_three_hits := 0
	var own_cpu_crates: Array = []
	var tick := 0
	var max_hp := 0
	var boundary_maneuver_frames := 0
	for frame in range(max_ticks):
		tick = frame + 1
		# Sole explicit simulation assist. The active scalar must match actor0
		# because the session captures that facade at the next frame boundary.
		for actor in session.runtime.actors: actor.invincible = 999.0
		game.invincible = 999.0
		var controls: Dictionary
		if id == "2-6": controls = driver.call("controls_for", game, frame, game.world_two.checkout.snapshot())
		elif id in ["2-4", "2-S"]: controls = driver.call("controls_for", game, frame)
		else: controls = driver.call("controls_for", game, frame, wipe_start)
		if boundary_inputs(id, controls): boundary_maneuver_frames += 1
		var before_cpu_grounded: bool = mate.grounded
		var before_cpu_hits: int = int(mate.scene_state.get("boss_hits", 0))
		game.step(DT, controls)
		if absf(game.elapsed - tick * DT) > 0.00001: note_failure("shared level time did not advance exactly once")
		if game.player != p1.player or session.bridge.shared_phase: note_failure("facade/bridge did not close after source frame")
		for event in session.ai.events:
			if event.get("kind", "") == "catch_up" or event.has("from"): cpu_catchups += 1
		if before_cpu_grounded and not mate.grounded and mate.velocity.y < 0: cpu_jumps += 1
		for pad in game.world_two.hazard_controller.plates:
			if pad.on and mate.is_alive() and mate.grounded and absf(mate.player.x - pad.x) < 46 and absf(mate.player.y - pad.y) < 6:
				cpu_pad_frames += 1
				if pad.id not in cpu_pads: cpu_pads.append(pad.id)
				if not p1.grounded or absf(p1.player.x - pad.x) >= 46 or absf(p1.player.y - pad.y) >= 6: cpu_solo_pad_frames += 1
		for bullet in game.bullets:
			if not bullet.enemy and int(bullet.get("owner_slot", -1)) == 1 and not seen_cpu_shots.any(func(old): return is_same(old, bullet)):
				seen_cpu_shots.append(bullet); cpu_shots += 1
		for enemy in game.enemies:
			if not seen.any(func(old): return is_same(old, enemy)): seen.append(enemy)
		if game.world_two.wiping and wipe_start < 0: wipe_start = frame
		if id == "2-2":
			# Original solo runner's read-only shelf observation feeds its route.
			for index in game.level.islands.size():
				var shelf: Array = game.level.islands[index]
				if game.grounded and absf(game.player.y - 246) < 0.1 and game.player.x >= shelf[0] + 6 and game.player.x <= shelf[1] - 6 and index not in driver.seen_shelves: driver.seen_shelves.append(index)
		if id == "2-5":
			if driver.card_frame < 0 and "double-jump" in p1.movement_skills.skills: driver.card_frame = frame
			if driver.live_double_jump_frame < 0 and "double-jump" in p1.movement_skills.events: driver.live_double_jump_frame = frame
		if id == "2-6":
			if not game.abilities.active.is_empty(): driver.special_used = true
			var boss: Dictionary = game.world_two.checkout.boss
			if not boss.is_empty():
				max_hp = int(boss.max)
				if int(boss.phase) == 3:
					cpu_phase_three_hits += maxi(0, int(mate.scene_state.get("boss_hits", 0)) - before_cpu_hits)
					for index in int(boss.steps):
						var row: Array = game.world_two.checkout.receipt_step(index).row
						if mate.grounded and absf(mate.player.y - row[2]) < 0.01 and mate.player.x >= row[0] and mate.player.x <= row[1] and index not in cpu_receipt_steps: cpu_receipt_steps.append(index)
				if boss.phase not in phases: phases.append(boss.phase)
				for box in boss.crates:
					if box.by == 1 and not seen_cpu_crates.any(func(old): return is_same(old, box)):
						seen_cpu_crates.append(box); own_cpu_crates.append(box); cpu_crates += 1
				for box in own_cpu_crates:
					if box.st in ["fly", "on"]:
						# Do not mark world objects: remove only the test's reference.
						cpu_deliveries += 1
				own_cpu_crates = own_cpu_crates.filter(func(box): return box.st not in ["fly", "on"])
		if trace and frame % 1800 == 0:
			print("W2 pair trace ", id, " ", leader, "+", cpu, " frame=", frame, " p1=", p1.player, " cpu=", mate.player, " camera=", game.camera, " live=", game.enemies.filter(func(e): return e.state != "pop").map(func(e): return [e.kind,e.p,e.hp]), " scene=", game.world_two.scene_index)
		if game.mode != "play": break
	if game.mode != "clear": note_failure("bounded original normal-input route did not clear")
	if game.combat.waves.size() != expected_waves or not game.combat.waves.all(func(w): return w.done and w.index == w.group.size()): note_failure("not all source pair waves completed")
	if seen.size() < expected_enemies or (id != "2-6" and seen.size() != expected_enemies) or seen.any(func(enemy): return enemy.state != "pop"): note_failure("source enemies were missed or escaped instead of defeated")
	if not game.receipts.all(func(r): return r.taken): note_failure("not all source receipts collected")
	if JSON.stringify(game.meta) != imported: note_failure("imported source metadata changed")
	if not game.save.get("cleared", {}).get(id, false): note_failure("real source objective did not save clear")
	if cpu_shots == 0: note_failure("CPU never fired an actual projectile")
	if id == "2-6":
		if max_hp != 90 or phases != [1, 2, 3]: note_failure("pair checkout did not traverse source90HP phases")
		if cpu_crates == 0 or cpu_deliveries == 0: note_failure("CPU did not pick up and deliver any actual checkout crate")
		if 2 not in cpu_receipt_steps or cpu_phase_three_hits == 0: note_failure("CPU did not reach top receipt step and land an actual phase-three screen hit")
	var result := {"level": id, "leader": leader, "cpu": cpu, "passed": failures.is_empty(), "ticks": tick, "mode": game.mode,
		"waves": game.combat.waves.filter(func(w): return w.done).size(), "wave_count": expected_waves,
		"receipts": game.receipts.filter(func(r): return r.taken).size(), "enemies_seen": seen.size(), "expected_wave_enemies": expected_enemies,
		"undefeated_seen": seen.filter(func(enemy): return enemy.state != "pop").size(), "p1_pops": p1.pop_count,
		"cpu_shots": cpu_shots, "cpu_pops": mate.pop_count, "cpu_coins": mate.coins, "cpu_jumps": cpu_jumps,
		"cpu_catchups": cpu_catchups, "cpu_crates": cpu_crates, "cpu_deliveries": cpu_deliveries,
		"cpu_pad_frames": cpu_pad_frames, "cpu_solo_pad_frames": cpu_solo_pad_frames, "cpu_pads": cpu_pads,
		"checkout_phases": phases, "cpu_boss_hits": mate.scene_state.get("boss_hits", 0),
		"cpu_receipt_steps": cpu_receipt_steps, "cpu_phase_three_hits": cpu_phase_three_hits,
		"p1": str(p1.player), "p2": str(mate.player), "camera": str(game.camera), "boundary_maneuver_frames": boundary_maneuver_frames,
		"failures": failures.duplicate(), "live_enemies": game.enemies.filter(func(e): return e.state != "pop").map(func(e): return {"kind":e.kind,"p":str(e.p),"hp":e.hp})}
	results.append(result)
	print("W2 pair route: ", JSON.stringify(result))
	return failures.is_empty()

func boundary_inputs(id: String, controls: Dictionary) -> bool:
	# Narrow human-driver repair, not a source CPU/gameplay change. Pair targeting
	# can leave the bakery's last drone just beyond a closed scene boundary.
	# The solo controller aims while walking into that cap forever. A human can
	# jump and keep shooting diagonally right to reach its actual elevated body.
	# Every choice below is ordinary input; no position, HP or clock is edited.
	if id != "2-5" or game.world_two.scene_index >= game.level.get("scenes", []).size(): return false
	var edge: float = game.level.scenes[game.world_two.scene_index][0]
	var live: Array = game.enemies.filter(func(enemy): return enemy.state != "pop")
	if live.size() != 1 or live[0].kind != "drone" or game.player.x < edge - 4: return false
	if live[0].p.x <= edge or live[0].p.x > edge + 120: return false
	controls.left = false
	controls.right = true
	controls.aim = true
	controls.shoot = true
	controls.down = false
	controls.jump = game.grounded and not game.jump_held
	return true
