extends SceneTree
## Actual source party routes. Only repeated invulnerability is assisted, for
## both actors. Source falls can still damage/down them. Native CPU is unchanged;
## catch-up relocations, down frames and clear-only revivals are reported openly.
const Main = preload("res://src/main.gd")
const AI = preload("res://src/companion_ai.gd")
const Driver = preload("res://tests/moving_day_party_route_controls.gd")
const SaveStore = preload("res://src/save_store.gd")
const DT := 1.0 / 60
const LEVELS := ["5-1", "5-2", "5-3", "5-4", "5-5", "5-6", "5-S"]
class ObservedAI extends AI:
	var catchups := 0
	var decisions := 0
	func controls(dt, actor, context):
		var result: Dictionary = super.controls(dt, actor, context)
		decisions += 1
		for event in events:
			if event.has("from"): catchups += 1
		return result
class ObservedMain extends Main:
	var falls := [0, 0]
	var clear_down_counts := [0, 0]
	func _complete_level():
		# Observe dirty records before normal settlement revives them, including
		# an actor downed earlier within this very same final source frame.
		if mode == "play" and party_session.active:
			for p in combat_participants():
				if p.get("down", false) or int(p.hearts) <= 0: clear_down_counts[int(p.slot)] += 1
		super._complete_level()
	func _fall_off():
		if party_session.active: falls[combat_owner_slot()] += 1
		super._fall_off()
var game
var results: Array = []
var failures: Array[String] = []
var trace := false
func _initialize() -> void: call_deferred("run")
func fail(reason: String) -> void:
	if reason not in failures: failures.append(reason)
func run() -> void:
	var stages: Array = LEVELS.duplicate()
	var modes: Array = ["cpu"]
	var mates: Array = ["maya"]
	var excluded: Array = []
	var max_ticks := 42000
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg == "--all-cpu": mates = ["jp", "maya", "ama", "leo", "theo", "mei"]
		elif arg == "--both-modes": modes = ["cpu", "p2"]
		elif arg == "--trace": trace = true
		elif arg.begins_with("--mode="): modes = [arg.trim_prefix("--mode=")]
		elif arg.begins_with("--mate="): mates = [arg.trim_prefix("--mate=")]
		elif arg.begins_with("--skip-mate="): excluded.append(arg.trim_prefix("--skip-mate="))
		elif arg.begins_with("--stage="): stages = [arg.trim_prefix("--stage=")]
		elif arg.begins_with("--max-ticks="): max_ticks = int(arg.trim_prefix("--max-ticks="))
		elif arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	mates = mates.filter(func(mate): return mate not in excluded)
	game = ObservedMain.new()
	game.party_session.ai = ObservedAI.new()
	root.add_child(game); game.set_physics_process(false)
	preload("res://tests/test_support.gd").silence(game)
	var success := true
	for selected_mode in modes:
		for mate in mates:
			for id in stages:
				if id not in LEVELS or mate not in game.CHARACTERS or selected_mode not in ["cpu", "p2"]:
					printerr("Invalid route selection"); success = false; continue
				if not route(id, selected_mode, mate, max_ticks): success = false
				if not output.is_empty():
					var file = FileAccess.open(output, FileAccess.WRITE)
					if file == null: printerr("Cannot write result: ", output); success = false
					else: file.store_string(JSON.stringify(results, "\t"))
	game.queue_free(); await process_frame
	print("Moving Day full party input routes: %d attempts, %s. Both-actor invulnerability; source catch-up/down/clear-revive reported; not device/difficulty certification." % [results.size(), "PASS" if success else "FAIL"])
	quit(0 if success else 1)
func route(id: String, selected_mode: String, mate_name: String, max_ticks: int) -> bool:
	failures.clear()
	game._show_menu()
	game.character = "maya" if mate_name == "jp" else "jp"
	var leader: String = game.character
	game.save = {"schema": 1, "receipts": {}, "skills": ["slide", "double-jump", "ground-pound", "dash"], "kitty": 0, "seen": {}}
	if SaveStore.write_save(game.save) != OK: fail("fresh isolated save failed")
	if not game.configure_party(selected_mode, mate_name) or not game.load_level(id) or not game.party_session.active:
		fail("party did not load"); printerr(id, " party did not load"); return false
	var session = game.party_session
	var p1 = session.runtime.actors[0]
	var p2 = session.runtime.actors[1]
	var drivers := [Driver.new(), Driver.new()]
	game.falls = [0, 0]; game.clear_down_counts = [0, 0]; session.ai.catchups = 0; session.ai.decisions = 0
	var original: String = JSON.stringify(game.meta)
	var expected_entries := 0
	for i in game.level.waves.size():
		var source: Dictionary = game.level.waves[i]
		var expected: Array = source.g.duplicate(true)
		if source.get("extra", true): expected.append([expected[-1][0] + 600, "l" if expected.size() % 2 else "r", "rush"])
		expected_entries += expected.size()
		if game.combat.waves[i].group != expected: fail("pair authored wave mismatch")
	var seen := {"sofa_tip": false, "sofa_carry": false, "beams": false, "beam_active": false, "vehicle_in": false, "vehicle_hold": false, "vehicle_out": false, "king_phases": [], "king_max_hp": [], "king_armour": true, "king_helpers": false, "king_collapse": [], "king_rebuild": [], "king_down": false, "jar": false, "end_started": -1.0}
	var last := [p1.player, p2.player]
	var stuck := [0, 0]
	var shots := [0, 0]
	var jumps := [0, 0]
	var down_frames := [0, 0]
	var revives := [0, 0]
	var carry_frames := [0, 0]
	var seen_shots: Array = []
	var tick := 0
	for frame in max_ticks:
		if game.mode != "play": break
		tick = frame + 1
		for actor in session.runtime.actors: actor.invincible = 999.0
		game.invincible = 999.0
		var first: Dictionary = drivers[0].controls(game, frame, stuck[0])
		var second: Dictionary = {}
		if selected_mode == "p2":
			session.bind(game, 1)
			second = drivers[1].controls(game, frame, stuck[1])
			session.bind(game, 0)
		var was_down := [p1.down, p2.down]
		var grounded_before := [p1.grounded, p2.grounded]
		session.step(game, DT, first, second)
		drivers[0].observe(game, seen)
		if absf(game.elapsed - tick * DT) > 0.00001 or absf(game.elapsed - game.world_five.level_time) > 0.00001: fail("shared clock advanced more or less than once")
		if game.player != p1.player or session.bridge.shared_phase: fail("final facade or shared bridge not restored")
		for i in 2:
			var actor = session.runtime.actors[i]
			if actor.down: down_frames[i] += 1
			if was_down[i] and not actor.down and game.mode != "clear": revives[i] += 1
			if grounded_before[i] and not actor.grounded and actor.velocity.y < 0: jumps[i] += 1
			if actor.scene_state.get("carrying", false): carry_frames[i] += 1
			stuck[i] = stuck[i] + 1 if actor.player.distance_to(last[i]) < 0.2 else 0
			last[i] = actor.player
		# Once a friendly shot leaves the live list it never reappears. Compare
		# only last frame's live identities, avoiding quadratic telemetry and
		# retaining thousands of expired projectiles during full matrices.
		var live_shots: Array = []
		for bullet in game.bullets:
			var owner: int = int(bullet.get("owner_slot", -1))
			if not bullet.enemy and owner in [0, 1]:
				if not seen_shots.any(func(old): return is_same(old, bullet)): shots[owner] += 1
				live_shots.append(bullet)
		seen_shots = live_shots
		if trace and frame % 1800 == 0: print("W5 TRACE ", id, " ", selected_mode, " ", leader, "+", mate_name, " frame=", frame, " p1=", p1.player, " p2=", p2.player, " down=", p2.down, " cam=", game.camera, " waves=", game.combat.waves.filter(func(w): return w.done).size(), " live=", game.enemies.filter(func(e): return e.state != "pop").size(), " scene=", game.world_five.scene_index, " sofa=", game.world_five.sofa.get("x", 0))
	if game.mode != "clear": fail("bounded normal-input party route did not clear")
	if not game.combat.waves.all(func(w): return w.done and w.index == w.group.size()): fail("not all source pair wave entries completed")
	if not game.receipts.all(func(r): return r.taken): fail("not all three physical receipts collected")
	if JSON.stringify(game.meta) != original: fail("source metadata changed")
	var saved := SaveStore.read_save()
	if not game.save.get("cleared", {}).get(id, false) or not saved.get("cleared", {}).get(id, false): fail("normal clear did not persist")
	if saved.get("receipts", {}).get(id, []).size() != 3: fail("receipt identities not persisted")
	if game.save.kitty != game.score or saved.get("kitty", -1) != game.score or game.receipt_score != 0: fail("shared kitty save or zero receipt reward mismatch")
	if shots[1] == 0: fail("mate never fired actual visible projectile")
	if id == "5-2" and (not seen.sofa_tip or game.world_five.scene_index != 5 or game.world_five.sofa.x < game.level.sofa.end): fail("sofa tip or five physical scene gates missing")
	if id == "5-3" and not session.runtime.actors.any(func(a): return a.player.y <= game.level.goalY + 4): fail("no actor reached highest lift floor")
	if id == "5-4" and (not p1.movement_skills.skills.has("wall-jump") or not p2.movement_skills.skills.has("wall-jump") or saved.skills.count("wall-jump") != 1): fail("physical skill card was not shared and saved")
	if id == "5-5" and (game.elapsed < 242.58 or not seen.beam_active or not seen.vehicle_in or not seen.vehicle_hold or not seen.vehicle_out): fail("van clock or beam/vehicle phases incomplete")
	if id == "5-6" and (seen.king_phases != [0, 1, 2] or seen.king_max_hp != [34, 42, 49] or seen.king_collapse != [0, 1] or seen.king_rebuild != [0, 1] or not seen.king_helpers or not seen.jar or not game.boss.state.jar.got): fail("scaled King phases/helpers/physical jar incomplete")
	var result := {"level": id, "mode": selected_mode, "leader": leader, "mate": mate_name, "passed": failures.is_empty(), "ticks": tick, "end_mode": game.mode, "waves": game.combat.waves.filter(func(w): return w.done).size(), "wave_count": game.combat.waves.size(), "wave_entries": expected_entries, "receipts": game.receipts.filter(func(r): return r.taken).size(), "score": game.score,
		"shots_observed": shots, "pops": [p1.pop_count, p2.pop_count], "coins": [p1.coins, p2.coins], "boss_hits": [p1.scene_state.get("boss_hits", 0), p2.scene_state.get("boss_hits", 0)], "jumps": jumps, "falls": game.falls.duplicate(), "down_frames": down_frames, "revives": revives, "clear_revives": game.clear_down_counts.duplicate(), "cpu_catchups": session.ai.catchups, "cpu_decisions": session.ai.decisions, "carry_frames": carry_frames, "scene_count": game.world_five.scene_index, "king_hp": seen.king_max_hp, "p1": str(p1.player), "p2": str(p2.player), "failures": failures.duplicate()}
	results.append(result)
	print("W5 PARTY ROUTE ", JSON.stringify(result))
	return failures.is_empty()
