extends RefCounted
## Three authored Cardboard King phases. Source W5.kingShape/kingHurt/updateKing.
## Delayed helpers and double-stomp use run-local simulation timers: paused and
## discarded with this object, unlike the source's unguarded wall-clock timeouts.
const PHASES := [{"cols": 2, "rows": 2, "hp": 26, "speed": 70}, {"cols": 3, "rows": 3, "hp": 32, "speed": 85}, {"cols": 4, "rows": 3, "hp": 38, "speed": 100}]
const EPS := 0.000000001
var state: Dictionary = {}
var rng := RandomNumberGenerator.new()
var _world := 4400.0
var _view := 738.0
var _ground := 482.0
var _count := 1
var _events: Array = []
var _helpers := -1.0
var _double_stomp := -1.0
func reset(world_width: float, view_width: float = 738, ground: float = 482, participants: int = 1, seed_value: int = 51) -> void:
	_world = world_width; _view = view_width; _ground = ground; _count = maxi(1, participants); rng.seed = seed_value
	_helpers = -1; _double_stomp = -1
	state = {"x": _world + 200, "fy": ground, "hp": 1, "max": 1, "state": "enter", "t": 0.0, "face": -1, "flash": 0.0, "dizzy": 0.0, "waves": [], "phase": 0, "armour": false, "flying": [], "next": 0.0, "jar": {}, "name": "Cardboard King", "kind": "king"}
	_set_phase(0)
	_events = [{"type": "warning", "text": "Warning! The Cardboard King"}]
func shape() -> Dictionary:
	var p: Dictionary = PHASES[state.phase]
	var boxes: Array = []
	var wob := sin(float(state.t) / 0.12) if state.state == "walk" else 0.0
	for i in 2: boxes.append({"dx": (1 if i else -1) * 58 * 0.55, "dy": 0.0, "w": 44.0, "h": 46 + (wob if i else -wob) * 4, "key": "box3"})
	for r in int(p.rows):
		for c in int(p.cols): boxes.append({"dx": (c - (p.cols - 1) / 2.0) * 58 + (6 if r % 2 else -6), "dy": -46 - r * 46, "w": 58.0, "h": 46.0, "key": "box1" if (r + c) % 3 else "box2"})
	var top: float = -46 - (p.rows - 1) * 46 - 46
	for side in [-1, 1]: boxes.append({"dx": side * (p.cols / 2.0 * 58 + 26), "dy": top + 46 * 1.2 - (46 if state.state in ["throw", "stomp"] else 0), "w": 44.0, "h": 60.0, "key": "box3"})
	boxes.append({"dx": 0.0, "dy": top, "w": 76.0, "h": 64.0, "key": "box2", "head": true})
	return {"boxes": boxes, "top": top - 64, "hw": p.cols / 2.0 * 58 + 30}
func _set_phase(n: int) -> void:
	state.phase = n; state.name = "Cardboard King %d/3" % (n + 1); state.hp = int(floorf(PHASES[n].hp * (1.3 if _count > 1 else 1.0) + 0.5)); state.max = state.hp
	var sh := shape(); state.hw = sh.hw; state.hh = -sh.top; state.crown_y = _ground + sh.top + 70
func hit(point: Vector2, _damage: int = 1) -> bool:
	if state.is_empty() or state.state in ["down", "enter"] or state.armour or absf(point.x - state.x) >= state.hw or point.y <= _ground - state.hh or point.y >= _ground: return false
	# Source boss ignores projectile dmg, but doubles dizzy AND crown strikes.
	state.hp -= (2 if state.dizzy > 0 else 1) * (2 if point.y < state.crown_y else 1)
	state.flash = 0.08; _events.append({"type": "hit"})
	if state.hp <= 0: _phase_down()
	return true
func _phase_down() -> void:
	if state.phase >= 2:
		state.state = "down"; state.t = 0.0; state.waves = []; _helpers = -1; _double_stomp = -1
		_events.append_array([{"type": "down"}, {"type": "coins", "position": Vector2(state.x, _ground - 160), "count": 16}, {"type": "kill_bots"}]); return
	state.state = "collapse"; state.t = 0.0; state.armour = true
	_events.append_array([{"type": "stomp"}, {"type": "coins", "position": Vector2(state.x, _ground - 120), "count": 10}])
	state.flying = []
	for q in shape().boxes: state.flying.append({"p": Vector2(state.x + q.dx, _ground + q.dy - q.h / 2), "v": Vector2(rng.randf_range(-500, 500), rng.randf_range(-900, -400)), "angle": 0.0, "vr": rng.randf_range(-20, 20), "key": q.key, "rest": false})
	_helpers = 0.9
func drain_events() -> Array:
	var out := _events; _events = []; return out
func boss_tick(dt: float, players: Array, bots_alive: bool = false) -> Array:
	if state.is_empty(): return []
	state.t += dt; state.flash = maxf(0, state.flash - dt); state.dizzy = maxf(0, state.dizzy - dt)
	if _helpers >= 0:
		_helpers -= dt
		if _helpers <= EPS:
			_helpers = -1
			if state.state == "collapse": _events.append({"type": "helpers", "count": (3 if _count > 1 else 2) + state.phase, "x": state.x})
	if _double_stomp >= 0:
		_double_stomp -= dt
		if _double_stomp <= EPS:
			_double_stomp = -1
			if state.state == "walk": _stomp(360)
	var left := _world - _view + 110
	var right := _world - 110
	for wave in state.waves:
		wave.x += wave.vx * dt; wave.t += dt
		for i in players.size():
			if absf(wave.x - players[i].p.x) < 24 and players[i].p.y > _ground - 30: _events.append({"type": "hurt_player", "index": i, "source_x": wave.x - wave.vx * 0.05})
	state.waves = state.waves.filter(func(w): return w.x > left - 120 and w.x < right + 120)
	for f in state.flying:
		if f.rest: continue
		f.v.y += 2600 * dt; f.p += f.v * dt; f.angle += f.vr * dt
		if f.p.y > _ground - 24:
			f.p.y = _ground - 24; f.v.y *= -0.3; f.v.x *= 0.6
			if absf(f.v.y) < 100: f.rest = true
	if state.state == "down":
		if state.t > 1.5 + EPS and state.jar.is_empty(): state.jar = {"x": state.x - 10, "y": _ground - 200, "vy": -900.0, "vx": -120.0, "t": 0.0, "got": false}; _events.append({"type": "jar_spawn"})
		return drain_events()
	if state.state == "collapse":
		if state.t > 2.2 + EPS and (not bots_alive or state.t > 9 + EPS): state.state = "rebuild"; state.t = 0.0; _events.append({"type": "warning", "text": "He is rebuilding!"})
		return drain_events()
	if state.state == "rebuild":
		var k := minf(1, state.t / 1.6)
		for f in state.flying: f.p += (Vector2(state.x, _ground - 160) - f.p) * k * 0.08; f.angle *= 0.9
		if state.t > 1.7 + EPS:
			state.flying = []; _set_phase(state.phase + 1); state.state = "walk"; state.t = 0.0; state.armour = false; state.next = 1.2
			_events.append({"type": "warning", "text": "Phase %d: %s" % [state.phase + 1, "Aim for the crown!" if state.phase == 2 else "Bigger, and now he stomps"]})
		return drain_events()
	var target: Dictionary = {}
	for p in players:
		if target.is_empty() or absf(p.p.x - state.x) < absf(target.p.x - state.x): target = p
	if target.is_empty(): return drain_events()
	if state.state != "enter" and target.p.x != state.x: state.face = signf(target.p.x - state.x)
	if state.state == "enter":
		state.x -= 300 * dt
		if state.x <= right - 160: state.state = "walk"; state.t = 0.0; state.next = 1.5
	elif state.state == "walk":
		if absf(target.p.x - state.x) > 150: state.x += signf(target.p.x - state.x) * PHASES[state.phase].speed * dt
		if state.t > state.next + EPS:
			var r := rng.randf()
			state.state = "throw" if state.phase == 0 or r < 0.45 else ("stomp" if r < 0.8 or state.phase < 2 else "charge")
			state.t = 0.0; state.pending = true
	elif state.state in ["throw", "stomp"]:
		if state.t + EPS >= 0.34 and state.pending:
			state.pending = false
			if state.state == "throw":
				_events.append({"type": "throw"})
				var n: int = state.phase + 2
				for i in n:
					var x: float = target.p.x + (i - (n - 1) / 2.0) * 130
					_events.append({"type": "bill", "position": Vector2(state.x + state.face * 50, _ground - state.hh + 40), "velocity": Vector2(clampf((x - state.x) / 1.05, -650, 650), -750 - i * 60), "gravity": 1600.0})
			else:
				_stomp(440)
				if state.phase == 2: _double_stomp = 0.65
		if state.t + EPS >= 0.68: state.state = "walk"; state.t = 0.0; state.next = 1.5 + rng.randf() * 1.2 - state.phase * 0.25
	elif state.state == "charge":
		if state.t < 0.7:
			if int(state.t / 0.12) % 2: state.flash = 0.06
			state.cdir = state.face
		else:
			state.x += state.cdir * 550 * dt
			if state.x <= left or state.x >= right or state.t > 2.6 + EPS: state.state = "walk"; state.t = 0.0; state.next = 1.4; state.dizzy = 1.6; _events.append({"type": "stomp"})
	state.x = clampf(state.x, left, right)
	if state.state != "enter":
		for i in players.size():
			if absf(players[i].p.x - state.x) < state.hw - 14 and players[i].p.y > _ground - state.hh + 30: _events.append({"type": "hurt_player", "index": i, "source_x": state.x})
	return drain_events()
func _stomp(speed: float) -> void:
	state.waves.append_array([{"x": state.x - 70, "vx": -speed, "t": 0.0}, {"x": state.x + 70, "vx": speed, "t": 0.0}]); _events.append({"type": "stomp"})
func jar_tick(dt: float, players: Array) -> Array:
	var jar: Dictionary = state.get("jar", {})
	if jar.is_empty() or jar.got: return drain_events()
	jar.t += dt
	if jar.y < _ground - 30 or jar.vy < 0:
		jar.vy += 2400 * dt; jar.y += jar.vy * dt; jar.x += jar.vx * dt
		if jar.y >= _ground - 30: jar.y = _ground - 30; jar.vy = -jar.vy * 0.4 if absf(jar.vy) > 200 else 0.0; jar.vx *= 0.5
	for p in players:
		if absf(p.p.x - jar.x) < 50 and jar.t > 0.6 + EPS: jar.got = true; _events.append({"type": "clear"}); break
	return drain_events()
