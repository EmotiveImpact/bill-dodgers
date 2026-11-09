extends RefCounted
## World 6 combat. Source order: waves/objective, W6 systems, bots, shots, pickups, boss, jar.
## Every W6 HTML shares this runtime. Native units: seconds, absolute feet, px/s.
const EPS := 0.000000001
var rng := RandomNumberGenerator.new()
var waves: Array = []
var participant_count := 1
var go_time := 0.0
var _spawning_wave: Dictionary = {}
func reset(host, participants: int = 1, seed_value: int = 61) -> void:
	rng.seed = seed_value
	participant_count = maxi(1, participants)
	waves.clear()
	go_time = 0
	_spawning_wave = {}
	for source in host.level.get("waves", []):
		var wave: Dictionary = source.duplicate(true)
		var group: Array = source.g.duplicate(true)
		if participant_count > 1: group.append_array(source.get("x", []).duplicate(true))
		# Source does NOT sort the concatenated multiplayer additions.
		wave.merge({"group": group, "started": false, "done": false, "t": 0.0, "index": 0}, true)
		waves.append(wave)
	host.crates.clear()
	for row in host.level.get("crates", []):
		var s: Dictionary = host.world_six.below(host, row[0], row[1])
		host.crates.append({"p": Vector2(row[0], s.row[2] if not s.is_empty() else host.meta.ground), "hp": 3, "give": row[2], "broken": false, "hit": 0.0})
func waves_tick(dt: float, host) -> void:
	for wave in waves:
		if not wave.started and host.world_six.wave_ready(wave, host):
			wave.started = true
			wave.t = 0
			wave.index = 0
			if not wave.get("free", false): host.camera_lock = host.camera.x + 40
		if wave.started and not wave.done:
			wave.t += dt
			while wave.index < wave.group.size() and wave.t >= float(wave.group[wave.index][0]) / 1000:
				_spawning_wave = wave
				spawn(host, wave.group[wave.index][1], wave.group[wave.index][2])
				_spawning_wave = {}
				wave.index += 1
			if wave.index >= wave.group.size() and (wave.get("free", false) or not host.world_six.has_active_foes(host, wave)):
				wave.done = true
				if not wave.get("free", false):
					host.camera_lock = null
					go_time = 2.2
					host.status = "Go!"
					if host.has_method("hud_go"): host.hud_go()
func spawn(host, side: Variant, kind: String) -> void:
	if kind == "mailer": spawn_flier(host, side)
	elif kind in ["drop", "dropthrow"]: spawn_drop(host, "rush" if kind == "drop" else "throw")
	elif kind.begins_with("mini:"): start_mini(host, kind.trim_prefix("mini:"), _spawning_wave)
	elif kind == "debit":
		_spawn_ordinary(host, side, "rush")
		# Preserve source's last-rusher conversion even when placement failed.
		if not host.enemies.is_empty() and host.enemies.back().type == "rush":
			var b: Dictionary = host.enemies.back()
			b.type = "debit"
			b.kind = "debit"
			b.hp = 2
			b.max_hp = 2
			b.speed = 170.0
	else: _spawn_ordinary(host, side, kind)
func _spawn_ordinary(host, side: Variant, kind: String) -> void:
	var from_right: bool = side == "r"
	var x: float = host.camera.x + host.view_width() + 70 if from_right else host.camera.x - 70
	var living := _living(host)
	var player_floor := 482.0
	if not living.is_empty():
		player_floor = 0.0
		for player in living: player_floor += player.p.y
		player_floor /= living.size()
	var chosen: Dictionary = {}
	for i in range(50):
		var candidate_x := x + (-1 if from_right else 1) * i * 24
		var distance := INF
		for surface in host.world_six.surfaces(host):
			var row: Array = surface.row
			var width := float(row[1]) - float(row[0])
			if surface.plat or width <= 200: continue
			if candidate_x <= float(row[0]) + 30 or candidate_x >= float(row[1]) - 30: continue
			if float(row[2]) <= host.view_top() + 120 or float(row[2]) >= host.camera.y + 600: continue
			var dy := absf(float(row[2]) - player_floor)
			if dy < distance:
				distance = dy
				chosen = surface
		if not chosen.is_empty():
			x = candidate_x
			break
	if chosen.is_empty(): return
	new_bot(host, x, chosen, kind, {"face": -1 if from_right else 1, "spawn_side": side})

func new_bot(host, x: float, surface: Dictionary, kind: String, extra: Dictionary = {}) -> Dictionary:
	var rush := kind == "rush"
	var enemy := {"p": Vector2(x, surface.row[2]), "kind": kind, "type": kind, "hp": 3 if rush else 4,
		"state": "walk", "t": rng.randf_range(0, 0.4), "cd": rng.randf_range(0.9, 1.8),
		"stop": 0.0 if rush else rng.randf_range(230, 400), "speed": (110 if rush else 75) * rng.randf_range(0.9, 1.15),
		"face": -1, "entered": false, "wait": 0.0, "gone": 0.0, "flash": 0.0,
		"pending": false, "scale": 1.0, "segment": surface.row, "surface": surface,
		"stride": 0.0, "visual_move": 0.0}
	enemy.merge(extra, true)
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
				else: _bill(host, enemy.p + Vector2(enemy.face * 26, -100), Vector2(clampf(dx / 0.9, -500, 500), -780), 1700)
			if enemy.t >= 0.44:
				enemy.state = "walk"
				enemy.t = 0.0
				enemy.cd = rng.randf_range(1.4, 2.8)
		if enemy.entered: enemy.p.x = clampf(enemy.p.x, host.camera.x + 40, host.camera.x + host.view_width() - 40)
		_edge_hop(host, enemy)
		if not enemy.has("hop"): enemy.p.x = clampf(enemy.p.x, float(enemy.segment[0]) + 22, float(enemy.segment[1]) - 22)
		for target in _living(host):
			if enemy.type != "debit" and absf(target.p.x - enemy.p.x) < 44 and target.p.y > enemy.p.y - 95 and target.p.y < enemy.p.y + 24:
				_hurt(host, target, enemy.p.x)
	for enemy in host.enemies.duplicate():
		if enemy.state != "pop" and _bubbled(host, enemy): continue
		if not enemy.entered and enemy.state != "pop":
			enemy.wait += dt
			if enemy.wait > 6 + EPS:
				host.enemies.erase(enemy)
				continue
		if enemy.get("lost", false) or (enemy.state == "pop" and enemy.gone > 1.3 + EPS) or enemy.p.x <= host.camera.x - 400 or enemy.p.x >= host.camera.x + host.view_width() + 400: host.enemies.erase(enemy)

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

func _edge_hop(host, enemy: Dictionary) -> void:
	var player := _nearest(host, enemy.p.x)
	if player.is_empty() or not enemy.entered or enemy.state != "walk" or absf(player.p.x - enemy.p.x) <= 30: return
	var direction := signf(player.p.x - enemy.p.x)
	var segment: Array = enemy.segment
	var edge: float = segment[1] if direction > 0 else segment[0]
	if absf(enemy.p.x - edge) >= 26: return
	var next: Array = []
	var next_surface: Dictionary = {}
	for surface in host.world_six.surfaces(host):
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
		if intercept_shot(host, shot): continue
		for enemy in host.enemies:
			if enemy.state == "pop": continue
			var hw := 34.0
			var hh := 112.0
			if enemy.p.x > minf(before.x, shot.p.x) - hw and enemy.p.x < maxf(before.x, shot.p.x) + hw and shot.p.y > enemy.p.y - hh and shot.p.y < enemy.p.y:
				# Source shoves before the death/coin-drop callback.
				enemy.p.x += signf(shot.v.x if shot.v.x != 0 else 0.001) * 6
				damage_enemy(host, enemy, int(shot.get("damage", 1)) * (2 if float(enemy.get("dz", 0)) > 0 else 1), _shot_owner_slot(host, shot))
				if host.has_method("fx_puff"): host.fx_puff(shot.p, Color.WHITE, 4, 200)
				_die(shot)
				break
		if not shot.get("dead", false) and host.boss != null and host.boss.hit(shot.p, int(shot.get("damage", 1))):
			_die(shot)
			if host.has_method("fx_puff"): host.fx_puff(shot.p, Color.WHITE, 4, 200)
			_credit_boss_hit(host, shot)
			host.boss.flush_down(host, host.world_six)
			host.boss.drain_events()
			host.sfx("hitBot")
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

func _die(shot: Dictionary) -> void:
	shot.dead = true
	shot.life = 0.0

func _bubbled(host, enemy: Dictionary) -> bool:
	return host.abilities != null and host.abilities.enemy_is_bubbled(enemy)

func _living(host) -> Array:
	# In a shared party phase the bridge supplies stable mutable records.
	# Each damage callback binds only its victim, never a second world tick.
	if host.has_method("combat_participants"):
		return host.combat_participants().filter(func(player): return not player.get("down", false) and int(player.hearts) > 0)
	if host.hearts <= 0: return []
	return [{"host_player": true, "p": host.player, "hearts": host.hearts, "height": host.character_height(), "crouching": host.crouching, "power": host.power, "grounded": host.grounded, "velocity": host.velocity, "invincible": host.invincible, "face": host.face}]

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

func _bill(host, position: Vector2, speed: Vector2, gravity: float, kind: String = "") -> void:
	bill(host, position, speed, gravity, {kind: true} if kind else {})
func bill(host, position: Vector2, speed: Vector2, gravity: float, extra: Dictionary = {}) -> void:
	var entry := {"p": position, "v": speed, "gravity": gravity, "age": 0.0, "life": 20.0, "damage": 1, "enemy": true}
	entry.merge(extra, true)
	host.bullets.append(entry)
func visuals_tick(dt: float, host) -> void:
	host.world_six.effects_tick(dt, host)
	go_time = maxf(0, go_time - dt)
	for crate in host.crates: crate.hit = maxf(0, crate.hit - dt)
	sync_visuals(host)
func spawn_flier(host, side: String) -> void:
	var living := _living(host)
	var floor_y: float = host.meta.ground
	if not living.is_empty():
		floor_y = INF
		for player in living: floor_y = minf(floor_y, player.p.y)
	host.world_six.fliers.append({"p": Vector2(host.camera.x + host.view_width() + 60 if side == "r" else host.camera.x - 60, maxf(host.view_top() + 80, floor_y - 300)), "hp": 2, "t": rng.randf_range(0, 0.5), "cd": rng.randf_range(1.4, 2.3), "face": -1 if side == "r" else 1, "flash": 0.0, "state": "fly", "off": rng.randf_range(-150, 150), "gone": 0.0, "drop": 0.0, "entered": false})
func spawn_drop(host, kind: String) -> void:
	var candidates: Array = host.world_six.surfaces(host).filter(func(s): return float(s.row[1]) - float(s.row[0]) >= 150 and s.row[2] > host.view_top() + 160 and s.row[2] < host.camera.y + 520 and s.row[1] > host.camera.x + 120 and s.row[0] < host.camera.x + host.view_width() - 120 and s.art != "lift")
	if candidates.is_empty():
		_spawn_ordinary(host, "l" if rng.randf() < 0.5 else "r", kind)
		return
	var surface: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
	var low := maxf(float(surface.row[0]) + 30, host.camera.x + 80)
	var high := maxf(low, minf(float(surface.row[1]) - 30, host.camera.x + host.view_width() - 80))
	var x := rng.randf_range(low, high)
	var living := _living(host)
	for player in living:
		if absf(player.p.x - x) < 120: x = clampf(player.p.x + (-150 if x < player.p.x else 150), low, high)
	var b := new_bot(host, x, surface, kind, {"p": Vector2(x, host.view_top() - 40), "entered": true, "face": -1 if not living.is_empty() and living[0].p.x < x else 1, "cd": rng.randf_range(1.2, 2.1)})
	_hop(b, surface, x, 0.52)
	host.world_six.vents.append({"x": x, "y": host.view_top() + 2, "t": 0.0})
func fliers_tick(dt: float, host) -> void:
	var world = host.world_six
	for f in world.fliers:
		f.t += dt
		f.flash = maxf(0, float(f.flash) - dt)
		f.drop = maxf(0, float(f.drop) - dt)
		if f.state == "pop":
			f.gone += dt
			f.p.y += 120 * dt
			continue
		var player := _nearest(host, f.p.x)
		if player.is_empty(): continue
		var destination: Vector2 = player.p + Vector2(f.off, -235 + sin(float(f.t) / 0.3) * 12)
		f.p.x += clampf((destination.x - f.p.x) * 4 * dt, -130 * dt, 130 * dt)
		f.p.y += clampf((destination.y - f.p.y) * 4 * dt, -130 * dt, 130 * dt)
		if player.p.x != f.p.x: f.face = signf(player.p.x - f.p.x)
		if not f.entered and f.p.x > host.camera.x + 40 and f.p.x < host.camera.x + host.view_width() - 40: f.entered = true
		if f.entered: f.p.x = clampf(f.p.x, host.camera.x + 30, host.camera.x + host.view_width() - 30)
		f.p.y = maxf(host.view_top() + 70, f.p.y)
		if rng.randf() < 0.125 * dt: f.off = rng.randf_range(-150, 150)
		f.cd -= dt
		if f.cd <= 0 and f.entered and absf(player.p.x - f.p.x) < 260:
			f.cd = rng.randf_range(1.7, 2.7)
			f.drop = 0.3
			bill(host, f.p + Vector2(0, 26), Vector2((player.p.x - f.p.x) / 2.4, 40), 1100, {"leaf": true})
			host.sfx("throw")
		for target in _living(host):
			if absf(target.p.x - f.p.x) < 34 and f.p.y > target.p.y - target.height - 20 and f.p.y < target.p.y: _hurt(host, target, f.p.x)
	world.fliers = world.fliers.filter(func(f): return not (f.state == "pop" and f.gone > 0.7 + EPS) and f.p.x > host.camera.x - 500 and f.p.x < host.camera.x + host.view_width() + 500)
func intercept_shot(host, shot: Dictionary) -> bool:
	for f in host.world_six.fliers:
		if f.state == "pop": continue
		if absf(shot.p.x - f.p.x) < 38 and absf(shot.p.y - f.p.y) < 34:
			_die(shot)
			f.hp -= int(shot.get("damage", 1))
			f.flash = 0.09
			host.sfx("hitBot")
			if f.hp <= 0:
				f.state = "pop"
				f.gone = 0
				host.add_coins(f.p, 3)
				_credit_pop(host, _shot_owner_slot(host, shot))
				host.sfx("pop")
			return true
	var m: Dictionary = host.world_six.mini_boss
	if not m.is_empty() and m.state == "fight" and absf(shot.p.x - m.x) < float(m.w) / 2 and shot.p.y > m.y - m.h and shot.p.y < m.y:
		_die(shot)
		m.hp -= int(shot.get("damage", 1))
		m.flash = 0.08
		host.sfx("hitBot")
		if m.hp <= 0: mini_down(host, _shot_owner_slot(host, shot))
		return true
	return false
func start_mini(host, kind: String, wave: Dictionary = {}) -> void:
	var x: float = host.camera.x + host.view_width() - 150
	var s: Dictionary = host.world_six.below(host, x, host.view_top())
	var hp := 60 if participant_count > 1 else 44
	host.world_six.mini_boss = {"kind": kind, "name": "Franking machine" if kind == "franker" else "The Jammer", "w": 300 if kind == "franker" else 270, "h": 240 if kind == "franker" else 220, "x": x + 400, "x1": x, "y": s.row[2] if not s.is_empty() else float(host.meta.ground), "hp": hp, "max": hp, "t": 0.0, "cd": 1.5, "flash": 0.0, "state": "enter", "wave": wave, "shock": [], "n": 0, "calls": 0, "anim": 0.0, "slam": 0.0}
	host.status = "Warning! " + host.world_six.mini_boss.name
	if host.has_method("scene_music"): host.scene_music(true)
	if host.has_method("hud_banner"): host.hud_banner("Warning!", "The " + host.world_six.mini_boss.name.to_lower().replace("the ", "") + " wants a word", true)
	host.sfx("warn")
func mini_tick(dt: float, host) -> void:
	var m: Dictionary = host.world_six.mini_boss
	m.t += dt
	m.flash = maxf(0, float(m.flash) - dt)
	for s in m.shock:
		s.x += s.vx * dt
		s.t += dt
		for target in _living(host):
			if absf(s.x - target.p.x) < 24 and target.p.y > m.y - 30: _hurt(host, target, s.x - s.vx * 0.05)
	m.shock = m.shock.filter(func(s): return s.t < 2.6)
	if m.state == "down": return
	if m.state == "enter":
		m.x -= 250 * dt
		if m.x <= m.x1:
			m.x = m.x1
			m.state = "fight"
			m.t = 0
		return
	var player := _nearest(host, m.x)
	if player.is_empty(): return
	m.cd -= dt
	if m.cd <= 0:
		m.n += 1
		m.anim = 0.4
		if m.kind == "franker":
			if int(m.n) % 3 == 0:
				m.shock.append({"x": m.x - float(m.w) / 2, "vx": -400.0, "t": 0.0})
				m.slam = 0.5
				host.sfx("stomp")
			else:
				for i in range(3): bill(host, Vector2(m.x - 70, m.y - m.h + 40), Vector2(clampf(player.p.x + (i - 1) * 110 - m.x, -700, 300), -750 - i * 80), 1600, {"stamp": true})
				host.sfx("throw")
			m.cd = rng.randf_range(1.5, 2.1)
		else:
			bill(host, Vector2(m.x - float(m.w) / 2, m.y - (34 if int(m.n) % 2 == 0 else 132)), Vector2(-460, 0), 0, {"flat": true, "sheet": true})
			if int(m.n) % 4 == 0: bill(host, Vector2(m.x - float(m.w) / 2, m.y - 132), Vector2(-460, 0), 0, {"flat": true, "sheet": true, "age": -0.2, "delay": 0.38})
			m.cd = rng.randf_range(1.1, 1.6)
			host.sfx("throw")
	var fraction: float = float(m.hp) / m.max
	if fraction < 0.6 and m.calls == 0:
		m.calls = 1
		spawn(host, "l", "drop" if m.kind == "jammer" else "mailer")
		spawn(host, "r", "drop")
		host.world_six.add_float("Backup!", Vector2(m.x, m.y - m.h - 30), Color("ffb3b3"))
	if fraction < 0.3 and m.calls == 1:
		m.calls = 2
		spawn(host, "l", "mailer")
		if participant_count > 1: spawn(host, "r", "drop")
	for target in _living(host):
		if absf(target.p.x - float(m.x)) < float(m.w) / 2 - 20 and target.p.y > m.y - m.h + 30:
			_hurt(host, target, m.x)
			if target.get("host_player", false): host.velocity.x = -500
			else: target.velocity.x = -500
	m.anim = maxf(0, float(m.anim) - dt)
	m.slam = maxf(0, float(m.slam) - dt)
func mini_down(host, owner_slot: int = -1) -> void:
	var m: Dictionary = host.world_six.mini_boss
	if m.state == "down": return
	m.state = "down"
	m.t = 0
	m.shock.clear()
	host.add_coins(Vector2(m.x, m.y - float(m.h) / 2), 18)
	for i in range(5): _credit_pop(host, owner_slot)
	host.sfx("pop")
	host.sfx("stomp")
	host.status = m.name + " bust!"
	if host.has_method("scene_music"): host.scene_music(false)
	host.world_six.add_float(host.status, Vector2(m.x, m.y - m.h - 20), Color("f4c542"))
	for b in host.bullets:
		if b.enemy and (b.get("stamp", false) or b.get("sheet", false)): _die(b)
func _hop(b: Dictionary, surface: Dictionary, x: float, duration: float) -> void:
	b.hop = {"start": b.p, "end": Vector2(x, surface.row[2]), "t": 0.0, "duration": duration, "surface": surface, "segment": surface.row}
func bot_navigation(host) -> void:
	var world = host.world_six
	for b in host.enemies:
		if b.has("hop") or b.state == "pop" or b.get("surface", {}).is_empty(): continue
		var inside: Dictionary = {}
		for q in world.surfaces(host, true):
			if not is_same(q, b.surface) and q.art not in ["cradle", "lift"] and b.p.x > q.row[0] - 2 and b.p.x < q.row[1] + 2 and q.row[2] < b.p.y - 6:
				inside = q
				break
		if not inside.is_empty():
			if inside.art == "void": b.p.x = inside.row[0] - 24 if absf(b.p.x - inside.row[0]) < absf(b.p.x - inside.row[1]) else inside.row[1] + 24
			else: _hop(b, inside, clampf(b.p.x, inside.row[0] + 30, inside.row[1] - 30), 0.42)
			continue
		var player := _nearest(host, b.p.x)
		if b.state != "walk" or not b.entered or player.is_empty(): continue
		var direction := signf(player.p.x - b.p.x)
		if direction == 0 or absf(player.p.x - b.p.x) < 40: continue
		var up: Dictionary = {}
		for q in world.surfaces(host, true):
			if is_same(q, b.surface) or q.art == "cradle" or q.row[2] >= b.p.y - 6 or q.row[2] <= b.p.y - 230: continue
			if (direction > 0 and q.row[0] > b.p.x and q.row[0] - b.p.x < 40) or (direction < 0 and b.p.x > q.row[1] and b.p.x - q.row[1] < 40):
				up = q
				break
		if not up.is_empty():
			_hop(b, up, up.row[0] + 36 if direction > 0 else up.row[1] - 36, 0.52)
			continue
		var edge: float = b.segment[1] if direction > 0 else b.segment[0]
		if absf(b.p.x - edge) < 26 and (player.p.x > edge if direction > 0 else player.p.x < edge):
			var q: Dictionary = world.below(host, edge + direction * 50, b.p.y + 2)
			if not q.is_empty() and not is_same(q, b.surface) and q.row[1] - q.row[0] > 60 and q.row[2] - b.p.y < 600: _hop(b, q, clampf(edge + direction * 50, q.row[0] + 24, q.row[1] - 24), 0.42 + absf(q.row[2] - b.p.y) / 1000)
		if b.type == "rush" and player.p.y < b.p.y - 190 and absf(player.p.x - b.p.x) < 260:
			# Deliberate source frame-count behavior: +16ms per invocation.
			b.high = float(b.get("high", 0)) + 0.016
			if b.high > 1.5 + EPS:
				b.type = "throw"
				b.stop = rng.randf_range(260, 340)
				b.speed = 75
				b.cd = 0.4
		else: b.high = 0
		if not b.has("hop") and player.grounded and player.p.y < b.p.y - 40 and player.p.y > b.p.y - 200 and absf(player.p.x - b.p.x) < 160 and b.type == "rush" and rng.randf() < 0.01:
			var q: Dictionary = world.surf_under(player.p.x, player.p.y)
			if not q.is_empty() and q.row[1] - q.row[0] > 60: _hop(b, q, clampf(b.p.x + direction * 80, q.row[0] + 24, q.row[1] - 24), 0.56)
func debits_tick(dt: float, host) -> void:
	if host.has_method("combat_participants") and host.combat_participants().any(func(p): return not p.get("host_player", false)):
		_party_debits_tick(dt, host)
		return
	for b in host.enemies:
		if b.type != "debit" or b.state == "pop": continue
		if b.get("latch", false):
			if host.hearts <= 0:
				b.latch = false
				continue
			b.p = host.player - Vector2(host.face * 18, 0)
			var s: Dictionary = host.world_six.surf_under(host.player.x, host.player.y)
			if not s.is_empty():
				b.surface = s
				b.segment = s.row
			b.drain = float(b.get("drain", 0)) + dt
			if b.drain > 0.65 + EPS:
				b.drain = 0
				if host.score > 0:
					host.score -= 1
					host.status = "-£1"
					host.world_six.add_float(host.status, host.player - Vector2(0, host.character_height() + 10), Color("ffb3b3"))
					host.sfx("coin")
			if not host.grounded and not b.get("was_air", false): b.jumps = int(b.get("jumps", 0)) + 1
			b.was_air = not host.grounded
			if int(b.get("jumps", 0)) >= 2:
				b.latch = false
				b.jumps = 0
				b.cool = 1.5
				var q: Dictionary = host.world_six.below(host, b.p.x - host.face * 120, b.p.y - 4)
				if q.is_empty(): q = b.surface
				_hop(b, q, b.p.x - host.face * 120, 0.5)
				host.status = "Shaken off!"
				host.world_six.add_float(host.status, host.player - Vector2(0, host.character_height() + 30), Color("9fe0b8"))
			continue
		b.cool = maxf(0, float(b.get("cool", 0)) - dt)
		if b.cool <= 0 and not b.has("hop") and host.hearts > 0 and absf(host.player.x - b.p.x) < 34 and absf(host.player.y - b.p.y) < 30 and host.invincible <= 0 and not host.enemies.any(func(other): return other.get("latch", false)):
			b.latch = true
			b.jumps = 0
			b.was_air = not host.grounded
			host.status = "Direct debit! Jump twice"
			host.world_six.add_float(host.status, host.player - Vector2(0, host.character_height() + 30), Color("ffb3b3"))
			host.sfx("hurt")

func _shot_owner_slot(host, shot: Dictionary) -> int:
	if shot.has("owner_slot"): return int(shot.owner_slot)
	if host.has_method("combat_participants") and host.combat_participants().any(func(player): return not player.get("host_player", false)): return -2
	return -1

func _shot_owner_x(host, shot: Dictionary) -> float:
	# Source keeps the firing player reference, not a frozen spawn x. A downed
	# owner is still the owner; do not filter this lookup through _living().
	if shot.has("owner_slot") and host.has_method("combat_participants"):
		for participant in host.combat_participants():
			if int(participant.get("slot", -2)) == int(shot.owner_slot): return float(participant.p.x)
	return float(shot.get("owner_x", host.player.x))

func _credit_pop(host, owner_slot: int) -> void:
	if owner_slot == -2: return
	if host.has_method("credit_combat_pop"): host.credit_combat_pop(owner_slot)
	else: host.pop_count += 1


func _credit_boss_hit(host, shot: Dictionary) -> void:
	var slot := _shot_owner_slot(host, shot)
	if slot < 0 or not host.has_method("combat_participants"): return
	for player in host.combat_participants():
		if int(player.get("slot", -2)) == slot:
			player.boss_hits = int(player.get("boss_hits", 0)) + 1
			return

func _party_debits_tick(dt: float, host) -> void:
	var roster: Array = host.combat_participants()
	for bot in host.enemies:
		if bot.type != "debit" or bot.state == "pop": continue
		if bot.get("latch", false):
			var player: Dictionary = {}
			for candidate in roster:
				if int(candidate.slot) == int(bot.get("latch_slot", -2)): player = candidate; break
			if player.is_empty() or player.down or player.hearts <= 0:
				bot.latch = false
				bot.erase("latch_slot")
				continue
			bot.p = player.p - Vector2(player.face * 18, 0)
			var surface: Dictionary = host.world_six.surf_under(player.p.x, player.p.y)
			if not surface.is_empty(): bot.surface = surface; bot.segment = surface.row
			bot.drain = float(bot.get("drain", 0)) + dt
			if bot.drain > 0.65 + EPS:
				bot.drain = 0
				if int(player.coins) > 0:
					player.coins -= 1
					host.score = maxi(0, host.score - 1)
					host.status = "-£1"
					host.world_six.add_float(host.status, player.p - Vector2(0, player.height + 10), Color("ffb3b3"))
					host.sfx("coin")
			if not player.grounded and not bot.get("was_air", false): bot.jumps = int(bot.get("jumps", 0)) + 1
			bot.was_air = not player.grounded
			if int(bot.get("jumps", 0)) >= 2:
				bot.latch = false
				bot.erase("latch_slot")
				bot.jumps = 0
				bot.cool = 1.5
				var to_x: float = bot.p.x - player.face * 120
				var target: Dictionary = host.world_six.below(host, to_x, bot.p.y - 4)
				if target.is_empty(): target = bot.surface
				_hop(bot, target, to_x, 0.5)
				host.status = "Shaken off!"
				host.world_six.add_float(host.status, player.p - Vector2(0, player.height + 30), Color("9fe0b8"))
			continue
		bot.cool = maxf(0, float(bot.get("cool", 0)) - dt)
		if bot.cool > 0 or bot.has("hop"): continue
		for player in _living(host):
			if absf(player.p.x - bot.p.x) >= 34 or absf(player.p.y - bot.p.y) >= 30 or player.invincible > 0: continue
			if host.enemies.any(func(other): return other.get("latch", false) and int(other.get("latch_slot", -2)) == int(player.slot)): continue
			bot.latch = true
			bot.latch_slot = player.slot
			bot.jumps = 0
			bot.was_air = not player.grounded
			host.status = "Direct debit! Jump twice"
			host.world_six.add_float(host.status, player.p - Vector2(0, player.height + 30), Color("ffb3b3"))
			host.sfx("hurt")
			break
