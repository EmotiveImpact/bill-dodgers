extends SceneTree
## Full routes driven by TWO independent synthetic engine-key pilots.
## Only repeated invulnerability is assisted. No CPU, seeded skills, teleports,
## enemy damage/kill writes, wave/objective edits, forced revives or clears.
const Keys = preload("res://tests/local_two_player_input.gd")
const Drivers = preload("res://tests/party_world_two_drivers.gd")
const Actor = preload("res://src/party_actor.gd")
const DT := 1.0 / 60.0
const STAGES := ["1-1", "2-1", "2-2"]

class HumanAisle extends Drivers.Aisle:
	## Source local-human pads hold2.6s, not solo/CPU5.2s. The legacy solo
	## pilot's0.35s reserve would demand2.86s at the first pad and never leave.
	## This changes only ordinary input decisions, not the production timer.
	func plate_gate(game, controls: Dictionary, id: int) -> bool:
		var hazards = game.world_two.hazard_controller
		var gate: Dictionary = hazards.gates.filter(func(g): return int(g.id) == id)[0]
		if game.player.x > gate.x + 70: return true
		var plate: Dictionary = hazards.plates.filter(func(p): return int(p.id) == id)[0]
		var time_to_cross := maxf(0, gate.x + 80 - game.player.x) / 270.0 + 0.04
		walk_toward(game, controls, gate.x + 95 if gate.timer > time_to_cross else plate.x)
		return false

class ReadView extends RefCounted:
	## Driver observation facade: reads actor-local values without binding,
	## capturing, moving or otherwise mutating production actor state.
	var host
	var actor
	func _init(h, a) -> void: host = h; actor = a
	func _get(property: StringName) -> Variant:
		return actor.get(property) if property in Actor.NATIVE_FIELDS else host.get(property)
	func character_height() -> float: return actor.character_height()
	func combat_owner_slot() -> int: return actor.slot

var game
var keys = Keys.new()
var results: Array = []
var failures: Array[String] = []
var trace := false
var legacy_aisle := false

func _initialize() -> void: call_deferred("run")
func fail(message: String) -> void:
	if message not in failures: failures.append(message)

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/test_support.gd").silence(game)
	var stages: Array = STAGES.duplicate()
	var max_ticks := 36000
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="): stages = [arg.trim_prefix("--level=")]
		elif arg.begins_with("--max-ticks="): max_ticks = int(arg.trim_prefix("--max-ticks="))
		elif arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		elif arg == "--trace": trace = true
		elif arg == "--legacy-aisle-pilot": legacy_aisle = true
	var passed := true
	for id in stages:
		if id not in STAGES: printerr("Invalid local-P2 stage: ", id); passed = false; continue
		if not route(id, max_ticks): passed = false
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file == null: printerr("Cannot write route report: ", output); passed = false
		else: file.store_string(JSON.stringify(results, "\t"))
	keys.release()
	game.queue_free()
	await process_frame
	print("Local P2 full key-event routes: ", "PASS" if passed else "FAIL", "; assisted synthetic input, NOT human or phone acceptance.")
	quit(0 if passed else 1)

func street_controls(actor, _frame: int) -> Dictionary:
	var controls := {"right": true, "shoot": true}
	var standoff := 220 if actor.slot == 0 else 170
	var target: Dictionary = {}
	for enemy in game.enemies:
		if enemy.state == "pop": continue
		if target.is_empty() or absf(enemy.p.x - actor.player.x) < absf(target.p.x - actor.player.x): target = enemy
	if not target.is_empty():
		var dx: float = target.p.x - actor.player.x
		controls.right = dx > standoff; controls.left = dx < -standoff
		if target.kind == "tiny": controls.down = true
		if target.kind == "fly":
			controls.aim = true; controls.right = dx > 30; controls.left = dx < -30
	if game.boss != null:
		var boss: Dictionary = game.boss.state
		if boss.state == "down" and not boss.jar.is_empty():
			controls.right = boss.jar.x > actor.player.x + 10; controls.left = boss.jar.x < actor.player.x - 10
		elif target.is_empty():
			var dx: float = boss.x - actor.player.x
			controls.right = dx > standoff; controls.left = dx < -standoff
	var facing_x: float = actor.player.x + 1
	if not target.is_empty(): facing_x = target.p.x
	elif game.boss != null: facing_x = game.boss.state.jar.x if game.boss.state.state == "down" and not game.boss.state.jar.is_empty() else game.boss.state.x
	if actor.face != (1 if facing_x >= actor.player.x else -1):
		controls.right = facing_x >= actor.player.x; controls.left = facing_x < actor.player.x
	if actor.abilities.meter >= 1: controls.special = true
	return controls

func route(id: String, max_ticks: int) -> bool:
	failures.clear()
	keys.release()
	keys.event_count = [0, 0]
	game._show_menu(); game.character = "jp"
	game.save = {"schema": 1, "receipts": {}, "skills": [], "seen": {}}
	if not game.configure_party("p2", "maya") or not game.load_level(id): fail("local two-player stage failed to load"); return false
	var session = game.party_session
	var actors: Array = session.runtime.actors
	var views := [ReadView.new(game, actors[0]), ReadView.new(game, actors[1])]
	var drivers: Array = [Drivers.Aisle.new(), Drivers.Aisle.new()] if id == "2-2" else [Drivers.Parking.new(), Drivers.Parking.new()]
	if id == "2-2" and not legacy_aisle: drivers = [HumanAisle.new(), HumanAisle.new()]
	var imported := JSON.stringify(game.meta)
	var expected_wave_enemies := 0
	for index in game.combat.waves.size():
		if id == "1-1":
			var count: int = game.level.waves[index][1].size() + 1
			expected_wave_enemies += count
			if game.combat.waves[index].group.size() != count: fail("source W1 pair extra enemy missing")
		else:
			var source: Dictionary = game.level.waves[index]
			var group: Array = source.g + source.get("x", [])
			expected_wave_enemies += group.size()
			if game.combat.waves[index].group != group: fail("source W2 pair wave group differs")
	var assist := {"invulnerability_every_frame": [0, 1], "seeded_skills": [], "actor_teleports": 0, "enemy_or_objective_mutations": 0, "forced_downs": 0, "forced_revives": 0, "forced_clear": 0, "audio": "silent adapter"}
	print("ASSISTS ", id, " ", JSON.stringify(assist))
	var shots := [0, 0]
	var jumps := [0, 0]
	var downs := [0, 0]
	var revives := [0, 0]
	var clear_rescues := [0, 0]
	var specials := [0, 0]
	var pad_frames := [0, 0]
	var pad_ids := [[], []]
	var seen_shots: Array = []
	var seen_enemies: Array = []
	var transitions: Array = []
	var prior_scene := 0
	var wipe_start := -1
	var distinct_controls := 0
	var tick := 0
	# Poll neutral state at zero delta to rearm every action without advancing time.
	keys.frame(game, {}, {}, 0)
	for frame in max_ticks:
		tick = frame + 1
		# Sole gameplay-state assist. Main captures P1 facade on the next frame.
		for actor in actors: actor.invincible = 999.0
		game.invincible = 999.0
		var intents: Array = []
		var was_down: Array = []
		var was_grounded: Array = []
		var was_active: Array = []
		var before_positions: Array = []
		for slot in 2:
			intents.append(street_controls(actors[slot], frame) if id == "1-1" else drivers[slot].controls_for(views[slot], frame, wipe_start))
			was_down.append(actors[slot].down); was_grounded.append(actors[slot].grounded); was_active.append(actors[slot].abilities.active)
			before_positions.append(str(actors[slot].player))
		if JSON.stringify(intents[0]) != JSON.stringify(intents[1]): distinct_controls += 1
		keys.frame(game, intents[0], intents[1])
		if absf(game.elapsed - tick * DT) > 0.00001: fail("shared clock did not advance exactly once")
		if game.player != actors[0].player or session.bridge.shared_phase: fail("P1 facade or shared pass not restored")
		if actors.any(func(actor): return actor.cpu) or not session.ai.events.is_empty(): fail("local route invoked CPU or catch-up")
		for slot in 2:
			if was_grounded[slot] and not actors[slot].grounded and actors[slot].velocity.y < 0: jumps[slot] += 1
			if not was_down[slot] and actors[slot].down: downs[slot] += 1
			if was_down[slot] and not actors[slot].down:
				if game.mode == "clear": clear_rescues[slot] += 1
				else: revives[slot] += 1
			if was_active[slot].is_empty() and not actors[slot].abilities.active.is_empty(): specials[slot] += 1
		for shot in game.bullets:
			if shot.enemy or int(shot.get("owner_slot", -1)) not in [0, 1]: continue
			if not seen_shots.any(func(old): return is_same(old, shot)):
				seen_shots.append(shot); shots[int(shot.owner_slot)] += 1
		for enemy in game.enemies:
			if not seen_enemies.any(func(old): return is_same(old, enemy)): seen_enemies.append(enemy)
		if id.begins_with("2-"):
			if game.world_two.wiping and wipe_start < 0: wipe_start = frame
			if game.world_two.scene_index != prior_scene:
				transitions.append({"tick": tick, "scene": game.world_two.scene_index, "before": before_positions, "after": actors.map(func(actor): return str(actor.player))})
				prior_scene = game.world_two.scene_index
			for slot in 2:
				if id == "2-2":
					for index in game.level.islands.size():
						var shelf: Array = game.level.islands[index]
						if actors[slot].grounded and absf(actors[slot].player.y - 246) < 0.1 and actors[slot].player.x >= shelf[0] + 6 and actors[slot].player.x <= shelf[1] - 6 and index not in drivers[slot].seen_shelves: drivers[slot].seen_shelves.append(index)
				for pad in game.world_two.hazard_controller.plates:
					if pad.on and actors[slot].is_alive() and actors[slot].grounded and absf(actors[slot].player.x - pad.x) < 46 and absf(actors[slot].player.y - pad.y) < 6:
						pad_frames[slot] += 1
						if pad.id not in pad_ids[slot]: pad_ids[slot].append(pad.id)
		if trace and frame % 1800 == 0: print("TRACE ", id, " tick=", tick, " actors=", actors.map(func(actor): return str(actor.player)), " camera=", game.camera, " waves=", game.combat.waves.filter(func(w): return w.done).size(), " live=", game.enemies.filter(func(e): return e.state != "pop").map(func(e): return [e.kind, str(e.p), e.hp]))
		if game.mode != "play": break
	if game.mode != "clear" or not game.save.get("cleared", {}).get(id, false): fail("bounded input pilot did not achieve real saved clear")
	if not game.combat.waves.all(func(w): return w.done and w.index == w.group.size()): fail("source pair waves not all consumed and defeated")
	if seen_enemies.size() < expected_wave_enemies or (id != "1-1" and seen_enemies.size() != expected_wave_enemies) or seen_enemies.any(func(enemy): return enemy.state != "pop"): fail("source enemies missing or not actually defeated")
	if shots.has(0) or actors.any(func(actor): return actor.pop_count == 0): fail("both human slots must fire and earn actual kills")
	if distinct_controls == 0: fail("pilots never produced independent controls")
	if id == "1-1" and (game.boss == null or game.boss.state.max != 90 or not game.boss.state.jar.get("got", false)): fail("party90HP boss and real jar clear not observed")
	if id.begins_with("2-") and (not game.receipts.all(func(r): return r.taken) or transitions.size() != game.level.scenes.size()): fail("source receipts or shared scene transitions incomplete")
	if JSON.stringify(game.meta) != imported: fail("source metadata mutated")
	var result := {"level": id, "pair": ["jp", "maya"], "mode": "p2", "passed": failures.is_empty(), "ticks": tick, "final_mode": game.mode, "assists": assist, "synthetic_key_events": keys.event_count.duplicate(), "distinct_input_frames": distinct_controls, "shots": shots, "jumps": jumps, "specials": specials, "pops": actors.map(func(actor): return actor.pop_count), "coins": actors.map(func(actor): return actor.coins), "downs": downs, "revives_or_checkpoint_rescues": revives, "clear_rescues": clear_rescues, "cpu_catchups": 0, "waves_done": game.combat.waves.filter(func(w): return w.done).size(), "waves_total": game.combat.waves.size(), "receipts": game.receipts.filter(func(r): return r.taken).size(), "scene_transitions": transitions, "pad_frames": pad_frames, "pad_ids": pad_ids, "enemies_seen": seen_enemies.size(), "undefeated_seen": seen_enemies.filter(func(e): return e.state != "pop").size(), "positions": actors.map(func(actor): return str(actor.player)), "camera": str(game.camera), "failures": failures.duplicate()}
	results.append(result)
	result["expected_wave_enemies"] = expected_wave_enemies
	result["pilot"] = "legacy-solo-pad-reserve" if id == "2-2" and legacy_aisle else "independent-human-key-pilots"
	print("LOCAL_P2_ROUTE ", JSON.stringify(result))
	keys.release()
	return failures.is_empty()
