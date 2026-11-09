extends RefCounted
## Source World 1 scene state, in absolute feet coordinates and seconds.
## Combat still owns waves, enemies, projectiles, crate drops and checkpoints.
## See docs/WORLD_ONE_PARITY.md for the host contract and required hook order.
const SCENE_LEVELS := ["1-1", "1-2", "1-3", "1-4", "1-5", "1-6", "1-S"]
const TIMED_EXITS := ["1-2", "1-4", "1-5", "1-S"]

var level_id := ""
var crumbles: Array = []
var end_time := 0.0
var clear_reported := false
var boss_requested := false
var safe_position := Vector2.ZERO
var next_coin := 700.0
var coin_pattern := 0

func reset(host) -> void:
	level_id = host.level_id
	crumbles.clear()
	end_time = 0.0
	clear_reported = false
	boss_requested = false
	safe_position = host.player
	next_coin = 700.0
	coin_pattern = 0
	for row in host.level.get("crumble", []):
		# Keep the imported level immutable. Fallen slates leave the collision set.
		crumbles.append({"row": row.duplicate(), "t": 0.0, "fall": 0.0})

func supports(id: String) -> bool:
	return id in SCENE_LEVELS

func surfaces(host, skip_platforms: bool = false) -> Array:
	var result: Array = []
	for row in host.level.get("solids", []): result.append({"row": row, "plat": false})
	if not skip_platforms:
		for row in host.level.get("plats", []): result.append({"row": row, "plat": true})
		for slate in crumbles:
			if slate.fall == 0: result.append({"row": slate.row, "plat": true, "crumble": true})
	return result

func land_on(host, x: float, old_y: float, new_y: float, skip_platforms: bool = false) -> Dictionary:
	var best: Dictionary = {}
	for surface in surfaces(host, skip_platforms):
		var row: Array = surface.row
		if x >= float(row[0]) and x <= float(row[1]) and float(row[2]) >= old_y - 1 and float(row[2]) <= new_y + 0.5:
			if best.is_empty() or float(row[2]) < float(best.row[2]): best = surface
	return best

func below(host, x: float, from_y: float) -> Dictionary:
	var best: Dictionary = {}
	for surface in surfaces(host):
		var row: Array = surface.row
		if x >= float(row[0]) and x <= float(row[1]) and float(row[2]) >= from_y - 2:
			if best.is_empty() or float(row[2]) < float(best.row[2]): best = surface
	return best

func after_motion(host) -> void:
	# Source p.safe differs from a checkpoint flag: falling returns to the
	# latest interior of a solid roof, never to a one-way or crumbling platform.
	if not host.grounded or host.on_platform: return
	var surface := below(host, host.player.x, host.player.y)
	if surface.is_empty(): return
	var row: Array = surface.row
	if host.player.x > float(row[0]) + 90 and host.player.x < float(row[1]) - 90:
		safe_position = host.player

func recover_from_fall(host) -> void:
	var x := clampf(safe_position.x, host.camera.x + 70, host.camera.x + host.view_width() - 70)
	var surface: Dictionary = {}
	for i in range(60):
		var test_x := x + i * 20
		var candidate := below(host, test_x, host.view_top() - 200)
		if candidate.is_empty(): continue
		var row: Array = candidate.row
		if test_x > float(row[0]) + 30 and test_x < float(row[1]) - 30 and test_x < host.camera.x + host.view_width() - 40:
			surface = candidate
			x = test_x
			break
	if surface.is_empty(): surface = below(host, x, -9999)
	if surface.is_empty():
		var available := surfaces(host)
		if available.is_empty(): return
		surface = available[0]
	host.player = Vector2(x, float(surface.row[2]))
	host.velocity.y = 0
	host.grounded = true
	host.on_platform = surface.plat
	host.invincible = 0
	host.hurt_player(x - host.face)
	host.velocity.x = 0
	host.status = "Mind the gap!"

func after_camera(dt: float, host) -> void:
	# Base following happens first. Auto-scroll ignores a wave camera lock.
	if host.mode != "play" or host.boss != null or _living(host).is_empty(): return
	var speed := float(host.level.get("auto", 0)) * 1000
	if speed <= 0: return
	host.camera.x = minf(float(host.level.w) - host.view_width(), host.camera.x + speed * dt)
	host.camera_speed = 0

func objective_tick(dt: float, host) -> String:
	# Call immediately after waves, BEFORE enemy/projectile/scene updates, as in
	# updatePlay. Events are one-shot; the host owns banners, music and saving.
	if host.mode != "play" or _living(host).is_empty() or clear_reported: return ""
	var event := ""
	if end_time == 0 and host.boss == null and host.camera.x >= float(host.level.w) - host.view_width() - 2 and host.combat.waves.all(func(wave): return wave.done):
		if level_id in ["1-1", "1-6"]:
			if not boss_requested:
				boss_requested = true
				return "boss"
		elif level_id in TIMED_EXITS:
			end_time = 0.001 # Source endT=1 millisecond, then adds this frame's dt.
			event = "ending"
		# 1-3 has its own bus_ride.gd timeline and objective; never clear it here.
	if end_time > 0:
		end_time += dt
		if end_time > 2.6:
			clear_reported = true
			return "clear"
	return event

func tick(dt: float, host) -> void:
	# Convenience for isolated scene-state tests. An integrated host uses the
	# three hooks below, interleaving combat bob/volleys and movement pickups.
	if host.mode != "play": return
	crumble_step(dt, host)
	chimney_step(host)
	after_pickups(host)

func crumble_step(dt: float, host) -> void:
	if host.mode != "play": return
	_update_crumbles(dt, host)

func chimney_step(host) -> void:
	if host.mode != "play": return
	_schedule_chimney_hops(host)

func after_pickups(host) -> void:
	if host.mode != "play": return
	_update_auto_walls(host)
	if level_id == "1-S": _spawn_bonus_coins(host)

func _update_crumbles(dt: float, host) -> void:
	for slate in crumbles:
		if slate.fall > 0:
			slate.fall += dt
			if slate.fall > 5.2:
				slate.fall = 0.0
				slate.t = 0.0
			continue
		var row: Array = slate.row
		var on: bool = _living(host).any(func(player): return player.grounded and absf(player.p.y - float(row[2])) < 3 and player.p.x >= float(row[0]) and player.p.x <= float(row[1]))
		if on or slate.t > 0: slate.t += dt
		if slate.t > 0.65:
			slate.fall = 0.001
			for player in _participants(host):
				if player.grounded and player.p.x >= float(row[0]) and player.p.x <= float(row[1]) and absf(player.p.y - float(row[2])) < 3:
					if player.get("host_player", false):
						host.grounded = false
						host.velocity.y = 50
					else:
						player.grounded = false
						player.velocity.y = 50
			for enemy in host.enemies:
				if enemy.state != "pop" and enemy.get("segment", []) == row: _kill_environment_enemy(host, enemy)
			host.sfx("stomp")

func flyer_floor(host) -> float:
	# Source chooses the lowest supporting feet among grounded living players.
	# A falling actor must not drag flyers down out of reach.
	var grounded_players: Array = _living(host).filter(func(player): return player.grounded)
	if not grounded_players.is_empty():
		var floor_y := -INF
		for player in grounded_players:
			var surface := below(host, player.p.x, player.p.y - 2)
			floor_y = maxf(floor_y, float(surface.row[2]) if not surface.is_empty() else float(player.p.y))
		return floor_y
	var middle := below(host, host.camera.x + host.view_width() / 2, -9999)
	return float(middle.row[2]) if not middle.is_empty() else float(host.meta.ground)

func tick_enemy_hop(dt: float, enemy: Dictionary) -> bool:
	if enemy.get("hop", {}) == null or enemy.get("hop", {}).is_empty(): return false
	var hop: Dictionary = enemy.hop
	hop.t += dt
	var fraction := minf(1, hop.t / hop.duration)
	enemy.p = hop.start.lerp(hop.finish, fraction)
	enemy.p.y -= sin(PI * fraction) * (70 + maxf(0, hop.start.y - hop.finish.y) * 0.6)
	if fraction >= 1:
		enemy.segment = hop.segment
		enemy.p.y = float(hop.segment[2])
		enemy.erase("hop")
	return true

func try_enemy_gap_hop(host, enemy: Dictionary) -> void:
	# Hook after entered-screen clamp, before segment-edge clamp. The original
	# updateBots evaluates this before its contact-damage check.
	if not enemy.get("entered", false) or enemy.state != "walk" or enemy.get("kind", "") == "fly" or enemy.has("hop"): return
	var segment: Array = enemy.get("segment", [])
	if segment.size() < 3 or host.hearts <= 0: return
	var dx: float = host.player.x - enemy.p.x
	var direction := signf(dx)
	var edge := float(segment[1] if direction > 0 else segment[0])
	if absf(dx) <= 30 or absf(enemy.p.x - edge) >= 26: return
	var best: Array = []
	for row in host.level.get("solids", []):
		if row == segment or float(row[1]) - float(row[0]) <= 200 or absf(float(row[2]) - enemy.p.y) >= 230: continue
		var eligible := float(row[0]) >= float(segment[1]) - 4 and float(row[0]) - float(segment[1]) < 230 if direction > 0 else float(row[1]) <= float(segment[0]) + 4 and float(segment[0]) - float(row[1]) < 230
		if not eligible: continue
		if best.is_empty() or (float(row[0]) < float(best[0]) if direction > 0 else float(row[1]) > float(best[1])): best = row
	if best.is_empty(): return
	var x := float(best[0]) + 40 if direction > 0 else float(best[1]) - 40
	_start_hop(enemy, best, x, 0.52 + absf(x - enemy.p.x) * 0.0012, direction)

func _schedule_chimney_hops(host) -> void:
	if _living(host).is_empty(): return
	for enemy in host.enemies:
		if enemy.get("kind", "") == "fly" or enemy.has("hop") or enemy.state != "walk" or enemy.get("segment", []).is_empty(): continue
		var player := _nearest(host, enemy.p.x)
		if player.is_empty(): continue
		var direction := signf(float(player.p.x) - enemy.p.x)
		if direction == 0: direction = 1
		for row in host.level.get("solids", []):
			if row == enemy.segment or float(row[2]) > enemy.p.y - 20 or float(row[1]) - float(row[0]) > 260 or float(row[1]) < enemy.p.x - 60 or float(row[0]) > enemy.p.x + 60: continue
			var inside: bool = enemy.p.x > float(row[0]) - 4 and enemy.p.x < float(row[1]) + 4
			var blocked: bool = float(row[0]) - enemy.p.x >= -4 and float(row[0]) - enemy.p.x < 30 and player.p.x > float(row[1]) if direction > 0 else enemy.p.x - float(row[1]) >= -4 and enemy.p.x - float(row[1]) < 30 and player.p.x < float(row[0])
			if not inside and not blocked: continue
			var x := float(row[1]) + 34 if direction > 0 else float(row[0]) - 34
			var landing := below(host, x, enemy.p.y - 6)
			if landing.is_empty() or float(landing.row[2]) > enemy.p.y + 40 or float(landing.row[2]) < enemy.p.y - 40: continue
			_start_hop(enemy, landing.row, x, 0.65 + absf(x - enemy.p.x) * 0.0015, direction)
			break

func _start_hop(enemy: Dictionary, segment: Array, x: float, duration: float, direction: float) -> void:
	enemy.face = direction
	enemy.hop = {"start": enemy.p, "finish": Vector2(x, float(segment[2])), "t": 0.0, "duration": duration, "segment": segment}

func _kill_environment_enemy(host, enemy: Dictionary) -> void:
	enemy.state = "pop"
	enemy.t = 0
	enemy.gone = 0
	host.add_coins(enemy.p - Vector2(0, 70), 4 + host.combat.rng.randi_range(0, 2))
	host.sfx("pop")

func _update_auto_walls(host) -> void:
	if not host.level.get("auto", 0): return
	for player in _living(host):
		# Source takes feet once per actor even if overlapping solids lift twice.
		var feet: float = player.p.y
		for row in host.level.get("solids", []):
			if player.p.x > float(row[0]) - 2 and player.p.x < float(row[1]) + 2 and feet > float(row[2]) + 4 and float(row[2]) < feet:
				if player.get("host_player", false):
					host.player.y = float(row[2])
					host.velocity.y = 0
					host.grounded = true
					host.on_platform = false
				else:
					player.p.y = float(row[2])
					player.velocity.y = 0
					player.grounded = true
					player.on_platform = false

func _spawn_bonus_coins(host) -> void:
	while next_coin < host.camera.x + host.view_width() + 120:
		var pattern := coin_pattern % 4
		coin_pattern += 1
		for i in range(8):
			var y := float(host.meta.ground)
			match pattern:
				0: y -= 40
				1: y -= 70 + sin(i / 7.0 * PI) * 170
				2: y -= 200
				3: y -= 40 + (i % 2) * 80
			host.coins.append({"p": Vector2(next_coin + i * 46, y), "v": Vector2.ZERO, "age": 0.26, "rest": true})
		next_coin += 560

func _participants(host) -> Array:
	if host.has_method("combat_participants"): return host.combat_participants()
	return [{"host_player": true, "p": host.player, "hearts": host.hearts,
		"grounded": host.grounded, "velocity": host.velocity, "on_platform": host.on_platform}]

func _living(host) -> Array:
	return _participants(host).filter(func(player): return not player.get("down", false) and int(player.hearts) > 0)

func _nearest(host, x: float) -> Dictionary:
	var best: Dictionary = {}
	for player in _living(host):
		if best.is_empty() or absf(player.p.x - x) < absf(best.p.x - x): best = player
	return best
