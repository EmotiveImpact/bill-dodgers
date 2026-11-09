extends RefCounted
## Stage 1-6 Binman Bot. Seconds, pixels/second, absolute world feet.
## Run the ordinary bot -> boss -> crate shot pass BEFORE tick(): bins are later.
## Players: position (feet), alive, height, crouching. Host owns invulnerability.
## Shots: mutable native bullets with p, life, enemy, damage; dead is also honored.
var state: Dictionary = {}
var rng := RandomNumberGenerator.new()
var _world := 0.0
var _view := 0.0
var _ground := 0.0
var _count := 1
var _time := 0.0
var _cleared := false
var _second_throws: Array[Dictionary] = []
var _events: Array[Dictionary] = []

func reset(world_width: float, view_width: float, ground_y: float, player_count: int = 1, random_seed: int = 1) -> void:
	_world = world_width
	_view = view_width
	_ground = ground_y
	_count = player_count
	_time = 0.0
	_cleared = false
	_second_throws = []
	rng.seed = random_seed
	var health := 340 if player_count > 1 else 260
	state = {"x": _world + 200.0, "fy": _ground, "hp": health, "max": health,
		"state": "enter", "t": 0.0, "face": -1, "flash": 0.0, "dizzy": 0.0,
		"waves": [], "bins": [], "rain": [], "next": 0.0, "lid": 0.0,
		"lid_t": 0.0, "phase": 1, "called": [false, false, false], "pending_throw": false}
	_events = [{"type": "warning"}]

func drain_events() -> Array[Dictionary]:
	var result := _events
	_events = []
	return result

func tick(dt: float, players: Array[Dictionary], shots: Array = [], view_top: float = 0.0, playing: bool = true) -> Array[Dictionary]:
	if state.is_empty(): return drain_events()
	dt = maxf(0.0, dt)
	_time += dt
	_update_second_throws(players)
	state.t += dt
	state.flash = maxf(0.0, state.flash - dt)
	state.lid_t = maxf(0.0, state.lid_t - dt)
	state.lid += ((1.0 if state.lid_t > 0 else 0.0) - state.lid) * minf(1.0, dt / 0.09)
	# Ama can set dizzy before the shot pass, but this boss clears it each update.
	state.dizzy = 0.0
	_update_waves(dt, players)
	_update_bins(dt, players, shots)
	_update_rain(dt, players)
	if state.state == "down":
		if state.t > 2.6 and playing and not _cleared:
			_cleared = true
			_events.append({"type": "clear"})
		return drain_events()
	var nearest := _nearest(players)
	if nearest < 0: return drain_events()
	var target: Vector2 = players[nearest].position
	var fraction: float = float(state.hp) / state.max
	state.phase = 1 if fraction > 0.66 else 2 if fraction > 0.33 else 3
	var direction := signf(target.x - state.x)
	if state.state != "enter" and direction != 0: state.face = direction
	var speed := 120.0 if state.phase == 3 else 80.0
	var gap := 0.9 if state.phase == 3 else 1.3 if state.phase == 2 else 1.7
	var left := _world - _view + 90.0
	var right := _world - 90.0
	if state.state == "enter":
		state.x -= 250.0 * dt
		if state.x <= right - 160.0:
			state.state = "walk"
			state.t = 0.0
			state.next = 1.4
			open_lid(1.4)
			_events.append({"type": "roar", "shake": 10})
	elif state.state == "walk":
		if absf(target.x - state.x) > 200.0: state.x += direction * speed * dt
		if state.t > state.next:
			var choice := rng.randf()
			state.state = "throw" if state.phase == 1 else ("roll" if choice < 0.5 else "throw") if state.phase == 2 else ("slam" if choice < 0.4 else "roll" if choice < 0.7 else "throw")
			state.t = 0.0
			state.pending_throw = true
	else:
		if state.t > 0.42 and state.pending_throw:
			state.pending_throw = false
			if state.state == "throw":
				throw_bin(target, false)
				if state.phase == 3: _second_throws.append({"at": _time + 0.26, "fallback": target})
			elif state.state == "roll":
				throw_bin(target, true)
			else:
				_events.append({"type": "stomp", "shake": 14})
				state.waves.append({"x": state.x - 80.0, "vx": -450.0, "t": 0.0})
				state.waves.append({"x": state.x + 80.0, "vx": 450.0, "t": 0.0})
				for i in 5:
					state.rain.append({"x": left + rng.randf() * (right - left), "y": view_top - 40.0 - i * 120.0, "vy": 0.0, "t": 0.0, "k": i % 3})
		if state.t > 0.82:
			state.state = "walk"
			state.t = 0.0
			state.next = gap + rng.randf() * 0.6
			open_lid(1.0 if state.phase == 2 else 1.2)
	# The original clamps entry too: its first live-player frame jumps to right.
	state.x = clampf(state.x, left, right)
	if fraction < 0.66 and not state.called[0]:
		state.called[0] = true
		_spawn("l", "rush")
		_spawn("r", "throw")
		_events.append({"type": "backup"})
		open_lid(2.4)
	if fraction < 0.33 and not state.called[1]:
		state.called[1] = true
		_spawn("l", "flat")
		_spawn("r", "rush")
		if _count > 1: _spawn("l", "fly")
		_events.append({"type": "furious"})
		open_lid(2.4)
	if state.state != "enter":
		for i in players.size():
			var p := players[i]
			if p.get("alive", true) and absf(p.position.x - state.x) < 210.0 * 0.42 and p.position.y > _ground - 260.0:
				_hurt(i, state.x, "body")
	return drain_events()

func open_lid(seconds: float) -> void:
	if not state.is_empty(): state.lid_t = seconds

func throw_bin(target: Vector2, rolling: bool = false) -> void:
	if state.is_empty() or state.state == "down": return
	var x: float = state.x + state.face * 60.0
	var bin: Dictionary = {"x": x, "rot": 0.0, "roll": rolling, "hp": 2, "t": 0.0}
	if rolling:
		bin.merge({"y": _ground - 40.0, "vx": state.face * (320.0 + rng.randf() * 100.0), "vy": 0.0})
	else:
		var tx := target.x + (rng.randf() - 0.5) * 120.0
		bin.merge({"y": _ground - 270.0, "vx": clampf((tx - x) / 1.1, -550.0, 550.0), "vy": -850.0})
	state.bins.append(bin)
	_events.append({"type": "throw", "position": Vector2(bin.x, bin.y), "rolling": rolling})

func hit(shot_position: Vector2, _damage: int = 1) -> bool:
	# Return CONSUMED, including the closed-lid clang. The original ignores dmg.
	if state.is_empty() or state.state in ["enter", "down"]: return false
	if absf(shot_position.x - state.x) > 105.0 or shot_position.y < _ground - 300.0 or shot_position.y > _ground: return false
	if state.lid < 0.6:
		_events.append({"type": "clang", "position": shot_position, "label": rng.randf() < 0.15})
		return true
	state.hp -= 2 if state.dizzy > 0 else 1
	state.flash = 0.08
	_events.append({"type": "hit", "position": shot_position, "boss_hits": 1})
	if state.hp <= 0: down()
	return true

func hit_shot(shot: Dictionary) -> bool:
	# Optional native-bullet adapter. Host still decides bot/boss/crate precedence.
	if not _live_shot(shot) or not hit(shot.p, int(shot.get("damage", 1))): return false
	_consume(shot)
	return true

func down() -> void:
	if state.is_empty() or state.state == "down": return
	state.state = "down"
	state.t = 0.0
	state.waves = []
	_second_throws = []
	_events.append({"type": "drop_coins", "position": Vector2(state.x, _ground - 160.0), "count": 16})
	_events.append({"type": "bits", "position": Vector2(state.x, _ground - 150.0)})
	_events.append({"type": "bits", "position": Vector2(state.x, _ground - 100.0)})
	_events.append({"type": "kill_bots"})
	_events.append({"type": "down", "shake": 16, "bus_delay": 1.5})

func _update_second_throws(players: Array[Dictionary]) -> void:
	if state.state == "down":
		_second_throws = []
		return
	var pending: Array[Dictionary] = []
	for item in _second_throws:
		if _time + 0.000000001 < item.at:
			pending.append(item)
			continue
		var nearest := _nearest(players)
		throw_bin(players[nearest].position if nearest >= 0 else item.fallback, false)
	_second_throws = pending

func _update_waves(dt: float, players: Array[Dictionary]) -> void:
	var retained: Array = []
	for wave: Dictionary in state.waves:
		wave.x += wave.vx * dt
		wave.t += dt
		for i in players.size():
			var p := players[i]
			if p.get("alive", true) and absf(wave.x - p.position.x) < 24.0 and p.position.y > _ground - 30.0:
				_hurt(i, wave.x - wave.vx * 0.05, "bin_marker" if wave.get("bin", false) else "wave")
		if wave.x > _world - _view - 30.0 and wave.x < _world + 30.0 and not wave.get("dead", false): retained.append(wave)
	state.waves = retained

func _update_bins(dt: float, players: Array[Dictionary], shots: Array) -> void:
	var retained: Array = []
	for bin: Dictionary in state.bins:
		bin.t += dt
		bin.rot += bin.vx * dt * 0.02
		if not bin.roll:
			bin.vy += 1700.0 * dt
			bin.x += bin.vx * dt
			bin.y += bin.vy * dt
			if bin.y >= _ground - 40.0:
				bin.y = _ground - 40.0
				bin.roll = true
				bin.vx = signf(bin.vx if bin.vx != 0 else state.face) * 300.0
				_events.append({"type": "bin_land", "position": Vector2(bin.x, _ground - 8.0), "shake": 5})
		else:
			bin.x += bin.vx * dt
		for i in players.size():
			var p := players[i]
			if not p.get("alive", true): continue
			var top: float = p.position.y - float(p.get("height", 180.0)) * (0.56 if p.get("crouching", false) else 0.86)
			if absf(bin.x - p.position.x) < 40.0 and p.position.y > bin.y - 40.0 and top < bin.y + 40.0:
				_hurt(i, bin.x, "bin")
				# A collision removes the bin even if the host rejects damage.
				bin.hp = 0
		for shot: Dictionary in shots:
			if _live_shot(shot) and absf(shot.p.x - bin.x) < 40.0 and absf(shot.p.y - bin.y) < 46.0:
				_consume(shot)
				bin.hp -= 1
				_events.append({"type": "bin_hit", "position": Vector2(bin.x, bin.y)})
				# Keep source order, including repeated rewards on overkill shots.
				if bin.hp <= 0:
					_events.append({"type": "bits", "position": Vector2(bin.x, bin.y)})
					_events.append({"type": "drop_coins", "position": Vector2(bin.x, bin.y - 10.0), "count": 2})
		if bin.x < _world - _view - 50.0 or bin.x > _world + 50.0: bin.hp = 0
		if bin.hp > 0: retained.append(bin)
	state.bins = retained
	state.waves = state.waves.filter(func(w): return not w.get("bin", false))
	for bin: Dictionary in state.bins:
		if bin.roll: state.waves.append({"x": bin.x, "vx": 0.0, "t": 0.0, "bin": true})

func _update_rain(dt: float, players: Array[Dictionary]) -> void:
	var retained: Array = []
	for item: Dictionary in state.rain:
		item.vy += 1800.0 * dt
		item.y += item.vy * dt
		item.t += dt
		if item.y > _ground - 14.0:
			item.dead = true
			_events.append({"type": "rain_land", "position": Vector2(item.x, _ground - 10.0)})
		for i in players.size():
			var p := players[i]
			if p.get("alive", true) and absf(item.x - p.position.x) < 28.0 and item.y > p.position.y - float(p.get("height", 180.0)) * 0.86 and item.y < p.position.y:
				_hurt(i, item.x, "rain")
				item.dead = true
		if not item.get("dead", false): retained.append(item)
	state.rain = retained

func _nearest(players: Array[Dictionary]) -> int:
	var nearest := -1
	var distance := INF
	for i in players.size():
		if not players[i].get("alive", true): continue
		var d := absf(players[i].position.x - state.x)
		if d < distance:
			distance = d
			nearest = i
	return nearest

func _live_shot(shot: Dictionary) -> bool:
	return not shot.get("enemy", false) and not shot.get("dead", false) and float(shot.get("life", 1.0)) > 0.0

func _consume(shot: Dictionary) -> void:
	shot.dead = true
	shot.life = 0.0

func _hurt(index: int, source_x: float, hazard: String) -> void:
	_events.append({"type": "hurt_player", "player_index": index, "source_x": source_x, "hazard": hazard})

func _spawn(side: String, kind: String) -> void:
	_events.append({"type": "spawn_bot", "side": side, "kind": kind})
