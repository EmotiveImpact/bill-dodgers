extends SceneTree
## Input-only actual-main traversal. Repeated invulnerability is the sole live
## assist; no position/camera/geometry/wave/boss/kill/clear writes after load.
## Initial skill list represents the preceding four worlds' earned cards.
const SaveStore = preload("res://src/save_store.gd")
var checks := 0
const DT := 1.0 / 60
const MAX_TICKS := 42000
var failures: Array[String] = []
var goal: Dictionary = {}
var chars: Array = ["jp"]
var stages: Array = ["5-1", "5-2", "5-3", "5-4", "5-5", "5-6", "5-S"]
var trace := false
var collect_all := true
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--all-characters": chars = ["jp", "maya", "ama", "leo", "theo", "mei"]
		if arg.begins_with("--stage="): stages = [arg.trim_prefix("--stage=")]
		if arg.begins_with("--character="): chars = [arg.trim_prefix("--character=")]
		if arg == "--trace": trace = true
		if arg == "--skip-receipts": collect_all = false
	var game = load("res://main.tscn").instantiate(); root.add_child(game); game.set_physics_process(false)
	preload("res://tests/test_support.gd").silence(game)
	for who in chars:
		for id in stages: route(game, id, who)
	game.queue_free(); await process_frame
	print("Full Moving Day input routes: %d requested, %d checks, %d failures. Invulnerability assisted; not unaided/device proof." % [chars.size() * stages.size(), checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
func route(g, id: String, who: String) -> void:
	g.character = who; g.save = {"schema": 1, "receipts": {}, "skills": ["slide", "double-jump", "ground-pound", "dash"], "kitty": 0}
	g.load_level(id); goal = {}
	var original: String = JSON.stringify(g.meta)
	var last := Vector2.ZERO; var stuck := 0
	var seen := {"sofa_tip": false, "sofa_carry": false, "beams": false, "beam_active": false, "vehicle_in": false, "vehicle_hold": false, "vehicle_out": false, "king_phases": [], "king_max_hp": [], "king_armour": true, "king_helpers": false, "king_collapse": [], "king_rebuild": [], "king_down": false, "jar": false, "end_started": -1.0}
	var clock_exact := true
	var early_clear := false
	for tick in MAX_TICKS:
		if g.mode != "play": break
		g.invincible = 99 # Explicit test-only survivability assist.
		var c := controls(g, tick, stuck)
		g.step(DT, c)
		observe(g, seen)
		clock_exact = clock_exact and absf(g.elapsed - g.world_five.level_time) < 0.00001
		if id == "5-5" and g.world_five.level_time < float(g.level.timed) / 1000.0: early_clear = early_clear or g.mode == "clear"
		if g.player.distance_to(last) < 0.2: stuck += 1
		else: stuck = 0
		last = g.player
		if trace and tick % 1800 == 0: print("TRACE ", id, " ", who, " t=", tick / 60, " p=", g.player, " cam=", g.camera, " waves=", g.combat.waves.filter(func(w): return w.done).size(), " enemies=", g.enemies.size(), " boss=", g.boss.state if g.boss != null else {}, " sofa=", g.world_five.sofa.get("x", 0))
	var passed: bool = g.mode == "clear" and g.combat.waves.all(func(w): return w.done) and JSON.stringify(g.meta) == original
	print("ROUTE ", id, " ", who, " ", "PASS" if passed else "FAIL", " time=", snappedf(g.elapsed, 0.1), " p=", g.player, " camera=", g.camera, " waves=", g.combat.waves.filter(func(w): return w.done).size(), "/", g.combat.waves.size(), " pops=", g.pop_count, " boss=", str(g.boss.state.state) if g.boss != null else "none")
	if not passed: failures.append(id + " " + who)
	var label := id + " " + who
	if collect_all:
		check(g.receipts.all(func(r): return r.taken), label + " full-route three physical receipts")
		var saved_receipts: Array = SaveStore.read_save().receipts.get(id, []).duplicate(); saved_receipts.sort()
		check(saved_receipts == [0, 1, 2], label + " all three identities persist from full route")
	check(clock_exact, label + " host and world clocks agree on every frame")
	check(g.save.get("cleared", {}).get(id, false) and SaveStore.read_save().get("cleared", {}).get(id, false), label + " actual clear persisted")
	check(g.save.kitty == g.score and SaveStore.read_save().get("kitty", -1) == g.score and g.receipt_score == 0, label + " one clear banks exact run score, receipts award zero")
	var score_at_clear: int = g.score
	var kitty_at_clear: int = g.save.kitty
	for frame in 8: g.step(DT, {})
	check(g.score == score_at_clear and g.save.kitty == kitty_at_clear, label + " clear frames cannot pay twice")
	if id != "5-6": check(seen.end_started >= 0 and g.world_five.end_time > 2.6 and g.elapsed - seen.end_started >= 2.58, label + " normal 2.6 second end countdown")
	if id == "5-2":
		check(seen.sofa_carry and seen.sofa_tip, label + " physical carry and doorway tip observed")
		check(g.world_five.scene_index == 5 and g.world_five._scenes.all(func(s): return s.done) and g.world_five.sofa.x >= g.level.sofa.end, label + " five sofa scene transitions and lorry end reached")
		check(not g.world_five.checkpoint.is_empty(), label + " physical halfway checkpoint reached")
	if id == "5-3": check(g.player.y <= g.level.goalY + 4, label + " physically reached final lift floor")
	if id == "5-4": check(g.movement_skills.card_collected and SaveStore.read_save().skills.count("wall-jump") == 1, label + " full-route physical card pickup and persistence")
	if id == "5-5":
		check(not early_clear and g.elapsed >= 242.58 and g.camera.y == 0, label + " full 240 second van clock and end countdown")
		check(seen.beams and seen.beam_active and seen.vehicle_in and seen.vehicle_hold and seen.vehicle_out, label + " low bridges and all vehicle phases observed")
	if id == "5-S": check(g.world_five.clock_left == 0 or g.camera.x >= g.level.w - g.view_width() - 2, label + " source bonus end predicate")
	if id == "5-6":
		check(seen.king_phases == [0, 1, 2] and seen.king_max_hp == [26,32,38] and seen.king_collapse == [0, 1] and seen.king_rebuild == [0, 1], label + " all three authored King HP pools and both collapse/rebuild cycles")
		check(seen.king_armour and seen.king_helpers, label + " collapse/rebuild armour and helper spawns observed")
		check(seen.king_down and seen.jar and g.boss.state.jar.got and g.boss.state.jar.t > 0.6 and absf(g.player.x - g.boss.state.jar.x) < 50, label + " final defeat and physical timed jar pickup")
	print("OBSERVED ", label, " receipts=", g.receipts.map(func(r): return r.taken), " phases=", seen)
func controls(g, tick: int, stuck: int) -> Dictionary:
	var c := {"left": false, "right": false, "jump": false, "down": false, "shoot": true, "aim": false, "special": false}
	if g.world_five.wiping: return c
	if collect_all:
		var pickup := pickup_controls(g)
		if not pickup.is_empty(): return pickup
	var targets: Array = g.enemies.filter(func(b): return b.state != "pop" and not b.get("lost", false) and b.p.x > g.camera.x - 40 and b.p.x < g.camera.x + g.view_width() + 40 and absf(b.p.y - g.player.y) < 220)
	targets.sort_custom(func(a,b): return absf(a.p.x-g.player.x) < absf(b.p.x-g.player.x))
	var target: Dictionary = targets[0] if not targets.is_empty() else {}
	if g.boss != null:
		var b: Dictionary = g.boss.state
		if not b.jar.is_empty():
			c.left = g.player.x > b.jar.x + 8; c.right = g.player.x < b.jar.x - 8; return c
		if b.state not in ["collapse", "rebuild", "down", "enter"]: target = {"p": Vector2(b.x, 482), "big": true}
	if g.level_id == "5-5":
		var want := 280.0
		if not target.is_empty():
			var face := signf(target.p.x - g.player.x)
			if absf(g.player.x - want) > 20: c.left = g.player.x > want; c.right = g.player.x < want
			elif g.face != face: c.left = face < 0; c.right = face > 0
		else: c.left = g.player.x > want + 4; c.right = g.player.x < want - 4
		c.down = g.world_five.beams.any(func(b): return b.warn <= 0 and absf(b.x - g.player.x) < 140)
		return c
	if not target.is_empty():
		var dx: float = target.p.x - g.player.x
		var dy: float = target.p.y - g.player.y
		if absf(dy) < 70 or target.get("big", false):
			var advance: bool = absf(dx) > 240 or (stuck > 120 and absf(dx) > 65)
			if advance: c.left = dx < 0; c.right = dx > 0
			elif g.face != signf(dx): c.left = dx < 0; c.right = dx > 0
			if advance and (stuck > 8 or tick % 42 == 0): c.jump = not g.jump_held
			return c
	if g.level_id == "5-3":
		if g.grounded:
			var next: Dictionary = {}; var rank := INF
			for q in g.world_five.surfaces(g):
				if q.get("lift", false) or q.row[2] >= g.player.y - 5 or q.row[2] < g.player.y - 150: continue
				var x := clampf(g.player.x, q.row[0] + 35, q.row[1] - 35)
				var distance := absf(x - g.player.x)
				if distance <= 230 and distance < rank: next = {"x": x, "y": q.row[2]}; rank = distance
			if not next.is_empty(): goal = next
		if not goal.is_empty():
			c.left = g.player.x > goal.x + 8; c.right = g.player.x < goal.x - 8
			if g.grounded and absf(g.player.x - goal.x) < 110 and not g.jump_held: c.jump = true
		return c
	if not g.world_five.sofa.is_empty():
		var sofa: Dictionary = g.world_five.sofa
		if g.player.x > sofa.x + 115:
			c.left = true; return c
		if sofa.door != null and not sofa.tip and absf(g.player.x - sofa.x) < 160: c.down = true; return c
	c.right = true
	if g.grounded and not g.jump_held:
		var wall: float = g._wall_clamp(g.player.x, g.player.x + 58, g.player.y)
		if wall < g.player.x + 58 or stuck > 8: c.jump = true
	elif not g.grounded and tick % 16 == 0 and not g.jump_held: c.jump = true
	return c

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: " + label)
func observe(g, seen: Dictionary) -> void:
	if g.world_five.end_time > 0 and seen.end_started < 0: seen.end_started = g.elapsed
	if not g.world_five.sofa.is_empty():
		seen.sofa_tip = seen.sofa_tip or g.world_five.sofa.tip
		seen.sofa_carry = seen.sofa_carry or g.world_five.carrying
	seen.beams = seen.beams or not g.world_five.beams.is_empty()
	seen.beam_active = seen.beam_active or g.world_five.beams.any(func(b): return b.warn <= 0)
	for q in g.world_five.movers:
		if not q.off and q.get("state", "") in ["in", "hold", "out"]: seen["vehicle_" + q.state] = true
	if g.boss != null:
		var b: Dictionary = g.boss.state
		if b.phase not in seen.king_phases: seen.king_phases.append(b.phase); seen.king_max_hp.append(b.max)
		if b.state in ["collapse", "rebuild"]: seen.king_armour = seen.king_armour and b.armour
		if b.state == "collapse" and g.enemies.any(func(e): return e.state != "pop"): seen.king_helpers = true
		if b.state in ["collapse", "rebuild"] and b.phase not in seen["king_" + b.state]: seen["king_" + b.state].append(b.phase)
		seen.king_down = seen.king_down or b.state == "down"
		seen.jar = seen.jar or not b.jar.is_empty()

func pickup_controls(g) -> Dictionary:
	var remaining: Array = g.receipts.filter(func(r): return not r.taken)
	if remaining.is_empty(): return {}
	remaining.sort_custom(func(a, b): return a.position.y > b.position.y if g.level_id == "5-3" else a.position.x < b.position.x)
	var target: Vector2 = remaining[0].position
	if g.level_id == "5-3":
		if g.player.y > target.y + 85 or g.player.y < target.y - 120: return {}
	elif g.level_id != "5-5" and target.x - g.player.x > 240: return {}
	var direction := signf(target.x - g.player.x) if absf(target.x - g.player.x) > 5 else 0.0
	var wall: bool = direction != 0 and absf(g._wall_clamp(g.player.x, g.player.x + direction * 35, g.player.y) - (g.player.x + direction * 35)) > 0.5
	var jump: bool = not g.jump_held and ((g.grounded and (g.player.y - target.y > 40 or wall)) or (not g.grounded and g.velocity.y >= 0 and g.player.y > target.y + 70 and not g.movement_skills.double_jumped))
	return {"left": direction < 0, "right": direction > 0, "jump": jump, "shoot": true}
