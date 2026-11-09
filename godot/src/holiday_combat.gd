extends RefCounted
## W4 ordinary combat, deliberately isolated from festival hooks. Common source
## algorithms translated in absolute feet/pixels, seconds, px/s. Custom foe
## interception precedes ordinary bot shots; host owns the world pre-combat pass.
const EPS := 0.000000001
var rng := RandomNumberGenerator.new()
var waves: Array = []
var participant_count := 1
var go_time := 0.0
func reset(host, participants: int = 1, seed_value: int = 41) -> void:
	rng.seed = seed_value
	participant_count = maxi(1, participants)
	waves.clear()
	go_time = 0
	for source in host.level.get("waves", []):
		var group: Array = source.g.duplicate(true)
		if participant_count > 1: group.append_array(source.get("x2", []).duplicate(true))
		waves.append({"at": float(source.at), "group": group, "started": false, "done": false, "t": 0.0, "index": 0})
	host.crates.clear()
	for row in host.level.get("crates", []):
		var surface: Dictionary = host.world_four.below(host, row[0], row[1])
		if not surface.is_empty(): host.crates.append({"p": Vector2(row[0], surface.row[2]), "hp": 3, "give": row[2], "broken": false, "hit": 0.0})
func waves_tick(dt: float, host) -> void:
	for wave in waves:
		if not wave.started and host.camera.x >= wave.at - 2:
			wave.started = true
			wave.t = 0
			wave.index = 0
			host.camera_lock = null if host.level.get("auto", 0) else host.camera.x + 40
		if wave.started and not wave.done:
			wave.t += dt
			while wave.index < wave.group.size() and wave.t >= float(wave.group[wave.index][0]) / 1000:
				var entry: Array = wave.group[wave.index]
				spawn(host, entry[1], entry[2])
				wave.index += 1
			if wave.index >= wave.group.size() and (host.level.get("auto", 0) or (not host.enemies.any(func(b): return b.state != "pop") and not host.world_four.busy(host))):
				wave.done = true
				host.camera_lock = null
				if not host.level.get("auto", 0):
					go_time = 2.2
					host.status = "Go!"
func spawn(host, side: Variant, kind: String) -> void:
	if not host.world_four.spawn_foe(str(side), kind, host): _spawn_ordinary(host, side, kind)

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
		for surface in host.world_four.surfaces(host):
			var row: Array = surface.row
			var width := float(row[1]) - float(row[0])
			if surface.plat or surface.get("nobot", false) or width <= 200: continue
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
		_try_hop(host, enemy)
		if not enemy.has("hop"): enemy.p.x = clampf(enemy.p.x, float(enemy.segment[0]) + 22, float(enemy.segment[1]) - 22)
		for target in _living(host):
			if absf(target.p.x - enemy.p.x) < 44 and target.p.y > enemy.p.y - 95 and target.p.y < enemy.p.y + 24:
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

func _try_hop(host, enemy: Dictionary) -> void:
	var player := _nearest(host, enemy.p.x)
	if player.is_empty() or not enemy.entered or enemy.state != "walk" or absf(player.p.x - enemy.p.x) <= 30: return
	var direction := signf(player.p.x - enemy.p.x)
	var segment: Array = enemy.segment
	var edge: float = segment[1] if direction > 0 else segment[0]
	if absf(enemy.p.x - edge) >= 26: return
	var next: Array = []
	var next_surface: Dictionary = {}
	for surface in host.world_four.surfaces(host):
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
		if host.world_four.intercept_shot(shot, before.x, host): continue
		for enemy in host.enemies:
			if enemy.state == "pop": continue
			var hw := 34.0
			var hh := 112.0
			if enemy.p.x > minf(before.x, shot.p.x) - hw and enemy.p.x < maxf(before.x, shot.p.x) + hw and shot.p.y > enemy.p.y - hh and shot.p.y < enemy.p.y:
				# Source shoves before the death/coin-drop callback.
				enemy.p.x += signf(shot.v.x if shot.v.x != 0 else 0.001) * 6
				damage_enemy(host, enemy, int(shot.get("damage", 1)), _shot_owner_slot(host, shot))
				if host.has_method("fx_puff"): host.fx_puff(shot.p, Color.WHITE, 4, 200)
				_die(shot)
				break
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
		if coin.get("dead", false) or coin.age >= 11 or coin.p.x <= host.camera.x - 60: host.coins.erase(coin)
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
	# In a shared party phase the bridge supplies stable mutable records.
	# Each damage callback binds only its victim, never a second world tick.
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
	for crate in host.crates: crate.hit = maxf(0, crate.hit - dt)
	sync_visuals(host)

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
