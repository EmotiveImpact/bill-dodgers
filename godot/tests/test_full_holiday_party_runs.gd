extends "res://tests/test_full_holiday_runs.gd"
## Real admitted W4 sessions, source-derived ordinary-input human route drivers and
## untouched CompanionAI. BOTH actors receive refreshed 999s invulnerability as
## the sole assist. Source falling/water damage deliberately clears that shield.
## No position, HP, wave, enemy, objective, pickup, skill or CPU-state edits.
## Natural CPU catch-ups/downed frames/checkpoint and clear rescues are reported.
const CaptainDriver = preload("res://tests/holiday_party_captain_controls.gd")
const LEVELS := ["4-1", "4-2", "4-3", "4-4", "4-5", "4-6", "4-S"]
var results: Array = []
var game

func run() -> void:
	game = load("res://main.tscn").instantiate()
	if not game.has_method("step"):
		printerr("Holiday CPU route: production main failed to load; no route started")
		game.free()
		quit(1)
		return
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/test_support.gd").silence(game)
	var mates: Array = ["maya"]
	var stages: Array = LEVELS.duplicate()
	var max_ticks := 60000
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg == "--all-cpu": mates = game.CHARACTERS.duplicate()
		elif arg == "--trace": debug_run = true
		elif arg.begins_with("--cpu="): mates = [arg.trim_prefix("--cpu=")]
		elif arg.begins_with("--stage="): stages = [arg.trim_prefix("--stage=")]
		elif arg.begins_with("--max-ticks="): max_ticks = int(arg.trim_prefix("--max-ticks="))
		elif arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	var passed := true
	for mate in mates:
		for id in stages:
			if mate not in game.CHARACTERS or id not in LEVELS:
				printerr("Invalid W4 route input: ", id, " / ", mate)
				passed = false
				continue
			if not run_pair(id, mate, max_ticks): passed = false
			if not output.is_empty():
				var file := FileAccess.open(output, FileAccess.WRITE)
				if file == null: passed = false; printerr("Cannot write result path: ", output)
				else: file.store_string(JSON.stringify(results, "\t"))
			await process_frame # Release queued UI; physics remains disabled.
	game.queue_free()
	await process_frame
	print("Holiday CPU input routes: %d/%d passed. Both-actor invulnerability only; natural catch-ups/downed frames recorded. Not normal-health/device acceptance." % [results.filter(func(row): return row.passed).size(), results.size()])
	quit(0 if passed else 1)

func run_pair(id: String, mate: String, max_ticks: int) -> bool:
	failures.clear()
	opening_done = false
	game._show_menu()
	game.character = "maya" if mate == "jp" else "jp"
	var leader: String = game.character
	game.save = {"schema": 1, "receipts": {}, "skills": [], "seen": {}}
	check(SaveStore.write_save(game.save) == OK, "fresh isolated save failed")
	check(game.configure_party("cpu", mate), "CPU mode rejected")
	check(game.load_level(id), "stage failed to load")
	check(game.party_session.active and game.party_session.runtime.actors.size() == 2, "stage lacks admitted party support; no fixture gate bypass")
	if not failures.is_empty(): printerr("Holiday CPU route blocked: ", id, " ", failures); return false
	var session = game.party_session
	var p1 = session.runtime.actors[0]
	var cpu = session.runtime.actors[1]
	check(cpu.cpu and p1.character != cpu.character and game.combat.participant_count == 2, "source distinct roster/scaling mismatch")
	check(p1.movement_skills.skills.is_empty() and cpu.movement_skills.skills.is_empty(), "unearned skill inherited")
	var captain_driver = CaptainDriver.new()
	captain_driver.trace = debug_run
	var imported := JSON.stringify(game.meta)
	var planned := 0
	for index in game.combat.waves.size():
		var source: Dictionary = game.level.waves[index]
		var sequence: Array = source.g + source.get("x2", [])
		check(game.combat.waves[index].group == sequence, "source party wave sequence differs")
		planned += sequence.size()
	var ticks := 0
	var catches := 0
	var down_frames := [0, 0]
	var down_events := [0, 0]
	var revive_events := [0, 0]
	var checkpoint_rescues := [0, 0]
	var clear_rescues := [0, 0]
	var falls := [0, 0]
	var water_rescues := [0, 0]
	var jumps := [0, 0]
	var dash_uses := [0, 0]
	var observed_shots := [0, 0]
	var previous_shots: Array = []
	var previous_cpu_events: Array = []
	var waves_seen: Array = []
	var gates_seen: Array = []
	var kinds_seen: Array = []
	var receipts_seen: Array = []
	var boss_states: Array = []
	var boss_phases: Array = []
	var boss_max := 0
	var boss_damage := 0
	var boss_previous_hp := 0
	var boss_started := false
	var end_started := -1
	var damage_events := [0, 0]
	var last_progress := 0
	var progress_key := ""
	for frame in max_ticks:
		ticks = frame + 1
		# Sole assist; keep active scalar consistent with next session capture.
		for actor in session.runtime.actors: actor.invincible = 999.0
		game.invincible = 999.0
		var controls: Dictionary = captain_driver.controls_for(game) if id == "4-6" else controls_for(game, frame)
		var before: Array = []
		for actor in session.runtime.actors:
			before.append({"p": actor.player, "down": actor.down, "grounded": actor.grounded, "hearts": actor.hearts, "dash": actor.movement_skills.dash_cooldown})
		var before_gate: bool = game.world_four.wipe_midpoint_done
		var before_check: bool = game.world_four.checkpoint_done
		game.step(DT, controls)
		check(absf(game.elapsed - ticks * DT) < 0.00001 and absf(game.world_four.level_time - ticks * DT) < 0.00001, "shared time did not advance exactly once")
		check(game.player == p1.player and not session.bridge.shared_phase, "P1 facade/bridge not restored")
		# A water hit can down the CPU before controls; the previous event array
		# then remains. Count each source event identity once, never stale frames.
		for event in session.ai.events:
			if event.kind == "catch_up" and not previous_cpu_events.any(func(old): return is_same(old, event)): catches += 1
		previous_cpu_events = session.ai.events.duplicate()
		var checkpoint_frame: bool = (not before_gate and game.world_four.wipe_midpoint_done) or (not before_check and game.world_four.checkpoint_done)
		for slot in [0, 1]:
			var actor = session.runtime.actors[slot]
			if actor.down: down_frames[slot] += 1
			if not before[slot].down and actor.down: down_events[slot] += 1
			if before[slot].down and not actor.down:
				if game.mode == "clear": clear_rescues[slot] += 1
				elif checkpoint_frame: checkpoint_rescues[slot] += 1
				else: revive_events[slot] += 1
			if before[slot].grounded and not actor.grounded and actor.velocity.y < 0: jumps[slot] += 1
			if actor.movement_skills.dash_cooldown > before[slot].dash + 0.1: dash_uses[slot] += 1
			if actor.hearts < before[slot].hearts: damage_events[slot] += before[slot].hearts - actor.hearts
			if not before[slot].down and not game.world_four.deck.is_empty() and before[slot].p.y > game.world_four.cfg.water + 20 and actor.player.y < before[slot].p.y - 10: water_rescues[slot] += 1
			elif before[slot].p.y > float(game.level.fall) - 80 and actor.player.y < before[slot].p.y - 100: falls[slot] += 1
		var shots: Array = game.bullets.filter(func(bullet): return not bullet.enemy)
		for projectile in shots:
			var slot: int = projectile.get("owner_slot", -1)
			if slot in [0, 1] and not previous_shots.any(func(old): return is_same(old, projectile)): observed_shots[slot] += 1
		previous_shots = shots
		for index in game.combat.waves.size():
			var wave: Dictionary = game.combat.waves[index]
			if wave.started and index not in waves_seen: waves_seen.append(index)
			if wave.done: check(wave.index == wave.group.size(), "source wave marked complete before all entries consumed")
		for index in game.world_four.gates.size():
			if game.world_four.gates[index].passed and index not in gates_seen: gates_seen.append(index)
		for index in game.receipts.size():
			if game.receipts[index].taken and index not in receipts_seen: receipts_seen.append(index)
		for foe in game.world_four.foes.entries:
			if foe.kind not in kinds_seen: kinds_seen.append(foe.kind)
			if foe.kind == "bailiff": check(foe.max == 46, "source party Bailiff HP mismatch")
		if id == "4-6" and game.boss != null:
			var boss: Dictionary = game.boss.state
			if not boss_started:
				boss_started = true
				boss_max = int(boss.max)
				boss_previous_hp = boss_max
			boss_damage += maxi(0, boss_previous_hp - int(boss.hp))
			boss_previous_hp = int(boss.hp)
			if boss.state not in boss_states: boss_states.append(boss.state)
			if boss.phase not in boss_phases: boss_phases.append(boss.phase)
			if boss.state == "throw" and boss.get("fired", false): captain_driver.saw_throw = true
			if boss.state == "charge": captain_driver.saw_charge = true
		if game.world_four.end_time > 0 and end_started < 0: end_started = frame
		var key := "%d:%d:%d:%d:%d" % [int(game.camera.x / 50), receipts_seen.size(), game.combat.waves.filter(func(w): return w.done).size(), p1.pop_count + cpu.pop_count, boss_damage]
		if key != progress_key: progress_key = key; last_progress = frame
		if debug_run and frame % 1800 == 0:
			print("Holiday CPU trace ", id, " ", leader, "+", mate, " frame=", frame, " actors=", [p1.player, cpu.player], " hearts=", [p1.hearts, cpu.hearts], " camera=", game.camera, " live=", game.enemies.filter(func(e): return e.state != "pop").map(func(e): return [e.kind,e.p,e.hp]), " foes=", game.world_four.foes.snapshot(), " driver=", captain_driver.route_step if id == "4-6" else opening_done)
		if game.mode != "play": break
		if frame - last_progress > 7200 and not (id == "4-3" and game.world_four.hold.on and not game.world_four.hold.over):
			check(false, "no camera/receipt/wave/pop/boss progress for 120 seconds")
			break
	var consumed := 0
	for wave in game.combat.waves: consumed += wave.index
	var source_sets: Array = game.level.cfg.get("sets", [])
	check(game.mode == "clear", "natural source clear not reached")
	check(game.combat.waves.all(func(w): return w.done) and consumed == planned, "not all source party waves/entries consumed")
	check(waves_seen.size() == game.combat.waves.size(), "not all source waves triggered")
	check(gates_seen.size() == game.world_four.gates.size(), "not all authored gates traversed")
	check(source_sets.all(func(sp): return game.world_four.set_done.has(sp.id)), "not all authored set pieces reached")
	check(game.receipts.all(func(receipt): return receipt.taken), "not all three physical receipts collected")
	check(JSON.stringify(game.meta) == imported, "imported source metadata was mutated")
	check(game.save.get("cleared", {}).get(id, false), "normal clear was not saved")
	# The source CPU cannot reliably hit low pedalo foes with its horizontal
	# standing shot. Record its actual pops; do not require an invented kill
	# quota that would force a non-source aim/duck repair to pass acceptance.
	check(observed_shots[1] > 0, "CPU never fired an actual owned projectile")
	if id == "4-4": check(p1.movement_skills.has_skill("dash") and cpu.movement_skills.has_skill("dash") and "dash" in game.save.skills, "physical Dash card not earned/shared/saved")
	if id == "4-S": check(game.world_four.dash.mult == 9 and game.world_four.dash.gates.all(func(g): return g.got), "not all eight bonus gates physically crossed")
	if id == "4-3": check(game.world_four.hold.over and game.world_four.hold.mini, "source hold/half-time Bailiff incomplete")
	if id == "4-6":
		check(boss_max == 120 and boss_phases == [1, 2, 3] and boss_damage >= 120, "120HP source Captain phases/damage incomplete")
		check(game.world_four.captain.jar.get("got", false), "physical Captain jar not picked up")
		check(int(cpu.scene_state.get("boss_hits", 0)) > 0, "CPU never landed a real Captain hit")
	else: check(end_started >= 0 and ticks - 1 - end_started >= 155, "source delayed ending skipped")
	var result := {"level": id, "leader": leader, "cpu": mate, "passed": failures.is_empty(), "ticks": ticks, "mode": game.mode,
		"waves": game.combat.waves.filter(func(w): return w.done).size(), "wave_count": game.combat.waves.size(), "entries": consumed, "planned": planned,
		"receipts": receipts_seen, "gates": gates_seen.size(), "sets": game.world_four.set_done.size(), "kinds": kinds_seen,
		"pops": [p1.pop_count, cpu.pop_count], "coins": [p1.coins, cpu.coins], "score": game.score,
		"observed_shots": observed_shots, "jumps": jumps, "dash_uses": dash_uses, "cpu_catchups": catches,
		"down_frames": down_frames, "down_events": down_events, "revivals": revive_events, "checkpoint_rescues": checkpoint_rescues, "clear_rescues": clear_rescues,
		"falls": falls, "water_rescues": water_rescues, "damage_events": damage_events, "hearts": [p1.hearts, cpu.hearts],
		"captain_max": boss_max, "captain_damage": boss_damage, "captain_states": boss_states, "captain_phases": boss_phases,
		"boss_hits": [int(p1.scene_state.get("boss_hits", 0)), int(cpu.scene_state.get("boss_hits", 0))],
		"positions": [str(p1.player), str(cpu.player)], "camera": str(game.camera), "failures": failures.duplicate(),
		"driver_step": captain_driver.route_step if id == "4-6" else -1,
		"raised_approach_frames": captain_driver.raised_approach_frames,
		"live_enemies": game.enemies.filter(func(enemy): return enemy.state != "pop").map(func(enemy): return {"kind": enemy.kind, "p": str(enemy.p), "hp": enemy.hp}),
		"live_foes": game.world_four.foes.snapshot() if not failures.is_empty() else []}
	results.append(result)
	print("Holiday CPU route: ", JSON.stringify(result))
	return failures.is_empty()
