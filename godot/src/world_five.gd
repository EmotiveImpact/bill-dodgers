extends RefCounted
## Moving Day source runtime, game/5-*/index.html W5. Feet are absolute pixels;
## clocks seconds, velocities px/s. Mutable surfaces are never imported META.
const SUPPORTED_LEVELS := ["5-1", "5-2", "5-3", "5-4", "5-5", "5-6", "5-S"]
const WIPE_CALLBACK := 1.43
const WIPE_OPEN_START := 1.57
const WIPE_DURATION := 2.17
const EPS := 0.000000001
var rng := RandomNumberGenerator.new()
var level_id := ""
var run_generation := 0
var _active := false
var _host_id := 0
var _surfaces: Array = []
var _scenes: Array = []
var mimics: Array = []
var drops: Array = []
var shutters: Array = []
var movers: Array = []
var beams: Array = []
var sofa: Dictionary = {}
var lift: Dictionary = {}
var checkpoint: Dictionary = {}
var safe_position := Vector2.ZERO
var level_time := 0.0
var elapsed := 0.0
var clock_left := 0.0
var end_time := 0.0
var clear_reported := false
var carrying := false
var flag_time := 0.0
var scene_index := 0
var wiping := false
var wipe_elapsed := 0.0
var wipe_midpoint_done := false
var wipe_kind := ""
var wipe_label := ""
var wipe_focus_start := Vector2.ZERO
var wipe_focus_end := Vector2.ZERO
var _wipe_generation := -1
var _wipe_scene: Dictionary = {}
var _wipe_callback_due := false
var _wipe_open_captured := false
var controls: Dictionary = {}

func supports(id: String) -> bool: return id in SUPPORTED_LEVELS
func reset(host, seed_value: int = 51) -> void:
	invalidate_run()
	level_id = host.level_id
	_host_id = host.get_instance_id()
	_active = supports(level_id)
	rng.seed = seed_value
	_surfaces.clear()
	for rows in [host.level.get("solids", []), host.level.get("plats", [])]:
		for row in rows:
			var q := {"row": row.duplicate(true), "plat": rows == host.level.get("plats", [])}
			if row.size() > 3 and row[3] is Dictionary: q.merge(row[3].duplicate(true), true)
			_surfaces.append(q)
	_scenes = host.level.get("scenes", []).duplicate(true)
	for s in _scenes: s.done = false
	mimics.clear(); drops.clear(); shutters.clear(); beams.clear(); movers.clear()
	checkpoint = {}; sofa = {}; lift = {}; carrying = false
	level_time = 0; elapsed = 0; end_time = 0; flag_time = 0; clear_reported = false
	scene_index = 0; wipe_elapsed = 0; wipe_midpoint_done = false
	wipe_kind = ""; wipe_label = ""; controls = {}
	clock_left = float(host.level.get("clock", 0)) / 1000.0
	safe_position = host.player
	for m in host.level.get("mimics", []):
		mimics.append({"x": float(m[0]), "surface": below(host, m[0], float(m[1]) - 4), "type": str(m[2]) if m.size() > 2 else ("rush" if rng.randf() < 0.6 else "throw"), "sprung": false, "t": rng.randf()})
	for d in host.level.get("drops", []): drops.append({"x": float(d[0]), "top": float(d[1]), "state": "wait", "t": 0.0, "y": 0.0, "vy": 0.0})
	for s in host.level.get("shutters", []): shutters.append({"x": float(s[0]), "top": float(s[1]), "open": 0.0, "want": 0.0, "t": 0.0})
	for q in _surfaces:
		if q.get("slot", false): q.off = true; q.vx = 0.0; movers.append(q)
		if q.get("lift", false): lift = {"surface": q, "state": "wait", "t": 0.0, "floor": 0, "from": float(q.row[2]), "to": float(q.row[2]), "dir": 1}
	if host.level.has("sofa"):
		var start: float = host.level.sofa.x
		var q := below(host, start, float(host.meta.ground) - 3000)
		sofa = {"x": start, "w": 236.0, "tip": false, "tip_t": 0.0, "lift": 0.0, "off": 0.0, "carriers": [], "fy": float(q.row[2]) if not q.is_empty() else float(host.meta.ground), "door": null}

func party_start(host) -> void:
	# Source resolves each slot against the world, never against P1's roof.
	for p in _all(host):
		if p.get("host_player", false): continue
		var q := below(host, p.p.x, float(host.meta.ground) - (10 if host.level.get("vert", false) else 3000))
		p.p.y = float(host.meta.ground) if q.is_empty() else float(q.row[2])
		p.safe_position = p.p; p.checkpoint = p.p; p.px = p.p.x
		_set_carry(host, p, false)

func seed_pickups(host) -> void:
	for c in host.level.get("coins", []): host.coins.append({"p": Vector2(c[0], c[1]), "v": Vector2.ZERO, "age": 0.3, "rest": true, "stay": true})

func invalidate_run() -> void:
	run_generation += 1; _active = false; wiping = false
	_wipe_generation = -1; _wipe_scene = {}; _wipe_callback_due = false; _wipe_open_captured = false
func _can_step(host) -> bool:
	var final_step: bool = host.mode in ["clear", "story"] and host.has_method("family_base_step_active") and host.family_base_step_active(5)
	return _active and host.get_instance_id() == _host_id and host.level_id == level_id and (host.mode == "play" or final_step)
func surfaces(_host, skip_platforms: bool = false) -> Array:
	return _surfaces.filter(func(q): return not q.get("off", false) and (not skip_platforms or not q.plat))
func land_on(host, x: float, old_y: float, new_y: float, skip: bool = false) -> Dictionary:
	var best: Dictionary = {}
	for q in surfaces(host, skip):
		if x >= q.row[0] and x <= q.row[1] and q.row[2] >= old_y - 1 and q.row[2] <= new_y + 0.5 and (best.is_empty() or q.row[2] < best.row[2]): best = q
	return best
func below(host, x: float, y: float) -> Dictionary:
	var best: Dictionary = {}
	for q in surfaces(host):
		if x >= q.row[0] and x <= q.row[1] and q.row[2] >= y - 2 and (best.is_empty() or q.row[2] < best.row[2]): best = q
	return best
func wall_clamp(host, x0: float, x1: float, feet: float) -> float:
	for q in surfaces(host, true):
		if q.row[2] >= feet - 15: continue
		if x1 > x0 and x0 <= q.row[0] and x1 > q.row[0] - 14: x1 = minf(x1, q.row[0] - 14)
		if x1 < x0 and x0 >= q.row[1] and x1 < q.row[1] + 14: x1 = maxf(x1, q.row[1] + 14)
	return x1
func inside_wall(host, point: Vector2) -> bool:
	return surfaces(host, true).any(func(q): return point.x > q.row[0] and point.x < q.row[1] and point.y > q.row[2] + 4)
func base_displacement(dt: float, _host, move: float) -> float: return move * 270 * (0.78 if carrying else 1.0) * dt
func carry_player(dt: float, host) -> void:
	# W5 carry belongs AFTER wall clamp/support and BEFORE gravity, not W3's seam.
	if not host.grounded: return
	var q := land_on(host, host.player.x, host.player.y - 2, host.player.y + 2)
	if not q.is_empty(): host.player.x += (float(q.get("push", 0)) * 1000 + float(q.get("vx", 0))) * dt
func landing(host, surface: Dictionary) -> void:
	if not surface.is_empty() and surface.get("bounce", false):
		host.velocity.y = -1420; host.grounded = false; surface.squash = 1.0; host.sfx("jump")
func after_motion(host) -> void:
	if not host.grounded or host.on_platform: return
	var q := below(host, host.player.x, host.player.y)
	if not q.is_empty() and host.player.x > q.row[0] + 90 and host.player.x < q.row[1] - 90: safe_position = host.player
func camera_cap(_host) -> float: return maxf(0, float(sofa.x) - 150) if not sofa.is_empty() else INF
func receipt_position(row: Array) -> Vector2: return Vector2(row[0], row[1])
func corrected_receipt_position(host, index: int) -> Vector2:
	var row: Array = host.level.receipts[index]
	# Original x=-250 is outside the nonnegative-camera actor clamp. Keep
	# original JSON/save index; expose the first secret at reachable x=60.
	return Vector2(60 if index == 0 and level_id in ["5-1", "5-2", "5-4", "5-6"] and float(row[0]) == -250 else row[0], row[1])
func receipt_reward() -> int: return 0
func finds_near(host, point: Vector2) -> bool: return host.hearts > 0 and absf(host.player.x - point.x) < 36 and absf(host.player.y - point.y) < 90
func at_end(host) -> bool:
	if host.level.get("timed", 0): return level_time * 1000 + EPS >= float(host.level.timed)
	if host.level.get("vert", false): return _living(host).any(func(p): return p.p.y <= float(host.level.goalY) + 4)
	if host.level.get("clock", 0) and clock_left <= 0: return true
	if not sofa.is_empty(): return sofa.x >= host.level.sofa.end and host.camera.x >= float(host.level.w) - host.view_width() - 2
	return host.camera.x >= float(host.level.w) - host.view_width() - 2
func objective_tick(dt: float, host) -> String:
	if not _can_step(host) or clear_reported: return ""
	var result := ""
	if at_end(host) and host.combat.waves.all(func(w): return w.done) and end_time == 0 and host.boss == null:
		if host.level.get("king", false): host.combat.start_boss(host)
		else: end_time = 0.001; result = "ending"
	if end_time > 0:
		end_time += dt
		if end_time > 2.6 + EPS: clear_reported = true; return "clear"
	return result
func before_camera(dt: float, host, input: Dictionary = {}) -> void:
	if not _can_step(host): return
	controls = input
	level_time += dt; elapsed = level_time
	if wiping: wipe_elapsed += dt; _wipe_callback_due = not wipe_midpoint_done and wipe_elapsed + EPS >= WIPE_CALLBACK
	for s in _scenes:
		if not s.done and not wiping and _living(host).any(func(p): return p.p.x >= s.x) and (sofa.is_empty() or sofa.x >= s.x - 260):
			s.done = true; _start_wipe(host, s); break
	if host.level.get("check", 0) and checkpoint.is_empty():
		for p in _living(host):
			if p.p.x > host.level.check:
				checkpoint = {"x": float(host.level.check), "y": p.p.y}; flag_time = 0.001
				# Source heals the complete roster, including a downed mate.
				for q in _all(host):
					if q.get("host_player", false): host.hearts = 3; host.invincible = 1.2
					else: q.hearts = 3; q.down = false; q.invincible = 1.2
				host.status = "Halfway! Full hearts."; host.sfx("power")
				if host.has_method("hud_banner"): host.hud_banner("Halfway!", "Checkpoint: everyone back to full hearts")
				break
	if flag_time > 0: flag_time += dt
	if host.level.get("clock", 0): clock_left = maxf(0, clock_left - dt)
	for m in mimics:
		m.t += dt
		if m.sprung or m.surface.is_empty(): continue
		var p := _nearest(host, m.x)
		if not p.is_empty() and absf(p.p.x - m.x) < 250 and absf(p.p.y - m.surface.row[2]) < 160:
			m.sprung = true
			var b: Dictionary = host.combat.new_bot(host, m.x, m.surface, m.type, {"entered": true})
			b.hop = {"start": b.p, "end": b.p + Vector2(20 if p.p.x > m.x else -20, 0), "t": 0.0, "duration": 0.42, "segment": m.surface.row, "surface": m.surface}
			host.status = "Surprise!"; host.sfx("pop")
	_tick_drops(dt, host)
	for s in shutters:
		s.t += dt; s.open = move_toward(s.open, s.want, dt / 0.45)
		if s.want == 1 and s.t > 2.6 + EPS: s.want = 0.0
	for b in host.enemies:
		if b.get("hidden", 0): b.hidden = maxf(0, float(b.hidden) - dt)
		if b.state == "pop" or b.get("big", false): continue
		b.age = float(b.get("age", 0)) + dt
		var near: bool = _living(host).any(func(p): return absf(p.p.x - b.p.x) < 520 and absf(p.p.y - b.p.y) < 150)
		b.far = 0.0 if near else float(b.get("far", 0)) + dt
		if b.far > 7 + EPS or b.age > 30 + EPS: host.combat.kill_enemy(host, b, false)
	_tick_movers(dt, host)
	_tick_lift(dt, host)
	if host.has_method("collect_level_pickups"):
		for p in _living(host):
			if p.get("host_player", false): host.collect_level_pickups()
			else: host.call_combat_participant(p, host.collect_level_pickups, [])
	_tick_beams(dt, host)
	_tick_sofa(dt, host)
	for q in _surfaces: q.squash = maxf(0, float(q.get("squash", 0)) - dt * 3.6)
func _all(host) -> Array:
	if host.has_method("combat_participants"): return host.combat_participants()
	return [{"host_player": true, "p": host.player, "hearts": host.hearts}]
func _living(host) -> Array: return host.combat._living(host)
func _set_carry(host, participant: Dictionary, value: bool) -> void:
	if participant.get("host_player", false): carrying = value
	else: host.call_combat_participant(participant, Callable(self, "_apply_carry"), [value])
func _apply_carry(value: bool) -> void: carrying = value
func _nearest(host, x: float) -> Dictionary: return host.combat._nearest(host, x)
func _tick_drops(dt: float, host) -> void:
	for d in drops:
		if d.state == "wait":
			if _living(host).any(func(p): return absf(p.p.x - d.x) < 140 and absf(p.p.y - d.top) < 60): d.state = "warn"; d.t = 0.0
			continue
		d.t += dt
		if d.state == "warn" and d.t > 0.65 + EPS: d.state = "fall"; d.y = host.view_top() - 80; d.vy = 200.0
		if d.state != "fall": continue
		var old: float = d.y
		d.vy = minf(1600, d.vy + 4000 * dt); d.y += d.vy * dt
		for p in _living(host):
			var top: float = p.p.y - p.height * (0.65 if p.crouching else 0.95)
			if absf(p.p.x - d.x) < 44 and d.y > top and old < p.p.y: host.combat._hurt(host, p, d.x); d.state = "gone"
		var q := land_on(host, d.x, old, d.y)
		if not q.is_empty() and d.state == "fall":
			d.state = "gone"; host.sfx("pop")
			if rng.randf() < 0.5: host.add_coins(Vector2(d.x, q.row[2] - 40), 2)
		if d.y > host.level.fall: d.state = "gone"
	drops = drops.filter(func(d): return d.state != "gone" or d.t < 0.05)
func _tick_movers(dt: float, host) -> void:
	for q in movers:
		if q.off: continue
		q.t += dt
		var v := 0.0
		if q.state == "in":
			var d: float = q.goal - q.row[0]
			v = signf(d) * minf(320, absf(d) / 0.3 + 40)
			if absf(d) < 3: q.state = "hold"; q.t = 0.0
		elif q.state == "hold":
			v = sin(q.t / 0.9 + q.wob) * 30
			var riders: bool = host.enemies.any(func(b): return is_same(b.surface, q) and b.state != "pop")
			if q.t > q.hold or (not riders and q.t > 1.8): q.state = "out"; q.t = 0.0
		else:
			v = q.from * minf(500, 50 + q.t / 1.5 * 1000)
			if q.row[1] < host.camera.x - 80 or q.row[0] > host.camera.x + host.view_width() + 80: q.off = true; v = 0
		q.vx = v; q.row[0] += v * dt; q.row[1] += v * dt
func _tick_lift(dt: float, host) -> void:
	if lift.is_empty(): return
	var q: Dictionary = lift.surface
	lift.t += dt
	var riders: Array = _living(host).filter(func(p): return p.get("grounded", false) and p.p.x > q.row[0] - 4 and p.p.x < q.row[1] + 4 and absf(p.p.y - q.row[2]) < 4)
	var old: float = q.row[2]
	var base: float = host.level.liftBase
	var fh: float = host.level.storey
	if lift.state == "wait":
		if lift.t > 1.8 + EPS:
			lift.state = "move"; lift.t = 0.0
			lift.dir = -1 if lift.floor >= host.level.floors else (1 if lift.floor <= 0 else lift.dir)
			lift.to = base - (lift.floor + lift.dir) * fh
	elif lift.state == "move":
		q.row[2] = move_toward(q.row[2], lift.to, 160 * dt)
		if absf(lift.to - q.row[2]) < 0.5:
			q.row[2] = lift.to; lift.floor += lift.dir; lift.state = "wait"; lift.t = 0.0
			if not riders.is_empty() and lift.dir > 0 and lift.floor >= 3 and lift.floor < host.level.floors - 1 and (lift.floor in [4, 8] or rng.randf() < 0.15): lift.state = "shake"; host.status = "The lift's broken!"; host.sfx("warn")
	elif lift.state == "shake":
		if lift.t > 0.9 + EPS: lift.state = "drop"; lift.t = 0.0; lift.to = base - maxi(0, lift.floor - 2) * fh
	elif lift.state == "drop":
		q.row[2] = minf(lift.to, q.row[2] + minf(900, 100 + lift.t / 0.4 * 1000) * dt)
		if q.row[2] >= lift.to: q.row[2] = lift.to; lift.floor = maxi(0, lift.floor - 2); lift.state = "wait"; lift.t = -0.8; host.sfx("stomp")
	for p in riders:
		if p.get("host_player", false): host.player.y += q.row[2] - old
		else: p.p.y += q.row[2] - old
func _tick_beams(dt: float, host) -> void:
	var deck: Dictionary = {}
	for q in _surfaces:
		if q.get("deck", false): deck = q; break
	if deck.is_empty(): return
	for b in beams:
		b.t += dt
		if b.warn > 0: b.warn -= dt; continue
		b.x -= 1150 * dt
		var under: float = deck.row[2] - 150
		for p in _living(host):
			if absf(p.p.x - b.x) < 70 and p.p.y - p.height * (0.62 if p.crouching else 0.95) < under: host.combat._hurt(host, p, p.p.x + 1)
		for enemy in host.enemies:
			if enemy.state != "pop" and not enemy.has("hop") and absf(enemy.p.x - b.x) < 60 and enemy.p.y - 112 < under: host.combat.kill_enemy(host, enemy, false)
	beams = beams.filter(func(b): return b.x > host.camera.x - 300)
func _tick_sofa(dt: float, host) -> void:
	if sofa.is_empty(): return
	for p in _all(host): _set_carry(host, p, false)
	var q := below(host, sofa.x, sofa.fy - 15)
	var fy: float = sofa.fy if q.is_empty() else q.row[2]
	var near: Array = _living(host).filter(func(p): return p.get("grounded", false) and absf(p.p.x - sofa.x) < sofa.w / 2 + 26 and absf(p.p.y - fy) < 100)
	var door: Variant = null
	for d in host.level.get("doors", []):
		if sofa.x < d + 170 and sofa.x + sofa.w / 2 > d - 160: door = d; break
	sofa.door = door
	if door != null:
		var holding := false
		for p in _living(host):
			if absf(p.p.x - sofa.x) < sofa.w / 2 + 60 and (controls.get("down", false) if p.get("host_player", false) else controls.get(int(p.slot), {}).get("down", false)): holding = true
		if not sofa.tip:
			sofa.tip_t = sofa.tip_t + dt if holding else maxf(0, sofa.tip_t - dt)
			if sofa.tip_t > 0.45 + EPS: sofa.tip = true; host.sfx("power"); host.status = "Tipped!"
	elif sofa.tip and not host.level.get("doors", []).any(func(d): return absf(sofa.x - d) < 200): sofa.tip = false; sofa.tip_t = 0.0
	var hw: float = 46 if sofa.tip else sofa.w / 2
	if not near.is_empty():
		var mid := 0.0
		for p in near: mid += p.p.x
		mid /= near.size()
		if sofa.carriers.is_empty(): sofa.off = sofa.x - mid
		sofa.off *= pow(0.996, dt * 1000)
		var nx: float = mid + sofa.off
		if door != null and not sofa.tip and nx + hw > door - 26: nx = minf(nx, door - 26 - hw)
		for wall in surfaces(host, true):
			if wall.row[2] < fy - 200 and nx + hw > wall.row[0] and sofa.x + hw <= wall.row[0] + 4: nx = minf(nx, wall.row[0] - hw); break
		sofa.x = move_toward(sofa.x, nx, 300 * dt); sofa.lift = minf(1, sofa.lift + dt / 0.26)
		for p in near: _set_carry(host, p, true)
		sofa.carriers = near
	else:
		sofa.carriers = []; sofa.lift = maxf(0, sofa.lift - dt / 0.2)
		for b in host.enemies:
			if b.state != "pop" and absf(b.p.x - sofa.x) < hw + 20 and absf(b.p.y - fy) < 40: sofa.x -= 50 * dt * signf(b.p.x - sofa.x if b.p.x != sofa.x else 1)
	sofa.fy = fy; sofa.x = maxf(host.level.sofa.x - 200, sofa.x)
func sofa_rect() -> Rect2:
	if sofa.is_empty(): return Rect2()
	var h := 0.0
	for p in sofa.carriers: h = float(p.height) if h == 0 else minf(h, p.height)
	var w: float = 92 if sofa.tip else sofa.w
	var height: float = 200 if sofa.tip else 86
	return Rect2(sofa.x - w / 2, sofa.fy - sofa.lift * h * 0.28 - height, w, height)
func blocks(point: Vector2) -> bool:
	if sofa.is_empty() or sofa.carriers.is_empty(): return false
	var r := sofa_rect()
	return point.x > r.position.x and point.x < r.end.x and point.y > r.position.y and point.y < r.end.y
func _start_wipe(host, s: Dictionary) -> void:
	wiping = true; wipe_elapsed = 0; wipe_midpoint_done = false
	wipe_kind = str(s.get("wipe", "door")); wipe_label = str(s.get("label", ""))
	_wipe_scene = s; _wipe_generation = run_generation; _wipe_callback_due = false; _wipe_open_captured = false
	wipe_focus_start = Vector2(clampf((host.player.x - host.camera.x) * 1.3, 211.2, 748.8), 324)
	wipe_focus_end = wipe_focus_start
func finish_frame(host) -> void:
	if host.mode != "play" or not wiping or not _can_step(host) or _wipe_generation != run_generation: return
	if _wipe_callback_due: _apply_scene_transition(host, run_generation)
	if not _wipe_open_captured and wipe_elapsed + EPS >= WIPE_OPEN_START: wipe_focus_end = Vector2(clampf((host.player.x - host.camera.x) * 1.3, 211.2, 748.8), 324); _wipe_open_captured = true
	if wipe_elapsed + EPS >= WIPE_DURATION: wiping = false
func _apply_scene_transition(host, generation: int) -> bool:
	if host.mode != "play" or generation != run_generation or generation != _wipe_generation or not _can_step(host) or not wiping or wipe_midpoint_done or not _wipe_callback_due: return false
	wipe_midpoint_done = true; _wipe_callback_due = false
	var dest: float = _wipe_scene.to
	var q: Dictionary = {}
	var leader_y: float = host.meta.ground
	var roster := _all(host)
	for i in roster.size():
		var p: Dictionary = roster[i]
		var x := dest + i * 60
		q = below(host, x, host.meta.ground - 3000)
		var y: float = host.meta.ground if q.is_empty() else q.row[2]
		if i == 0: leader_y = y
		# Source does not heal, revive or replace safe floors/onPlat here.
		if p.get("host_player", false): host.player = Vector2(x, y); host.velocity = Vector2.ZERO; host.grounded = true
		else: p.p = Vector2(x, y); p.px = x; p.velocity = Vector2.ZERO; p.grounded = true
	if not sofa.is_empty(): sofa.x = dest + 200; q = below(host, sofa.x, host.meta.ground - 3000); sofa.fy = host.meta.ground if q.is_empty() else q.row[2]
	host.camera = Vector2(maxf(0, dest - 200), leader_y - host.meta.ground); host.camera_speed = 0; host.camera_lock = null
	for b in host.enemies:
		if b.p.x < dest - 400: b.state = "pop"
	scene_index += 1
	return true
func respawn(host) -> void:
	if checkpoint.is_empty(): return
	for p in _all(host):
		if p.p.x >= checkpoint.x - 40 or host.camera.x >= checkpoint.x: continue
		if p.get("host_player", false): host.player = Vector2(checkpoint.x, checkpoint.y); host.velocity.y = 0; host.grounded = true
		else: p.p = Vector2(checkpoint.x, checkpoint.y); p.px = checkpoint.x; p.velocity.y = 0; p.grounded = true
func recover_from_fall(host) -> void:
	var x := clampf(safe_position.x, host.camera.x + 70, host.camera.x + host.view_width() - 70)
	var q: Dictionary = {}
	for i in range(60):
		var xx := x + i * 20
		var c := below(host, xx, host.view_top() - 200)
		if not c.is_empty() and xx > c.row[0] + 30 and xx < c.row[1] - 30 and xx < host.camera.x + host.view_width() - 40: q = c; x = xx; break
	if q.is_empty(): q = below(host, x, -9999)
	if q.is_empty(): q = _surfaces[0]
	host.player = Vector2(x, q.row[2]); host.velocity.y = 0; host.grounded = true; host.on_platform = q.plat; host.invincible = 0; host.hurt_player(x - host.face); host.velocity.x = 0
func snapshot() -> Dictionary:
	return {"level_id": level_id, "elapsed": elapsed, "clock_left": clock_left, "end_time": end_time, "sofa": sofa.duplicate(true), "lift": lift.duplicate(true), "mimics": mimics.duplicate(true), "drops": drops.duplicate(true), "shutters": shutters.duplicate(true), "movers": movers.duplicate(true), "beams": beams.duplicate(true), "checkpoint": checkpoint.duplicate(true), "wiping": wiping, "scene_index": scene_index}
