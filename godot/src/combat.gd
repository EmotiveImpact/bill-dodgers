extends RefCounted
## World 1 shared combat, translated from the pinned Canvas source.
## Coordinates are absolute world pixels; timers use seconds.
var rng := RandomNumberGenerator.new()
var waves: Array = []
var checks: Array = []
var bailiff_seen := false
var participant_count := 1

func reset(host, seed_value: int = 11, participants: int = 1) -> void:
	rng.seed = seed_value
	participant_count = maxi(1, participants)
	waves.clear()
	checks.clear()
	bailiff_seen = false
	for source in host.level.get("waves", []):
		var at: float = float(source[0]) if source is Array else float(source.at)
		var group: Array = (source[1] if source is Array else source.g).duplicate(true)
		if participant_count > 1 and not group.is_empty():
			var last: Array = group[-1]
			group.append([float(last[0]) + 600, "l" if last[1] == "r" else "r", last[2]])
		waves.append({"at": minf(at, float(host.level.w) - host.view_width()), "group": group.duplicate(true), "started": false, "done": false, "t": 0.0, "index": 0})
	for x in host.level.get("checks", []): checks.append({"x": float(x), "hit": false})
	for row in host.level.get("crates", []):
		host.crates.append({"p": Vector2(row[0], host.floor_at(row[0], row[1])), "hp": 3, "give": row[2], "broken": false, "hit": 0.0})

func tick(dt: float, host) -> void:
	for wave in waves:
		if not wave.started and host.camera.x >= wave.at - 2:
			wave.started = true
			host.camera_lock = null if host.level.get("auto", 0) else host.camera.x + 40
		if wave.started and not wave.done:
			wave.t += dt
			while wave.index < wave.group.size() and wave.t >= float(wave.group[wave.index][0]) / 1000:
				var entry: Array = wave.group[wave.index]
				spawn(host, entry[1], entry[2])
				wave.index += 1
			if wave.index >= wave.group.size() and not host.enemies.any(func(enemy): return enemy.state != "pop"):
				wave.done = true
				host.camera_lock = null
				host.status = "Go!"
				if host.has_method("hud_go"): host.hud_go()
	host.scene_objective(dt)
	if host.mode != "play": return
	_update_enemies(dt, host)
	if host.level_id == "1-6" or (host.has_method("combat_participants") and host.combat_participants().filter(func(player): return not player.get("host_player", false)).size() > 1):
		if host.has_method("combat_bubbles_tick"): host.combat_bubbles_tick(dt)
		else: host.abilities.bubbles_tick(dt, host)
	if host.mode != "play": return
	projectiles(dt, host)
	if host.mode != "play": return
	_pickups(dt, host)
	for check_point in checks:
		if not check_point.hit and host.camera.x + host.view_width() * 0.5 >= check_point.x:
			check_point.hit = true
			for participant in _living(host):
				if participant.get("host_player", false): host.hearts = maxi(host.hearts, 2)
				else: participant.hearts = maxi(int(participant.hearts), 2)
			host.checkpoint = Vector2(check_point.x, host.floor_at(check_point.x, -9999))
			for participant in _living(host):
				if not participant.get("host_player", false): participant.checkpoint = host.checkpoint
			host.status = "Checkpoint! Carry on from here."
			if host.has_method("hud_banner"): host.hud_banner("Checkpoint!", "Knocked out? You carry on from here")
			host.sfx("power")

func spawn(host, side: String, kind: String) -> void:
	if host.bus_ride.spawn(host, side, kind): return
	var x: float = host.camera.x + host.view_width() + 70 if side == "r" else host.camera.x - 70
	var player_floor: float = host.player.y
	var living := _living(host)
	if not living.is_empty():
		player_floor = 0
		for participant in living: player_floor += participant.p.y / living.size()
	var floor_y: float = player_floor
	var segment: Array = []
	if kind != "fly":
		for i in range(50):
			var test_x := x + (-1 if side == "r" else 1) * i * 24
			var nearest := INF
			for row in host.level.get("solids", []):
				if float(row[1]) - float(row[0]) <= 200 or test_x <= float(row[0]) + 30 or test_x >= float(row[1]) - 30: continue
				if float(row[2]) <= host.view_top() + 120 or float(row[2]) >= host.camera.y + 600: continue
				var distance: float = absf(float(row[2]) - player_floor)
				if distance < nearest:
					segment = row
					nearest = distance
			if not segment.is_empty():
				x = test_x
				floor_y = float(segment[2])
				break
		if segment.is_empty(): return
	var rush := kind in ["rush", "tiny"]
	var enemy := {"p": Vector2(x, floor_y), "kind": kind, "type": "rush" if rush else ("flat" if kind == "flat" else "throw"), "hp": 3 if rush else 4, "state": "walk", "t": rng.randf_range(0, 0.4), "cd": rng.randf_range(0.9, 1.8), "stop": 0.0 if rush else rng.randf_range(230, 400), "speed": (110 if rush else 75) * rng.randf_range(0.9, 1.15), "face": -1 if side == "r" else 1, "entered": false, "wait": 0.0, "gone": 0.0, "flash": 0.0, "pending": false, "scale": 1.0, "segment": segment, "fly_time": 0.0}
	if kind == "tiny":
		enemy.scale = 0.6
		enemy.hp = 1
		enemy.speed = rng.randf_range(190, 230) + float(host.level.get("auto", 0)) * 1000
		host.status = "Small print! Crouch and shoot."
		if not bailiff_seen:
			bailiff_seen = true
			if host.has_method("hud_banner"): host.hud_banner("Small print!", "Too small to hit standing up. Crouch and shoot!", true)
	elif kind == "mini":
		enemy.scale = 1.75
		enemy.hp = 46 if participant_count > 1 else 32
		enemy.speed = 50
		enemy.stop = 280
		enemy.volley = 2.4
		host.status = "The Bailiff Bot. Keep shooting!"
		if host.has_method("hud_banner"): host.hud_banner("Mini boss!", "The Bailiff Bot. Keep shooting!", true)
		host.sfx("warn")
	elif kind == "fly":
		enemy.p.y = _flyer_floor(host) - rng.randf_range(190, 230)
		enemy.base_y = enemy.p.y
		enemy.hp = 2
		enemy.cd = rng.randf_range(1.2, 2.1)
		enemy.stop = rng.randf_range(60, 200)
		enemy.speed = 90 * rng.randf_range(0.9, 1.15)
		enemy.segment = [-100000, 1000000, enemy.p.y]
	enemy.max_hp = enemy.hp
	enemy.fly = kind == "fly"
	enemy.big = kind == "mini"
	host.enemies.append(enemy)

func _update_enemies(dt: float, host) -> void:
	for enemy in host.enemies.duplicate():
		if host.level_id == "1-6" and enemy.state != "pop" and host.abilities.enemy_is_bubbled(enemy): continue
		enemy.t += dt
		enemy.flash = maxf(0, enemy.flash - dt)
		if enemy.state == "pop":
			enemy.gone += dt
			continue
		if host.abilities != null and host.abilities.enemy_is_bubbled(enemy): continue
		if host.world_one.tick_enemy_hop(dt, enemy): continue
		var target := _nearest(host, enemy.p.x)
		if target.is_empty():
			enemy.state = "walk"
			continue
		var dx: float = target.p.x - enemy.p.x
		var distance := absf(dx)
		if dx != 0: enemy.face = signf(dx)
		if not enemy.entered and enemy.p.x > host.camera.x + 50 and enemy.p.x < host.camera.x + host.view_width() - 50: enemy.entered = true
		if enemy.state == "walk" and not enemy.entered:
			enemy.face = -1 if enemy.p.x > host.camera.x + host.view_width() / 2 else 1
			enemy.p.x += enemy.face * maxf(enemy.speed, 100) * dt
		elif enemy.state == "walk":
			if distance > enemy.stop + 10: enemy.p.x += signf(dx) * enemy.speed * dt
			elif enemy.stop > 0 and distance < enemy.stop - 80: enemy.p.x -= signf(dx) * enemy.speed * 0.6 * dt
			enemy.cd -= dt
			if enemy.stop > 0 and enemy.cd <= 0 and enemy.p.x > host.camera.x - 10 and enemy.p.x < host.camera.x + host.view_width() + 10:
				enemy.state = "throw"
				enemy.t = 0
				enemy.pending = true
		elif enemy.state == "throw":
			if enemy.t >= 0.22 and enemy.pending:
				enemy.pending = false
				host.sfx("throw")
				if enemy.type == "flat": _bill(host, enemy.p + Vector2(enemy.face * 30, -128), Vector2(enemy.face * 420, 0), 0, false, true)
				else: _bill(host, enemy.p + Vector2(enemy.face * 26, -100), Vector2(clampf(dx / 0.9, -500, 500), -780), 1700)
			if enemy.t >= 0.44:
				enemy.state = "walk"
				enemy.t = 0
				enemy.cd = rng.randf_range(1.4, 2.8)
		if enemy.entered: enemy.p.x = clampf(enemy.p.x, host.camera.x + 40, host.camera.x + host.view_width() - 40)
		if target.get("host_player", false): host.world_one.try_enemy_gap_hop(host, enemy)
		else: host.call_combat_participant(target, Callable(host.world_one, "try_enemy_gap_hop"), [host, enemy])
		if not enemy.has("hop"): enemy.p.x = clampf(enemy.p.x, float(enemy.segment[0]) + 22, float(enemy.segment[1]) - 22)
		for participant in _living(host):
			if absf(participant.p.x - enemy.p.x) < 44 and participant.p.y > enemy.p.y - 95 and participant.p.y < enemy.p.y + 24: _hurt(host, participant, enemy.p.x)
	# Source cleanup is global, except the ability wrapper temporarily removes
	# Binman-stage bubbled bots before both ordinary AI and cleanup.
	for enemy in host.enemies.duplicate():
		if host.level_id == "1-6" and enemy.state != "pop" and host.abilities.enemy_is_bubbled(enemy): continue
		if not enemy.entered and enemy.state != "pop":
			enemy.wait += dt
			if enemy.wait > 6: host.enemies.erase(enemy); continue
		if (enemy.state == "pop" and enemy.gone > 1.3) or enemy.p.x <= host.camera.x - 400 or enemy.p.x >= host.camera.x + host.view_width() + 400:
			host.enemies.erase(enemy)

func bob_flyers(dt: float, host) -> void:
	# Source sceneUpdate runs this after projectile collisions, not in enemy AI.
	for enemy in host.enemies:
		if enemy.kind == "fly" and enemy.state != "pop":
			enemy.fly_time += dt
			enemy.p.y = enemy.base_y + sin(enemy.fly_time / 0.38) * 14

func bailiff_volleys(dt: float, host) -> void:
	# New volley bills start moving next frame, after this frame's projectiles.
	for enemy in host.enemies:
		if enemy.kind != "mini" or enemy.state == "pop": continue
		enemy.volley -= dt
		if enemy.volley <= 0:
			enemy.volley = rng.randf_range(2.6, 3.5)
			var target := _nearest(host, enemy.p.x)
			if target.is_empty(): continue
			host.sfx("throw")
			for i in range(3): _bill(host, enemy.p + Vector2(enemy.face * 50, -200), Vector2(clampf(target.p.x + (i - 1) * 110 - enemy.p.x, -600, 600), -700 - i * 80), 1600, true)

func _bill(host, position: Vector2, speed: Vector2, gravity: float, big: bool = false, flat: bool = false) -> void:
	host.bullets.append({"p": position, "v": speed, "life": 20.0, "enemy": true, "gravity": gravity, "big": big, "flat": flat, "damage": 1})

func projectiles(dt: float, host) -> void:
	for bullet in host.bullets.duplicate():
		var before: Vector2 = bullet.p
		if not bullet.enemy and bullet.get("first_frame", false):
			before.x = _shot_owner_x(host, bullet)
			bullet.first_frame = false
		if not bullet.enemy and bullet.get("homing", false):
			var target: Dictionary = {}
			for enemy in host.enemies:
				if enemy.state == "pop": continue
				if target.is_empty() or absf(enemy.p.x - bullet.p.x) < absf(target.p.x - bullet.p.x): target = enemy
			if not target.is_empty() and signf(target.p.x - bullet.p.x) == signf(bullet.v.x): bullet.v.y = clampf(bullet.v.y + signf(target.p.y - 60 - bullet.p.y) * 1200 * dt, -300, 300)
		bullet.v.y += float(bullet.get("gravity", 0)) * dt
		bullet.p += bullet.v * dt
		bullet.life -= dt
		if bullet.get("dead", false): bullet.life = 0
		if bullet.life <= 0:
			host.bullets.erase(bullet)
			continue
		if bullet.enemy:
			for participant in _living(host):
				var height: float = participant.height * (0.56 if participant.crouching else 0.86)
				if absf(bullet.p.x - participant.p.x) < 26 and bullet.p.y > participant.p.y - height and bullet.p.y < participant.p.y:
					_hurt(host, participant, bullet.p.x - bullet.v.x * 0.1)
					bullet.life = 0
			if bullet.v.y > 0 and host._land(bullet.p.x, before.y + 6, bullet.p.y + 6) != INF:
				bullet.life = 0
				if host.has_method("fx_puff"): host.fx_puff(bullet.p, Color("a8d79a"), 4, 150)
		else:
			for enemy in host.enemies:
				if enemy.state == "pop": continue
				if enemy.p.x > minf(before.x, bullet.p.x) - 34 and enemy.p.x < maxf(before.x, bullet.p.x) + 34 and bullet.p.y > enemy.p.y - 112 * enemy.scale and bullet.p.y < enemy.p.y:
					damage_enemy(host, enemy, int(bullet.get("damage", 1)), _shot_owner_slot(host, bullet))
					if host.has_method("fx_puff"): host.fx_puff(bullet.p, Color.WHITE, 4, 200)
					enemy.p.x += signf(bullet.v.x + 0.0001) * 6
					bullet.life = 0
					break
			if bullet.life > 0 and host.boss != null and host.boss.hit(bullet.p, int(bullet.get("damage", 1))):
				bullet.life = 0
				if host.boss.has_method("drain_events"):
					for event in host.boss.drain_events(): host._boss_event(event)
			if bullet.life > 0:
				for crate in host.crates:
					if not crate.broken and absf(bullet.p.x - crate.p.x) < 34 and bullet.p.y > crate.p.y - 70 and bullet.p.y < crate.p.y:
						hit_crate(host, crate, 1)
						bullet.life = 0
						break
		if host.ability_inside_wall(bullet.p):
			if bullet.life > 0 and host.has_method("fx_puff"): host.fx_puff(bullet.p, Color("a8d79a") if bullet.enemy else Color.WHITE, 4 if bullet.enemy else 3, 150)
			bullet.life = 0
		if host.level_id == "1-6" and not bullet.enemy:
			# Source player shots are filtered before the later Binman-bin pass.
			# Positions use Vector2 precision; compare the boundary on that same
			# grid so a representable point exactly on the edge is excluded.
			var top := Vector2(0, host.view_top() - 60).y
			if bullet.p.x <= host.camera.x - 40 or bullet.p.x >= host.camera.x + host.view_width() + 40 or bullet.p.y <= top or bullet.p.y >= host.camera.y + 580: bullet.life = 0
		var margin := 60 if bullet.enemy else 40
		if bullet.p.x < host.camera.x - margin or bullet.p.x > host.camera.x + host.view_width() + margin: bullet.life = 0
		if bullet.p.y > float(host.level.get("fall", 882)): bullet.life = 0
		# Source hostile bills arc above the viewport and return. Only player
		# projectiles use the upper view bound.
		if not bullet.enemy and bullet.p.y < host.view_top() - 60: bullet.life = 0
		if bullet.life <= 0: host.bullets.erase(bullet)

func damage_enemy(host, enemy: Dictionary, damage: int, owner_slot: int = -1) -> void:
	if enemy.state == "pop": return
	enemy.hp -= damage
	enemy.flash = 0.09
	host.sfx("hitBot")
	if enemy.hp > 0: return
	kill_enemy(host, enemy, true, owner_slot)

func kill_enemy(host, enemy: Dictionary, credited: bool = true, owner_slot: int = -1) -> void:
	if enemy.state == "pop": return
	enemy.state = "pop"
	enemy.t = 0
	enemy.gone = 0
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

func _pickups(dt: float, host) -> void:
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
				else: coin.rest = true; coin.v.y = 0
		for participant in _living(host):
			var delta_p: Vector2 = participant.p - Vector2(0, participant.height * 0.4) - coin.p
			if absf(delta_p.x) < 110 and absf(delta_p.y) < 150 and coin.age > 0.25:
				coin.p.x += signf(delta_p.x) * minf(absf(delta_p.x), 500 * dt)
				if coin.rest and absf(delta_p.y) > 40: coin.rest = false; coin.v.y = -200
			if absf(delta_p.x) < 30 and absf(delta_p.y) < participant.height * 0.6 and coin.age > 0.25:
				host.score += 1
				if not participant.get("host_player", false): participant.coins = int(participant.get("coins", 0)) + 1
				if host.has_method("fx_coin"): host.fx_coin(coin.p)
				host.coins.erase(coin)
				host.sfx("pick")
				break
		if coin.age >= 11 or coin.p.x <= host.camera.x - 60 or coin.p.y > host.level.get("fall", 882): host.coins.erase(coin)
	for item in host.items.duplicate():
		item.age += dt
		if not item.rest:
			var old_y: float = item.p.y
			item.vy += 2000 * dt
			item.p.y += item.vy * dt
			var floor_y: float = host._land(item.p.x, old_y + 26, item.p.y + 26) if item.vy > 0 else INF
			if floor_y != INF: item.p.y = floor_y - 26; item.vy = 0; item.rest = true
		for participant in _living(host):
			if absf(participant.p.x - item.p.x) < 40 and item.age > 0.3:
				_grant_item(host, participant, item.give)
				if host.has_method("fx_item"): host.fx_item(item.p, item.give)
				host.items.erase(item)
				host.sfx("power")
				break
		if item.p.y > host.level.get("fall", 882): host.items.erase(item)

func _living(host) -> Array:
	# Native solo uses host state. A future co-op adapter can supply mutable
	# records with p/hearts/down/height/crouching and a hurt_combat_participant
	# callback. The count passed to reset only controls wave/HP scaling.
	if host.has_method("combat_participants"):
		return host.combat_participants().filter(func(player): return not player.get("down", false) and int(player.hearts) > 0)
	if host.hearts <= 0: return []
	return [{"host_player": true, "p": host.player, "hearts": host.hearts, "height": host.character_height(), "crouching": host.crouching, "grounded": host.grounded}]

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

func _flyer_floor(host) -> float:
	return host.world_one.flyer_floor(host)

func _shot_owner_slot(host, shot: Dictionary) -> int:
	if shot.has("owner_slot"): return int(shot.owner_slot)
	if host.has_method("combat_participants") and host.combat_participants().any(func(player): return not player.get("host_player", false)): return -2
	return -1

func _shot_owner_x(host, shot: Dictionary) -> float:
	if shot.has("owner_slot") and host.has_method("combat_participants"):
		for participant in host.combat_participants():
			if int(participant.get("slot", -2)) == int(shot.owner_slot): return float(participant.p.x)
	return float(shot.get("owner_x", host.player.x))

func _credit_pop(host, owner_slot: int) -> void:
	if owner_slot == -2: return # Unowned source/environment projectile.
	if host.has_method("credit_combat_pop"): host.credit_combat_pop(owner_slot)
	else: host.pop_count += 1
