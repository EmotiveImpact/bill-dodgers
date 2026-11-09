extends RefCounted
## Ordered non-bot W4 entities. Never merge these into ordinary bot storage:
## source homing, bubbles, pound and slide deliberately do not target this list.
const KINDS := ["case", "drop", "bailiff", "jet", "ring", "banana", "melon", "grab", "chute", "melons"]
var entries: Array = []
func reset(host, world) -> void:
	clear()
	for row in world.cfg.get("cases", []):
		var q: Dictionary = world.below(host, row[0], host.meta.ground - 400)
		if not q.is_empty(): _add({"kind": "case", "x": float(row[0]), "y": float(q.row[2]), "hp": 2, "h": 70, "type": str(row[1]) if row.size() > 1 else "rush", "flip": int(row[0]) % 2})
func clear() -> void:
	# JS tracing GC accepts mutual towel/carrier references; RefCounted does not.
	# Break only discarded ownership links, never an active gameplay target.
	for f in entries: _detach(f)
	entries.clear()
func _detach(f: Dictionary) -> void:
	if f.kind != "grab": return
	var towel = f.get("carry")
	if towel != null and is_same(towel.get("held"),f): towel.held = null
	f.carry = null
	f.target = null
func _add(values: Dictionary) -> Dictionary:
	var f := {"t": 0.0, "dead": false, "die_t": 0.0, "gone": false, "flash": 0.0, "state": "", "face": -1, "coins": 4}
	f.merge(values, true)
	entries.append(f)
	return f
func hittable(f: Dictionary) -> bool: return f.kind in ["case", "bailiff", "jet", "ring", "banana", "melon", "grab"]
func controller(f: Dictionary) -> bool: return f.kind in ["chute", "melons"]
func busy(host) -> bool:
	# Source W4.busy ignores banana.blocking and keeps it blocking while in
	# the 250px margin; camera pause separately releases at state=out.
	return entries.any(func(f): return not f.dead and f.kind in ["case", "bailiff", "jet", "banana", "grab", "chute", "melons"] and (controller(f) or (f.x > host.camera.x - 250 and f.x < host.camera.x + host.view_width() + 250)))
func pause_camera(auto: bool = false) -> bool:
	return entries.any(func(f): return not f.dead and f.kind in ["bailiff", "banana"] and (not auto or f.state != "out"))
func keep_controllers() -> void:
	for f in entries:
		if not controller(f): _detach(f)
	entries = entries.filter(func(f): return controller(f))
func spawn(side: String, kind: String, host, world) -> bool:
	if kind not in KINDS: return false
	var rng: RandomNumberGenerator = world.rng
	var cam: float = host.camera.x
	var width: float = host.view_width()
	var right := side == "r"
	match kind:
		"case":
			var x := cam + (width - 90 - rng.randf() * 120 if right else 90 + rng.randf() * 120)
			var q: Dictionary = world.below(host, x, host.view_top() + 100)
			if not q.is_empty(): _add({"kind": kind, "x": x, "y": float(q.row[2]), "hp": 2, "h": 70, "type": "rush" if rng.randf() < 0.5 else "throw", "flip": rng.randf() < 0.5})
		"drop":
			var p := _nearest(host, world, cam + width / 2)
			var px: float = host.player.x if p.is_empty() else p.p.x
			var x := clampf(px + (rng.randf() - 0.4) * 240, cam + 60, cam + width - 60)
			var q: Dictionary = world.below(host, x, host.view_top())
			if not q.is_empty(): _add({"kind": kind, "x": x, "y": host.view_top() - 80, "fy": float(q.row[2]), "state": "fall", "duration": 1.1, "h": 60, "flip": rng.randf() < 0.5})
		"bailiff":
			var q: Dictionary = {}
			var best := 0.0
			for fraction in [0.6, 0.5, 0.75, 0.35]:
				var c: Dictionary = world.below(host, cam + width * fraction, host.view_top() + 100)
				if c.is_empty() or c.plat: continue
				var overlap := minf(c.row[1], cam + width - 90) - maxf(c.row[0], cam + 90)
				if overlap > best and overlap > 300:
					best = overlap
					q = c
			if q.is_empty(): return true
			var hp := 46 if host.combat.participant_count > 1 else 34
			_add({"kind": kind, "x": minf(cam + width + 120, q.row[1] - 70) if right else maxf(cam - 120, q.row[0] + 70), "y": float(q.row[2]), "surface": q, "hp": hp, "max": hp, "h": 200, "face": -1 if right else 1, "state": "walk", "cd": 1.8, "waves": [], "coins": 14, "entered": false})
			host.status = "Bailiff bot! Big, armoured and hard to shift."
			if host.has_method("hud_banner"): host.hud_banner("Bailiff bot!","Big, armoured and hard to shift",true)
			host.sfx("warn")
		"jet":
			_add({"kind": kind, "x": cam + width + 140 if right else cam - 140, "y": float(world.cfg.get("jetY", float(world.cfg.get("water", 482)) + 18)), "side": side, "h": 110, "hp": 3, "cd": rng.randf_range(1.4, 2.3), "slot": _jet_slot(host, world), "face": -1 if right else 1, "life": rng.randf_range(16, 22), "coins": 5, "throw_t": 0.0})
		"ring":
			var kinds: Array = []
			for name in ["ring", "duck", "croc", "unicorn"]:
				if host.meta.get("imgs", {}).has("fl-" + name): kinds.append(name)
			var top: float = host.meta.ground if world.deck.is_empty() else world.deck.row[2]
			_add({"kind": kind, "x": cam + width + 80 if right else cam - 80, "y": top, "vx": (-1 if right else 1) * rng.randf_range(160, 240), "hp": 2, "h": 60, "img": kinds[rng.randi_range(0, kinds.size() - 1)] if not kinds.is_empty() else "", "coins": 2})
		"banana":
			var seats: Array = []
			for offset in [-150, -50, 50, 150]: seats.append({"offset": offset, "hp": 3, "dead": false, "cd": rng.randf_range(1, 3), "die_t": 0.0, "throw_t": 0.0, "flash": 0.0})
			_add({"kind": kind, "x": cam + width + 300, "y": float(world.cfg.get("water", 482)) + 16, "h": 140, "state": "in", "seats": seats, "coins": 0})
			host.status = "Banana boat! Four robots, one big banana."
			if host.has_method("hud_banner"): host.hud_banner("Banana boat!","Four robots, one big banana",true)
			host.sfx("warn")
		"melon":
			var x := cam + width + 40
			var q: Dictionary = world.below(host, x, host.view_top() - 400)
			if q.is_empty(): q = world.below(host, cam + width - 40, host.view_top() - 400)
			if not q.is_empty(): _add({"kind": kind, "x": x, "y": float(q.row[2]), "vy": 0.0, "vx": -rng.randf_range(200, 280), "h": 52, "hp": 1, "grounded": true, "coins": 2})
		"grab":
			var free: Array = world.hold.get("towels", []).filter(func(t): return not t.gone and t.held == null)
			var q: Dictionary = world.below(host, cam + width / 2, host.view_top() + 100)
			if not q.is_empty(): _add({"kind": kind, "x": cam + width + 60 if right else cam - 60, "y": float(q.row[2]), "side": side, "h": 112, "hp": 3, "face": -1 if right else 1, "target": free[rng.randi_range(0, free.size() - 1)] if not free.is_empty() else null, "carry": null})
	return true
func _jet_slot(host, world) -> float:
	var rng: RandomNumberGenerator = world.rng
	if not world.cfg.has("deck"): return 120 + rng.randf() * (host.view_width() - 240)
	var d: Dictionary = world.cfg.deck
	return 50 + rng.randf() * maxf(10, d.off - 120) if rng.randf() < 0.5 else d.off + d.w + 70 + rng.randf() * maxf(10, host.view_width() - d.off - d.w - 120)
func start_set(host, world, sp: Dictionary) -> void:
	match str(sp.kind):
		"chute":
			_add({"kind": "chute", "x": 0.0, "y": 0.0, "n": int(sp.get("n", 14)), "next": 0.0, "gap": float(sp.get("gap", 900)) / 1000})
			host.status = "Luggage avalanche! Watch for the shadows."
			if host.has_method("hud_banner"): host.hud_banner("Luggage avalanche!","Watch for the shadows",true)
			host.sfx("warn")
		"melons":
			_add({"kind": "melons", "x": 0.0, "y": 0.0, "n": int(sp.get("n", 12)), "next": 0.0})
			host.status = "Runaway melons! Jump them or pop them."
			if host.has_method("hud_banner"): host.hud_banner("Runaway melons!","Jump them or pop them",true)
			host.sfx("warn")
		"bailiff", "banana": spawn("r", sp.kind, host, world)
func tick(dt: float, host, world) -> void:
	# Indexed live loop preserves JS for-of append semantics for chute/melons.
	var i := 0
	while i < entries.size():
		var f: Dictionary = entries[i]
		i += 1
		f.t += dt
		f.flash = maxf(0, f.flash - dt)
		if f.dead:
			f.die_t += dt
			continue
		match str(f.kind):
			"case":
				var p := _nearest(host, world, f.x)
				if not p.is_empty() and absf(p.p.x - f.x) < 230 and absf(p.p.y - f.y) < 80: _open_case(f, host, world)
			"drop":
				if f.state == "fall":
					var k := minf(1, f.t / f.duration)
					f.y = host.view_top() - 80 + (f.fy - host.view_top() + 80) * k * k
					if k >= 1:
						f.state = "land"
						f.t = 0
						host.sfx("stomp")
						_contact(f, 50, f.fy - 70, f.fy + 4, host, world)
				elif f.t > 0.5:
					f.dead = true
					f.die_t = 0
					host.add_coins(Vector2(f.x, f.fy - 40), 1)
			"bailiff": _bailiff_tick(f, dt, host, world)
			"jet": _jet_tick(f, dt, host, world)
			"ring":
				f.x += (f.vx + float(host.level.get("auto", 0)) * 1000) * dt
				if not world.deck.is_empty(): f.y = world.deck.row[2] - 4 - absf(sin(f.t / 0.22)) * 10
				_contact(f, 38, f.y - 60, f.y, host, world)
				if f.x < host.camera.x - 150 or f.x > host.camera.x + host.view_width() + 150: f.gone = true
			"banana": _banana_tick(f, dt, host, world)
			"melon": _melon_tick(f, dt, host, world)
			"grab": _grab_tick(f, dt, host, world)
			"chute", "melons":
				f.next -= dt
				if f.next <= 0 and f.n > 0:
					f.n -= 1
					f.next = f.gap * world.rng.randf_range(0.7, 1.3) if f.kind == "chute" else world.rng.randf_range(0.7, 1.6)
					spawn("r", "drop" if f.kind == "chute" else "melon", host, world)
				if f.n <= 0:
					if f.kind == "chute" and not entries.any(func(o): return o.kind == "drop" and not o.dead): f.gone = true
					if f.kind == "melons" and not entries.any(func(o): return o.kind == "melon"): f.gone = true
	for f in entries:
		if (f.dead and f.die_t > 0.9) or f.gone: _detach(f)
	entries = entries.filter(func(f): return not (f.dead and f.die_t > 0.9) and not f.gone)
func _bailiff_tick(f: Dictionary, dt: float, host, world) -> void:
	var p := _nearest(host, world, f.x)
	if p.is_empty(): return
	var dx: float = p.p.x - f.x
	if not f.entered:
		f.x += f.face * 120 * dt
		if f.x > host.camera.x + 120 and f.x < host.camera.x + host.view_width() - 120: f.entered = true
	elif f.state == "walk":
		if dx != 0: f.face = signf(dx)
		if absf(dx) > 160: f.x += f.face * 60 * dt
		f.cd -= dt
		if f.cd <= 0:
			f.state = "stomp" if world.rng.randf() < 0.5 else "throw"
			f.t = 0
			f.fired = false
	else:
		if f.t > 0.33 and not f.fired:
			f.fired = true
			if f.state == "stomp":
				host.sfx("stomp")
				f.waves.append_array([{"x": f.x - 70, "vx": -400.0}, {"x": f.x + 70, "vx": 400.0}])
			else:
				for j in 3: world.bill(host, Vector2(f.x + f.face * 50, f.y - 230), p.p.x + (j - 1) * 110, true)
		if f.t > 0.7:
			f.state = "walk"
			f.cd = world.rng.randf_range(1.3, 2.3)
	if f.entered: f.x = clampf(f.x, host.camera.x + 80, host.camera.x + host.view_width() - 80)
	f.x = clampf(f.x, f.surface.row[0] + 60, f.surface.row[1] - 60)
	if not f.entered and f.x > host.camera.x + 60 and f.x < host.camera.x + host.view_width() - 60: f.entered = true
	for wave in f.waves:
		wave.x += wave.vx * dt
		for player in world.living(host):
			if absf(wave.x - player.p.x) < 24 and absf(player.p.y - f.y) < 20: world.hurt(host, player, wave.x - wave.vx * 0.05)
	f.waves = f.waves.filter(func(w): return w.x > host.camera.x - 60 and w.x < host.camera.x + host.view_width() + 60)
	_contact(f, 66, f.y - 200, f.y + 10, host, world)
func _jet_tick(f: Dictionary, dt: float, host, world) -> void:
	var p := _nearest(host, world, f.x)
	if not p.is_empty() and p.p.x != f.x: f.face = signf(p.p.x - f.x)
	if f.t > f.life:
		f.x += (1 if f.side == "r" else -1) * 500 * dt
		if f.x > host.camera.x + host.view_width() + 200 or f.x < host.camera.x - 200: f.gone = true
		return
	f.x += clampf((host.camera.x + f.slot - f.x) / 0.3, -500, 500) * dt
	if world.rng.randf() < 0.003: f.slot = _jet_slot(host, world)
	f.cd -= dt
	if f.cd <= 0 and not p.is_empty() and f.x > host.camera.x and f.x < host.camera.x + host.view_width():
		f.cd = world.rng.randf_range(1.6, 3)
		f.throw_t = 0.4
		world.bill(host, Vector2(f.x + f.face * 30, f.y - 100), p.p.x)
	f.throw_t = maxf(0, f.throw_t - dt)
func _banana_tick(f: Dictionary, dt: float, host, world) -> void:
	var want: float = host.camera.x + host.view_width() * 0.62
	if f.state == "in":
		f.x += maxf(-400, (want - f.x) / 0.4) * dt
		if absf(f.x - want) < 6: f.state = "fight"
	elif f.state == "fight": f.x = want + sin(f.t / 1.4) * 120
	else:
		f.x += 600 * dt
		if f.x > host.camera.x + host.view_width() + 500: f.gone = true
	for seat in f.seats:
		seat.flash = maxf(0, seat.flash - dt)
		if seat.dead:
			seat.die_t += dt
			continue
		seat.cd -= dt
		var p := _nearest(host, world, f.x + seat.offset)
		if seat.cd <= 0 and not p.is_empty() and f.state == "fight":
			seat.cd = world.rng.randf_range(2.2, 4)
			seat.throw_t = 0.4
			world.bill(host, Vector2(f.x + seat.offset - 20, f.y - 140), p.p.x)
		seat.throw_t = maxf(0, seat.throw_t - dt)
	if f.state == "fight" and f.seats.all(func(s): return s.dead):
		f.state = "out"
		host.add_coins(Vector2(f.x, f.y - 120), 10)
		host.status = "Wipe out!"
	f.blocking = f.state != "out"
func _melon_tick(f: Dictionary, dt: float, host, world) -> void:
	var old_y: float = f.y
	if not f.grounded:
		f.vy = minf(1400, f.vy + 3000 * dt)
		f.y += f.vy * dt
		var q: Dictionary = world.land_on(host, f.x, old_y, f.y)
		if not q.is_empty():
			f.y = q.row[2]
			f.vy = -f.vy * 0.35 if f.vy > 400 else 0.0
			f.grounded = f.vy == 0
	elif world.land_on(host, f.x, f.y - 2, f.y + 2).is_empty():
		f.grounded = false
		f.vy = 50
	var wanted: float = f.x + f.vx * dt
	var nx: float = world.wall_clamp(host, f.x, wanted, f.y)
	if nx != wanted: f.vx = -f.vx
	f.x = nx
	_contact(f, 34, f.y - 52, f.y, host, world)
	if f.x < host.camera.x - 100 or f.y > host.level.fall: f.gone = true
func _grab_tick(f: Dictionary, dt: float, host, world) -> void:
	if f.carry == null:
		if f.target == null or f.target.gone or (f.target.held != null and not is_same(f.target.held, f)):
			var free: Array = world.hold.get("towels", []).filter(func(t): return not t.gone and t.held == null)
			free.sort_custom(func(a, b): return absf(a.x - f.x) < absf(b.x - f.x))
			f.target = free[0] if not free.is_empty() else null
		if f.target == null:
			f.face = 1 if f.side == "r" else -1
			f.x += f.face * 120 * dt
			if f.x > host.camera.x + host.view_width() + 80 or f.x < host.camera.x - 80: f.gone = true
			return
		if f.target.x != f.x: f.face = signf(f.target.x - f.x)
		f.x += f.face * 120 * dt
		if absf(f.x - f.target.x) < 8:
			f.carry = f.target
			f.target.held = f
			host.sfx("throw")
	else:
		f.face = 1 if f.side == "r" else -1
		f.x += f.face * 100 * dt
		if f.x > host.camera.x + host.view_width() + 60 or f.x < host.camera.x - 60:
			f.gone = true
			f.carry.gone = true
			f.carry.held = null
			host.status = "Towel nabbed!"
			host.sfx("hurt")
	_contact(f, 40, f.y - 100, f.y + 10, host, world)
func _open_case(f: Dictionary, host, world) -> void:
	if f.dead: return
	f.dead = true
	f.die_t = 0
	host.sfx("pop")
	host.status = "Surprise!"
	var q: Dictionary = world.below(host, f.x, f.y - 4)
	if not q.is_empty(): host.combat.new_bot(host, f.x, q, f.type, {"face": -1, "entered": true, "lock": 0})
func _path(shot: Dictionary, old_x: float, x: float, width: float, top: float, bottom: float) -> bool:
	return maxf(old_x, shot.p.x) > x - width and minf(old_x, shot.p.x) < x + width and shot.p.y > top and shot.p.y < bottom
func intercept_shot(shot: Dictionary, old_x: float, host, world) -> bool:
	for f in entries:
		if f.dead or not hittable(f): continue
		var hit := false
		match str(f.kind):
			"case":
				hit = _path(shot, old_x, f.x, 34, f.y - 70, f.y)
				if hit:
					f.hp -= 1 # Deliberately fixed damage, even a high-damage special.
					f.flash = 0.09
					if f.hp <= 0: _open_case(f, host, world)
			"banana":
				for seat in f.seats:
					if seat.dead or not _path(shot, old_x, f.x + seat.offset, 34, f.y - 150, f.y - 20): continue
					hit = true
					seat.hp -= int(shot.get("damage", 1))
					seat.flash = 0.09
					if seat.hp <= 0:
						seat.dead = true
						host.sfx("pop")
						host.add_coins(Vector2(f.x + seat.offset, f.y - 120), 4)
						host.combat._credit_pop(host, host.combat._shot_owner_slot(host, shot))
					break
			_:
				var width := 36.0
				var height := 112.0
				var bottom: float = f.y
				match str(f.kind):
					"bailiff":
						width = 70
						height = 210
					"jet":
						width = 60
						height = 120
						bottom += 10
					"ring":
						width = 44
						height = 70
					"melon":
						width = 30
						height = 56
				hit = _path(shot, old_x, f.x, width, f.y - height, bottom)
				if hit:
					f.hp -= int(shot.get("damage", 1))
					f.flash = 0.09
					if f.hp <= 0:
						die(f, host, true, host.combat._shot_owner_slot(host, shot))
						if f.get("carry", null) != null:
							f.carry.held = null
							f.carry.back = 0.6
							host.status = "Towel saved!"
		if hit:
			shot.dead = true
			shot.life = 0
			host.sfx("hitBot")
			return true
	return false
func die(f: Dictionary, host, credited: bool = true, owner_slot: int = -1) -> void:
	if f.dead: return
	f.dead = true
	f.die_t = 0
	host.sfx("pop")
	host.add_coins(Vector2(f.x, minf(f.y, f.get("coin_y", f.y)) - 60), int(f.coins) if f.coins else 4)
	if credited: host.combat._credit_pop(host, owner_slot)
func _contact(f: Dictionary, width: float, top: float, bottom: float, host, world) -> void:
	for p in world.living(host):
		if absf(p.p.x - f.x) < width and p.p.y > top and p.p.y - p.height * (0.56 if p.crouching else 0.86) < bottom: world.hurt(host, p, f.x)
func _nearest(host, world, x: float) -> Dictionary:
	var best: Dictionary = {}
	for p in world.living(host):
		if best.is_empty() or absf(p.p.x - x) < absf(best.p.x - x): best = p
	return best
func snapshot() -> Array:
	# Avoid recursive towel<->carrier references in debug/render snapshots.
	var out: Array = []
	for f in entries:
		var safe: Dictionary = {}
		for key in f:
			if key in ["target", "carry", "surface"]: continue
			safe[key] = f[key].duplicate(true) if f[key] is Array or f[key] is Dictionary else f[key]
		if f.get("carry", null) != null: safe.carry_x = f.carry.x
		out.append(safe)
	return out
