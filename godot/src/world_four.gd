extends RefCounted
## Holiday runtime. Absolute feet/pixels, seconds, px/s.
## Source phase order: pre-motion, camera, waves/objective, world, combat, boss/jar, wipe.
const Foes = preload("res://src/holiday_foes.gd")
const Captain = preload("res://src/holiday_captain.gd")
const SUPPORTED_LEVELS := ["4-1", "4-2", "4-3", "4-4", "4-5", "4-6", "4-S"]
const EPS := 0.000000001
var level_id := ""
var level_time := 0.0
var elapsed := 0.0
var scene_index := 0
var checkpoint_done := false
var safe_position := Vector2.ZERO
var end_time := 0.0
var clear_reported := false
var generation := 0
var wiping := false
var wipe_elapsed := 0.0
var wipe_midpoint_done := false
var wipe_kind := ""
var wipe_label := ""
var wipe_focus_start := Vector2.ZERO
var wipe_focus_end := Vector2.ZERO
var cfg: Dictionary = {}
var gates: Array = []
var set_done: Dictionary = {}
var hold: Dictionary = {}
var dash: Dictionary = {}
var deck: Dictionary = {}
var foes = Foes.new()
var captain = Captain.new()
var rng := RandomNumberGenerator.new()
var _surfaces: Array = []
var _gate: Dictionary = {}
var _active := false
var _host_id := 0
var _wipe_generation := -1
var _mini_lock := false

func supports(id: String) -> bool: return id in SUPPORTED_LEVELS
func reset(host, seed_value: int = 41) -> void:
	invalidate_run()
	level_id = host.level_id
	_host_id = host.get_instance_id()
	_active = supports(level_id)
	rng.seed = seed_value
	level_time = 0
	elapsed = 0
	scene_index = 0
	checkpoint_done = false
	safe_position = host.player
	end_time = 0
	clear_reported = false
	_mini_lock = false
	cfg = host.level.get("cfg", {}).duplicate(true)
	gates = host.level.get("gates", []).duplicate(true)
	for gate in gates: gate.merge({"passed": false, "busy": false}, true)
	set_done.clear()
	_surfaces.clear()
	deck = {}
	hold = {}
	dash = {}
	for row in host.level.get("solids", []): _surfaces.append({"row": row.slice(0, 3).duplicate(), "plat": false, "nobot": row.size() > 3 and bool(row[3])})
	for row in host.level.get("plats", []): _surfaces.append({"row": row.slice(0, 3).duplicate(), "plat": true, "nobot": false})
	for row in host.level.get("belts", []):
		for surface in _surfaces:
			if surface.plat and surface.row == row.slice(0, 3):
				surface.belt = float(row[3])
				surface.nobot = true
				break
	for row in host.level.get("bobs", []):
		var surface := _solid_ends(row)
		if not surface.is_empty(): surface.merge({"bob": float(row[2]), "bob0": float(surface.row[2]), "style": "boat", "col": row[3], "phase": float(row[0]) / 97.0}, true)
	for row in host.level.get("styles", []):
		var surface := _solid_ends(row)
		if not surface.is_empty(): surface.merge(row[2].duplicate(true), true)
	for ground in cfg.get("ground", []):
		for surface in _surfaces:
			if not surface.plat and not surface.get("style", "") and not surface.get("hide", false) and surface.row[2] == host.meta.ground and surface.row[1] > ground.x0 and surface.row[0] < ground.x1: surface.merge(ground.st.duplicate(true), true)
	if cfg.has("deck"):
		var d: Dictionary = cfg.deck
		deck = {"row": [float(d.off), float(d.off + d.w), float(d.top)], "plat": false, "nobot": true, "dynamic": true, "hide": true}
		_surfaces.append(deck)
		host.player = Vector2(deck.row[0] + 120, deck.row[2])
		host.grounded = true
		host.on_platform = false
		safe_position = host.player
	if cfg.has("hold"):
		hold = {"on": false, "over": false, "left": float(cfg.hold.time) / 1000, "next": 1.5, "side": 0, "towels": [], "resets": 0, "mini": false}
		for x in cfg.hold.towels: hold.towels.append({"x": float(x), "gone": false, "held": null, "back": 0.0})
	if cfg.has("dash"):
		dash = {"left": float(cfg.dash.time) / 1000, "over": false, "mult": 1, "gates": [], "bonus": 0}
		for x in cfg.dash.gates: dash.gates.append({"x": float(x), "got": false})

	foes.reset(host, self)
	if captain != null:
		captain.reset(host)
		captain.configure_context(host, self)
func _solid_ends(row: Array) -> Dictionary:
	for surface in _surfaces:
		if not surface.plat and surface.row[0] == row[0] and surface.row[1] == row[1]: return surface
	return {}
func invalidate_run() -> void:
	foes.clear()
	generation += 1
	_active = false
	wiping = false
	wipe_elapsed = 0
	wipe_midpoint_done = false
	_wipe_generation = -1
	_gate = {}
func _can_step(host) -> bool:
	var final_step: bool = host.mode in ["clear", "story"] and host.has_method("family_base_step_active") and host.family_base_step_active(4)
	return _active and host.get_instance_id() == _host_id and host.level_id == level_id and (host.mode == "play" or final_step)
func surfaces(_host, skip_platforms: bool = false) -> Array:
	return _surfaces.filter(func(s): return not s.plat) if skip_platforms else _surfaces
func land_on(host, x: float, old_y: float, new_y: float, skip: bool = false) -> Dictionary:
	var best: Dictionary = {}
	for s in surfaces(host, skip):
		if x >= s.row[0] and x <= s.row[1] and s.row[2] >= old_y - 1 and s.row[2] <= new_y + 0.5:
			if best.is_empty() or s.row[2] < best.row[2]: best = s
	return best
func below(host, x: float, y: float) -> Dictionary:
	var best: Dictionary = {}
	for s in surfaces(host):
		if x >= s.row[0] and x <= s.row[1] and s.row[2] >= y - 2:
			if best.is_empty() or s.row[2] < best.row[2]: best = s
	return best
func wall_clamp(host, from_x: float, to_x: float, feet: float) -> float:
	for s in surfaces(host, true):
		if s.row[2] >= feet - 6: continue
		if to_x > from_x and from_x <= s.row[0] and to_x > s.row[0] - 14: to_x = minf(to_x, s.row[0] - 14)
		if to_x < from_x and from_x >= s.row[1] and to_x < s.row[1] + 14: to_x = maxf(to_x, s.row[1] + 14)
	return to_x
func inside_wall(host, point: Vector2) -> bool:
	for s in surfaces(host, true):
		if point.x > s.row[0] and point.x < s.row[1] and point.y > s.row[2] + 4: return true
	return false
func base_displacement(dt: float, _host, move: float) -> float: return move * 270 * dt
func pre_motion(dt: float, host) -> void:
	if not _can_step(host): return
	level_time += dt
	elapsed = level_time
	var party := _party_records(host)
	for s in _surfaces:
		var dx := 0.0
		var dy := 0.0
		if s.get("dynamic", false) and cfg.has("deck"):
			dx = host.camera.x + float(cfg.deck.off) - float(s.row[0])
			s.row[0] += dx
			s.row[1] += dx
			var new_y := float(cfg.deck.top) + sin(level_time / 0.42) * 4
			dy = new_y - float(s.row[2])
			s.row[2] = new_y
		if float(s.get("bob", 0)) != 0:
			var new_y := float(s.bob0) + sin(level_time / 0.52 + float(s.phase)) * float(s.bob)
			dy = new_y - float(s.row[2])
			s.row[2] = new_y
		s.dx = dx
		s.dy = dy
		if dx == 0 and dy == 0 and not s.get("belt", 0): continue
		if not party.is_empty():
			# Source surface-first order: all supported actors, then supported bots.
			for actor in party:
				if actor.grounded and not actor.down and actor.hearts > 0 and actor.p.x >= s.row[0] - dx - 1 and actor.p.x <= s.row[1] - dx + 1 and absf(actor.p.y - (s.row[2] - dy)) < 4:
					actor.p.x += dx + float(s.get("belt", 0)) * dt * 1000
					actor.p.y = s.row[2]
					actor.px = actor.p.x
		elif host.grounded and host.hearts > 0 and host.player.x >= s.row[0] - dx - 1 and host.player.x <= s.row[1] - dx + 1 and absf(host.player.y - (s.row[2] - dy)) < 4:
			host.player.x += dx + float(s.get("belt", 0)) * dt * 1000
			host.player.y = s.row[2]
		if dx != 0 or dy != 0:
			for b in host.enemies:
				if is_same(b.get("surface", {}), s):
					b.p.x += dx
					b.p.y = s.row[2]
	if not deck.is_empty() and not party.is_empty():
		for actor in party:
			# W4.pre clamps a grounded CPU even while down, without reviving it.
			if actor.cpu and actor.grounded:
				actor.p.x = clampf(actor.p.x, deck.row[0] + 30, deck.row[1] - 30)
				actor.px = actor.p.x
			if not actor.down and actor.hearts > 0 and actor.p.y > float(cfg.water) + 20:
				actor.p = Vector2((deck.row[0] + deck.row[1]) / 2 + (40 if int(actor.slot) != 0 else -40), deck.row[2])
				actor.px = actor.p.x
				actor.velocity = Vector2.ZERO
				actor.grounded = true
				actor.on_platform = false
				actor.invincible = 0.0
				hurt(host, actor, actor.p.x - actor.face)
				actor.velocity.x = 0
				host.status = "Splash!"
	elif not deck.is_empty() and host.hearts > 0 and host.player.y > float(cfg.water) + 20:
		host.player = Vector2((deck.row[0] + deck.row[1]) / 2 - 40, deck.row[2])
		host.velocity = Vector2.ZERO
		host.grounded = true
		host.on_platform = false
		host.invincible = 0
		host.hurt_player(host.player.x - host.face)
		host.velocity.x = 0
		host.status = "Splash!"
	if not dash.is_empty():
		for c in host.coins:
			if c.get("keep", false): c.age = minf(c.age, 5)
func after_motion(host) -> void:
	if not _can_step(host) or not host.grounded or host.on_platform: return
	var q := below(host, host.player.x, host.player.y)
	if not q.is_empty() and host.player.x > q.row[0] + 90 and host.player.x < q.row[1] - 90: safe_position = host.player
func fall_off(host) -> void:
	var x := clampf(safe_position.x, host.camera.x + 70, host.camera.x + host.view_width() - 70)
	var q: Dictionary = {}
	for i in 60:
		var xx := x + i * 20
		var candidate := below(host, xx, host.view_top() - 200)
		if not candidate.is_empty() and xx > candidate.row[0] + 30 and xx < candidate.row[1] - 30 and xx < host.camera.x + host.view_width() - 40:
			q = candidate
			x = xx
			break
	if q.is_empty(): q = below(host, x, -9999)
	if q.is_empty() and not _surfaces.is_empty(): q = _surfaces[0]
	if q.is_empty(): return
	host.player = Vector2(x, q.row[2])
	host.velocity = Vector2.ZERO
	host.grounded = true
	host.on_platform = q.plat
	host.invincible = 0
	host.hurt_player(x - host.face)
	host.velocity.x = 0
	var fall_text = host.meta.get("txt", {}).get("fall", "")
	host.status = str(fall_text) if fall_text else "Mind the gap!"
func wave_active(host) -> bool: return host.combat.waves.any(func(w): return w.started and not w.done)
func all_waves_done(host) -> bool: return host.combat.waves.all(func(w): return w.done)
func camera_step(dt: float, host) -> bool:
	if not _can_step(host): return true
	if wiping: return true
	var gate: Dictionary = {}
	for q in gates:
		if not q.passed:
			gate = q
			break
	if not gate.is_empty():
		if gate.busy: return true
		if host.level.get("auto", 0):
			if host.camera.x >= gate.x - host.view_width() - 4:
				_start_gate(host, gate)
				return true
		else:
			var cap: float = gate.x + 40 - host.view_width()
			host.camera_lock = cap if host.camera_lock == null else minf(host.camera_lock, cap)
			if _gate_front(host) > gate.x - 150 and not wave_active(host) and not busy(host) and not foes.pause_camera():
				_start_gate(host, gate)
				return true
	if host.level.get("auto", 0):
		if end_time == 0 and not foes.pause_camera(true): host.camera.x = minf(host.level.w - host.view_width(), host.camera.x + float(host.level.auto) * 1000 * dt)
		return true
	if foes.pause_camera():
		host.camera_lock = host.camera.x if host.camera_lock == null else minf(host.camera_lock, host.camera.x)
		_mini_lock = true
	elif _mini_lock:
		_mini_lock = false
		if not wave_active(host): host.camera_lock = null
	if not hold.is_empty() and not hold.over:
		if hold.on: return true
		host.camera_lock = float(cfg.hold.cam) if host.camera_lock == null else minf(host.camera_lock, cfg.hold.cam)
	return false
func camera_cap(_host) -> float: return INF
func _start_gate(host, gate: Dictionary) -> void:
	gate.busy = true
	_gate = gate
	wiping = true
	wipe_elapsed = 0
	wipe_midpoint_done = false
	_wipe_generation = generation
	wipe_kind = gate.get("kind", "fade")
	wipe_label = gate.get("label", "Checkpoint!")
	wipe_focus_start = _wipe_focus(host)
	wipe_focus_end = wipe_focus_start
	host.sfx("power")
func _wipe_focus(host) -> Vector2:
	var party := _party_records(host)
	# A gate relocation dirties records before the bridge restores the facade.
	var focus_x: float = host.player.x if party.is_empty() else party[0].p.x
	return Vector2(clampf((focus_x-host.camera.x)*1.3,960*0.22,960*0.78),540*0.6)
func finish_frame(host) -> void:
	if not _can_step(host) or not wiping or _wipe_generation != generation: return
	if wipe_elapsed >= 1.43 and not wipe_midpoint_done:
		wipe_midpoint_done = true
		_gate.passed = true
		_gate.busy = false
		host.enemies.clear()
		host.bullets.clear()
		foes.keep_controllers()
		host.camera.x = float(_gate.to) - (40 if host.level.get("auto", 0) else 60)
		host.camera_speed = 0
		host.camera_lock = null
		if not deck.is_empty():
			var dx: float = host.camera.x + float(cfg.deck.off) - float(deck.row[0])
			deck.row[0] += dx
			deck.row[1] += dx
		var x := float(deck.row[0]) + 120 if not deck.is_empty() else float(_gate.to) + 140
		var party := _party_records(host)
		if party.is_empty():
			var q := deck if not deck.is_empty() else below(host, x, host.meta.ground - 2000)
			host.player = Vector2(x, float(q.row[2]) if not q.is_empty() else float(host.meta.ground))
			host.velocity = Vector2.ZERO
			host.grounded = true
			host.on_platform = false
			safe_position = host.player
		else:
			for actor in party: _place_party_actor(host, actor, x + int(actor.slot) * 90)
		_heal(host)
		checkpoint_done = true
		host.status = wipe_label + ". Hearts topped up."
		if host.has_method("hud_banner"): host.hud_banner(wipe_label,"Hearts topped up")
		wipe_focus_end = _wipe_focus(host)
	if wipe_elapsed >= 2.17: wiping = false
func before_combat(dt: float, host) -> void:
	if not _can_step(host): return
	if wiping: wipe_elapsed += dt
	var scenes: Array = host.level.get("scenes", [])
	for i in scenes.size():
		if host.camera.x >= scenes[i].x - 1: scene_index = i
	if cfg.get("check", 0) and not checkpoint_done and host.camera.x >= cfg.check:
		checkpoint_done = true
		_heal(host)
		host.status = "Checkpoint! Hearts topped up."
		if host.has_method("hud_banner"): host.hud_banner("Checkpoint!","Hearts topped up")
		host.sfx("power")
	for sp in cfg.get("sets", []):
		if set_done.has(sp.id) or host.camera.x < sp.at - 2: continue
		if sp.get("after", false) and host.combat.waves.any(func(w): return w.at <= sp.at and not w.done): continue
		set_done[sp.id] = true
		foes.start_set(host, self, sp)
	var party := _party_records(host)
	if party.is_empty():
		if host.has_method("collect_level_pickups"): host.collect_level_pickups()
		if host.has_method("holiday_dash_step"): host.holiday_dash_step()
	else:
		# All picks precede all early Dash updates, as updatePicks/updateDash2 do.
		if host.has_method("collect_level_pickups"):
			for actor in living(host): host.call_combat_participant(actor, host.collect_level_pickups, [])
		if host.has_method("holiday_dash_step"):
			for actor in living(host):
				if not actor.cpu: host.call_combat_participant(actor, host.holiday_dash_step, [])
	if not hold.is_empty(): _hold_tick(dt, host)
	if not dash.is_empty(): _dash_tick(dt, host)
	foes.tick(dt, host, self)
	if cfg.get("boss", false) and captain != null and captain.boss.is_empty() and host.camera.x >= host.level.w - host.view_width() - 2 and all_waves_done(host):
		captain.start(host)
		host.boss = captain
func _heal(host) -> void:
	var party := _party_records(host)
	if party.is_empty():
		if host.hearts <= 0: host.invincible = 2
		host.hearts = 3
	else:
		for actor in party:
			if actor.down or actor.hearts <= 0:
				actor.down = false
				actor.invincible = 2.0
			actor.hearts = 3
func _hold_tick(dt: float, host) -> void:
	if not hold.on and not hold.over and host.camera.x >= cfg.hold.cam - 2 and all_waves_done(host):
		hold.on = true
		hold.left = float(cfg.hold.time) / 1000
		host.status = "Hold the loungers! Stop the robots nabbing your towels."
		if host.has_method("hud_banner"): host.hud_banner("Hold the loungers!","Stop the robots nabbing your towels")
		host.sfx("warn")
	if not hold.on or hold.over: return
	for towel in hold.towels: towel.back = maxf(0, towel.back - dt)
	hold.left -= dt
	hold.next -= dt
	var k := 1 - float(hold.left) / (float(cfg.hold.time) / 1000)
	if k > 0.5 and not hold.mini:
		hold.mini = true
		spawn_foe("r", "bailiff", host)
	if hold.next <= 0 and hold.left > 3:
		hold.next = (2.3 - k * 1.1) * (0.8 if host.combat.participant_count > 1 else 1) * rng.randf_range(0.8, 1.2)
		hold.side = 1 - hold.side
		var side := "r" if hold.side else "l"
		var r := rng.randf()
		if r < 0.5: spawn_foe(side, "grab", host)
		else: host.combat.spawn(host, side, "rush" if r < 0.7 else ("throw" if r < 0.85 else "flat"))
		if k > 0.5 and rng.randf() < 0.3: spawn_foe("l" if side == "r" else "r", "grab", host)
	if hold.towels.all(func(t): return t.gone):
		hold.resets += 1
		hold.left = minf(float(cfg.hold.time) / 1000, hold.left + 40)
		for towel in hold.towels:
			towel.gone = false
			towel.held = null
		for f in foes.entries:
			if f.kind == "grab":
				f.dead = true
				f.die_t = 0
		host.status = "Every towel gone! Fresh towels, more time on the clock."
		if host.has_method("hud_banner"): host.hud_banner("Every towel gone!","Fresh towels, more time on the clock",true)
		host.sfx("hurt")
	if hold.left <= 0:
		hold.over = true
		clear_threats(host)
		for f in foes.entries:
			if f.get("carry", null) != null: f.carry.held = null
		var kept: int = hold.towels.filter(func(t): return not t.gone).size()
		host.score += kept * 10
		hold.reward = kept * 10
		host.status = "+£%d for %d towels kept" % [kept * 10, kept]
func _dash_tick(dt: float, host) -> void:
	if dash.over: return
	dash.left -= dt
	for gate in dash.gates:
		if not gate.got and _any_player_past(host, gate.x):
			gate.got = true
			dash.left += 8
			dash.mult += 1
			host.sfx("power")
	if dash.left <= 0 or _any_player_past(host, host.level.w - 160):
		dash.over = true
		dash.bonus = maxi(0, int(floorf(dash.left + 0.5))) * int(dash.mult)
		host.score += dash.bonus
		for b in host.enemies: host.combat.kill_enemy(host, b, false)
		host.status = "Time bonus £%d" % dash.bonus if dash.left > 0 else "Out of time!"
func done(host) -> bool:
	if cfg.get("boss", false): return false
	if not hold.is_empty(): return hold.over
	if not dash.is_empty(): return dash.over
	return host.camera.x >= host.level.w - host.view_width() - 2 and all_waves_done(host) and not busy(host) and cfg.get("sets", []).all(func(s): return set_done.has(s.id))
func objective_tick(dt: float, host) -> String:
	if not _can_step(host) or clear_reported: return ""
	var event := ""
	if end_time == 0 and done(host):
		end_time = 0.001
		event = "ending"
	if end_time > 0:
		end_time += dt
		if end_time > 2.6 + EPS:
			clear_reported = true
			return "clear"
	return event
func busy(host) -> bool: return foes.busy(host)
func spawn_foe(side: String, kind: String, host) -> bool: return foes.spawn(side, kind, host, self)
func intercept_shot(shot: Dictionary, old_x: float, host) -> bool:
	if foes.intercept_shot(shot, old_x, host, self): return true
	return captain != null and captain.intercept_shot(shot, old_x, host, self)
func living(host) -> Array: return host.combat._living(host)
func hurt(host, participant: Dictionary, from_x: float) -> void: host.combat._hurt(host, participant, from_x)
func bill(host, position: Vector2, target_x: float, big: bool = false) -> void:
	host.bullets.append({"p": position, "v": Vector2(clampf((target_x - position.x) / 0.95, -550, 550), -720 - rng.randf() * 100), "gravity": 1600, "big": big, "enemy": true, "life": 20.0, "age": 0.0, "damage": 1})
	host.sfx("throw")
func clear_threats(host) -> void:
	for b in host.enemies: host.combat.kill_enemy(host, b, false)
	for f in foes.entries:
		if not f.dead and foes.hittable(f): foes.die(f, host, false)
func boss_tick(dt: float, host) -> void:
	if captain == null or captain.boss.is_empty(): return
	captain.tick(dt, host, self)
	for event in captain.drain_events():
		if host.has_method("holiday_event"): host.holiday_event(event)
		elif host.has_method("festival_event"): host.festival_event(event)
func snapshot() -> Dictionary:
	return {"level_id": level_id, "elapsed": elapsed, "scene_index": scene_index, "checkpoint_done": checkpoint_done, "hold": _hold_snapshot(), "dash": dash.duplicate(true), "set_done": set_done.duplicate(), "surfaces": _surfaces.duplicate(true), "foes": foes.snapshot(), "wiping": wiping, "wipe_elapsed": wipe_elapsed}

func seed_pickups(host) -> void:
	if not dash.is_empty():
		for c in cfg.dash.coins: host.coins.append({"p": Vector2(c[0], c[1]), "v": Vector2.ZERO, "age": 0.4, "rest": true, "keep": true})
func receipt_position(host, index: int) -> Vector2:
	# Intentional functional repair: source4-2 first receipt is at x=-300,
	# unreachable behind the x>=camera+30 clamp. Imported META is untouched.
	if host.level_id == "4-2" and index == 0: return Vector2(60, 482)
	var row: Array = host.level.receipts[index]
	return Vector2(row[0], row[1])

func jar_tick(dt: float, host) -> String:
	if captain == null or captain.jar.is_empty() or captain.jar.got: return ""
	var jar: Dictionary = captain.jar
	jar.t += dt
	var ground: float = host.meta.ground
	if jar.p.y < ground - 30 or jar.v.y < 0:
		jar.v.y += 2400 * dt
		jar.p += jar.v * dt
		if jar.p.y >= ground - 30:
			jar.p.y = ground - 30
			jar.v.y = -jar.v.y * 0.4 if absf(jar.v.y) > 200 else 0.0
			jar.v.x *= 0.5
	for participant in living(host):
		if absf(participant.p.x - jar.p.x) < 50 and jar.t > 0.6:
			jar.got = true
			return "clear"
	return ""

func _hold_snapshot() -> Dictionary:
	if hold.is_empty(): return {}
	var result: Dictionary = {}
	for key in hold:
		if key != "towels": result[key] = hold[key]
	result.towels = []
	for towel in hold.towels: result.towels.append({"x": towel.x, "gone": towel.gone, "held": towel.held != null, "back": towel.back})
	return result

# These helpers consume stable records only inside a bridge shared phase.
# They never refresh records or advance scene/actor clocks themselves.
func _party_records(host) -> Array:
	if not host.has_method("combat_participants"): return []
	var records: Array = host.combat_participants()
	return records if records.any(func(actor): return not actor.get("host_player", false)) else []

func party_start(host) -> void:
	# Source W4.start replaces the generic -80 mate spawn on the pedalo only.
	# Call once after constructing the roster, with the shared bridge open.
	if deck.is_empty(): return
	for actor in _party_records(host): _place_party_actor(host, actor, float(deck.row[0]) + 120 + int(actor.slot) * 90)

func _place_party_actor(host, actor: Dictionary, x: float) -> void:
	var q := deck if not deck.is_empty() else below(host, x, host.meta.ground - 2000)
	actor.p = Vector2(x, float(q.row[2]) if not q.is_empty() else float(host.meta.ground))
	actor.px = x
	actor.velocity = Vector2.ZERO
	actor.grounded = true
	actor.on_platform = false
	actor.safe_position = actor.p

func _gate_front(host) -> float:
	var party := _party_records(host)
	if party.is_empty(): return float(host.player.x)
	# W4 receives camAl, which includes downed humans and excludes the CPU.
	var humans: Array = party.filter(func(actor): return not actor.cpu and not actor.get("remote", false) and not actor.get("out", false))
	var eligible: Array = humans if not humans.is_empty() else living(host)
	var front := -INF
	for actor in eligible: front = maxf(front, actor.p.x)
	return front

func _any_player_past(host, x: float) -> bool:
	var party := _party_records(host)
	# Sponsored dash deliberately checks players, not alive() or camAl.
	return host.player.x > x if party.is_empty() else party.any(func(actor): return actor.p.x > x)
