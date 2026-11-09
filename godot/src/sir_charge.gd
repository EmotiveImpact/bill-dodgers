extends RefCounted
## Actual W6 Sir Charge, NOT the unused startBossOld copied into its HTML.
## .fy intentionally aliases GROUND+yo: source omitted fy and specials missed him.
const EPS := 0.000000001
var state: Dictionary = {}
var rng := RandomNumberGenerator.new()
var _world := 0.0
var _view := 0.0
var _ground := 482.0
var _count := 1
var _pending_down := false
var _events: Array = []
func reset(world_width: float, view_width: float, ground_y: float, participants: int = 1, seed_value: int = 61) -> void:
	_world = world_width
	_view = view_width
	_ground = ground_y
	_count = participants
	rng.seed = seed_value
	_pending_down = false
	_events.clear()
	var hp := 150 if participants > 1 else 110
	state = {"name": "Sir Charge", "x": _world + 180, "yo": 0.0, "fy": _ground, "hp": hp, "max": hp, "state": "enter", "t": 0.0, "at": 0.0, "face": -1, "flash": 0.0, "dizzy": 0.0, "waves": [], "next": 1.8, "phase": 1, "act": "walk", "pend": false, "vx": 0.0, "fee_t": 0.0, "mail_t": 0.0, "rock_t": 0.0, "shout": 0.0, "jar": {}}
func hit_test(position: Vector2) -> bool:
	return not state.is_empty() and state.state not in ["down", "enter"] and absf(position.x - state.x) < 78 and position.y > _ground + state.yo - 300 and position.y < _ground + state.yo - 10
func hit(position: Vector2, _damage: int = 1) -> bool:
	if not hit_test(position): return false
	# Source updateShots ignores s.dmg and only doubles for dizzy.
	damage(2 if state.dizzy > 0 else 1)
	return true
func damage(amount: int) -> void:
	if state.is_empty() or state.state in ["down", "enter"]: return
	if state.shout <= 0 and rng.randf() < 0.06:
		state.shout = 1.6
		_events.append({"type": "float", "text": ["Admin fee!", "Late charge!", "Service charge!", "Card fee!"][rng.randi_range(0, 3)], "position": Vector2(state.x, _ground + state.yo - 340)})
	state.hp -= amount
	state.flash = 0.08
	_events.append({"type": "hit", "position": Vector2(state.x, state.fy - 160)})
	if state.hp <= 0:
		state.state = "down"
		state.t = 0
		state.waves.clear()
		_pending_down = true
func drain_events() -> Array:
	var result := _events
	_events = []
	return result
func flush_down(host, world) -> void:
	for event in _events:
		if event.type == "float": world.add_float(event.text, event.position, Color("ffd2d2"))
	_events = _events.filter(func(event): return event.type != "float")
	if not _pending_down: return
	_pending_down = false
	world.fees.clear()
	world.clear_threats(host)
	host.add_coins(Vector2(state.x, _ground - 180), 24)
	host.sfx("pop")
	host.sfx("stomp")
	host.status = "The ledger is smashed! Grab the jar."
	if host.has_method("hud_banner"): host.hud_banner("The ledger is smashed!", "Everyone's money is going home")
func boss_tick(dt: float, host, world) -> void:
	if state.is_empty(): return
	flush_down(host, world)
	state.t += dt
	state.at += dt
	state.flash = maxf(0, state.flash - dt)
	state.dizzy = maxf(0, state.dizzy - dt)
	state.shout = maxf(0, state.shout - dt)
	var left := _world - _view + 90
	var right := _world - 90
	for wave in state.waves:
		wave.x += wave.vx * dt
		wave.t += dt
		for target in _living(host):
			if absf(wave.x - target.p.x) < 24 and target.p.y > _ground - 30: _hurt(host, target, wave.x - wave.vx * 0.05)
	state.waves = state.waves.filter(func(w): return w.x > left - 100 and w.x < right + 100)
	if state.state == "down":
		state.yo = minf(0, float(state.yo) + 300 * dt)
		state.fy = _ground + state.yo
		if state.t > 0.6 and state.t < 3.6 and rng.randf() < 0.3: host.coins.append({"p": Vector2(host.camera.x + 60 + rng.randf() * (_view - 120), host.view_top() + 10), "v": Vector2(0, 100), "age": 0.0, "rest": false})
		if state.t > 1.8 + EPS and state.jar.is_empty():
			var jx := clampf(float(state.x) - 10, host.camera.x + 120, host.camera.x + _view - 120)
			state.jar = {"x": jx, "y": _ground - 220, "vx": clampf((host.camera.x + _view / 2 - jx) / 0.9, -200, 200), "vy": -900.0, "t": 0.0, "got": false}
			host.sfx("power")
		if not state.jar.is_empty() and not state.jar.got: state.jar.x = clampf(state.jar.x, host.camera.x + 60, host.camera.x + _view - 60)
		return
	var player := _nearest(host, state.x)
	if player.is_empty(): return
	if state.state == "enter":
		state.x -= 280 * dt
		state.act = "walk"
		if state.x <= right - 160:
			state.state = "fight"
			state.at = 0
		return
	var fraction: float = float(state.hp) / state.max
	var phase := 1 if fraction > 0.66 else 2 if fraction > 0.33 else 3
	if phase != state.phase:
		state.phase = phase
		state.act = "walk"
		state.at = 0
		state.vx = 0
		state.dizzy = 0
		host.status = "Fee storm! Watch the shadows. Shoot up and forward." if phase == 2 else "The tower is shaking! Let him hit the wall."
		if host.has_method("hud_banner"): host.hud_banner("Fee storm!" if phase == 2 else "The tower is shaking!", "Watch the shadows. Shoot up and forward" if phase == 2 else "He charges. Let him hit the wall", true)
		host.sfx("warn")
	if state.dizzy > 0:
		state.yo = minf(0, float(state.yo) + 500 * dt)
		state.fy = _ground + state.yo
		return
	var direction := signf(player.p.x - float(state.x))
	if direction != 0: state.face = direction
	if phase == 1:
		state.yo = minf(0, float(state.yo) + 400 * dt)
		if state.act == "walk":
			if absf(player.p.x - float(state.x)) > 150: state.x += direction * 80 * dt
			if state.at > state.next:
				state.act = "slam" if rng.randf() < 0.5 else "volley"
				state.at = 0
				state.pend = true
		else:
			if state.at > 0.48 + EPS and state.pend:
				state.pend = false
				attack(host)
			if state.at > 0.9 + EPS:
				state.act = "walk"
				state.at = 0
				state.next = rng.randf_range(1.3, 2.3)
	elif phase == 2:
		state.yo += (-180 - float(state.yo)) * minf(1, dt / 0.5)
		state.act = "float"
		state.x += sin(float(state.t) / 1.4) * 120 * dt
		state.fee_t -= dt
		state.mail_t -= dt
		if state.fee_t <= 0:
			state.fee_t = 0.52 if _count > 1 else 0.65
			# Source chooses any living player, independently of nearest boss aim.
			var living := _living(host)
			var target: Dictionary = living[rng.randi_range(0, living.size() - 1)] if living.size() > 1 else living[0]
			_fee(world, clampf(target.p.x + rng.randf_range(-130, 130), left, right), host.view_top() - 30, 0.7, 16, "fee")
		if state.mail_t <= 0:
			state.mail_t = 7
			if world.fliers.filter(func(f): return f.state != "pop").size() < 2: host.combat.spawn_flier(host, "l" if rng.randf() < 0.5 else "r")
		if state.at > 9 + EPS:
			state.at = 0
			state.dizzy = 2.8
			host.status = "Out of breath! Double damage"
			world.add_float(host.status, Vector2(state.x, _ground - 320), Color("f4c542"))
	else:
		state.yo = minf(0, float(state.yo) + 500 * dt)
		state.rock_t -= dt
		if state.rock_t <= 0:
			state.rock_t = 0.9
			_fee(world, rng.randf_range(left, right), host.view_top() - 30, 0.65, 22, "rock")
		if state.act in ["walk", "float"]:
			state.act = "wind"
			state.at = 0
		if state.act == "wind":
			if state.at > 0.7 + EPS:
				state.act = "charge"
				state.at = 0
				state.vx = state.face * 550
				host.sfx("stomp")
		elif state.act == "charge":
			state.x += state.vx * dt
			if state.x <= left or state.x >= right:
				state.x = clampf(state.x, left, right)
				state.act = "wind"
				state.at = -0.3
				state.vx = 0
				state.dizzy = 1.9
				attack(host, true)
				host.status = "Dizzy! Double damage"
				world.add_float(host.status, Vector2(state.x, _ground - 320), Color("f4c542"))
				for i in range(3): _fee(world, rng.randf_range(left, right), host.view_top() - 30 - i * 60, 0.5, 22, "rock")
	state.x = clampf(state.x, left, right)
	state.fy = _ground + state.yo
	if state.yo > -60:
		for target in _living(host):
			if absf(target.p.x - float(state.x)) < 60 and target.p.y > _ground - 200:
				_hurt(host, target, state.x)
				if state.act == "charge":
					if target.get("host_player", false): host.velocity.x = state.vx * 0.9
					else: target.velocity.x = state.vx * 0.9
func attack(host, quake: bool = false) -> void:
	if quake or state.act == "slam":
		state.waves.append({"x": state.x - 70, "vx": -420.0, "t": 0.0})
		state.waves.append({"x": state.x + 70, "vx": 420.0, "t": 0.0})
		host.sfx("stomp")
		return
	var player := _nearest(host, state.x)
	if player.is_empty(): return
	for i in range(3): host.combat.bill(host, Vector2(state.x + state.face * 50, _ground - 240), Vector2(clampf(player.p.x + (i - 1) * 130 - state.x, -650, 650), -720 - i * 80), 1600, {"big": true})
	host.sfx("throw")
func _fee(world, x: float, y: float, warning: float, radius: float, kind: String) -> void:
	world.fees.append({"x": x, "y": y, "vy": 0.0, "t": 0.0, "warn": warning, "r": radius, "kind": kind, "dead": false})
func jar_tick(dt: float, host) -> String:
	var jar: Dictionary = state.get("jar", {})
	if jar.is_empty() or jar.got: return ""
	jar.t += dt
	if jar.y < _ground - 30 or jar.vy < 0:
		jar.vy += 2400 * dt
		jar.y += jar.vy * dt
		jar.x += jar.vx * dt
		if jar.y >= _ground - 30:
			jar.y = _ground - 30
			jar.vy = -jar.vy * 0.4 if absf(jar.vy) > 200 else 0.0
			jar.vx *= 0.5
	if jar.t > 0.6 + EPS and _living(host).any(func(p): return absf(p.p.x - jar.x) < 50):
		jar.got = true
		return "clear"
	return ""

func _living(host) -> Array:
	if host.has_method("combat_participants"):
		return host.combat_participants().filter(func(p): return not p.get("down", false) and p.hearts > 0)
	return [{"host_player": true, "p": host.player}] if host.hearts > 0 else []

func _nearest(host, x: float) -> Dictionary:
	var best: Dictionary = {}
	for player in _living(host):
		if best.is_empty() or absf(player.p.x - x) < absf(best.p.x - x): best = player
	return best

func _hurt(host, player: Dictionary, from_x: float) -> void:
	if player.get("host_player", false): host.hurt_player(from_x)
	else: host.hurt_combat_participant(player, from_x)
