extends RefCounted
## World 3 shared runtime with isolated stage extensions. Imported metadata is never mutable run state.
## Absolute feet/pixels, seconds, px/s; surface conv remains authored px/ms.
## Source game/3-1/index.html:312–438,631–674,817–866,1170–1182,1262–1327.
const QueueRush = preload("res://src/festival_queue_rush.gd")
const Night = preload("res://src/festival_night.gd")
const BigTop = preload("res://src/festival_big_top.gd")
const Hayride = preload("res://src/festival_hayride.gd")
const Finale = preload("res://src/festival_finale.gd")
const Bonus = preload("res://src/festival_bonus.gd")
const SUPPORTED_LEVELS := ["3-1", "3-2", "3-3", "3-4", "3-5", "3-6", "3-S"]
const WIPE_CALLBACK := 1.43
const WIPE_OPEN_START := 1.57
const WIPE_DURATION := 2.17
const EPS := 0.000000001

var queue_rush = QueueRush.new()
var night = Night.new()
var big_top = BigTop.new()
var hayride = Hayride.new()
var finale = Finale.new()
var bonus = Bonus.new()
var stage_data: Dictionary:
	get:
		match level_id:
			"3-2": return queue_rush.snapshot()
			"3-3": return night.snapshot()
			"3-4": return big_top.snapshot()
			"3-5": return hayride.snapshot()
			"3-S": return bonus.snapshot()
			_: return {}
var level_id := ""
var run_generation := 0
var level_time := 0.0
var elapsed := 0.0
var cam_dx := 0.0
var scene_index := 0
var checkpoint_done := false
var mini_done := false
var end_time := 0.0
var clear_reported := false
var tied := 0.0
var cheer := 0.0
var tents: Array = []
var trailer: Dictionary = {} # Live authored deck, bound only for 3-5.
var safe_position := Vector2.ZERO
var wiping := false
var wipe_elapsed := 0.0
var wipe_midpoint_done := false
var wipe_kind := ""
var wipe_label := ""
var wipe_focus_start := Vector2.ZERO
var wipe_focus_end := Vector2.ZERO
var rng := RandomNumberGenerator.new()
var _surfaces: Array = []
var _scenes: Array = []
var _l3: Dictionary = {}
var _mud: Array = []
var _coin_rows: Array = []
var _coins_started := false
var _standing_surface: Dictionary = {}
var _camera_before := 0.0
var _wipe_scene: Dictionary = {}
var _wipe_generation := -1
var _wipe_callback_due := false
var _wipe_open_captured := false
var _host_id := 0
var _active := false

func supports(id: String) -> bool:
	return id in SUPPORTED_LEVELS

func reset(host, seed_value: int = 31) -> void:
	invalidate_run()
	level_id = host.level_id
	_host_id = host.get_instance_id()
	_active = supports(level_id)
	rng.seed = seed_value
	level_time = 0.0
	elapsed = 0.0
	cam_dx = 0.0
	_camera_before = host.camera.x
	scene_index = 0
	checkpoint_done = false
	mini_done = false
	end_time = 0.0
	clear_reported = false
	tied = 0.0
	cheer = 0.0
	safe_position = host.player
	_standing_surface = {}
	wipe_elapsed = 0.0
	wipe_midpoint_done = false
	wipe_kind = ""
	wipe_label = ""
	wipe_focus_start = Vector2.ZERO
	wipe_focus_end = Vector2.ZERO
	_coins_started = false
	_surfaces.clear()
	tents.clear()
	trailer = {}
	_l3 = host.meta.get("l3", {}).duplicate(true)
	queue_rush.reset(host)
	hayride.reset(host)
	bonus.reset(host)
	night.reset(host)
	_mud = host.level.get("mud", []).duplicate(true)
	_coin_rows = host.level.get("coinRows", []).duplicate(true)
	_scenes = _l3.get("scenes", []).duplicate(true)
	_scenes.sort_custom(func(a, b): return float(a.x) < float(b.x))
	for scene in _scenes: scene.done = false
	for row in host.level.get("solids", []): _add_surface(row, false)
	for row in host.level.get("plats", []): _add_surface(row, true)
	big_top.reset(host, self)
	hayride.bind_trailer(host, self)
	for row in host.level.get("tents", []):
		tents.append({"x": float(row[0]), "y": float(row[1]), "col": int(row[2]) if row.size() > 2 else 0, "kind": String(row[3]) if row.size() > 3 else "dome", "shake": 0.0})

func _add_surface(row: Array, platform: bool) -> void:
	var surface := {"row": row.duplicate(true), "plat": platform}
	# The source spreads props AFTER geometry/plat. Preserve every property,
	# especially nospawn/nodrop and later reusable carry fields.
	if row.size() > 3 and row[3] is Dictionary: surface.merge(row[3].duplicate(true), true)
	_surfaces.append(surface)

func invalidate_run() -> void:
	run_generation += 1
	_active = false
	wiping = false
	_wipe_generation = -1
	_wipe_scene = {}
	_wipe_callback_due = false
	_wipe_open_captured = false

func _can_step(host) -> bool:
	var within_final_base_step: bool = host.mode in ["clear", "story"] and host.has_method("festival_base_step_active") and host.festival_base_step_active()
	return _active and host.get_instance_id() == _host_id and host.level_id == level_id and (host.mode == "play" or within_final_base_step)

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
		if to_x > from_x and from_x <= float(row[0]) and to_x > float(row[0]) - 14: to_x = minf(to_x, float(row[0]) - 14)
		if to_x < from_x and from_x >= float(row[1]) and to_x < float(row[1]) + 14: to_x = maxf(to_x, float(row[1]) + 14)
	return to_x

func inside_wall(host, point: Vector2) -> bool:
	for surface in surfaces(host, true):
		var row: Array = surface.row
		if point.x > float(row[0]) and point.x < float(row[1]) and point.y > float(row[2]) + 4: return true
	return false

func in_mud(host, participant: Dictionary = {}) -> bool:
	var feet: Vector2 = host.player if participant.is_empty() or participant.get("host_player", false) else participant.p
	var on_ground: bool = host.grounded if participant.is_empty() or participant.get("host_player", false) else participant.get("grounded", false)
	if not on_ground or absf(feet.y - float(host.meta.ground)) >= 4: return false
	for row in _mud:
		if feet.x > float(row[0]) and feet.x < float(row[1]): return true
	return false

func base_displacement(dt: float, host, move: float) -> float:
	if not _can_step(host): return 0.0
	var multiplier := 0.45 if tied > 0 else 1.0
	if in_mud(host) and host.power != "wellies": multiplier *= 0.55
	return move * 270.0 * multiplier * dt

func can_jump(host) -> bool:
	return _can_step(host) and tied <= 0

func jump_multiplier(host) -> float:
	return 0.84 if in_mud(host) and host.power != "wellies" else 1.0

func allow_drop(host) -> bool:
	# Tied disables the normal jump, not the preceding source drop branch.
	if not _can_step(host): return false
	var surface := _standing_surface
	if surface.is_empty(): surface = land_on(host, host.player.x, host.player.y - 4, host.player.y + 4)
	return surface.is_empty() or not surface.get("nodrop", false)

func carry_player(dt: float, host) -> void:
	# Call AFTER base+knockback x, BEFORE side walls and camera-bound clamp.
	if not _can_step(host) or not host.grounded: return
	var surface := _standing_surface
	if surface.is_empty() or host.player.x < float(surface.row[0]) or host.player.x > float(surface.row[1]) or absf(float(surface.row[2]) - float(surface.get("dy", 0)) - host.player.y) > 4:
		surface = land_on(host, host.player.x, host.player.y - 4, host.player.y + 4)
		_standing_surface = surface
	if surface.is_empty(): return
	host.player.x += float(surface.get("conv", 0)) * dt * 1000 + float(surface.get("dx", 0))
	host.player.y += float(surface.get("dy", 0))

func after_motion(host) -> void:
	if not _can_step(host): return
	_camera_before = host.camera.x
	if not host.grounded: return
	_standing_surface = land_on(host, host.player.x, host.player.y - 2, host.player.y + 2)
	if host.on_platform: return
	var surface := below(host, host.player.x, host.player.y)
	if surface.is_empty(): return
	var row: Array = surface.row
	if host.player.x > float(row[0]) + 90 and host.player.x < float(row[1]) - 90: safe_position = host.player

func after_camera(dt: float, host) -> void:
	if not _can_step(host): return
	cam_dx = host.camera.x - _camera_before
	_camera_before = host.camera.x
	level_time += dt
	elapsed = level_time

func auto_displacement(dt: float, host) -> float:
	if level_id == "3-5": return hayride.auto_displacement(dt, host, self, level_time + dt)
	return queue_rush.auto_displacement(dt, host, self, level_time + dt) if level_id == "3-2" else 0.0

func squash_player(host) -> void:
	if level_id == "3-2": queue_rush.squash(host, self)
	if level_id == "3-5": hayride.squash(host, self)

func camera_cap(_host) -> float:
	# W3 scene changes do NOT reuse W2's approach cap or player-x clamp.
	return INF

func set_tied(host, participant: Dictionary, seconds: float = 2.2) -> void:
	if not _can_step(host): return
	if participant.is_empty() or participant.get("host_player", false): tied = maxf(0, seconds)
	else: participant.tied = maxf(0, seconds)

func receipt_position(row: Array) -> Vector2:
	return Vector2(float(row[0]), float(row[1]))

func receipt_reward() -> int:
	return 0

func finds_near(host, point: Vector2) -> bool:
	return host.hearts > 0 and absf(host.player.x - point.x) < 42 and point.y > host.player.y - host.character_height() - 10 and point.y < host.player.y + 20

func objective_tick(dt: float, host) -> String:
	# Source endOK checks all ten ordinary waves; the active mini, including
	# its down celebration, blocks via !boss. Do not invent a miniDone gate.
	if not _can_step(host) or clear_reported: return ""
	var event := ""
	var end_ok: bool = hayride.end_ok(host) if level_id == "3-5" else (queue_rush.end_ok(host) if level_id == "3-2" else host.combat.waves.all(func(wave): return wave.done))
	if end_time == 0 and host.boss == null and not _l3.get("noEnd", false) and not _l3.get("boss", false) and host.camera.x >= float(host.level.w) - host.view_width() - 2 and end_ok:
		end_time = 0.001
		event = "ending"
	if end_time > 0:
		end_time += dt
		if end_time > 2.6 + EPS:
			clear_reported = true
			return "clear"
	return event

func after_pickups(dt: float, host) -> void:
	if not _can_step(host): return
	var advance_existing_wipe := wiping
	# These phases intentionally remain after ordinary enemy/shot/coin updates.
	var roster := _party_participants(host)
	if roster.is_empty(): host.collect_level_pickups()
	else:
		for participant in roster:
			if int(participant.hearts) > 0 and not participant.get("down", false):
				host.call_combat_participant(participant, Callable(host, "collect_level_pickups"), [])
	_scene_update(host)
	if level_id == "3-2": queue_rush.events_tick(host, self)
	if level_id == "3-5": hayride.events_tick(host, self)
	if level_id == "3-4": big_top.events_tick(host, self)
	if level_id == "3-S":
		var early_clear: Dictionary = bonus.before_authored_coins(host, self)
		if not early_clear.is_empty():
			host.festival_event(early_clear)
			host._complete_level()
			return
	_authored_coins(host)
	cheer = maxf(0, cheer - dt)
	if level_id == "3-3": night.timers_tick(dt, host, self)
	for tent in tents: tent.shake = maxf(0, tent.shake - dt)
	# Source decrements each player's tie, including downed players, once here.
	# The party records are authoritative until the facade is rebound. Do not
	# also decrement whichever actor happens to be the active scalar facade.
	if roster.is_empty(): tied = maxf(0, tied - dt)
	else:
		for participant in roster: participant.tied = maxf(0, float(participant.get("tied", 0)) - dt)
	_checkpoint(host)
	if level_id == "3-2": queue_rush.banners_tick(host, self)
	if level_id == "3-5": hayride.banners_tick(host, self)
	if level_id == "3-3":
		night.fires_tick(host, self)
		night.fireworks_tick(dt, host, self)
	if level_id == "3-4":
		big_top.movers_tick(host, self)
		big_top.spotlights_tick(dt, host, self)
	if level_id == "3-5": hayride.trailer_tick(host, self)
	var mini: Dictionary = _l3.get("mini", {})
	if not mini.is_empty() and not mini_done and host.boss == null and host.camera.x >= float(mini.cam) - 260:
		host.combat.start_boss(host, mini.duplicate(true))
	if level_id == "3-2": queue_rush.late_tick(dt, host, self)
	if level_id == "3-5": hayride.harvester_tick(dt, host, self)
	if level_id == "3-6": finale.after_mini_trigger(dt, host, self)
	if level_id == "3-S":
		var timed_clear: Dictionary = bonus.late_tick(dt, host, self)
		if not timed_clear.is_empty():
			host.festival_event(timed_clear)
			host._complete_level()
	if advance_existing_wipe: _advance_wipe(dt, host)

func _authored_coins(host) -> void:
	if _coins_started: return
	_coins_started = true
	for row in _coin_rows:
		var count := int(row[3])
		for i in range(count):
			var arc := sin(i / float(maxi(1, count - 1)) * PI) * float(row[4]) if row.size() > 4 else 0.0
			host.coins.append({"p": Vector2(float(row[0]) + i * float(row[2]), float(row[1]) - arc), "v": Vector2.ZERO, "age": 0.3, "rest": true, "stay": true})

func _checkpoint(host) -> void:
	var check_x := float(_l3.get("check", 0))
	if check_x == 0 or checkpoint_done: return
	var roster := _party_participants(host)
	var crossed: bool = host.hearts > 0 and host.player.x > check_x if roster.is_empty() else roster.any(func(p): return int(p.hearts) > 0 and not p.get("down", false) and p.p.x > check_x)
	if not crossed: return
	checkpoint_done = true
	if roster.is_empty():
		host.hearts = 3
		host.invincible = 1.5
	else:
		for p in roster:
			p.down = false
			p.hearts = 3
			p.invincible = 1.5
	host.sfx("power")
	host.status = "Checkpoint. Hearts filled up."
	if host.has_method("hud_banner"): host.hud_banner("Checkpoint!", "Hearts filled up")

func _scene_update(host) -> void:
	if wiping: return
	var roster := _party_participants(host)
	for scene in _scenes:
		if not scene.get("wipe", "") or scene.done: continue
		var crossed: bool = host.hearts > 0 and host.player.x > float(scene.x) if roster.is_empty() else roster.any(func(p): return int(p.hearts) > 0 and not p.get("down", false) and p.p.x > float(scene.x))
		if not crossed: continue
		if level_id == "3-2":
			if not queue_rush.scene_can_start(host, self): continue
		elif level_id == "3-5":
			if not hayride.scene_can_start(host, self): continue
		elif _wave_busy(host): continue
		scene.done = true
		wiping = true
		wipe_elapsed = 0.0
		wipe_midpoint_done = false
		wipe_kind = String(scene.wipe)
		wipe_label = String(scene.get("label", ""))
		wipe_focus_start = _wipe_focus(host)
		wipe_focus_end = wipe_focus_start
		_wipe_generation = run_generation
		_wipe_scene = scene.duplicate(true)
		_wipe_callback_due = false
		_wipe_open_captured = false
		host.status = String(scene.get("label", "On we go"))
		return

func _wave_busy(host) -> bool:
	return host.boss != null or host.combat.waves.any(func(wave): return wave.started and not wave.done) or host.enemies.any(func(enemy): return enemy.state != "pop")

func _advance_wipe(dt: float, host) -> void:
	if not wiping or not _can_step(host) or _wipe_generation != run_generation: return
	wipe_elapsed += dt
	if not wipe_midpoint_done and wipe_elapsed + EPS >= WIPE_CALLBACK: _wipe_callback_due = true

func finish_frame(host) -> void:
	# Render-phase callback AFTER all-down and late ability/ghost effects.
	# Simulated time pauses with gameplay; no stale wall-clock timer survives.
	if not wiping or not _can_step(host) or _wipe_generation != run_generation: return
	if _wipe_callback_due: _apply_scene_transition(host, _wipe_generation)
	if not _wipe_open_captured and wipe_elapsed + EPS >= WIPE_OPEN_START:
		wipe_focus_end = _wipe_focus(host)
		_wipe_open_captured = true
	if wipe_elapsed + EPS >= WIPE_DURATION:
		wipe_elapsed = WIPE_DURATION
		wiping = false

func _apply_scene_transition(host, generation: int) -> bool:
	if generation != run_generation or generation != _wipe_generation or not _can_step(host) or not wiping or wipe_midpoint_done or not _wipe_callback_due or _wipe_scene.is_empty(): return false
	wipe_midpoint_done = true
	_wipe_callback_due = false
	var distance: float = float(_wipe_scene.to) - host.camera.x
	host.camera.x += distance
	_camera_before = host.camera.x
	host.camera_lock = null
	var roster := _party_participants(host)
	if roster.is_empty():
		host.player.x += distance
		host.velocity.x = 0
		if not host.level.get("auto", 0):
			var surface := below(host, host.player.x, host.view_top() - 600)
			if surface.is_empty(): surface = below(host, host.player.x, float(host.meta.ground) - 10)
			if not surface.is_empty():
				host.player.y = float(surface.row[2])
				host.velocity.y = 0
		safe_position = host.player
	else:
		# Records are authoritative in the shared phase. Translating the active
		# facade independently risks losing its new safe point during reconciliation.
		for p in roster:
			p.p.x += distance
			p.velocity.x = 0
			if not host.level.get("auto", 0):
				var landing := below(host, p.p.x, host.view_top() - 600)
				if landing.is_empty(): landing = below(host, p.p.x, float(host.meta.ground) - 10)
				if not landing.is_empty():
					p.p.y = float(landing.row[2])
					p.velocity.y = 0
			p.safe_position = p.p
			p.px = p.p.x
	# Preserve grounded/on_platform/surface, cameraY/speed, invulnerability,
	# powers, tents and coins exactly as sceneJump does.
	if level_id == "3-5": hayride.scene_translate(distance, self)
	host.enemies.clear()
	host.bullets.clear()
	for i in range(_scenes.size()):
		if _scenes[i].get("to", _scenes[i].x) == _wipe_scene.to: scene_index = i
	return true

func _wipe_focus(host) -> Vector2:
	# polish.js focuses the mean x of non-down/non-out players, falling back to
	# the full roster. The currently bound callback facade is not authoritative.
	var roster := _party_participants(host)
	var x: float = host.player.x
	if not roster.is_empty():
		var standing := roster.filter(func(p): return not p.get("down", false) and not p.get("out", false))
		if standing.is_empty(): standing = roster
		x = 0.0
		for participant in standing: x += participant.p.x
		x /= standing.size()
	return Vector2(clampf((x - host.camera.x) * 1.3, 960 * 0.22, 960 * 0.78), 540 * 0.6)

func _party_participants(host) -> Array:
	if not host.has_method("combat_participants"): return []
	return host.combat_participants().filter(func(participant): return not participant.get("host_player", false))

func boss_event(host, event: Dictionary) -> void:
	if event.has("cheer"): cheer = float(event.cheer)
	if host.has_method("festival_event"): host.festival_event(event)

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

func snapshot() -> Dictionary:
	return {"level_id": level_id, "run_generation": run_generation, "level_time": level_time, "elapsed": elapsed, "cam_dx": cam_dx, "scene_index": scene_index, "checkpoint_done": checkpoint_done, "mini_done": mini_done, "end_time": end_time, "tied": tied, "cheer": cheer, "tents": tents.duplicate(true), "trailer": trailer.duplicate(true), "safe_position": safe_position, "wiping": wiping, "wipe_elapsed": wipe_elapsed, "wipe_midpoint_done": wipe_midpoint_done, "wipe_kind": wipe_kind, "wipe_label": wipe_label, "wipe_focus_start": wipe_focus_start, "wipe_focus_end": wipe_focus_end, "coins_started": _coins_started, "stage_data": stage_data}
