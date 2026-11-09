extends RefCounted
## World 2 shared geometry, live hazards, source scene policies and objectives.
## Absolute feet/pixels, velocity in pixels/second, clocks in seconds.
## All content is copied on reset; imported META is never runtime state.
const SharedHazards = preload("res://src/supermarket_hazards.gd")
const Course = preload("res://src/supermarket_course.gd")
const CheckoutBoss = preload("res://src/checkout_boss.gd")
const SUPPORTED_LEVELS := ["2-1", "2-2", "2-3", "2-4", "2-5", "2-6", "2-S"]
const SCENE_POLICIES := {"2-3": {"view": 120.0, "land": 0.0, "camera": 200.0, "landing_y": 476.0}}
const WIPE_CALLBACK := 1.43
const WIPE_OPEN_START := 1.57
const WIPE_DURATION := 2.17
const TIME_EPSILON := 0.000000001 # Avoid seconds-conversion drift at inclusive ms edges.

var hazard_controller = SharedHazards.new()
var course_controller = Course.new()
var checkout = null
var level_id := ""
var run_generation := 0
var scene_policy: Dictionary = {}
var scene_index := 0
var wiping := false # Full visual lifetime; source LVS.wiping ends at midpoint.
var wipe_elapsed := 0.0
var wipe_midpoint_done := false
var wipe_kind := ""
var wipe_label := ""
var wipe_focus_start := Vector2.ZERO
var wipe_focus_end := Vector2.ZERO
var checkpoint_hit := false
var entities: Array = []
var elapsed := 0.0
var end_time := 0.0
var clear_reported := false
var safe_position := Vector2.ZERO
var coins_done: Dictionary = {}
var hinted: Dictionary = {}
var hazards: Array = [] # Lossless copied schemas, including unimplemented kinds.
var unsupported_hazards: Array = []
var rng := RandomNumberGenerator.new()
var _surfaces: Array = []
var _scenes: Array = []
var _wipe_scene: Array = []
var _wipe_generation := -1
var _wipe_open_captured := false
var _wipe_callback_due := false
var _host_id := 0
var _active := false

func supports(id: String) -> bool:
	return id in SUPPORTED_LEVELS

func reset(host, seed_value: int = 21) -> void:
	invalidate_run()
	level_id = host.level_id
	scene_policy = SCENE_POLICIES.get(level_id, {}).duplicate(true)
	_host_id = host.get_instance_id()
	_active = supports(level_id)
	rng.seed = seed_value
	scene_index = 0
	wipe_elapsed = 0.0
	wipe_midpoint_done = false
	wipe_kind = ""
	wipe_label = ""
	wipe_focus_start = Vector2.ZERO
	wipe_focus_end = Vector2.ZERO
	checkpoint_hit = false
	elapsed = 0.0
	end_time = 0.0
	clear_reported = false
	safe_position = host.player
	entities.clear()
	coins_done.clear()
	hinted.clear()
	_surfaces.clear()
	hazards = host.level.get("hz", []).duplicate(true)
	_scenes = host.level.get("scenes", []).duplicate(true)
	unsupported_hazards.clear()
	for row in host.level.get("solids", []):
		_surfaces.append({"row": row.duplicate(true), "plat": false})
	for row in host.level.get("plats", []):
		_surfaces.append({"row": row.duplicate(true), "plat": true})
	for hazard in hazards:
		if not hazard is Array or hazard.is_empty():
			unsupported_hazards.append(hazard)
			continue
		if hazard[0] not in ["coins", "trolleys"] and hazard[0] not in SharedHazards.KINDS and hazard[0] not in Course.KINDS:
			unsupported_hazards.append(hazard)
		elif hazard[0] == "trolleys" and _active:
			entities.append({"k": "tspawn", "at": float(hazard[1]), "n": int(hazard[2]), "gap": float(hazard[3]) / 1000.0, "dir": float(hazard[4]) if hazard.size() > 4 and hazard[4] else -1.0, "t": 0.0, "done": 0, "on": false})

	hazard_controller.reset(host, self)
	course_controller.reset(host, self)
	checkout = CheckoutBoss.new() if level_id == "2-6" else null
	if checkout != null: checkout.reset(host, self)

func party_start(host) -> void:
	# Main resets world geometry before constructing the fresh party. Replace
	# the temporary scalar checkout identity after bridge.configure, without
	# resetting shared scenery, clocks, RNG or authored entities a second time.
	if not _active or host.get_instance_id() != _host_id or host.level_id != level_id or _party_participants(host).is_empty(): return
	if checkout != null: checkout.reset(host, self)

func invalidate_run() -> void:
	# No wall-clock SceneTreeTimer survives pause, leaving a run, or restart.
	# The token is still checked at the callback boundary for stale callers.
	run_generation += 1
	_active = false
	wiping = false
	_wipe_generation = -1
	_wipe_scene.clear()
	_wipe_open_captured = false
	_wipe_callback_due = false

func _can_step(host) -> bool:
	return _active and host.get_instance_id() == _host_id and host.level_id == level_id and host.mode == "play"

func surfaces(_host, skip_platforms: bool = false) -> Array:
	return _surfaces.filter(func(surface): return not surface.plat) if skip_platforms else _surfaces

func land_on(host, x: float, old_y: float, new_y: float, skip: bool = false) -> Dictionary:
	var best: Dictionary = {}
	for surface in surfaces(host, skip):
		var row: Array = surface.row
		if x >= float(row[0]) and x <= float(row[1]) and float(row[2]) >= old_y - 1 and float(row[2]) <= new_y + 0.5:
			if best.is_empty() or float(row[2]) < float(best.row[2]): best = surface
	return best

func below(host, x: float, y: float) -> Dictionary:
	var best: Dictionary = {}
	for surface in surfaces(host):
		var row: Array = surface.row
		if x >= float(row[0]) and x <= float(row[1]) and float(row[2]) >= y - 2:
			if best.is_empty() or float(row[2]) < float(best.row[2]): best = surface
	return best

func wall_clamp(host, from_x: float, to_x: float, feet: float) -> float:
	for surface in surfaces(host, true):
		var row: Array = surface.row
		if float(row[2]) >= feet - 6: continue
		if to_x > from_x and from_x <= float(row[0]) and to_x > float(row[0]) - 14:
			to_x = minf(to_x, float(row[0]) - 14)
		if to_x < from_x and from_x >= float(row[1]) and to_x < float(row[1]) + 14:
			to_x = maxf(to_x, float(row[1]) + 14)
	return to_x

func inside_wall(host, point: Vector2) -> bool:
	for surface in surfaces(host, true):
		var row: Array = surface.row
		if point.x > float(row[0]) and point.x < float(row[1]) and point.y > float(row[2]) + 4: return true
	return false

func after_motion(host) -> void:
	if not _can_step(host) or not host.grounded or host.on_platform: return
	var surface := below(host, host.player.x, host.player.y)
	if surface.is_empty() or surface.plat: return
	var row: Array = surface.row
	if host.player.x > float(row[0]) + 90 and host.player.x < float(row[1]) - 90: safe_position = host.player

func recover_from_fall(host) -> void:
	if not _can_step(host): return
	var x := clampf(safe_position.x, host.camera.x + 70, host.camera.x + host.view_width() - 70)
	var surface: Dictionary = {}
	for i in range(60):
		var test_x := x + i * 20
		var candidate := below(host, test_x, host.view_top() - 200)
		if candidate.is_empty(): continue
		var row: Array = candidate.row
		if test_x > float(row[0]) + 30 and test_x < float(row[1]) - 30 and test_x < host.camera.x + host.view_width() - 40:
			surface = candidate
			x = test_x
			break
	if surface.is_empty(): surface = below(host, x, -9999)
	if surface.is_empty():
		if _surfaces.is_empty(): return
		surface = _surfaces[0]
	host.player = Vector2(x, float(surface.row[2]))
	host.velocity.y = 0
	host.grounded = true
	host.on_platform = surface.plat
	host.invincible = 0
	host.hurt_player(x - host.face)
	host.velocity.x = 0
	host.status = "Mind the gap!"

func base_displacement(dt: float, host, move: float) -> float:
	return hazard_controller.base_displacement(dt, host, move) if _can_step(host) else 0.0

func auto_displacement(dt: float, host) -> float:
	return course_controller.auto_displacement(dt, host) if _can_step(host) else 0.0

func camera_cap(host) -> float:
	if not _active or host.level_id != level_id: return INF
	var cap: float = float(_scenes[scene_index][0]) + float(scene_policy.get("view", 300.0)) - host.view_width() if scene_index < _scenes.size() else INF
	return minf(cap, checkout.camera_cap()) if checkout != null else cap

func _checkout_events(host) -> void:
	if checkout == null: return
	for event in checkout.drain_events():
		if host.has_method("checkout_event"): host.checkout_event(event)

func objective_tick(dt: float, host) -> String:
	# Call after waves but BEFORE bots, shots and late world updates. Source
	# checks state, not hearts: all-down resolution occurs at the frame end.
	if not _can_step(host) or clear_reported: return ""
	if checkout != null:
		if host.camera.x >= float(host.level.w) - host.view_width() - 2 and host.combat.waves.all(func(wave): return wave.done): checkout.ready_end(host)
		_checkout_events(host)
		return "" # The checkout can only clear through its actual jar.
	var event := ""
	if end_time == 0 and host.camera.x >= float(host.level.w) - host.view_width() - 2 and host.combat.waves.all(func(wave): return wave.done):
		end_time = 0.001
		event = "ending"
	if end_time > 0:
		end_time += dt
		if end_time > 2.6:
			clear_reported = true
			return "clear"
	return event

func intercept_shot(host, bullet: Dictionary) -> bool:
	# Buttons intercept after ordinary bots and before crates/walls.
	if hazard_controller.intercept_shot(host, bullet): return true
	return checkout.intercept_shot(host, bullet) if checkout != null else false

func after_pickups(dt: float, host) -> void:
	if not _can_step(host): return
	elapsed += dt
	var advance_existing_wipe := wiping
	_scene_update(host)
	_repair_embedded_bots(host)
	_checkpoint(host)
	_authored_coins(host)
	hazard_controller.gates_tick(dt, host, self)
	_trolleys(dt, host)
	hazard_controller.drops_tick(dt, host, self)
	course_controller.hazards_tick(dt, host, self)
	host.combat.late_carts(dt, host)
	host.combat.late_drones(dt, host)
	var roster := _party_participants(host)
	if roster.is_empty(): host.collect_level_pickups()
	else:
		for participant in _living(roster):
			host.call_combat_participant(participant, Callable(host, "collect_level_pickups"), [])
	entities = entities.filter(func(entity): return not entity.get("dead", false))
	if checkout != null:
		var outcome: String = checkout.late_tick(dt, host, self)
		_checkout_events(host)
		if outcome == "jar_collected":
			clear_reported = true
			host._complete_level()
	# BD.drawWipe invokes go after the update. Queue its simulation-time
	# callback here; host.finish_frame follows late ability/ghost effects.
	if advance_existing_wipe: _advance_wipe(dt, host)

func _scene_update(host) -> void:
	if scene_index >= _scenes.size(): return
	var scene: Array = _scenes[scene_index]
	var roster := _party_participants(host)
	var front: float = host.player.x
	if roster.is_empty():
		host.player.x = minf(host.player.x, float(scene[0]))
		front = host.player.x
		if wiping or host.hearts <= 0: return
	else:
		# Source clamps every actor, including downed players and their optional
		# previous-x field. Only a living actor can then trigger the transition.
		for participant in roster:
			if participant.p.x > float(scene[0]):
				participant.p.x = float(scene[0])
				if participant.has("px"): participant.px = minf(float(participant.px), float(scene[0]))
		var living := _living(roster)
		if wiping or living.is_empty(): return
		front = float(living[0].p.x)
		for participant in living: front = maxf(front, float(participant.p.x))
	if host.combat.waves.any(func(wave): return wave.started and not wave.done): return
	var cap := camera_cap(host)
	if host.combat.waves.any(func(wave): return not wave.done and float(wave.at) <= cap): return
	if front < float(scene[0]) - 50:
		var hint_key := "scene_%d" % scene_index
		if not hinted.has(hint_key) and host.camera.x >= cap - 4:
			hinted[hint_key] = true
			host.status = String(scene[3]) if scene.size() > 3 else "This way!"
		return
	wiping = true
	wipe_elapsed = 0.0
	wipe_midpoint_done = false
	wipe_kind = String(scene[1]) if scene.size() > 1 else "fade"
	wipe_label = String(scene[2]) if scene.size() > 2 else ""
	wipe_focus_start = _wipe_focus(host)
	wipe_focus_end = wipe_focus_start
	_wipe_open_captured = false
	_wipe_generation = run_generation
	_wipe_scene = scene.duplicate(true)
	host.sfx("power")

func _advance_wipe(dt: float, host) -> void:
	if not wiping or not _can_step(host) or _wipe_generation != run_generation: return
	wipe_elapsed += dt
	if not wipe_midpoint_done and wipe_elapsed + TIME_EPSILON >= WIPE_CALLBACK: _wipe_callback_due = true

func finish_frame(host) -> void:
	# Run after late effects and deferred knockout resolution. A pending
	# callback freezes while over/paused, then resumes after Continue.
	if not wiping or not _can_step(host) or _wipe_generation != run_generation: return
	if _wipe_callback_due: _apply_scene_transition(host, _wipe_generation)
	if not _wipe_open_captured and wipe_elapsed + TIME_EPSILON >= WIPE_OPEN_START:
		wipe_focus_end = _wipe_focus(host)
		_wipe_open_captured = true
	if wipe_elapsed + TIME_EPSILON >= WIPE_DURATION:
		wipe_elapsed = WIPE_DURATION
		wiping = false

func _apply_scene_transition(host, generation: int) -> bool:
	if generation != run_generation or generation != _wipe_generation or not _can_step(host) or not wiping or wipe_midpoint_done or not _wipe_callback_due or _wipe_scene.is_empty(): return false
	wipe_midpoint_done = true
	_wipe_callback_due = false
	scene_index += 1
	var destination := float(_wipe_scene[0]) + float(scene_policy.get("land", 420.0))
	var roster := _party_participants(host)
	if roster.is_empty():
		var surface := below(host, destination, float(scene_policy.get("landing_y", -9999)))
		if surface.is_empty(): surface = below(host, destination, -9999)
		host.player = Vector2(destination, float(surface.row[2]) if not surface.is_empty() else float(host.meta.ground))
		host.velocity = Vector2.ZERO
		host.grounded = true
		if host.hearts <= 0: host.hearts = 3
	else:
		for index in range(roster.size()):
			var participant: Dictionary = roster[index]
			var x := destination + index * (-70.0 if float(scene_policy.get("land", 420.0)) < 100 else 70.0)
			var surface := below(host, x, float(scene_policy.get("landing_y", -9999)))
			if surface.is_empty(): surface = below(host, x, -9999)
			participant.p = Vector2(x, float(surface.row[2]) if not surface.is_empty() else float(host.meta.ground))
			participant.px = x
			participant.velocity = Vector2.ZERO
			participant.grounded = true
			if participant.get("down", false) or int(participant.hearts) <= 0:
				participant.down = false
				participant.hearts = 3
	for enemy in host.enemies:
		if enemy.p.x < destination - 100: enemy.state = "pop"
	host.camera.x = maxf(host.camera.x, destination - float(scene_policy.get("camera", 160.0)))
	host.camera.y = 0
	host.camera_speed = 0
	host.bullets.clear()
	# Source intentionally retains safe, onPlat, invulnerability and ability
	# state. Continue also retains runtime state; only reset starts a new run.
	return true

func _wipe_focus(host) -> Vector2:
	var x: float = host.player.x
	var roster := _party_participants(host)
	if not roster.is_empty():
		# polish.js focusPoint averages the living roster (all if none are up).
		# Read the live records so a midpoint earlier in this call is visible
		# before the scalar facade is restored at the shared-phase boundary.
		var living := _living(roster)
		var focused: Array = living if not living.is_empty() else roster
		x = 0.0
		for participant in focused: x += float(participant.p.x)
		x /= focused.size()
	return Vector2(clampf((x - host.camera.x) * 1.3, 960 * 0.22, 960 * 0.78), 540 * 0.6)

func _repair_embedded_bots(host) -> void:
	for enemy in host.enemies:
		if enemy.state in ["pop", "drone"]: continue
		for surface in surfaces(host, true):
			var row: Array = surface.row
			if enemy.p.x > float(row[0]) + 4 and enemy.p.x < float(row[1]) - 4 and float(row[2]) < enemy.p.y - 6 and float(row[2]) > enemy.p.y - 400:
				enemy.p.y = float(row[2])
				enemy.segment = row
				enemy.surface = surface
				break

func _checkpoint(host) -> void:
	var check_x := float(host.level.get("check", 0))
	if not check_x or checkpoint_hit or host.camera.x + host.view_width() * 0.5 < check_x: return
	checkpoint_hit = true
	var roster := _party_participants(host)
	if roster.is_empty():
		if host.hearts <= 0: host.invincible = 2.0
		host.hearts = 3
	else:
		for participant in roster:
			if participant.get("down", false) or int(participant.hearts) <= 0:
				participant.down = false
				participant.invincible = 2.0
			participant.hearts = 3
	host.sfx("revive")
	host.status = "Checkpoint · Hearts topped up"
	if host.has_method("hud_banner"): host.hud_banner("Checkpoint", "Hearts topped up")

func _authored_coins(host) -> void:
	for i in range(hazards.size()):
		var hazard = hazards[i]
		if not hazard is Array or hazard.is_empty() or hazard[0] != "coins" or coins_done.has(i): continue
		if float(hazard[1]) >= host.camera.x + host.view_width() + 260: continue
		coins_done[i] = true
		var count := int(hazard[4])
		for k in range(count):
			var x := lerpf(float(hazard[1]), float(hazard[2]), k / float(count - 1) if count > 1 else 0.5)
			var arc := sin(PI * k / float(maxi(1, count - 1))) * float(hazard[5]) if hazard.size() > 5 else 0.0
			host.coins.append({"p": Vector2(x, float(hazard[3]) - arc), "v": Vector2.ZERO, "age": 0.3, "rest": true, "keep": true})
	for coin in host.coins:
		if coin.get("keep", false) and coin.get("rest", false) and coin.age > 2.0: coin.age = 2.0

func _trolleys(dt: float, host) -> void:
	# Snapshot spawners, then update every trolley, including this frame's
	# newly appended ones. Large dt still creates at most one per batch.
	for entity in entities.duplicate():
		if entity.k != "tspawn": continue
		if not entity.on and host.camera.x >= entity.at:
			entity.on = true
			entity.t = entity.gap
			host.status = "Runaway trolleys!"
		if entity.on and entity.done < entity.n:
			entity.t += dt
			if entity.t + TIME_EPSILON >= entity.gap:
				entity.t = 0.0
				entity.done += 1
				var x: float = host.camera.x + host.view_width() + 90 if entity.dir < 0 else host.camera.x - 90
				var surface := below(host, x, float(host.meta.ground) - 4)
				if not surface.is_empty():
					entities.append({"k": "trolley", "p": Vector2(x, float(surface.row[2])), "v": Vector2(entity.dir * rng.randf_range(360.0, 440.0), 0), "t": 0.0, "dead": false})
				host.sfx("throw")
	for entity in entities:
		if entity.k != "trolley": continue
		entity.t += dt
		entity.p.x += entity.v.x * dt
		var surface := land_on(host, entity.p.x, entity.p.y - 3, entity.p.y + 3)
		if surface.is_empty():
			entity.v.y += 3000.0 * dt
			var old_y: float = entity.p.y
			entity.p.y += entity.v.y * dt
			var landing := land_on(host, entity.p.x, old_y, entity.p.y)
			if not landing.is_empty():
				entity.p.y = float(landing.row[2])
				entity.v.y = 0.0
			if entity.p.y > float(host.level.get("fall", 742)): entity.dead = true
		if wall_clamp(host, entity.p.x - entity.v.x * dt, entity.p.x, entity.p.y) != entity.p.x:
			entity.v.x *= -0.6
			host.sfx("hitBot")
		var roster := _party_participants(host)
		if roster.is_empty():
			if host.hearts > 0 and absf(host.player.x - entity.p.x) < 46 and host.player.y > entity.p.y - 86 and host.player.y < entity.p.y + 20:
				host.hurt_player(entity.p.x)
		else:
			for participant in _living(roster):
				if absf(participant.p.x - entity.p.x) < 46 and participant.p.y > entity.p.y - 86 and participant.p.y < entity.p.y + 20:
					host.hurt_combat_participant(participant, entity.p.x)
		if entity.p.x < host.camera.x - 300 or entity.p.x > host.camera.x + host.view_width() + 400: entity.dead = true

func _party_participants(host) -> Array:
	# A true party returns stable mutable records inside the bridge's shared
	# boundary. Solo snapshots must keep using the existing scalar code paths.
	if not host.has_method("combat_participants"): return []
	var roster: Array = host.combat_participants()
	return roster if roster.any(func(participant): return not participant.get("host_player", false)) else []

func _living(roster: Array) -> Array:
	return roster.filter(func(participant): return not participant.get("down", false) and int(participant.hearts) > 0)

func snapshot() -> Dictionary:
	# A detached view for tests/tools; the renderer may read public state
	# directly but must never advance simulation or consume this RNG.
	return {"level_id": level_id, "run_generation": run_generation, "scene_index": scene_index, "wiping": wiping, "wipe_elapsed": wipe_elapsed, "wipe_midpoint_done": wipe_midpoint_done, "wipe_kind": wipe_kind, "wipe_label": wipe_label, "wipe_focus_start": wipe_focus_start, "wipe_focus_end": wipe_focus_end, "checkpoint_hit": checkpoint_hit, "entities": entities.duplicate(true), "elapsed": elapsed, "end_time": end_time}
