extends RefCounted
## Actual configurable World 3 encounter, not the dormant Jar Thief code.
## Source game/3-*/index.html:1350–1395 and shared updateJar:618–622.
## Caller ticks boss AFTER levelUpdate, then jar; hit() runs earlier in shots.
const EPS := 0.000000001
var state: Dictionary = {}
var rng := RandomNumberGenerator.new()
var _view := 738.0
var _ground := 482.0
var _count := 1
var _stage: Dictionary = {}
var _tents := false
var _events: Array[Dictionary] = []
var _mini_reported := false

func reset(config: Dictionary, view_width: float = 738, ground_y: float = 482, participants: int = 1, random_seed: int = 31, stage: Dictionary = {}, tents: bool = false) -> void:
	_view = view_width
	_ground = ground_y
	_count = maxi(1, participants)
	_stage = stage
	_tents = tents
	rng.seed = random_seed
	_mini_reported = false
	var maximum: int = config.hp2 if _count > 1 else config.hp
	state = {"cfg": config.duplicate(true), "kind": config.kind, "name": config.name, "cam": float(config.cam),
		"x": float(config.cam) + _view + 160, "fy": _ground, "hp": maximum, "max": maximum,
		"state": "enter", "t": 0.0, "face": -1, "flash": 0.0, "dizzy": 0.0, "waves": [],
		"next": 0.0, "pending_throw": false, "called": [false, false], "stage_t": 0.0, "land_t": 0.0, "jar": {}}
	_events = [{"type": "warning", "sub": str(config.get("sub", config.name)), "music": true}]

func drain_events() -> Array[Dictionary]:
	var result := _events
	_events = []
	return result

func boss_tick(dt: float, players: Array[Dictionary]) -> Array[Dictionary]:
	if not state.is_empty(): _update_boss(maxf(dt, 0), players)
	return drain_events()

func jar_tick(dt: float, players: Array[Dictionary]) -> Array[Dictionary]:
	if not state.is_empty(): _update_jar(maxf(dt, 0), players)
	return drain_events()

func tick(dt: float, players: Array[Dictionary]) -> Array[Dictionary]:
	var events := boss_tick(dt, players)
	events.append_array(jar_tick(dt, players))
	return events

func _update_boss(dt: float, players: Array[Dictionary]) -> void:
	state.t += dt
	for timer in ["land_t", "flash", "dizzy"]:
		state[timer] = maxf(0, state[timer] - dt)
		if state[timer] <= EPS: state[timer] = 0.0
	var left: float = state.cam + 90
	var right: float = state.cam + _view - 90
	# Fraction and on-stage are snapshots; later branches intentionally use
	# the pre-transition values, preserving the source's early-return ordering.
	var fraction: float = float(state.hp) / float(state.max)
	for wave in state.waves:
		wave.x += wave.vx * dt
		wave.t += dt
		for i in players.size():
			var player: Dictionary = players[i]
			if player.get("alive", true) and absf(wave.x - player.position.x) < 24 and player.position.y > _ground - 30:
				_hurt(i, wave.x - wave.vx * 0.05)
	state.waves = state.waves.filter(func(wave): return wave.x > left - 100 and wave.x < right + 100)
	if state.state == "down":
		if state.cfg.get("mini", false):
			if state.t > 1.8 + EPS and not _mini_reported:
				_mini_reported = true
				_events.append({"type": "mini_done"})
			return
		if state.t > 1.5 + EPS and state.jar.is_empty():
			state.jar = {"x": state.x - 10, "y": state.fy - 200, "vy": -900.0, "vx": -120.0, "t": 0.0, "got": false}
			_events.append({"type": "jar_spawn"})
		return
	var nearest := -1
	var distance := INF
	for i in players.size():
		if not players[i].get("alive", true): continue
		var d := absf(players[i].position.x - state.x)
		if d < distance:
			distance = d
			nearest = i
	if nearest < 0: return
	var target: Vector2 = players[nearest].position
	if state.has("hop"):
		var hop: Dictionary = state.hop
		hop.t += dt
		var k := minf(1, hop.t / hop.duration)
		state.x = lerpf(hop.start.x, hop.end.x, k)
		state.fy = lerpf(hop.start.y, hop.end.y, k) - sin(PI * k) * hop.height
		if k >= 1:
			state.erase("hop")
			state.fy = hop.end.y
			if hop.get("slam", false):
				state.land_t = 0.32
				_stomp(460, 14)
			state.state = "walk"
			state.t = 0.0
			state.next = 0.9
		return
	if state.state not in ["enter", "charge"] and target.x != state.x: state.face = signf(target.x - state.x)
	var on_stage: bool = state.fy < _ground - 10
	if state.state == "enter":
		state.x -= 300 * dt
		if state.x <= right - 180:
			state.state = "walk"
			state.t = 0.0
			state.next = 1.6
	elif state.dizzy > 0: pass
	elif state.state == "walk":
		if not on_stage and distance > 120: state.x += signf(target.x - state.x) * 90 * dt
		if state.t > state.next + EPS:
			state.t = 0.0
			state.pending_throw = true
			var choice := rng.randf()
			if state.kind == "tout" and fraction < 0.66 and fraction >= 0.33 and not on_stage and state.stage_t <= 0 and not _stage.is_empty():
				var row: Array = _stage.row
				_hop(Vector2((float(row[0]) + float(row[1])) / 2, row[2]), 0.8, 160)
				state.stage_t = 9.0
				return
			if on_stage and state.stage_t <= 0:
				_hop(Vector2(target.x, _ground), 0.9, 140, true)
				state.stage_t = 6.0
				return
			if state.kind == "tout" and fraction < 0.33 and choice < 0.4:
				_hop(Vector2(clampf(target.x, left, right), _ground), 0.85, 230, true)
				return
			if state.kind == "bailiff" and choice < 0.45:
				state.state = "charge"
				state.face = signf(target.x - state.x) if target.x != state.x else -1
				return
			state.state = "throw" if choice < (0.85 if on_stage else 0.55) else "stomp"
	elif state.state == "charge":
		state.x += state.face * 500 * dt
		if state.x <= left + 2 or state.x >= right - 2 or state.t > 2.6 + EPS:
			state.state = "walk"
			state.t = 0.0
			state.next = 0.9
			_events.append({"type": "stomp", "shake": 8})
	elif state.state in ["throw", "stomp"]:
		var frame := floori((state.t + EPS) / 0.16)
		if frame >= 2 and state.pending_throw:
			state.pending_throw = false
			if state.state == "throw":
				_events.append({"type": "throw"})
				var count := 3 if state.kind == "bailiff" else (5 if on_stage else (4 if fraction < 0.33 else 3))
				var tie: bool = state.kind != "bailiff"
				for i in count:
					var vx := clampf(target.x + (i - (count - 1) / 2.0) * 110 - state.x, -600, 600)
					_events.append({"type": "bill", "position": Vector2(state.x + state.face * 40, state.fy - 230), "velocity": Vector2(vx, -700 - i * 60), "gravity": 1600.0, "big": not tie, "tie": tie})
			elif not on_stage: _stomp(420, 12)
			else: _events.append({"type": "stomp", "shake": 12})
		if frame >= 4:
			state.state = "walk"
			state.t = 0.0
			state.next = (0.9 if fraction < 0.33 else 1.3) + rng.randf() * 1.1
	state.stage_t -= dt
	# This deliberately clamps ENTER on the first tick before it has walked
	# in. Do not move the clamp into the walk-only branch.
	if not on_stage: state.x = clampf(state.x, left, right)
	if fraction < 0.66 and not state.called[0]:
		state.called[0] = true
		_spawn("t" if _tents else "l", "rush")
		_spawn("r", "throw")
		_events.append({"type": "backup"})
	if fraction < 0.5 and not state.get("dz", false):
		state.dz = true
		state.dizzy = 2.6
		state.state = "walk"
		_events.append({"type": "dizzy"})
	if fraction < 0.33 and not state.called[1]:
		state.called[1] = true
		_spawn("l", "flat")
		_spawn("r", "rush")
		if _count > 1: _spawn("r", "throw")
	if state.state != "enter":
		for i in players.size():
			if players[i].get("alive", true) and absf(players[i].position.x - state.x) < 62 and absf(players[i].position.y - state.fy) < 120: _hurt(i, state.x)

func _hop(target: Vector2, duration: float, height: float, slam: bool = false) -> void:
	state.hop = {"start": Vector2(state.x, state.fy), "end": target, "t": 0.0, "duration": duration, "height": height, "slam": slam}

func _stomp(speed: float, shake: int) -> void:
	state.waves.append({"x": state.x - 60, "vx": -speed, "t": 0.0})
	state.waves.append({"x": state.x + 60, "vx": speed, "t": 0.0})
	_events.append({"type": "stomp", "shake": shake})

func _spawn(side: String, kind: String) -> void:
	_events.append({"type": "spawn_bot", "side": side, "kind": kind})

func _hurt(index: int, from_x: float) -> void:
	_events.append({"type": "hurt_player", "player_index": index, "source_x": from_x})

func hit(point: Vector2, _damage: int = 1) -> bool:
	if state.is_empty() or state.state in ["enter", "down"]: return false
	if not (absf(point.x - state.x) < 70 and point.y > state.fy - 250 and point.y < state.fy): return false
	# Includes specials represented as invisible ghost shots. No weak-point
	# multiplier other than dizzy, and no dependency on the bullet damage field.
	state.hp -= 2 if state.dizzy > 0 else 1
	state.flash = 0.08
	_events.append({"type": "hit", "position": point, "cheer": 0.6})
	if state.hp <= 0: _down()
	return true

func _down() -> void:
	state.state = "down"
	state.t = 0.0
	state.waves = []
	state.erase("hop")
	_events.append({"type": "drop_coins", "position": Vector2(state.x, state.fy - 160), "count": 16})
	_events.append({"type": "kill_bots"})
	_events.append({"type": "down", "shake": 16, "name": state.name, "mini": true if state.cfg.get("mini", false) else false, "music": false})

func _update_jar(dt: float, players: Array[Dictionary]) -> void:
	var jar: Dictionary = state.jar
	if jar.is_empty() or jar.got: return
	jar.t += dt
	if jar.y < _ground - 30 or jar.vy < 0:
		jar.vy += 2400 * dt
		jar.y += jar.vy * dt
		jar.x += jar.vx * dt
		if jar.y >= _ground - 30:
			jar.y = _ground - 30
			jar.vy = -jar.vy * 0.4 if absf(jar.vy) > 200 else 0.0
			jar.vx *= 0.5
	for i in players.size():
		if players[i].get("alive", true) and absf(players[i].position.x - jar.x) < 50 and jar.t > 0.6 + EPS:
			jar.got = true
			jar.by = i
			_events.append({"type": "clear", "player_index": i})
			break # One native settlement; source loops can emit duplicate co-op clears.
