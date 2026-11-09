extends SceneTree
## Real admitted W3 CPU sessions. Controls are ordinary gameplay inputs.
## The sole gameplay assist is 999s invulnerability refreshed for BOTH actors.
## No actor position, HP, enemy, wave, timer, native gate or completion writes.
const Drivers = preload("res://tests/festival_party_route_controls.gd")
const SaveStore = preload("res://src/save_store.gd")
const DT := 1.0 / 60.0
const LEVELS := ["3-1", "3-2", "3-3", "3-4", "3-5", "3-6", "3-S"]
var game
var failures: Array[String] = []
var trace := false
var trace_events := false

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok and label not in failures: failures.append(label)

func run() -> void:
	game = load("res://main.tscn").instantiate()
	if game.get_script() == null:
		printerr("Festival party route blocked: main scene script failed to load; no gameplay ran.")
		game.free()
		quit(1)
		return
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/test_support.gd").silence(game)
	var characters: Array = ["jp"]
	var levels: Array = LEVELS.duplicate()
	for arg in OS.get_cmdline_user_args():
		if arg == "--all-characters": characters = game.CHARACTERS.duplicate()
		if arg == "--trace": trace = true
		if arg == "--events": trace_events = true
		if arg.begins_with("--character="): characters = [arg.trim_prefix("--character=")]
		if arg.begins_with("--level="): levels = [arg.trim_prefix("--level=")]
	var passed := true
	for who in characters:
		if who not in game.CHARACTERS: passed = false; continue
		var mate: String = game.CHARACTERS[(game.CHARACTERS.find(who) + 1) % game.CHARACTERS.size()]
		for id in levels:
			if id not in LEVELS or not run_pair(id, who, mate): passed = false
			# Let queued UI/scene nodes release between complete routes. Physics
			# stays disabled; this does not advance or assist the simulation.
			await process_frame
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)

func run_pair(id: String, who: String, mate: String) -> bool:
	failures.clear()
	game._show_menu()
	game.character = who
	game.save = {"schema": 1, "receipts": {}, "skills": [], "seen": {}}
	check(SaveStore.write_save(game.save) == OK, "fresh isolated save write failed")
	check(game.configure_party("cpu", mate), "source CPU roster rejected")
	check(game.load_level(id), "native level load failed")
	var session = game.party_session
	check(session.active and session.runtime.actors.size() == 2, "stage lacks admitted party integration; no test gate bypass")
	if not failures.is_empty():
		printerr("Festival party [%s %s+CPU %s] BLOCKED %s" % [id, who, mate, failures])
		return false
	var lead = session.runtime.actors[0]
	var cpu = session.runtime.actors[1]
	check(cpu.cpu and lead.character != cpu.character and game.combat.participant_count == 2, "incorrect source party identity or scaling")
	check(lead.movement_skills.skills.is_empty() and cpu.movement_skills.skills.is_empty(), "unearned source skill fixture")
	var driver = Drivers.create(id)
	var source_meta := JSON.stringify(game.meta)
	var planned := 0
	for row in game.meta.l3.get("waves", []): planned += row[1].size()
	var initial_plan := 0
	for wave in game.combat.waves: initial_plan += wave.group.size()
	check(planned == initial_plan, "party wave flags/order omitted at fresh load")
	var ticks := 0
	var catchups := 0
	var cpu_jump_frames := 0
	var leader_jump_frames := 0
	var cpu_shot_frames := 0
	var leader_shot_frames := 0
	var cpu_down_frames := 0
	var cpu_revivals := 0
	var cpu_previous_down := false
	var boss_start_hp := 0
	var boss_damage := 0
	var boss_last_hp := 0
	var boss_seen := false
	var harvester_start_hp := 0.0
	var harvester_last_hp := 0.0
	var harvester_damage := 0.0
	var completed_wipe := false
	var moving_support := [false, false]
	var physical_coins := 0
	var sweep_coins := 0
	var imported_unchanged := true
	var maximum := 60000 if id == "3-4" else (5500 if id == "3-S" else 42000)
	for frame in range(maximum):
		ticks = frame + 1
		if id != "3-S":
			game.invincible = 999
			lead.invincible = 999
			cpu.invincible = 999
		if id == "3-6" and game.boss != null:
			var jar: Dictionary = game.boss.state.get("jar", {})
			driver.jar_goal = float(jar.x) if not jar.is_empty() else float(game.boss.state.x)
		var controls: Dictionary = driver.controls(game, frame)
		var before_coins: int = game.score
		var cpu_controls_ran: bool = cpu.is_alive()
		var before_scene: int = game.world_three.scene_index
		var before_position: Vector2 = lead.player
		var cpu_before: Dictionary = {}
		if trace_events:
			cpu_before = {"p": cpu.player, "velocity": cpu.velocity, "hearts": cpu.hearts, "down": cpu.down, "grounded": cpu.grounded, "safe": cpu.scene_state.get("safe_position", Vector2.ZERO), "tied": cpu.scene_state.get("tied", 0), "ai": cpu.ai.duplicate(true), "camera": game.camera}
		var before_bot_states: Array = []
		if id == "3-1" and not driver.stomp_confirmed:
			for enemy in game.enemies: before_bot_states.append([enemy, enemy.state, enemy.hp])
		game.step(DT, controls)
		if trace_events and (cpu.hearts != cpu_before.hearts or cpu.down != cpu_before.down):
			print("Party CPU event ", id, " ", who, "+", mate, " f=", frame, " before=", cpu_before, " after=", {"p": cpu.player, "velocity": cpu.velocity, "hearts": cpu.hearts, "down": cpu.down, "grounded": cpu.grounded, "invincible": cpu.invincible, "safe": cpu.scene_state.get("safe_position", Vector2.ZERO), "tied": cpu.scene_state.get("tied", 0), "ai": cpu.ai, "camera": game.camera, "status": game.status}, " leader=", lead.player)
		if cpu_controls_ran:
			for event in session.ai.events:
				if event.kind == "catch_up": catchups += 1
		if not lead.grounded: leader_jump_frames += 1
		if not cpu.grounded: cpu_jump_frames += 1
		if cpu.down: cpu_down_frames += 1
		if cpu_previous_down and not cpu.down and game.mode == "play": cpu_revivals += 1
		cpu_previous_down = cpu.down
		if game.bullets.any(func(b): return not b.enemy and int(b.get("owner_slot", -1)) == 0): leader_shot_frames += 1
		if game.bullets.any(func(b): return not b.enemy and int(b.get("owner_slot", -1)) == 1): cpu_shot_frames += 1
		for index in [0, 1]:
			var support: Dictionary = session.runtime.actors[index].scene_state.get("standing_surface", {})
			if session.runtime.actors[index].grounded and not support.is_empty() and (absf(float(support.get("dx", 0))) > 0 or absf(float(support.get("dy", 0))) > 0): moving_support[index] = true
		if game.mode != "clear": physical_coins += maxi(0, game.score - before_coins)
		if game.world_three.wipe_midpoint_done: completed_wipe = true
		check(absf(lead.player.x - before_position.x) < 30 or game.world_three.scene_index != before_scene, "leader relocated outside source movement/wipe; inspect fall separately")
		check(absf(game.elapsed - ticks * DT) < 0.00001 and absf(game.world_three.level_time - ticks * DT) < 0.00001, "shared clock advanced more than once per frame")
		if game.boss != null:
			var hp: int = game.boss.state.hp
			if not boss_seen:
				boss_seen = true
				boss_start_hp = game.boss.state.max
				boss_last_hp = boss_start_hp
				check(boss_start_hp == int(game.boss.state.cfg.hp2), "source party boss hp2 mismatch")
			boss_damage += maxi(0, boss_last_hp - hp)
			boss_last_hp = hp
		if id == "3-5":
			var harvester: Dictionary = game.world_three.hayride.harvester
			if not harvester.is_empty() and harvester.has("max"):
				if harvester_start_hp == 0:
					harvester_start_hp = float(harvester.max)
					harvester_last_hp = harvester_start_hp
					check(is_equal_approx(harvester_start_hp, float(game.meta.l3.harv.hp) * 1.3), "source 1.3x party harvester HP mismatch")
				harvester_damage += maxf(0, harvester_last_hp - float(harvester.hp))
				harvester_last_hp = float(harvester.hp)
		if id == "3-1" and not driver.stomp_confirmed:
			for state in before_bot_states:
				if state[1] != "pop" and state[0].state == "pop" and state[0].hp == state[2] and lead.velocity.y <= -799: driver.stomp_confirmed = true
		if id == "3-4" and "ground-pound-land" in lead.movement_skills.events: driver.pound_landed = true
		if trace and frame % 1200 == 0:
			print("Party trace ", id, " ", who, " f=", frame, " p1=", lead.player, " p2=", cpu.player, " camera=", game.camera, " route=", driver.get("route_step") if "route_step" in driver else "auto", " boss=", game.boss.state if game.boss != null else {}, " pops=", [lead.pop_count, cpu.pop_count])
		if game.mode != "play": break
	check(game.mode == "clear", "no natural clear: " + game.mode)
	var consumed := 0
	for wave in game.combat.waves: consumed += wave.index
	check(consumed == planned and game.combat.waves.all(func(w): return w.done), "not all authored party waves naturally dispatched/completed")
	check(game.receipts.all(func(r): return r.taken), "ordinary leader/CPU route missed source receipts")
	if id in ["3-1", "3-2", "3-3", "3-5"]: check(completed_wipe, "source scene midpoint never completed")
	if id in ["3-1", "3-3", "3-4", "3-6"]: check(boss_seen and boss_damage >= boss_start_hp, "source party boss not defeated through actual damage")
	if id == "3-4":
		check(lead.movement_skills.has_skill("ground-pound") and cpu.movement_skills.has_skill("ground-pound") and driver.pound_landed, "actual shared earned card/pound not demonstrated")
		check(moving_support[0], "leader never traversed moving trapezes")
	if id == "3-5":
		check(moving_support[0] and moving_support[1], "both actors never rode actual moving trailer")
		check(harvester_start_hp > 0 and harvester_damage >= harvester_start_hp, "harvester defeat route did not deal its actual party HP")
	if id != "3-S": check(leader_shot_frames > 0 and cpu_shot_frames > 0 and cpu.pop_count > 0, "both actor weapons/contributions not observed")
	imported_unchanged = JSON.stringify(game.meta) == source_meta
	check(imported_unchanged, "run mutated imported source metadata")
	check(lead.coins + cpu.coins == game.score, "shared kitty differs from attributed physical pickups and source clear sweep")
	sweep_coins = game.score - physical_coins
	var final_score: int = game.score
	var final_clock: float = game.elapsed
	for index in 30: game.step(DT, {})
	check(game.score == final_score and game.elapsed == final_clock, "postclear/game-over input repeated settlement or advanced clocks")
	var result := "PASS" if failures.is_empty() else "FAIL"
	print("Festival party [%s %s+CPU %s] %s ticks=%d waves=%d/%d p1=%s p2=%s mode=%s pops=%s coins=%s kitty=%d physical_before_clear=%d final_frame_plus_sweep=%d catches=%d air=%s shot_frames=%s cpu_down_frames=%d cpu_revives=%d boss_hp/damage=%s harvester_hp/damage=%s moving_support=%s receipts=%s failures=%s" % [id, who, mate, result, ticks, consumed, planned, lead.player, cpu.player, game.mode, [lead.pop_count,cpu.pop_count], [lead.coins,cpu.coins], game.score, physical_coins, sweep_coins, catchups, [leader_jump_frames,cpu_jump_frames], [leader_shot_frames,cpu_shot_frames], cpu_down_frames, cpu_revivals, [boss_start_hp,boss_damage], [harvester_start_hp,harvester_damage], moving_support, game.receipts.map(func(r): return r.taken), failures])
	return failures.is_empty()
