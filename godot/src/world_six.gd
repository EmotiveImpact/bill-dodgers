extends RefCounted
## World 6 shared systems, game/6-*/index.html:718-1186 (identical in all seven).
## Native absolute feet, seconds, px/s. Authored surface vx remains px/ms.
const SirCharge = preload("res://src/sir_charge.gd")
const SUPPORTED_LEVELS := ["6-1", "6-2", "6-3", "6-4", "6-5", "6-6", "6-S"]
const EPS := 0.000000001
var level_id := ""
var kind := ""
var level_time := 0.0
var elapsed := 0.0
var world_time := 0.0
var end_time := 0.0
var clear_reported := false
var checkpoint_done := false
var safe_position := Vector2.ZERO
var scene_index := 0
var generation := 0
var wiping := false
var wipe_elapsed := 0.0
var wipe_midpoint_done := false
var wipe_kind := ""
var wipe_label := ""
var wipe_focus_start := Vector2.ZERO
var wipe_focus_end := Vector2.ZERO
var hold: Dictionary = {}
var lift: Dictionary = {}
var ride: Dictionary = {}
var dash: Dictionary = {}
var hazards: Array = []
var fees: Array = []
var floating: Array = []
var fliers: Array = []
var vents: Array = []
var mini_boss: Dictionary = {}
var doors_used: Dictionary = {}
var lift_hurt_time := 0.0
var rng := RandomNumberGenerator.new()
var _surfaces: Array = []
var _door: Dictionary = {}
var _active := false
var _host_id := 0
var _wipe_generation := -1
var _last_dt := 0.0
var _coins_seeded := false

func supports(id: String) -> bool: return id in SUPPORTED_LEVELS
func add_float(text: String, position: Vector2, colour: Color) -> void:
	floating.append({"text": text, "position": position, "colour": colour, "age": 0.0})
func effects_tick(dt: float, host) -> void:
	if not _can_step(host): return
	for f in floating: f.age += dt
	floating = floating.filter(func(f): return f.age < 1.3 - EPS)
# Four source receipts are placed on non-playable door void sentinels, 1,400px
# above the actual floor. Repair display/collection coordinates only; imported
# META and the zero-based receipt identity remain untouched.
const RECEIPT_REPAIRS := {
	"6-1": {2: Vector2(8440, 412)},
	"6-2": {1: Vector2(6880, 412), 2: Vector2(10180, 412)},
	"6-3": {1: Vector2(8180, 412)},
}
func receipt_position(host, index: int, source_position: Vector2) -> Vector2:
	return RECEIPT_REPAIRS.get(host.level_id, {}).get(index, source_position)
func reset(host, seed_value: int = 61) -> void:
	invalidate_run()
	level_id = host.level_id
	kind = host.level.get("kind", "run")
	_host_id = host.get_instance_id()
	_active = supports(level_id)
	rng.seed = seed_value
	level_time = 0
	elapsed = 0
	world_time = 0
	end_time = 0
	clear_reported = false
	checkpoint_done = false
	safe_position = host.player
	scene_index = 0
	lift_hurt_time = 0
	_coins_seeded = false
	_surfaces.clear()
	fees.clear()
	floating.clear()
	fliers.clear()
	vents.clear()
	hazards.clear()
	doors_used.clear()
	mini_boss = {}
	hold = {}
	lift = {}
	ride = {}
	dash = {}
	for row in host.level.get("solids", []): _add_surface(row, false)
	for row in host.level.get("plats", []): _add_surface(row, true)
	if kind == "hold": hold = {"on": false, "done": false, "t": 0.0, "secs": float(host.level.hold.secs), "spawn_t": 0.0, "jams": 0, "doors": 0}
	if kind == "climb":
		for s in _surfaces:
			if s.art == "lift":
				lift = s
				lift.row[2] = float(host.level.climb.start)
	if kind == "ride":
		for s in _surfaces:
			if s.art == "cradle":
				ride = s
				ride.off0 = float(s.row[0])
				ride.off1 = float(s.row[1])
		for h in host.level.get("hazards", []): hazards.append({"x": float(h[0]), "kind": h[1], "hit": false})
	if kind == "dash": dash = {"left": float(host.level.dash.secs), "done": false, "bonus": 0}
	if host.level.has("intro"):
		wiping = true
		wipe_kind = host.level.intro.get("wipe", "fade")
		wipe_label = host.level.intro.get("label", "")
		wipe_focus_start = host.player
		_wipe_generation = generation
func seed_pickups(host) -> void:
	if _coins_seeded: return
	_coins_seeded = true
	for row in host.level.get("coinRows", []): host.coins.append({"p": Vector2(row[0], row[1]), "v": Vector2.ZERO, "age": 0.3, "rest": true, "stay": true})
func _add_surface(row: Array, platform: bool) -> void:
	_surfaces.append({"row": row.slice(0, 3).duplicate(), "plat": platform, "vx": float(row[3]) if row.size() > 3 else 0.0, "art": String(row[4]) if row.size() > 4 else ""})
func invalidate_run() -> void:
	generation += 1
	_active = false
	wiping = false
	wipe_elapsed = 0
	wipe_midpoint_done = false
	_wipe_generation = -1
	_door = {}
func _can_step(host) -> bool:
	var final_base_step: bool = host.mode in ["clear", "story"] and host.has_method("family_base_step_active") and host.family_base_step_active(6)
	return _active and host.get_instance_id() == _host_id and host.level_id == level_id and (host.mode == "play" or final_base_step)
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
func surf_under(x: float, feet: float) -> Dictionary:
	var best: Dictionary = {}
	for s in _surfaces:
		if x >= s.row[0] and x <= s.row[1] and absf(float(s.row[2]) - feet) < 3:
			if best.is_empty() or s.row[2] < best.row[2]: best = s
	return best
func wall_clamp(host, from_x: float, to_x: float, feet: float) -> float:
	for s in surfaces(host, true):
		if s.row[2] >= feet - 6: continue
		if to_x > from_x and from_x <= s.row[0] and to_x > s.row[0] - 14: to_x = minf(to_x, s.row[0] - 14)
		if to_x < from_x and from_x >= s.row[1] and to_x < s.row[1] + 14: to_x = maxf(to_x, s.row[1] + 14)
	return to_x
func inside_wall(host, point: Vector2) -> bool:
	return surfaces(host, true).any(func(s): return point.x > s.row[0] and point.x < s.row[1] and point.y > s.row[2] + 4)
func base_displacement(dt: float, _host, move: float) -> float: return move * 270 * dt
func pre_motion(dt: float, host) -> void:
	if not _can_step(host): return
	level_time += dt
	elapsed = level_time
	_last_dt = dt
func carry_player(dt: float, host) -> void:
	if not _can_step(host) or not host.grounded: return
	var s := surf_under(host.player.x, host.player.y)
	if s.is_empty(): return
	host.player.x += (float(host.level.ride.speed) if s.art == "cradle" else float(s.vx)) * 1000 * dt
func after_motion(host) -> void:
	if not _can_step(host) or not host.grounded or host.on_platform: return
	var s := below(host, host.player.x, host.player.y)
	if not s.is_empty() and host.player.x > s.row[0] + 90 and host.player.x < s.row[1] - 90: safe_position = host.player
func after_camera(_dt: float, _host) -> void: pass
func camera_override(dt: float, host) -> bool:
	if kind == "ride":
		if end_time == 0: host.camera.x = minf(float(host.level.w) - host.view_width(), host.camera.x + float(host.level.ride.speed) * 1000 * dt)
		ride.row[0] = host.camera.x + ride.off0
		ride.row[1] = host.camera.x + ride.off1
		return true
	if kind == "climb": host.camera.x = 0
	return false
func fall_off(host) -> void:
	var x := clampf(safe_position.x, host.camera.x + 70, host.camera.x + host.view_width() - 70)
	var surface: Dictionary = {}
	for i in range(60):
		var xx := x + i * 20
		var q := below(host, xx, host.view_top() - 200)
		if not q.is_empty() and xx > q.row[0] + 30 and xx < q.row[1] - 30 and xx < host.camera.x + host.view_width() - 40:
			surface = q
			x = xx
			break
	if surface.is_empty(): surface = below(host, x, -9999)
	if surface.is_empty(): surface = _surfaces[0]
	host.player = Vector2(x, surface.row[2])
	host.velocity = Vector2.ZERO
	host.grounded = true
	host.on_platform = surface.plat
	host.invincible = 0
	host.hurt_player(x - host.face)
	host.velocity.x = 0
	host.status = "Mind the gap!"
func finds_near(host, position: Vector2) -> bool:
	return host.hearts > 0 and absf(host.player.x - position.x) < 40 and absf(host.player.y - host.character_height() * 0.5 - position.y) < host.character_height() * 0.6
func all_waves_done(host) -> bool: return host.combat.waves.all(func(w): return w.done)
func wave_ready(w: Dictionary, host) -> bool:
	if w.has("atT"): return level_time >= float(w.atT) / 1000
	if w.has("atY"): return _living(host).any(func(p): return p.p.y <= float(w.atY))
	return host.camera.x >= float(w.get("at", 0)) - 2
func has_active_foes(host, wave: Dictionary = {}) -> bool:
	if host.enemies.any(func(b): return b.state != "pop") or fliers.any(func(f): return f.state != "pop"): return true
	return not mini_boss.is_empty() and mini_boss.state != "down" and (wave.is_empty() or is_same(mini_boss.wave, wave))
func done(host) -> bool:
	match kind:
		"hold": return hold.done
		"boss": return false
		"climb": return all_waves_done(host) and _living(host).any(func(p): return p.grounded and p.p.y <= float(host.level.climb.top) + 4)
		"dash":
			if _living(host).any(func(p): return p.p.x >= float(host.level.dash.finish)):
				if not dash.done:
					dash.done = true
					dash.bonus = ceili(dash.left)
					host.score += dash.bonus
					if _party(host):
						var first: Dictionary = host.combat_participants()[0]
						first.coins += dash.bonus
					add_float("+£%d time bonus" % dash.bonus, Vector2(host.level.dash.finish, host.meta.ground - 300), Color("f4c542"))
				return true
			return false
	return host.camera.x >= float(host.level.w) - host.view_width() - 2 and all_waves_done(host)
func objective_tick(dt: float, host) -> String:
	if not _can_step(host) or clear_reported: return ""
	var event := ""
	if end_time == 0 and done(host):
		end_time = 0.001
		event = "ending"
	if end_time > 0:
		end_time += dt
		if end_time > 2.6 + EPS and host.mode == "play":
			clear_reported = true
			return "clear"
	return event
func door_open(d: Dictionary, host) -> bool:
	for w in host.combat.waves:
		if w.has("at") and float(w.at) < float(d.x) and not w.done: return false
	if not mini_boss.is_empty() and mini_boss.state != "down": return false
	return not host.enemies.any(func(b): return b.state != "pop" and absf(b.p.x - float(d.x)) < 900)
func _doors_tick(host) -> void:
	if wiping or _living(host).is_empty(): return
	for d in host.level.get("doors", []):
		if doors_used.has(d.x) or not _living(host).any(func(p): return p.p.x > float(d.x) - 70) or not door_open(d, host): continue
		doors_used[d.x] = true
		_door = d.duplicate(true)
		wiping = true
		wipe_elapsed = 0
		wipe_midpoint_done = false
		wipe_kind = d.get("wipe", "fade")
		wipe_label = d.get("label", "")
		wipe_focus_start = host.player - host.camera
		_wipe_generation = generation
		host.sfx("power")
		break
func finish_frame(host) -> void:
	if not wiping or not _can_step(host) or host.mode != "play" or generation != _wipe_generation: return
	wipe_elapsed += _last_dt
	if not wipe_midpoint_done and wipe_elapsed >= 1.43 - EPS:
		wipe_midpoint_done = true
		if _door.is_empty():
			wipe_focus_end = host.player - host.camera
		else:
			_apply_door(host)
	if wipe_elapsed >= 1.57 - EPS: wipe_focus_end = host.player - host.camera
	if wipe_elapsed >= 2.17 - EPS: wiping = false
func _apply_door(host) -> void:
	if _party(host):
		_apply_party_door(host)
		return
	host.enemies.clear()
	host.bullets.clear()
	fliers.clear()
	host.player = Vector2(float(_door.to) + 80, float(host.meta.ground))
	host.velocity = Vector2.ZERO
	host.grounded = true
	host.on_platform = false
	host.face = 1
	host.camera = Vector2(float(_door.to) - 60, 0)
	host.camera_speed = 0
	host.camera_lock = null
	scene_index += 1
	if _door.get("cp", false):
		checkpoint_done = true
		host.hearts = maxi(host.hearts, 2)
		host.checkpoint = host.player
	host.status = _door.label + ". " + _door.get("sub", "")
	if host.has_method("hud_banner"): host.hud_banner(_door.label, _door.get("sub", ""))
	if host.has_method("hud_go"): host.hud_go(1.8)
	wipe_focus_end = host.player - host.camera
func world_tick(dt: float, host) -> void:
	if not _can_step(host): return
	world_time += dt
	_doors_tick(host)
	for b in host.enemies:
		if b.state == "pop" or b.has("hop") or b.get("surface", {}).is_empty(): continue
		var s: Dictionary = b.surface
		b.p.x += float(s.vx) * dt * 1000
		if s.art == "cradle": b.p.x += float(host.level.ride.speed) * dt * 1000
		if s.art == "lift": b.p.y = s.row[2]
	host.combat.bot_navigation(host)
	host.combat.debits_tick(dt, host)
	# Secrets precede pickups in the source. Receipts are stored zero-based by host.
	if _party(host):
		for player in _living(host): host.call_combat_participant(player, host.collect_level_pickups, [])
	else: host.collect_level_pickups()
	for c in host.coins:
		if c.rest:
			var s := surf_under(c.p.x, c.p.y + 8)
			if not s.is_empty(): c.p.x += (float(host.level.ride.speed) if s.art == "cradle" else float(s.vx)) * dt * 1000
		if c.get("stay", false): c.age = minf(c.age, 0.4)
	host.combat.fliers_tick(dt, host)
	for v in vents: v.t += dt
	vents = vents.filter(func(v): return v.t < 0.7)
	if not mini_boss.is_empty(): host.combat.mini_tick(dt, host)
	if host.level.has("cp") and not checkpoint_done and host.camera.x >= float(host.level.cp):
		checkpoint_done = true
		if _party(host):
			for player in _living(host): player.hearts = maxi(player.hearts, 2)
		else:
			if host.hearts > 0: host.hearts = maxi(host.hearts, 2)
			host.checkpoint = host.player
		host.status = "Halfway! Checkpoint"
		add_float(host.status, Vector2(host.camera.x + host.view_width() / 2, host.view_top() + 150), Color("9fe0b8"))
		host.sfx("power")
	match kind:
		"hold": _hold_tick(dt, host)
		"climb": _lift_tick(dt, host)
		"ride": _ride_tick(host)
		"dash": _dash_tick(dt, host)
		"boss":
			if host.boss == null and host.camera.x >= float(host.level.w) - host.view_width() - 2 and all_waves_done(host):
				host.boss = SirCharge.new()
				host.boss.reset(float(host.level.w), host.view_width(), float(host.meta.ground), host.combat.participant_count, rng.randi())
				host.camera_lock = float(host.level.w) - host.view_width()
				host.status = "Sir Charge. Top of the Bill-ding. Get the jar back."
				if host.has_method("scene_music"): host.scene_music(true)
				if host.has_method("hud_banner"): host.hud_banner("Sir Charge", "Top of the Bill-ding. Get the jar back.", true)
				host.sfx("warn")
	_fees_tick(dt, host)
	for bill in host.bullets:
		if bill.enemy and float(bill.get("delay", 0)) > 0:
			bill.delay -= dt
			if bill.delay > 0: bill.p.x -= bill.v.x * dt
			else: bill.delay = 0
func _hold_tick(dt: float, host) -> void:
	if not hold.on and not hold.done and host.camera.x >= float(host.level.w) - host.view_width() - 2 and all_waves_done(host):
		hold.on = true
		hold.t = 0
		host.camera_lock = float(host.level.w) - host.view_width()
		host.status = "Hold out until the lift comes. Keep the robots off the doors!"
		if host.has_method("hud_banner"): host.hud_banner("Hold out!", "Keep the robots off the lift until it comes", true)
		host.sfx("warn")
	if not hold.on: return
	hold.t += dt
	hold.spawn_t -= dt
	var live: int = host.enemies.filter(func(b): return b.state != "pop").size() + fliers.filter(func(f): return f.state != "pop").size()
	var multi: bool = host.combat.participant_count > 1
	var pace := maxf(1.2, (2.1 if multi else 2.6) - float(hold.t) / 60)
	if hold.spawn_t <= 0 and live < (7 if multi else 5):
		hold.spawn_t = pace
		var r := rng.randf()
		host.combat.spawn(host, "l" if rng.randf() < 0.5 else "r", "mailer" if r < 0.18 else "drop" if r < 0.32 else "throw" if r < 0.55 else "flat" if r < 0.68 else "rush")
	for b in host.enemies:
		if b.state != "pop" and not b.has("hop") and absf(b.p.x - float(host.level.hold.door)) < 46 and absf(b.p.y - float(host.meta.ground)) < 4:
			host.combat.kill_enemy(host, b, false)
			hold.t = maxf(0, float(hold.t) - 5)
			hold.jams += 1
			host.status = "Lift jammed! +5s"
			add_float(host.status, Vector2(host.level.hold.door, host.meta.ground - 300), Color("ffb3b3"))
			host.sfx("hurt")
	if hold.t >= hold.secs:
		hold.on = false
		hold.done = true
		hold.doors = 1
		hold.open_at = world_time
		clear_threats(host)
		host.sfx("win")
		host.status = "Ding!"
		add_float(host.status, Vector2(host.level.hold.door, host.meta.ground - 320), Color("f4c542"))
func _lift_tick(dt: float, host) -> void:
	var living := _living(host)
	if living.is_empty(): return
	var high := INF
	var low := -INF
	for player in living:
		high = minf(high, player.p.y)
		low = maxf(low, player.p.y)
	var c: Dictionary = host.level.climb
	var progress := clampf((float(c.start) - high) / (float(c.start) - float(c.top)), 0, 1)
	if level_time > float(c.delay) / 1000 and end_time == 0:
		var speed := lerpf(float(c.v0), float(c.v1), progress) * 1000
		var gap: float = lift.row[2] - low
		if gap > 640: speed *= 2.6
		elif gap > 420: speed *= 1.6
		lift.row[2] -= speed * dt
	if end_time > 0: lift.row[2] -= 20 * dt
	lift.row[2] = maxf(lift.row[2], float(c.top) + 160)
	lift_hurt_time = maxf(0, lift_hurt_time - dt)
	if _party(host):
		_party_lift_players(host, c)
	elif host.player.y > float(lift.row[2]) - 1:
		host.player.y = lift.row[2]
		if host.velocity.y > 0: host.velocity.y = 0
		host.grounded = true
		host.on_platform = false
		if level_time > float(c.delay) / 1000 and lift_hurt_time <= 0 and host.invincible <= 0:
			host.hurt_player(host.player.x - host.face)
			host.velocity.y = -900
			host.grounded = false
			host.status = "The lift is charging you!"
			add_float(host.status, Vector2(host.player.x, lift.row[2] - 260), Color("ffb3b3"))
	for b in host.enemies:
		if b.state != "pop" and not b.has("hop") and not is_same(b.get("surface", {}), lift) and b.p.y > float(lift.row[2]) - 4: host.combat.kill_enemy(host, b, false)
	for coin in host.coins:
		if coin.p.y > float(lift.row[2]) - 6:
			coin.p.y = float(lift.row[2]) - 8
			coin.rest = true
			coin.v.y = 0
	for item in host.items:
		if item.p.y > float(lift.row[2]) - 26:
			item.p.y = float(lift.row[2]) - 26
			item.rest = true
			item.vy = 0
func _ride_tick(host) -> void:
	if _party(host):
		_party_ride_tick(host)
		return
	if host.hearts <= 0: return
	for h in hazards:
		if h.hit or absf(host.player.x - float(h.x)) > 30: continue
		var hit: bool = (h.kind == "beam" and not host.crouching and host.player.y > float(ride.row[2]) - 150 and host.player.y - host.character_height() * 0.75 < float(ride.row[2]) - 150) or (h.kind == "box" and host.player.y > float(ride.row[2]) - 58)
		if hit:
			h.hit = true
			host.hurt_player(float(h.x) + 40)
			host.velocity.x = -300
			host.status = "Duck!" if h.kind == "beam" else "Jump!"
			add_float(host.status, host.player - Vector2(0, 230), Color("ffb3b3"))
func _dash_tick(dt: float, host) -> void:
	if dash.done or end_time > 0: return
	dash.left -= dt
	if dash.left <= 0:
		dash.left = 0
		dash.done = true
		end_time = 0.001
		host.status = "Time's up! Coffee is going cold."
		if host.has_method("hud_banner"): host.hud_banner("Time's up!", "Coffee is going cold", true)
		host.sfx("warn")
func _fees_tick(dt: float, host) -> void:
	for f in fees:
		f.t += dt
		if f.t < f.warn: continue
		f.vy += 2200 * dt
		f.y += f.vy * dt
		for player in _living(host):
			if absf(player.p.x - f.x) < float(f.r) + 12 and f.y > player.p.y - player.height and f.y - f.r < player.p.y:
				f.dead = true
				_hurt(host, player, f.x)
		if f.y > float(host.meta.ground) - 6: f.dead = true
	fees = fees.filter(func(f): return not f.get("dead", false))
func clear_threats(host) -> void:
	for b in host.enemies:
		if b.state != "pop": host.combat.kill_enemy(host, b, false)
	for f in fliers:
		if f.state != "pop":
			f.state = "pop"
			f.gone = 0
func boss_tick(dt: float, host) -> void:
	if host.boss == null: return
	host.boss.boss_tick(dt, host, self)
func jar_tick(dt: float, host) -> String:
	if host.boss == null: return ""
	return host.boss.jar_tick(dt, host)
func snapshot() -> Dictionary:
	return {"level_id": level_id, "kind": kind, "level_time": level_time, "world_time": world_time, "end_time": end_time, "hold": hold.duplicate(true), "lift": lift.duplicate(true), "ride": ride.duplicate(true), "dash": dash.duplicate(true), "fliers": fliers.duplicate(true), "mini": mini_boss.duplicate(true), "fees": fees.duplicate(true), "checkpoint_done": checkpoint_done, "wiping": wiping}

# Party records are mutable and stable only inside the session's shared phases.
# Carry/after_motion/fall remain actor callbacks with separately bound safe_position.
func _party(host) -> bool:
	return host.has_method("combat_participants") and host.combat_participants().any(func(p): return not p.get("host_player", false))

func _living(host) -> Array:
	if host.has_method("combat_participants"):
		return host.combat_participants().filter(func(p): return not p.get("down", false) and p.hearts > 0)
	if host.hearts <= 0: return []
	return [{"host_player": true, "p": host.player, "height": host.character_height(), "grounded": host.grounded}]

func _hurt(host, player: Dictionary, from_x: float) -> void:
	if player.get("host_player", false): host.hurt_player(from_x)
	else: host.hurt_combat_participant(player, from_x)

func _apply_party_door(host) -> void:
	host.enemies.clear()
	# Source doors clear hostile bills, but leave already-fired friendly shots.
	host.bullets = host.bullets.filter(func(shot): return not shot.enemy)
	fliers.clear()
	for player in host.combat_participants():
		player.p = Vector2(float(_door.to) + 80 + 70 * int(player.slot), float(host.meta.ground))
		player.px = player.p.x
		player.velocity.y = 0
		player.grounded = true
		player.face = 1
		# Source does not revive, reset horizontal knockback/platform/safe, or
		# change per-player checkpoint on this transition, even at a cp door.
		if _door.get("cp", false): player.hearts = maxi(player.hearts, 2)
	host.camera = Vector2(float(_door.to) - 60, 0)
	host.camera_speed = 0
	host.camera_lock = null
	host.combat.go_time = 1.8
	scene_index += 1
	if _door.get("cp", false): checkpoint_done = true
	host.status = _door.label + ". " + _door.get("sub", "")
	if host.has_method("hud_banner"): host.hud_banner(_door.label, _door.get("sub", ""))
	if host.has_method("hud_go"): host.hud_go(1.8)
	wipe_focus_end = host.combat_participants()[0].p - host.camera

func _party_lift_players(host, config: Dictionary) -> void:
	for player in host.combat_participants():
		if player.p.y <= float(lift.row[2]) - 1: continue
		player.p.y = lift.row[2]
		if player.velocity.y > 0: player.velocity.y = 0
		player.grounded = true
		player.on_platform = false
		if not player.down and player.hearts > 0 and level_time > float(config.delay) / 1000 and lift_hurt_time <= 0 and player.invincible <= 0:
			_hurt(host, player, player.p.x - player.face)
			player.velocity.y = -900
			player.grounded = false
			host.status = "The lift is charging you!"
			add_float(host.status, Vector2(player.p.x, lift.row[2] - 260), Color("ffb3b3"))

func _party_ride_tick(host) -> void:
	for hazard in hazards:
		if not hazard.has("hit_slots"): hazard.hit_slots = {}
		for player in _living(host):
			if hazard.hit_slots.has(player.slot) or absf(player.p.x - float(hazard.x)) > 30: continue
			var hit: bool = (hazard.kind == "beam" and player.player_animation != "crouch" and player.p.y > float(ride.row[2]) - 150 and player.p.y - player.height * 0.75 < float(ride.row[2]) - 150) or (hazard.kind == "box" and player.p.y > float(ride.row[2]) - 58)
			if not hit: continue
			hazard.hit_slots[player.slot] = true
			_hurt(host, player, float(hazard.x) + 40)
			player.velocity.x = -300
			host.status = "Duck!" if hazard.kind == "beam" else "Jump!"
			add_float(host.status, player.p - Vector2(0, 230), Color("ffb3b3"))
