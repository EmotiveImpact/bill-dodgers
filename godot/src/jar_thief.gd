extends RefCounted
## Stage 1-1 encounter. Positions are absolute world feet; all time is seconds.
## Events are drained by tick, including events queued by hit().
var state: Dictionary = {}
var rng := RandomNumberGenerator.new()
var _world := 0.0
var _view := 0.0
var _ground := 0.0
var _count := 1
var _events: Array[Dictionary] = []

func reset(world_width: float, view_width: float, ground_y: float, player_count: int = 1, random_seed: int = 1) -> void:
	_world = world_width
	_view = view_width
	_ground = ground_y
	_count = player_count
	rng.seed = random_seed
	var health := 90 if player_count > 1 else 70
	state = {"x": _world + 160.0, "fy": _ground, "hp": health, "max": health,
		"state": "enter", "t": 0.0, "face": -1, "flash": 0.0, "dizzy": 0.0,
		"waves": [], "next": 0.0, "pending_throw": false, "called": [false, false],
		"dz": false, "jar": {}}
	_events = [{"type": "warning"}]

func tick(dt: float, players: Array[Dictionary]) -> Array[Dictionary]:
	if state.is_empty():
		return []
	dt = maxf(0.0, dt)
	_update_boss(dt, players)
	_update_jar(dt, players)
	var result := _events
	_events = []
	return result

func _update_boss(dt: float, players: Array[Dictionary]) -> void:
	state.t += dt
	state.flash = maxf(0.0, state.flash - dt)
	state.dizzy = maxf(0.0, state.dizzy - dt)
	var left := _world - _view + 90.0
	var right := _world - 90.0
	var retained: Array = []
	for wave: Dictionary in state.waves:
		wave.x += wave.vx * dt
		wave.t += dt
		for i in players.size():
			var p := players[i]
			if p.get("alive", true) and absf(wave.x - p.position.x) < 24 and p.position.y > _ground - 30:
				_events.append({"type": "hurt_player", "player_index": i, "source_x": wave.x - wave.vx * 0.05})
		if wave.x > left - 100 and wave.x < right + 100:
			retained.append(wave)
	state.waves = retained
	if state.state == "down":
		if state.t > 1.5 and state.jar.is_empty():
			state.jar = {"x": state.x - 10, "y": _ground - 200, "vy": -900.0, "vx": -120.0, "t": 0.0, "got": false}
			_events.append({"type": "jar_spawn"})
		return
	var nearest_index := -1
	var distance := 1e9
	for i in players.size():
		if players[i].get("alive", true):
			var d := absf(players[i].position.x - state.x)
			if d < distance:
				distance = d
				nearest_index = i
	if nearest_index < 0:
		return
	var target: Vector2 = players[nearest_index].position
	var direction := signf(target.x - state.x)
	if state.state != "enter" and direction != 0:
		state.face = direction
	if state.state == "enter":
		state.x -= 300 * dt
		if state.x <= right - 180:
			state.state = "walk"
			state.t = 0.0
			state.next = 1.6
	elif state.dizzy > 0:
		pass
	elif state.state == "walk":
		if distance > 120:
			state.x += direction * 90 * dt
		if state.t > state.next:
			state.state = "throw" if rng.randf() < 0.55 else "stomp"
			state.t = 0.0
			state.pending_throw = true
	elif state.state == "throw" or state.state == "stomp":
		var frame := floori(state.t / 0.16)
		if frame >= 2 and state.pending_throw:
			state.pending_throw = false
			if state.state == "throw":
				for i in 3:
					var vx := clampf(target.x + (i - 1) * 120 - state.x, -600, 600)
					_events.append({"type": "bill", "position": Vector2(state.x + state.face * 40, _ground - 230), "velocity": Vector2(vx, -700 - i * 80), "gravity": 1600.0, "big": true})
			else:
				state.waves.append({"x": state.x - 60, "vx": -420.0, "t": 0.0})
				state.waves.append({"x": state.x + 60, "vx": 420.0, "t": 0.0})
				_events.append({"type": "stomp", "shake": 12})
		if frame >= 4:
			state.state = "walk"
			state.t = 0.0
			state.next = 1.3 + rng.randf() * 1.2
	state.x = clampf(state.x, left, right)
	var fraction: float = float(state.hp) / state.max
	if fraction < 0.66 and not state.called[0]:
		state.called[0] = true
		_spawn("l", "rush")
		_spawn("r", "throw")
		_events.append({"type": "backup"})
	if fraction < 0.5 and not state.dz:
		state.dz = true
		state.dizzy = 2.6
		state.state = "walk"
		_events.append({"type": "dizzy"})
	if fraction < 0.33 and not state.called[1]:
		state.called[1] = true
		_spawn("l", "flat")
		_spawn("r", "rush")
		if _count > 1:
			_spawn("r", "throw")
	if state.state != "enter":
		for i in players.size():
			if players[i].get("alive", true) and absf(players[i].position.x - state.x) < 62:
				_events.append({"type": "hurt_player", "player_index": i, "source_x": state.x})

func _spawn(side: String, kind: String) -> void:
	_events.append({"type": "spawn_bot", "side": side, "kind": kind})

func hit(shot_position: Vector2, _damage: int = 1) -> bool:
	# Original updateShots ignores s.dmg for this boss, including ability shots.
	if state.is_empty() or state.state == "enter" or state.state == "down":
		return false
	if not (absf(shot_position.x - state.x) < 70 and shot_position.y > _ground - 250 and shot_position.y < _ground):
		return false
	state.hp -= 2 if state.dizzy > 0 else 1
	state.flash = 0.08
	_events.append({"type": "hit", "position": shot_position})
	if state.hp <= 0:
		state.state = "down"
		state.t = 0.0
		state.waves = []
		_events.append({"type": "drop_coins", "position": Vector2(state.x, _ground - 160), "count": 16})
		_events.append({"type": "kill_bots"})
		_events.append({"type": "down", "shake": 16, "bus_delay": 1.5})
	return true

func _update_jar(dt: float, players: Array[Dictionary]) -> void:
	var jar: Dictionary = state.jar
	if jar.is_empty() or jar.got:
		return
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
		if players[i].get("alive", true) and absf(players[i].position.x - jar.x) < 50 and jar.t > 0.6:
			jar.got = true
			jar.by = i
			_events.append({"type": "clear", "player_index": i})
			# Source can clear twice in one multiplayer frame; emit once intentionally.
			break
