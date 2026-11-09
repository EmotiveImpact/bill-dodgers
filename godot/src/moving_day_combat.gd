extends RefCounted
## Moving Day combat: authored W5 waves, shutter/scooter/vehicle arrivals,
## removal men, tape projectiles, crown vulnerability and source coin rules.
const King = preload("res://src/cardboard_king.gd")
const EPS := 0.000000001
var rng := RandomNumberGenerator.new()
var waves: Array = []
var participant_count := 1
var go_time := 0.0

func reset(host, participants: int = 1, seed_value: int = 51) -> void:
	rng.seed = seed_value; participant_count = maxi(1, participants); waves.clear(); go_time = 0
	for source in host.level.get("waves", []):
		var group: Array = source.g.duplicate(true)
		if participant_count > 1 and source.get("extra", true) and not group.is_empty(): group.append([group[-1][0] + 600, "l" if group.size() % 2 else "r", "rush"])
		waves.append({"at": float(source.at), "group": group, "started": false, "done": false, "t": 0.0, "index": 0, "say": str(source.get("say", ""))})
	host.crates.clear()
	for row in host.level.get("crates", []): host.crates.append({"p": Vector2(row[0], host.floor_at(row[0], row[1])), "hp": 3, "give": row[2], "broken": false, "hit": 0.0})
func waves_tick(dt: float, host) -> void:
	var progress: float = host.camera.x
	if host.level.get("timed", 0): progress = host.world_five.level_time * 1000
	elif host.level.get("vert", false):
		var feet: float = host.meta.ground
		for p in _living(host): feet = minf(feet, p.p.y)
		progress = host.meta.ground - 30 - feet
	for wave in waves:
		var threshold: float = wave.at if host.level.get("timed", 0) or host.level.get("vert", false) else wave.at - 2
		if not wave.started and progress + EPS >= threshold:
			wave.started = true; wave.t = 0.0; wave.index = 0
			if not host.level.get("timed", 0): host.camera_lock = host.camera.x + 40
			if wave.say: host.status = wave.say
		if wave.started and not wave.done:
			wave.t += dt
			while wave.index < wave.group.size() and wave.t + EPS >= float(wave.group[wave.index][0]) / 1000.0:
				var entry: Array = wave.group[wave.index]; spawn(host, entry[1], entry[2]); wave.index += 1
			if wave.index >= wave.group.size() and not host.enemies.any(func(b): return b.state != "pop"):
				wave.done = true
				if not host.level.get("timed", 0): host.camera_lock = null; go_time = 2.2
				if not host.level.get("timed", 0) and host.has_method("hud_go"): host.hud_go()
func spawn(host, side: Variant, kind: String) -> void:
	var world = host.world_five
	var right: bool = side == "r"
	var deck: Dictionary = {}
	for q in world.surfaces(host):
		if q.get("deck", false): deck = q; break
	if kind == "bridge": world.beams.append({"x": host.camera.x + host.view_width() + 260, "warn": 1.6, "t": 0.0}); host.status = "Low bridge! Duck!"; host.sfx("warn"); return
	if kind == "drop":
		var p := _nearest(host, host.camera.x + host.view_width() / 2)
		if not p.is_empty(): world.drops.append({"x": p.p.x + rng.randf_range(-60, 60), "top": p.p.y, "state": "warn", "t": 0.0, "y": 0.0, "vy": 0.0})
		return
	if kind in ["van", "flatbed"]: _ride_in(host, side, kind, deck); return
	if kind == "big":
		var x: float = host.camera.x + host.view_width() + 90 if right else host.camera.x - 90
		var found: Dictionary = {}
		for i in range(40):
			var xx := x + (-1 if right else 1) * i * 30
			for q in world.surfaces(host):
				if (not q.plat or host.level.get("vert", false)) and not q.get("lift", false) and q.row[1] - q.row[0] > 360 and xx > q.row[0] + 60 and xx < q.row[1] - 60 and q.row[2] > host.view_top() + 120 and q.row[2] < host.camera.y + 600: found = q; x = xx; break
			if not found.is_empty(): break
		if found.is_empty() and host.level.get("timed", 0) and not deck.is_empty():
			x = host.camera.x + host.view_width() + 80
			var b := new_bot(host, x, deck, "throw", {"big": true, "hp": 34 if participant_count > 1 else 26, "stop": 200.0, "speed": 60.0, "scale": 1.66})
			_hop(b, Vector2(x, deck.row[2] - 60), Vector2(deck.row[1] - 50, deck.row[2]), 0.9, deck)
		elif not found.is_empty(): new_bot(host, x, found, "throw", {"big": true, "hp": 34 if participant_count > 1 else 26, "stop": 300.0, "speed": 60.0, "entered": false, "scale": 1.66})
		host.status = str(host.level.get("bigName", "The removal man!")); host.sfx("warn"); return
	if host.level.get("vert", false):
		var feet: float = host.meta.ground
		var living := _living(host)
		if not living.is_empty():
			feet = INF
			for p in living: feet = minf(feet, p.p.y)
		var found: Dictionary = {}; var distance := INF
		for q in world.surfaces(host):
			if q.get("lift", false) or q.row[1] - q.row[0] <= 300 or q.row[2] <= host.view_top() + 140 or q.row[2] >= host.camera.y + 560: continue
			var d: float = absf(q.row[2] - feet + 20)
			if d < distance: found = q; distance = d
		if not found.is_empty(): new_bot(host, minf(found.row[1] - 40, host.camera.x + host.view_width() + 60) if right else maxf(found.row[0] + 40, host.camera.x - 60), found, kind, {"entered": false})
		return
	if host.level.get("timed", 0) and not deck.is_empty():
		var x0: float = host.camera.x + host.view_width() + 60 if right else host.camera.x - 60
		var b := new_bot(host, x0, deck, kind, {"face": -1 if right else 1})
		_hop(b, Vector2(x0, deck.row[2] + 40), Vector2(deck.row[1] - 60 if right else deck.row[0] + 60, deck.row[2]), 0.76, deck)
		return
	var eligible: Array = world.shutters.filter(func(s): return s.x > host.camera.x + 120 and s.x < host.camera.x + host.view_width() - 60 and s.open < 0.2 and s.top > host.view_top() + 150 and s.top < host.camera.y + 580 and not _living(host).any(func(p): return absf(p.p.x - s.x) < 90))
	if not eligible.is_empty():
		var s: Dictionary = eligible[rng.randi_range(0, eligible.size() - 1)]
		s.want = 1.0; s.t = 0.0
		var q: Dictionary = world.below(host, s.x, s.top - 4)
		if not q.is_empty(): new_bot(host, s.x, q, kind, {"hidden": 0.52, "shutter": s})
		host.sfx("throw"); return
	_spawn_ordinary(host, side, kind)
func _spawn_ordinary(host, side: Variant, kind: String) -> void:
	var right: bool = side == "r"
	var x: float = host.camera.x + host.view_width() + 70 if right else host.camera.x - 70
	var living := _living(host)
	var feet: float = host.meta.ground if living.is_empty() else 0.0
	for p in living: feet += p.p.y / living.size()
	for i in range(50):
		var xx := x + (-1 if right else 1) * i * 24
		var found: Dictionary = {}; var distance := INF
		for q in host.world_five.surfaces(host):
			if q.plat or q.row[1] - q.row[0] <= 200 or xx <= q.row[0] + 30 or xx >= q.row[1] - 30 or q.row[2] <= host.view_top() + 120 or q.row[2] >= host.camera.y + 600: continue
			var d: float = absf(q.row[2] - feet)
			if d < distance: found = q; distance = d
		if not found.is_empty(): new_bot(host, xx, found, kind, {"entered": false, "face": -1 if right else 1}); return
func _hop(b: Dictionary, from: Vector2, to: Vector2, duration: float, q: Dictionary) -> void:
	b.hop = {"start": from, "end": to, "t": 0.0, "duration": duration, "surface": q, "segment": q.row}
func _ride_in(host, side: Variant, kind: String, deck: Dictionary) -> void:
	if deck.is_empty(): return
	var q: Dictionary = {}
	for m in host.world_five.movers:
		if m.off: q = m; break
	if q.is_empty(): return
	var dims: Dictionary = host.meta.get("dims", {})
	var w: float = roundf(float(dims.rvan[0]) * 217 / float(dims.rvan[1])) if kind == "van" and dims.has("rvan") else (300 if kind == "van" else 420)
	var painted: bool = kind == "flatbed" and dims.has("rlorry")
	var width: float = 276 if painted else w
	var from_left: bool = side == "l"
	q.w = width; q.row[0] = host.camera.x - width - 40 if from_left else host.camera.x + host.view_width() + 40
	q.row[1] = q.row[0] + width; q.row[2] = deck.row[2] - (84 if kind == "van" else (0 if painted else 52))
	q.off = false; q.kind = kind
	q.goal = deck.row[0] - width * 0.55 if from_left else (deck.row[1] + 90 if painted else deck.row[1] - 210)
	q.hold = rng.randf_range(6.5, 9.0); q.t = 0.0; q.from = -1 if from_left else 1; q.state = "in"; q.vx = 0.0; q.wob = rng.randf_range(0, 6)
	var n := 3 if participant_count > 1 else 2
	for i in n: new_bot(host, q.row[0] + 70 + i * ((w - 140) / maxi(1, n - 1)), q, "throw" if i % 2 else "rush", {"hp": 3})
	host.sfx("honk")
func new_bot(host, x: float, surface: Dictionary, kind: String, extra: Dictionary = {}) -> Dictionary:
	var rush := kind == "rush"
	var enemy := {"p": Vector2(x, surface.row[2]), "kind": kind, "type": kind, "hp": 3 if rush else 4,
		"state": "walk", "t": rng.randf_range(0, 0.4), "cd": rng.randf_range(0.9, 1.8),
		"stop": 0.0 if rush else rng.randf_range(230, 400), "speed": (110 if rush else 75) * rng.randf_range(0.9, 1.15),
		"face": -1, "entered": true, "wait": 0.0, "gone": 0.0, "flash": 0.0,
		"pending": false, "scale": 1.0, "segment": surface.row, "surface": surface,
		"stride": 0.0, "visual_move": 0.0}
	enemy.merge(extra, true)
	if not extra.has("face"):
		var p := _nearest(host, x)
		if not p.is_empty() and p.p.x != x: enemy.face = signf(p.p.x - x)
	enemy.max_hp = enemy.hp
	host.enemies.append(enemy)
	return enemy

func enemies_tick(dt: float, host) -> void:
	for enemy in host.enemies.duplicate():
		# Source removes held bots before AI AND cleanup, then the ability
		# phase floats/releases and appends them after the other bots.
		if enemy.state != "pop" and _bubbled(host, enemy): continue
		enemy.t += dt
		enemy.flash = maxf(0, enemy.flash - dt)
		if enemy.state == "pop":
			enemy.gone += dt
			continue
		if _tick_hop(dt, enemy): continue
		if enemy.surface.get("vx", 0): enemy.p.x += float(enemy.surface.vx) * dt
		if enemy.surface.get("off", false): enemy.lost = true; continue
		var player := _nearest(host, enemy.p.x)
		if player.is_empty():
			enemy.state = "walk"
			continue
		var dx: float = player.p.x - enemy.p.x
		var distance := absf(dx)
		if dx != 0: enemy.face = signf(dx)
		if not enemy.entered and enemy.p.x > host.camera.x + 50 and enemy.p.x < host.camera.x + host.view_width() - 50: enemy.entered = true
		if enemy.state == "walk" and not enemy.entered:
			enemy.p.x += (-1 if enemy.p.x > host.camera.x + host.view_width() * 0.5 else 1) * maxf(enemy.speed, 100) * dt
			enemy.face = -1 if enemy.p.x > host.camera.x + host.view_width() * 0.5 else 1
		elif enemy.state == "walk":
			if distance > enemy.stop + 10: enemy.p.x += signf(dx) * enemy.speed * dt
			elif enemy.stop > 0 and distance < enemy.stop - 80: enemy.p.x -= signf(dx) * enemy.speed * 0.6 * dt
			enemy.cd -= dt
			if enemy.stop > 0 and enemy.cd <= 0 and enemy.p.x > host.camera.x - 10 and enemy.p.x < host.camera.x + host.view_width() + 10:
				enemy.state = "throw"
				enemy.t = 0.0
				enemy.pending = true
		elif enemy.state == "throw":
			if enemy.t >= 0.22 and enemy.pending:
				enemy.pending = false
				host.sfx("throw")
				if enemy.type == "flat": _bill(host, enemy.p + Vector2(enemy.face * 30, -128), Vector2(enemy.face * 420, 0), 0, "flat")
				elif enemy.type == "tape": _bill(host, enemy.p + Vector2(enemy.face * 30, -18), Vector2(enemy.face * 500, 0), 0, "tape")
				else: _bill(host, enemy.p + Vector2(enemy.face * (50 if enemy.get("big", false) else 26), -170 if enemy.get("big", false) else -100), Vector2(clampf(dx / 0.9, -500, 500), -780), 1700, "big" if enemy.get("big", false) else "")
			if enemy.t >= 0.44:
				enemy.state = "walk"
				enemy.t = 0.0
				enemy.cd = rng.randf_range(1.4, 2.8)
		if enemy.entered and not enemy.surface.get("vx", 0): enemy.p.x = clampf(enemy.p.x, host.camera.x + 40, host.camera.x + host.view_width() - 40)
		_try_hop(host, enemy)
		if not enemy.has("hop"): enemy.p.x = clampf(enemy.p.x, float(enemy.segment[0]) + 22, float(enemy.segment[1]) - 22)
		for target in _living(host):
			if absf(target.p.x - enemy.p.x) < (66 if enemy.get("big", false) else 44) and target.p.y > enemy.p.y - (170 if enemy.get("big", false) else 95) and target.p.y < enemy.p.y + 24:
				_hurt(host, target, enemy.p.x)
	for enemy in host.enemies.duplicate():
		if enemy.state != "pop" and _bubbled(host, enemy): continue
		if not enemy.entered and enemy.state != "pop":
			enemy.wait += dt
			if enemy.wait > 6 + EPS:
				host.enemies.erase(enemy)
				continue
		if enemy.get("lost", false) or (enemy.state == "pop" and enemy.gone > 1.3 + EPS) or enemy.p.x <= host.camera.x - 400 or enemy.p.x >= host.camera.x + host.view_width() + 400 or (host.level.get("vert", false) and enemy.p.y > host.camera.y + 1040): host.enemies.erase(enemy)

func _tick_hop(dt: float, enemy: Dictionary) -> bool:
	if not enemy.has("hop"): return false
	var hop: Dictionary = enemy.hop
	hop.t += dt
	var k := minf(1, hop.t / hop.duration)
	enemy.p = Vector2(lerpf(hop.start.x, hop.end.x, k), lerpf(hop.start.y, hop.end.y, k) - sin(PI * k) * (70 + maxf(0, hop.start.y - hop.end.y) * 0.6))
	if k >= 1:
		enemy.segment = hop.segment
		enemy.surface = hop.surface
		enemy.p.y = hop.segment[2]
		enemy.erase("hop")
	return true

func _try_hop(host, enemy: Dictionary) -> void:
	var player := _nearest(host, enemy.p.x)
	if player.is_empty() or not enemy.entered or enemy.state != "walk" or absf(player.p.x - enemy.p.x) <= 30: return
	var direction := signf(player.p.x - enemy.p.x)
	var segment: Array = enemy.segment
	var edge: float = segment[1] if direction > 0 else segment[0]
	if absf(enemy.p.x - edge) >= 26: return
	var next: Array = []
	var next_surface: Dictionary = {}
	for surface in host.world_five.surfaces(host):
		var row: Array = surface.row
		if surface.plat or row == segment or float(row[1]) - float(row[0]) <= 200 or absf(float(row[2]) - enemy.p.y) >= 230: continue
		if direction > 0:
			if float(row[0]) < float(segment[1]) - 4 or float(row[0]) - float(segment[1]) >= 230: continue
			if next.is_empty() or float(row[0]) < float(next[0]):
				next = row
				next_surface = surface
		else:
			if float(row[1]) > float(segment[0]) + 4 or float(segment[0]) - float(row[1]) >= 230: continue
			if next.is_empty() or float(row[1]) > float(next[1]):
				next = row
				next_surface = surface
	if next.is_empty(): return
	var to_x := float(next[0]) + 40 if direction > 0 else float(next[1]) - 40
	enemy.hop = {"start": enemy.p, "end": Vector2(to_x, next[2]), "t": 0.0, "duration": 0.520 + absf(to_x - enemy.p.x) * 0.0012, "segment": next, "surface": next_surface}
	enemy.face = direction

func projectiles_tick(dt: float, host) -> void:
	# Player shots all resolve before hostile bills, even if their storage is
	# interleaved. Late world intercepts run only after this filter.
	for shot in host.bullets.duplicate():
		if shot.enemy: continue
		var before: Vector2 = shot.p
		if shot.get("first_frame", false):
			before.x = _shot_owner_x(host, shot)
			shot.first_frame = false
		if shot.get("homing", false):
			var target: Dictionary = {}
			for enemy in host.enemies:
				if enemy.state == "pop": continue
				if target.is_empty() or absf(enemy.p.x - shot.p.x) < absf(target.p.x - shot.p.x): target = enemy
			if not target.is_empty() and signf(target.p.x - shot.p.x) == signf(shot.v.x): shot.v.y = clampf(shot.v.y + signf(target.p.y - 60 - shot.p.y) * 1200 * dt, -300, 300)
		shot.p += shot.v * dt
		shot.age = float(shot.get("age", 0)) + dt
		if shot.get("dead", false) or float(shot.get("life", 20)) <= 0: continue
		for enemy in host.enemies:
			if enemy.state == "pop": continue
			var hw := 58.0 if enemy.get("big", false) else 34.0
			var hh := 190.0 if enemy.get("big", false) else 112.0
			if enemy.p.x > minf(before.x, shot.p.x) - hw and enemy.p.x < maxf(before.x, shot.p.x) + hw and shot.p.y > enemy.p.y - hh and shot.p.y < enemy.p.y:
				# Source shoves before the death/coin-drop callback.
				enemy.p.x += signf(shot.v.x if shot.v.x != 0 else 0.001) * 6
				damage_enemy(host, enemy, int(shot.get("damage", 1)), _shot_owner_slot(host, shot))
				if host.has_method("fx_puff"): host.fx_puff(shot.p, Color.WHITE, 4, 200)
				_die(shot)
				break
		if not shot.get("dead", false) and host.boss != null and host.boss.hit(shot.p, int(shot.get("damage", 1))):
			_credit_boss_hit(host, _shot_owner_slot(host, shot))
			_die(shot)
			if host.has_method("fx_puff"): host.fx_puff(shot.p, Color.WHITE, 4, 200)
			if host.boss.has_method("drain_events"):
				_boss_events(host, host.boss.drain_events())
		if not shot.get("dead", false):
			for crate in host.crates:
				if not crate.broken and absf(shot.p.x - crate.p.x) < 34 and shot.p.y > crate.p.y - 70 and shot.p.y < crate.p.y:
					hit_crate(host, crate, 1)
					_die(shot)
					break
	# Source wall filtering is a separate pass after ALL shot hit hooks.
	for shot in host.bullets.duplicate():
		if shot.enemy: continue
		if not shot.get("dead", false) and host.ability_inside_wall(shot.p):
			_die(shot)
			if host.has_method("fx_puff"): host.fx_puff(shot.p, Color.WHITE, 3, 150)
		var top := Vector2(0, host.view_top() - 60).y
		if shot.get("dead", false) or float(shot.get("life", 20)) <= 0 or shot.p.x <= host.camera.x - 40 or shot.p.x >= host.camera.x + host.view_width() + 40 or shot.p.y <= top or shot.p.y >= host.camera.y + 580: host.bullets.erase(shot)
	for bill in host.bullets.duplicate():
		if not bill.enemy: continue
		# Ama's bubbleAll and Maya's shield remove canceled bills during the
		# player/ability pre-step in source. Native abilities mark life=0;
		# honor that removal before either motion or contact, even when the
		# shield itself expires later in the same pre-step. Live bills still
		# collide before the ordinary floor/wall/culling pass below.
		if bill.get("dead", false) or float(bill.get("life", 20)) <= 0:
			host.bullets.erase(bill)
			continue
		var old_y: float = bill.p.y
		bill.v.y += float(bill.get("gravity", 0)) * dt
		bill.p += bill.v * dt
		bill.age = float(bill.get("age", 0)) + dt
		for player in _living(host):
			var height: float = player.height * (0.56 if player.crouching else 0.86)
			if absf(bill.p.x - player.p.x) < 26 and bill.p.y > player.p.y - height and bill.p.y < player.p.y:
				_die(bill)
				_hurt(host, player, bill.p.x - bill.v.x * 0.1)
		if host.world_five.blocks(bill.p): _die(bill)
		var hits_surface: bool = bill.v.y > 0 and host._land(bill.p.x, old_y + 6, bill.p.y + 6) != INF
		var hits_wall: bool = host.ability_inside_wall(bill.p) or bill.p.y > float(host.level.get("fall", 742))
		if hits_surface or hits_wall:
			_die(bill)
			if host.has_method("fx_puff"): host.fx_puff(bill.p, Color("a8d79a"), 4, 150)
		if bill.get("dead", false) or float(bill.get("life", 20)) <= 0 or bill.p.x <= host.camera.x - 60 or bill.p.x >= host.camera.x + host.view_width() + 60: host.bullets.erase(bill)

func pickups_tick(dt: float, host) -> void:
	for coin in host.coins.duplicate():
		coin.age += dt
		if not coin.rest:
			var old_y: float = coin.p.y
			coin.v.y += 2400 * dt
			coin.p += coin.v * dt
			var floor_y: float = host._land(coin.p.x, old_y + 8, coin.p.y + 8) if coin.v.y > 0 else INF
			if floor_y != INF:
				coin.p.y = floor_y - 8
				if absf(coin.v.y) > 150:
					coin.v.y *= -0.45
					coin.v.x *= 0.7
				else:
					coin.rest = true
					coin.v.y = 0
			if coin.p.y > float(host.level.get("fall", 742)): coin.dead = true
		for player in _living(host):
			var delta_p: Vector2 = player.p - Vector2(0, player.height * 0.4) - coin.p
			if absf(delta_p.x) < 110 and absf(delta_p.y) < 150 and coin.age > 0.25:
				coin.p.x += signf(delta_p.x) * minf(absf(delta_p.x), 500 * dt)
				if coin.rest and absf(delta_p.y) > 40:
					coin.rest = false
					coin.v.y = -200
			if absf(delta_p.x) < 30 and absf(delta_p.y) < player.height * 0.6 and coin.age > 0.25:
				coin.dead = true
				host.score += 1
				if host.has_method("fx_coin"): host.fx_coin(coin.p)
				if not player.get("host_player", false): player.coins = int(player.get("coins", 0)) + 1
				host.sfx("pick")
				break
		if coin.get("dead", false) or (not coin.get("stay", false) and coin.age >= 11) or coin.p.x <= host.camera.x - 60: host.coins.erase(coin)
	for item in host.items.duplicate():
		item.age += dt
		if not item.rest:
			var old_y: float = item.p.y
			item.vy += 2000 * dt
			item.p.y += item.vy * dt
			var floor_y: float = host._land(item.p.x, old_y + 26, item.p.y + 26) if item.vy > 0 else INF
			if floor_y != INF:
				item.p.y = floor_y - 26
				item.vy = 0
				item.rest = true
			if item.p.y > float(host.level.get("fall", 742)): item.dead = true
		for player in _living(host):
			if absf(player.p.x - item.p.x) < 40 and item.age > 0.3:
				_grant_item(host, player, item.give)
				if host.has_method("fx_item"): host.fx_item(item.p, item.give)
				item.dead = true
				host.sfx("power")
				break
		if item.get("dead", false): host.items.erase(item)

func sync_visuals(host) -> void:
	# Move source drawBot bookkeeping out of rendering. Call once after late
	# motion, so sprite stride is net displacement including projectile shoves.
	for enemy in host.enemies:
		# Source drawBot returns before bookkeeping outside this view margin.
		if enemy.p.x < host.camera.x - 150 or enemy.p.x > host.camera.x + host.view_width() + 150: continue
		var dx: float = enemy.p.x - float(enemy.get("last_visual_x", enemy.p.x))
		var distance := absf(dx)
		enemy.last_visual_x = enemy.p.x
		enemy.stride = float(enemy.get("stride", 0)) + distance
		if enemy.flash > 0 or enemy.state != "walk": enemy.visual_move = 0.0
		elif distance > 0.25: enemy.visual_move = signf(dx)
		elif distance < 0.05: enemy.visual_move = 0.0

func damage_enemy(host, enemy: Dictionary, damage: int, owner_slot: int = -1) -> void:
	if enemy.state == "pop": return
	enemy.hp -= damage
	enemy.flash = 0.09
	host.sfx("hitBot")
	if enemy.hp <= 0: kill_enemy(host, enemy, true, owner_slot)

func kill_enemy(host, enemy: Dictionary, credited: bool = true, owner_slot: int = -1) -> void:
	if enemy.state == "pop": return
	if enemy.get("big", false): host.add_coins(enemy.p - Vector2(0, 120), 14)
	enemy.state = "pop"
	enemy.t = 0.0
	enemy.gone = 0.0
	if host.has_method("fx_bits"): host.fx_bits(enemy.p - Vector2(0,60))
	if host.has_method("fx_shake"): host.fx_shake(3)
	if credited: _credit_pop(host, owner_slot)
	host.add_coins(enemy.p - Vector2(0, 70), 4 + rng.randi_range(0, 2))
	host.sfx("pop")

func hit_crate(host, crate: Dictionary, damage: int) -> void:
	if crate.broken: return
	crate.hp -= damage
	crate.hit = 0.12
	host.sfx("hitBot")
	if crate.hp <= 0:
		crate.broken = true
		if host.has_method("fx_bits"): host.fx_bits(crate.p - Vector2(0,40))
		host.items.append({"p": crate.p - Vector2(0, 40), "vy": -600.0, "give": crate.give, "age": 0.0, "rest": false})
		host.sfx("pop")

func _bill(host, position: Vector2, speed: Vector2, gravity: float, kind: String = "") -> void:
	var bill := {"p": position, "v": speed, "life": 20.0, "enemy": true, "gravity": gravity, "damage": 1}
	if not kind.is_empty(): bill[kind] = true
	host.bullets.append(bill)

func _die(shot: Dictionary) -> void:
	shot.dead = true
	shot.life = 0.0

func _bubbled(host, enemy: Dictionary) -> bool:
	return host.abilities != null and host.abilities.enemy_is_bubbled(enemy)

func _living(host) -> Array:
	# PartyCombat publishes stable mutable records for this once-shared pass.
	# Actor-specific damage still goes through that victim's scalar facade.
	if host.has_method("combat_participants"):
		return host.combat_participants().filter(func(player): return not player.get("down", false) and int(player.hearts) > 0)
	if host.hearts <= 0: return []
	return [{"host_player": true, "p": host.player, "hearts": host.hearts, "height": host.character_height(), "crouching": host.crouching, "power": host.power, "grounded": host.grounded, "velocity": host.velocity}]

func _nearest(host, x: float) -> Dictionary:
	var best: Dictionary = {}
	for player in _living(host):
		if best.is_empty() or absf(player.p.x - x) < absf(best.p.x - x): best = player
	return best

func _hurt(host, player: Dictionary, from_x: float) -> void:
	if player.get("host_player", false): host.hurt_player(from_x)
	else: host.hurt_combat_participant(player, from_x)

func _grant_item(host, player: Dictionary, give: String) -> void:
	if player.get("host_player", false):
		if give == "heart": host.hearts = mini(3, host.hearts + 1)
		else:
			host.power = give
			host.power_time = 12.0
	else:
		if give == "heart": player.hearts = mini(3, player.hearts + 1)
		else:
			player.power = give
			player.power_time = 12.0


func visuals_tick(dt: float, host) -> void:
	go_time = maxf(0, go_time - dt)
	sync_visuals(host)
func start_boss(host, _config: Dictionary = {}) -> void:
	if host.boss != null: return
	host.boss = King.new()
	if host.has_method("scene_music"): host.scene_music(true) # Source startKing requests boss track once.
	host.boss.reset(float(host.level.w), host.view_width(), float(host.meta.ground), participant_count, rng.randi())
	host.camera_lock = float(host.level.w) - host.view_width()
	_boss_events(host, host.boss.drain_events())
func boss_tick(dt: float, host) -> String:
	if host.boss == null: return ""
	var players := _living(host)
	return _boss_events(host, host.boss.boss_tick(dt, players, host.enemies.any(func(b): return b.state != "pop")), players)
func jar_tick(dt: float, host) -> String:
	if host.boss == null: return ""
	return _boss_events(host, host.boss.jar_tick(dt, _living(host)))
func _boss_events(host, events: Array, roster: Array = []) -> String:
	var result := ""
	for e in events:
		match e.type:
			"bill": host.bullets.append({"p": e.position, "v": e.velocity, "gravity": e.gravity, "enemy": true, "life": 20.0, "age": 0.0, "damage": 1, "big": true, "box": true})
			"helpers":
				for i in int(e.count):
					var x: float = clampf(e.x + (i - float(e.count) / 2) * 110, host.camera.x + 80, host.camera.x + host.view_width() - 80)
					var q: Dictionary = host.world_five.below(host, x, host.meta.ground - 10)
					if not q.is_empty(): new_bot(host, x, q, "throw" if i % 2 else "rush")
			"hurt_player":
				var players := _living(host) if roster.is_empty() else roster
				if e.index < players.size(): _hurt(host, players[e.index], e.source_x)
			"coins": host.add_coins(e.position, e.count)
			"kill_bots":
				for b in host.enemies: kill_enemy(host, b, false)
			"warning":
				host.status = str(e.text); host.sfx("warn")
				if host.has_method("hud_banner"):
					if str(e.text).begins_with("Warning!"): host.hud_banner("Warning!", "The Cardboard King", true)
					elif str(e.text).begins_with("Phase "):
						var title: String = str(e.text).split(":")[0]
						host.hud_banner(title, "Biggest yet. Aim for the crown!" if title == "Phase 3" else "Bigger, and now he stomps", true)
			"hit": host.sfx("hitBot")
			"throw": host.sfx("throw")
			"stomp": host.sfx("stomp")
			"jar_spawn": host.sfx("power")
			"down": host.status = "The Cardboard King is down. Grab the jar!"; host.sfx("stomp")
			"clear": result = "clear"
	return result

func _shot_owner_slot(host, shot: Dictionary) -> int:
	if shot.has("owner_slot"): return int(shot.owner_slot)
	if host.has_method("combat_participants") and host.combat_participants().any(func(p): return not p.get("host_player", false)): return -2
	return -1

func _shot_owner_x(host, shot: Dictionary) -> float:
	# Match the source owner reference, including a downed firing actor.
	if shot.has("owner_slot") and host.has_method("combat_participants"):
		for p in host.combat_participants():
			if int(p.get("slot", -2)) == int(shot.owner_slot): return float(p.p.x)
	return float(shot.get("owner_x", host.player.x))

func _credit_pop(host, owner_slot: int) -> void:
	if owner_slot == -2: return
	if host.has_method("credit_combat_pop"): host.credit_combat_pop(owner_slot)
	else: host.pop_count += 1

func _credit_boss_hit(host, owner_slot: int) -> void:
	if owner_slot < 0 or not host.has_method("combat_participants"): return
	for p in host.combat_participants():
		if not p.get("host_player", false) and int(p.get("slot", -2)) == owner_slot:
			p.boss_hits = int(p.get("boss_hits", 0)) + 1
			return
