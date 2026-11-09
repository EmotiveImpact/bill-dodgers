extends RefCounted
## Captain Overcharge, game/4-1/index.html:1305–1356.
## Absolute world feet/pixels; seconds and pixels/second. Caller resolves custom
## foes before intercept_shot, then ordinary combat/pickups, tick, and jar_tick.
## Named native repair: fy mirrors y for shared ability targeting. The source
## omits fy and produces invalid direct-special coordinates; see parity notes.
var boss: Dictionary = {}
var state: Dictionary:
	get: return boss
var jar: Dictionary = {}
var _events: Array[Dictionary] = []
var _width := 0.0
var _view := 738.0
var _ground := 482.0
var _participants := 1
var _host: WeakRef
var _world: WeakRef

func reset(host) -> void:
	boss = {}
	jar = {}
	_events.clear()
	_host = weakref(host)
	_world = null
	_width = float(host.level.w)
	_view = float(host.view_width())
	_ground = float(host.meta.get("ground", 482))
	_participants = maxi(1, host.combat_participants().size()) if host.has_method("combat_participants") else 1

func configure_context(host, world) -> void:
	# Explicit binding supports the existing generic hit(position, damage) seam.
	# Weak references keep the runtime -> captain -> runtime ownership acyclic.
	_host = weakref(host)
	_world = weakref(world)

func hit(point: Vector2, damage: int = 1) -> bool:
	if _host == null or _world == null: return false
	var host = _host.get_ref()
	var world = _world.get_ref()
	if host == null or world == null: return false
	return intercept_shot({"p": point, "damage": damage}, point.x, host, world)

func start(host) -> void:
	# World owns the all-waves/camera predicate. Repeated calls cannot restart it.
	if not boss.is_empty(): return
	# Main constructs the source roster after the solo-compatible world reset.
	# Sample the final level roster here, not an earlier title/previous stage.
	if host.has_method("combat_participants"): _participants = maxi(1, host.combat_participants().size())
	var cfg: Dictionary = host.level.get("cfg", {})
	var y := float(cfg.get("bossY", 0))
	if y == 0: y = float(cfg.get("water", _ground - 30)) + 30
	var maximum := 120 if _participants > 1 else 90
	boss = {"w4": true, "x": _width + 260, "y": y, "fy": y, "hp": maximum, "max": maximum,
		"state": "enter", "t": 0.0, "face": -1, "flash": 0.0, "dizzy": 0.0,
		"wave": [], "next": 1.8, "phase": 1, "called": {}, "sink": 0.0, "aimX": 0.0}
	host.camera_lock = _width - _view
	host.status = "Warning! Captain Overcharge sails in"
	host.sfx("warn")
	_events.append({"type": "warning", "text": "Warning!", "sub": "Captain Overcharge sails in", "warn": true, "music": true})

func drain_events() -> Array[Dictionary]:
	var result := _events
	_events = []
	return result

func tick(dt: float, host, world) -> void:
	if boss.is_empty(): return
	configure_context(host, world)
	dt = maxf(0, dt)
	boss.fy = boss.y
	boss.t += dt
	boss.flash = maxf(0, boss.flash - dt)
	var left := _width - _view + 120
	var right := _width - 110
	# CPU aim deliberately lags this tick's movement, including the entry snap.
	boss.aimX = boss.x - 20
	for wave: Dictionary in boss.wave:
		wave.x += wave.vx * dt
		wave.t += dt
		for participant: Dictionary in world.living(host):
			if absf(wave.x - participant.p.x) < 26 and participant.p.y > _ground - 30:
				world.hurt(host, participant, wave.x - wave.vx * 0.05)
	boss.wave = boss.wave.filter(func(wave): return wave.x > left - 200 and wave.x < right + 200)
	if boss.state == "down":
		boss.sink = minf(1, boss.sink + dt / 2.4)
		boss.y += dt * 30
		boss.fy = boss.y
		if boss.t > 1.8 and jar.is_empty():
			jar = {"p": Vector2(host.camera.x + _view / 2, _ground - 220),
				"v": Vector2(-100, -900), "t": 0.0, "got": false}
			host.sfx("power")
			_events.append({"type": "jar_spawn", "p": jar.p})
		return
	var nearest: Dictionary = {}
	for participant: Dictionary in world.living(host):
		if nearest.is_empty() or absf(participant.p.x - boss.x) < absf(nearest.p.x - boss.x): nearest = participant
	if nearest.is_empty(): return
	var fraction: float = float(boss.hp) / float(boss.max)
	var phase := 1 if fraction > 0.66 else 2 if fraction > 0.33 else 3
	if phase != boss.phase:
		boss.phase = phase
		if phase == 2:
			host.status = "He is turning nasty. Jump the splash waves"
			host.sfx("warn")
			_events.append({"type": "warning", "text": "He is turning nasty", "sub": "Jump the splash waves", "warn": true})
		elif phase == 3:
			host.status = "The valve is open! Shoot the valve on the flamingo for triple damage"
			host.sfx("power")
			_events.append({"type": "warning", "text": "The valve is open!", "sub": "Shoot the valve on the flamingo for triple damage", "warn": false})
	match boss.state:
		"enter":
			boss.x -= 250 * dt
			if boss.x <= right - 120:
				boss.state = "drift"
				boss.t = 0.0
		"drift":
			boss.face = signf(nearest.p.x - boss.x)
			if boss.face == 0: boss.face = -1
			var want: float = right - 150 + sin(boss.t / 1.5) * 140
			boss.x += clampf((want - boss.x) / 0.5, -80, 80) * dt
			if boss.t > boss.next:
				var choice: float = world.rng.randf()
				boss.state = "rear" if phase >= 2 and choice < 0.4 else "throw"
				boss.t = 0.0
				boss.fired = false
		"throw":
			if boss.t > 0.38 and not boss.get("fired", false):
				boss.fired = true
				var count := 3 if phase == 1 else 4
				for i in count:
					world.bill(host, Vector2(boss.x - 60, boss.y - 300), nearest.p.x + (i - (count - 1) / 2.0) * 120, true)
			if boss.t > 0.9:
				boss.state = "drift"
				boss.t = 0.0
				boss.next = (1.0 if phase == 3 else 1.5) + world.rng.randf()
		"rear":
			if boss.t > 0.7:
				boss.state = "charge"
				boss.t = 0.0
				boss.dir = -1 if boss.x > (left + right) / 2 else 1
				host.sfx("stomp")
				_events.append({"type": "shake", "amount": 8})
		"charge":
			boss.x += boss.dir * 550 * dt
			# Source spray is cosmetic. Do not consume gameplay RNG to draw it.
			if (boss.dir < 0 and boss.x < left + 60) or (boss.dir > 0 and boss.x > right - 60):
				boss.state = "drift"
				boss.t = 0.0
				boss.next = 1.4
				host.sfx("stomp")
				_events.append({"type": "shake", "amount": 10})
				boss.wave.append({"x": boss.x - boss.dir * 30, "vx": -boss.dir * 400.0, "t": 0.0})
	boss.x = clampf(boss.x, left - 40, right + 300)
	if fraction < 0.8 and not boss.called.get("a", false):
		boss.called.a = true
		world.spawn_foe("r", "jet", host)
		_events.append({"type": "text", "p": Vector2(boss.x, _ground - 330), "text": "Crew!"})
	if fraction < 0.5 and not boss.called.get("b", false):
		boss.called.b = true
		world.spawn_foe("l", "jet", host)
		world.spawn_foe("r", "ring", host)
	if fraction < 0.25 and not boss.called.get("c", false):
		boss.called.c = true
		world.spawn_foe("r", "jet", host)
		if _participants > 1: world.spawn_foe("l", "jet", host)
	# No stationary body collision. The boundary frame is already drift.
	if boss.state == "charge":
		for participant: Dictionary in world.living(host):
			if absf(participant.p.x - (boss.x + boss.dir * 60)) < 60 and participant.p.y > _ground - 120:
				world.hurt(host, participant, boss.x)

func body_box() -> Dictionary:
	if boss.is_empty(): return {}
	var scale: float = 1 - boss.sink * 0.35
	return {"x0": boss.x - 150 * scale, "x1": boss.x + 120 * scale,
		"top": boss.y - 330 * scale, "bot": boss.y - 20}

func intercept_shot(shot: Dictionary, old_x: float, host, world) -> bool:
	if boss.is_empty() or boss.state in ["enter", "down"]: return false
	configure_context(host, world)
	if shot.get("dead", false) or shot.get("enemy", false) or float(shot.get("life", 1)) <= 0: return false
	var point: Vector2 = shot.p
	# Retain safe rejection for malformed inputs. Native ability hooks receive
	# the explicit fy=y repair, so their intended hits now have valid positions.
	if not point.is_finite() or not is_finite(old_x): return false
	var box := body_box()
	if not (maxf(old_x, point.x) > box.x0 and minf(old_x, point.x) < box.x1 and point.y > box.top and point.y < box.bot): return false
	var valve := Vector2(boss.x + (70 if boss.face < 0 else -70), boss.y - 120)
	var damage := 3 if boss.phase == 3 and absf(point.x - valve.x) < 60 and absf(point.y - valve.y) < 60 else 1
	boss.hp -= damage
	boss.flash = 0.08
	shot.dead = true
	shot.life = 0.0
	host.sfx("hitBot")
	_credit_owner_hit(host, shot)
	if shot.get("owner") is Dictionary:
		var owner: Dictionary = shot.owner
		owner.bossHits = int(owner.get("bossHits", 0)) + 1
	_events.append({"type": "hit", "p": point, "damage": damage, "boss_hits": 1, "valve": damage == 3})
	if boss.hp <= 0: _down(host, world)
	return true

func _down(host, world) -> void:
	if boss.state == "down": return
	boss.state = "down"
	boss.t = 0.0
	boss.wave = []
	host.sfx("pop")
	host.sfx("stomp")
	_events.append({"type": "shake", "amount": 16})
	host.add_coins(Vector2(boss.x - 60, _ground - 200), 18)
	_events.append({"type": "bits", "p": Vector2(boss.x, _ground - 200)})
	# Runtime removes live bots and hit-capable foes, not bills/controllers.
	world.clear_threats(host)
	host.status = "Captain Overcharge is sinking. Grab the holiday pot!"
	_events.append({"type": "text", "p": Vector2(boss.x, _ground - 320), "text": "Pssssssss..."})

func _credit_owner_hit(host, shot: Dictionary) -> void:
	# Source shots retain an owner reference, even when that owner is down.
	# Native keeps its stable slot and writes the bridge's scene-owned tally.
	if not shot.has("owner_slot") or not host.has_method("combat_participants"): return
	var slot := int(shot.owner_slot)
	if slot < 0: return
	for participant in host.combat_participants():
		if not participant.get("host_player", false) and int(participant.get("slot", -2)) == slot:
			participant.boss_hits = int(participant.get("boss_hits", 0)) + 1
			return
